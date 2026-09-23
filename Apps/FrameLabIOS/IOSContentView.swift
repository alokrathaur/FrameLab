#if os(iOS)
import SwiftUI
import PhotosUI
import FrameLabCore

public struct IOSContentView: View {
    @StateObject private var viewModel = VideoPlayerViewModel()
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showBenchmarkSheet = false
    @State private var showMetadataSheet = false
    @State private var exportData: Data? = nil

    public init() {}

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Viewport
                ZStack {
                    Color.black.ignoresSafeArea()

                    if let cgImage = viewModel.previewImage {
                        Image(decorative: cgImage, scale: 1.0, orientation: .up)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else if viewModel.isLoading {
                        ProgressView("Decoding...")
                            .tint(.white)
                            .foregroundColor(.white)
                    } else {
                        emptyStateView
                    }

                    // Floating HUD
                    if viewModel.metadata != nil {
                        VStack {
                            HStack {
                                Label(viewModel.activeFilter.shortName, systemImage: "sparkles")
                                    .font(.caption.bold())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)

                                Spacer()

                                Text(String(format: "%.1f ms", viewModel.currentLatencyMs))
                                    .font(.caption.monospaced())
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(.ultraThinMaterial)
                                    .cornerRadius(8)
                            }
                            .padding()
                            Spacer()
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                // Controls area
                VStack(spacing: 12) {
                    // Scrubber
                    HStack(spacing: 8) {
                        Text(viewModel.currentTimeFormatted)
                            .font(.caption.monospaced())
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
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)

                    // Filter selector
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(FilterType.allCases) { filter in
                                Button(action: { viewModel.activeFilter = filter }) {
                                    Text(filter.shortName)
                                        .font(.caption.bold())
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(viewModel.activeFilter == filter ? Color.accentColor : Color(.secondarySystemBackground))
                                        .foregroundColor(viewModel.activeFilter == filter ? .white : .primary)
                                        .cornerRadius(16)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }

                    // Bottom Action Bar
                    HStack {
                        Button(action: { viewModel.togglePlay() }) {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.system(size: 38))
                        }
                        .disabled(viewModel.metadata == nil)

                        Spacer()

                        PhotosPicker(selection: $selectedPhotoItem, matching: .videos) {
                            Image(systemName: "photo.badge.plus")
                                .font(.system(size: 22))
                        }

                        Button(action: {
                            Task { await viewModel.loadSyntheticDemo() }
                        }) {
                            Image(systemName: "play.rectangle.on.rectangle")
                                .font(.system(size: 22))
                        }

                        Button(action: { showMetadataSheet = true }) {
                            Image(systemName: "info.circle")
                                .font(.system(size: 22))
                        }
                        .disabled(viewModel.metadata == nil)

                        Button(action: {
                            showBenchmarkSheet = true
                            if viewModel.benchmarkReport == nil {
                                Task { await viewModel.runBenchmark() }
                            }
                        }) {
                            Image(systemName: "gauge.with.needle")
                                .font(.system(size: 22))
                        }
                        .disabled(viewModel.metadata == nil)

                        Button(action: exportFrame) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 22))
                        }
                        .disabled(viewModel.currentFrame == nil)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 4)
                    .padding(.bottom, 8)
                }
                .background(Color(.systemBackground))
            }
            .navigationTitle("FrameLab")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showBenchmarkSheet) {
                IOSBenchmarkSheet(
                    report: viewModel.benchmarkReport,
                    isRunning: viewModel.isBenchmarking,
                    progress: viewModel.benchmarkProgress,
                    onRerun: {
                        Task { await viewModel.runBenchmark() }
                    }
                )
            }
            .sheet(isPresented: $showMetadataSheet) {
                metadataSheetView
            }
            .sheet(isPresented: Binding(
                get: { exportData != nil },
                set: { if !$0 { exportData = nil } }
            )) {
                if let data = exportData {
                    IOSShareSheet(items: [data])
                }
            }
            .onChange(of: selectedPhotoItem) { _, newItem in
                guard let item = newItem else { return }
                Task {
                    if let movie = try? await item.loadTransferable(type: MovieTransferable.self) {
                        await viewModel.loadVideo(from: movie.url)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "film")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
            Text("FrameLab")
                .font(.title2.bold())
                .foregroundColor(.white)
            Text("Select a video from your library or try the color bars test demo.")
                .font(.caption)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button("Load Test Bars Demo") {
                Task { await viewModel.loadSyntheticDemo() }
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
        }
    }

    private var metadataSheetView: some View {
        NavigationStack {
            List {
                if let meta = viewModel.metadata {
                    Section(header: Text("Video Format")) {
                        LabeledContent("Resolution", value: meta.resolutionString)
                        LabeledContent("Frame Rate", value: meta.formattedFrameRate)
                        LabeledContent("Duration", value: meta.formattedDuration)
                        LabeledContent("Codec", value: meta.videoCodec)
                        LabeledContent("Bitrate", value: meta.formattedBitrate)
                        LabeledContent("Color Space", value: meta.colorSpace)
                    }
                    Section(header: Text("Current Performance")) {
                        LabeledContent("Engine", value: viewModel.activeFilter.rawValue)
                        LabeledContent("Latency", value: String(format: "%.2f ms", viewModel.currentLatencyMs))
                        LabeledContent("Frames Decoded", value: "\(viewModel.framesProcessedCount)")
                        LabeledContent("Frames Dropped", value: "\(viewModel.framesDroppedCount)")
                    }
                }
            }
            .navigationTitle("Video Metadata")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func exportFrame() {
        if let data = viewModel.exportCurrentFrame(format: .png) {
            self.exportData = data
        }
    }
}
#endif
