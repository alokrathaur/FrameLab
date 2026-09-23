import Foundation
import SwiftUI
import CoreMedia
import CoreVideo
import AVFoundation

/// Shared @MainActor presentation view model governing playback, processing, metrics, and state.
@MainActor
public final class VideoPlayerViewModel: ObservableObject {
    // Media and playback state
    @Published public private(set) var metadata: VideoMetadata?
    @Published public private(set) var currentFrame: ProcessedFrame?
    @Published public private(set) var previewImage: CGImage?
    @Published public var activeFilter: FilterType = .original {
        didSet {
            if activeFilter != oldValue {
                Task { await reprocessCurrentFrame() }
            }
        }
    }
    @Published public private(set) var isPlaying: Bool = false
    @Published public var playbackProgress: Double = 0.0
    @Published public private(set) var currentTimeFormatted: String = "00:00.000"

    // Engineering performance metrics
    @Published public private(set) var currentLatencyMs: Double = 0.0
    @Published public private(set) var framesProcessedCount: Int64 = 0
    @Published public private(set) var framesDroppedCount: Int64 = 0

    // Loading & Error states
    @Published public private(set) var isLoading: Bool = false
    @Published public var errorMessage: String? = nil

    // UI presentation flags
    @Published public var showBenchmarkSheet: Bool = false
    @Published public var isDraggingOver: Bool = false
    @Published public var showMetadataSheet: Bool = false
    @Published public var exportData: Data? = nil

    // Benchmark state
    @Published public private(set) var isBenchmarking: Bool = false
    @Published public private(set) var benchmarkProgress: Double = 0.0
    @Published public private(set) var benchmarkReport: BenchmarkReport? = nil

    // Internal services
    private let assetService = VideoAssetService()
    private let exporter = FrameExporter()
    private let benchmarkRunner = BenchmarkRunner()
    private var frameReader: VideoFrameReader?
    private var playbackTask: Task<Void, Never>?
    private var lastRawPixelBuffer: CVPixelBuffer?
    private var lastRawTime: CMTime = .zero

    public init() {}

    // MARK: - Video Loading

    public func loadVideo(from url: URL) async {
        stopPlayback()
        isLoading = true
        errorMessage = nil

        do {
            let meta = try await assetService.extractMetadata(from: url)
            self.metadata = meta
            let reader = VideoFrameReader(url: url)
            self.frameReader = reader

            // Seek and display the first frame
            if let firstFrame = try await reader.seekFrame(at: .zero) {
                self.lastRawPixelBuffer = firstFrame.pixelBuffer
                self.lastRawTime = firstFrame.presentationTime
                await reprocessCurrentFrame()
            }
            self.isLoading = false
        } catch {
            self.isLoading = false
            self.errorMessage = error.localizedDescription
        }
    }

    /// Loads a built-in synthetic test video (SMPTE color bars) for instant inspection without external files.
    public func loadSyntheticDemo() async {
        stopPlayback()
        isLoading = true
        errorMessage = nil

        do {
            let tempDir = FileManager.default.temporaryDirectory
            let testVideoURL = tempDir.appendingPathComponent("framelab_demo_bars.mp4")
            _ = try await PixelBufferTestUtilities.createSyntheticVideo(
                at: testVideoURL,
                durationSeconds: 3.0,
                fps: 30,
                width: 640,
                height: 360
            )
            await loadVideo(from: testVideoURL)
        } catch {
            self.isLoading = false
            self.errorMessage = "Failed to create synthetic demo: \(error.localizedDescription)"
        }
    }

    // MARK: - Playback Controls

    public func togglePlay() {
        if isPlaying {
            pause()
        } else {
            play()
        }
    }

    public func play() {
        guard !isPlaying, let reader = frameReader, let meta = metadata else { return }
        isPlaying = true

        let startTime: CMTime
        if playbackProgress >= 0.99 {
            startTime = .zero
            playbackProgress = 0.0
        } else {
            let seconds = playbackProgress * meta.durationSeconds
            startTime = CMTime(seconds: seconds, preferredTimescale: 600)
        }

        let timeRange = CMTimeRange(start: startTime, duration: meta.duration)

        playbackTask = Task.detached(priority: .userInitiated) { [weak self, reader, activeFilter] in
            let processor = ProcessorFactory.makeProcessor(for: activeFilter)
            let stream = reader.frames(timeRange: timeRange)

            do {
                for try await frame in stream {
                    if Task.isCancelled { break }

                    let processed = try await processor.process(
                        frame.pixelBuffer,
                        presentationTime: frame.presentationTime
                    )

                    await MainActor.run { [weak self] in
                        guard let self = self, self.isPlaying else { return }
                        self.applyProcessedFrame(processed, rawBuffer: frame.pixelBuffer)
                    }

                    // Throttle playback rate to match nominal FPS
                    let frameIntervalNs = UInt64(1_000_000_000.0 / Double(max(1.0, meta.nominalFrameRate)))
                    try? await Task.sleep(nanoseconds: frameIntervalNs)
                }
            } catch {
                await MainActor.run { [weak self] in
                    if !(error is CancellationError) {
                        self?.errorMessage = error.localizedDescription
                    }
                }
            }

            await MainActor.run { [weak self] in
                self?.isPlaying = false
            }
        }
    }

    public func pause() {
        stopPlayback()
    }

    public func seek(to progress: Double) async {
        stopPlayback()
        playbackProgress = max(0.0, min(progress, 1.0))

        guard let reader = frameReader, let meta = metadata else { return }
        let targetSeconds = playbackProgress * meta.durationSeconds
        let targetTime = CMTime(seconds: targetSeconds, preferredTimescale: 600)

        do {
            if let frame = try await reader.seekFrame(at: targetTime) {
                self.lastRawPixelBuffer = frame.pixelBuffer
                self.lastRawTime = frame.presentationTime
                await reprocessCurrentFrame()
            }
        } catch {
            self.errorMessage = "Seek error: \(error.localizedDescription)"
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playbackTask?.cancel()
        playbackTask = nil
        frameReader?.cancel()
    }

    // MARK: - Frame Processing

    private func reprocessCurrentFrame() async {
        guard let rawBuffer = lastRawPixelBuffer else { return }

        let processor = ProcessorFactory.makeProcessor(for: activeFilter)
        do {
            let processed = try await processor.process(rawBuffer, presentationTime: lastRawTime)
            applyProcessedFrame(processed, rawBuffer: rawBuffer)
        } catch {
            self.errorMessage = "Processing error: \(error.localizedDescription)"
        }
    }

    private func applyProcessedFrame(_ frame: ProcessedFrame, rawBuffer: CVPixelBuffer) {
        self.lastRawPixelBuffer = rawBuffer
        self.lastRawTime = frame.presentationTime
        self.currentFrame = frame
        self.currentLatencyMs = frame.processingLatencyMs
        self.framesProcessedCount += 1
        self.currentTimeFormatted = frame.presentationTime.formattedTimeString

        if let meta = metadata, meta.durationSeconds > 0 && frame.presentationTime.isValid {
            self.playbackProgress = max(0.0, min(frame.presentationTime.seconds / meta.durationSeconds, 1.0))
        }

        self.previewImage = exporter.createCGImage(from: frame.pixelBuffer)
    }

    // MARK: - Benchmarking

    public func runBenchmark() async {
        guard let rawBuffer = lastRawPixelBuffer else {
            errorMessage = "No frame loaded to benchmark."
            return
        }

        isBenchmarking = true
        benchmarkProgress = 0.0
        errorMessage = nil

        do {
            let report = try await benchmarkRunner.run(
                on: rawBuffer,
                iterations: 25,
                warmupIterations: 5,
                progress: { [weak self] p in
                    Task { @MainActor in
                        self?.benchmarkProgress = p
                    }
                }
            )
            self.benchmarkReport = report
            self.isBenchmarking = false
        } catch {
            self.isBenchmarking = false
            self.errorMessage = "Benchmark failed: \(error.localizedDescription)"
        }
    }

    // MARK: - Export

    public func exportCurrentFrame(format: ImageExportFormat = .png) -> Data? {
        guard let frame = currentFrame else { return nil }
        return try? exporter.exportToData(pixelBuffer: frame.pixelBuffer, format: format)
    }

    public func exportCurrentFrame(to url: URL, format: ImageExportFormat = .png) throws {
        guard let frame = currentFrame else {
            throw FrameLabError.exportFailed("No active frame to export.")
        }
        try exporter.export(pixelBuffer: frame.pixelBuffer, to: url, format: format)
    }
}
