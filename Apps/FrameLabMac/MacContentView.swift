#if os(macOS)
import SwiftUI
import FrameLabCore
import UniformTypeIdentifiers

@MainActor
public struct MacContentView: View {
    @ObservedObject private var viewModel: VideoPlayerViewModel

    public init(viewModel: VideoPlayerViewModel) {
        self.viewModel = viewModel
    }

    public init() {
        self.viewModel = VideoPlayerViewModel()
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Main video viewport
            viewportSection
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black.opacity(0.95))

            Divider()

            // Playback scrubber bar
            scrubberSection
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Bottom engineering metrics dashboard
            engineeringDashboardSection
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 900, minHeight: 650)
        .toolbar {
            toolbarContent
        }
        .sheet(isPresented: $viewModel.showBenchmarkSheet) {
            MacBenchmarkSheet(
                report: viewModel.benchmarkReport,
                isRunning: viewModel.isBenchmarking,
                progress: viewModel.benchmarkProgress,
                onRerun: {
                    Task { await viewModel.runBenchmark() }
                }
            )
        }
        .onDrop(of: [.fileURL], isTargeted: $viewModel.isDraggingOver) { providers in
            handleDrop(providers: providers)
        }
        .alert("Notice", isPresented: Binding(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    // MARK: - Viewport

    @ViewBuilder
    private var viewportSection: some View {
        ZStack {
            if let cgImage = viewModel.previewImage {
                Image(decorative: cgImage, scale: 1.0, orientation: .up)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Decoding Video Stream...")
                        .font(.headline)
                        .foregroundColor(.gray)
                }
            } else {
                emptyStateView
            }

            // HUD Overlay for active filter and latency
            if viewModel.metadata != nil {
                VStack {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Engine: \(viewModel.activeFilter.rawValue)")
                                .font(.system(.caption, design: .monospaced).bold())
                                .foregroundColor(.white)
                            Text("Frame Latency: \(String(format: "%.2f ms", viewModel.currentLatencyMs))")
                                .font(.system(.caption2, design: .monospaced))
                                .foregroundColor(.yellow)
                        }
                        .padding(8)
                        .background(.ultraThinMaterial.opacity(0.85))
                        .cornerRadius(6)

                        Spacer()
                    }
                    .padding(12)
                    Spacer()
                }
            }

            if viewModel.isDraggingOver {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.accentColor, lineWidth: 3)
                    .background(Color.accentColor.opacity(0.1))
                    .padding(8)
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film.stack")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            Text("FrameLab Video Engine")
                .font(.title.bold())
            Text("Select a local video file, drag and drop, or launch the color-bars demo.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            HStack(spacing: 16) {
                Button(action: openVideoDialog) {
                    Label("Open Video...", systemImage: "folder")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)

                Button(action: loadDemo) {
                    Label("Try SMPTE Bars Demo", systemImage: "play.rectangle.on.rectangle")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 8)
        }
        .padding(40)
    }

    // MARK: - Scrubber

    private var scrubberSection: some View {
        HStack(spacing: 14) {
            Button(action: { viewModel.togglePlay() }) {
                Image(systemName: viewModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 16))
            }
            .disabled(viewModel.metadata == nil)
            .keyboardShortcut(.space, modifiers: [])

            Text(viewModel.currentTimeFormatted)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

            Slider(
                value: Binding(
                    get: { viewModel.playbackProgress },
                    set: { newVal in
                        Task { await viewModel.seek(to: newVal) }
                    }
                ),
                in: 0.0...1.0
            )
            .disabled(viewModel.metadata == nil)

            Text(viewModel.metadata?.formattedDuration ?? "00:00.000")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Dashboard

    private var engineeringDashboardSection: some View {
        HStack(alignment: .top, spacing: 20) {
            videoPropertiesCard
            processingPipelineCard
        }
    }

    private var videoPropertiesCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "video.fill")
                    .foregroundColor(.blue)
                Text("Video Properties")
                    .font(.headline)
            }
            Divider()

            if let meta = viewModel.metadata {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Resolution:").foregroundColor(.secondary)
                        Text(meta.resolutionString).bold()
                        Spacer()
                        Text("Nominal FPS:").foregroundColor(.secondary)
                        Text(meta.formattedFrameRate).bold()
                    }
                    HStack {
                        Text("Codec:").foregroundColor(.secondary)
                        Text(meta.videoCodec).bold()
                        Spacer()
                        Text("Bitrate:").foregroundColor(.secondary)
                        Text(meta.formattedBitrate)
                    }
                    HStack {
                        Text("Color Space:").foregroundColor(.secondary)
                        Text(meta.colorSpace)
                        Spacer()
                        Text("File Size:").foregroundColor(.secondary)
                        Text(meta.formattedFileSize)
                    }
                }
                .font(.caption)
            } else {
                Text("No video loaded.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    private var processingPipelineCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "cpu")
                    .foregroundColor(.purple)
                Text("Processing & Telemetry")
                    .font(.headline)
            }
            Divider()

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Active Pipeline:").foregroundColor(.secondary)
                    Text(viewModel.activeFilter.rawValue).bold()
                    Spacer()
                    Text("Frame Latency:").foregroundColor(.secondary)
                    Text(String(format: "%.2f ms", viewModel.currentLatencyMs))
                        .bold()
                        .foregroundColor(viewModel.currentLatencyMs < 8.0 ? .green : .orange)
                }
                HStack {
                    Text("Frames Decoded:").foregroundColor(.secondary)
                    Text("\(viewModel.framesProcessedCount)")
                    Spacer()
                    Text("Frames Dropped:").foregroundColor(.secondary)
                    Text("\(viewModel.framesDroppedCount)")
                }
                HStack {
                    Text("Engine State:").foregroundColor(.secondary)
                    Text(viewModel.isPlaying ? "Streaming" : (viewModel.metadata != nil ? "Ready" : "Idle"))
                        .foregroundColor(viewModel.isPlaying ? .green : .secondary)
                    Spacer()
                    Text("Zero-Copy GPU:").foregroundColor(.secondary)
                    Text(viewModel.activeFilter == .metal ? "CVMetalTextureCache" : "CPU Active")
                        .foregroundColor(.blue)
                }
            }
            .font(.caption)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItemGroup(placement: .automatic) {
            Button(action: openVideoDialog) {
                Label("Open Video", systemImage: "folder")
            }
            .help("Open local video file (Cmd+O)")
            .keyboardShortcut("o", modifiers: .command)

            Button(action: loadDemo) {
                Label("Color Bars Demo", systemImage: "play.rectangle.on.rectangle")
            }
            .help("Load synthetic test video")

            Picker("Filter Engine", selection: $viewModel.activeFilter) {
                ForEach(FilterType.allCases) { filter in
                    Text(filter.shortName).tag(filter)
                }
            }
            .pickerStyle(.segmented)
            .disabled(viewModel.metadata == nil)
            .help("Select processing implementation")

            Button(action: {
                viewModel.showBenchmarkSheet = true
                if viewModel.benchmarkReport == nil {
                    Task { await viewModel.runBenchmark() }
                }
            }) {
                Label("Benchmark", systemImage: "gauge.with.needle")
            }
            .disabled(viewModel.metadata == nil)
            .help("Run multi-backend latency benchmark (Cmd+B)")
            .keyboardShortcut("b", modifiers: .command)

            Button(action: exportCurrentFrame) {
                Label("Export Frame", systemImage: "square.and.arrow.up")
            }
            .disabled(viewModel.currentFrame == nil)
            .help("Export current processed frame (Cmd+E)")
            .keyboardShortcut("e", modifiers: .command)
        }
    }

    // MARK: - Actions

    private func openVideoDialog() {
        if let url = MacFilePicker.pickVideoFile() {
            Task { await viewModel.loadVideo(from: url) }
        }
    }

    private func loadDemo() {
        Task { await viewModel.loadSyntheticDemo() }
    }

    private func exportCurrentFrame() {
        if let saveURL = MacFilePicker.pickExportLocation() {
            do {
                try viewModel.exportCurrentFrame(to: saveURL, format: .png)
            } catch {
                viewModel.errorMessage = "Export failed: \(error.localizedDescription)"
            }
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first else { return false }
        _ = provider.loadObject(ofClass: URL.self) { url, _ in
            if let validURL = url {
                Task { @MainActor in
                    await self.viewModel.loadVideo(from: validURL)
                }
            }
        }
        return true
    }
}
#endif
