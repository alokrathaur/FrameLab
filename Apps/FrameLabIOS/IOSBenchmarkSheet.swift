#if os(iOS)
import SwiftUI
import FrameLabCore

public struct IOSBenchmarkSheet: View {
    let report: BenchmarkReport?
    let isRunning: Bool
    let progress: Double
    let onRerun: () -> Void
    @Environment(\.dismiss) private var dismiss

    public init(
        report: BenchmarkReport?,
        isRunning: Bool,
        progress: Double,
        onRerun: @escaping () -> Void
    ) {
        self.report = report
        self.isRunning = isRunning
        self.progress = progress
        self.onRerun = onRerun
    }

    public var body: some View {
        NavigationStack {
            Group {
                if isRunning {
                    VStack(spacing: 16) {
                        ProgressView(value: progress)
                            .padding()
                        Text("Benchmarking pipelines... \(Int(progress * 100))%")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                } else if let report = report {
                    List {
                        Section(header: Text("Hardware Benchmark (\(Int(report.imageDimensions.width))x\(Int(report.imageDimensions.height)))")) {
                            ForEach(report.results) { res in
                                VStack(alignment: .leading, spacing: 6) {
                                    HStack {
                                        Text(res.processorName)
                                            .font(.headline)
                                        Spacer()
                                        Text(String(format: "%.1f FPS", res.estimatedFPS))
                                            .bold()
                                            .foregroundColor(res.estimatedFPS >= 60 ? .green : (res.estimatedFPS >= 30 ? .orange : .red))
                                    }
                                    HStack {
                                        Text("Avg: \(String(format: "%.2f ms", res.averageLatencyMs))")
                                        Spacer()
                                        Text("p95: \(String(format: "%.2f ms", res.p95LatencyMs))")
                                        Spacer()
                                        Text("Min: \(String(format: "%.2f ms", res.minLatencyMs))")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "gauge.with.needle")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                        Text("No Benchmark Available")
                            .font(.headline)
                    }
                }
            }
            .navigationTitle("Performance")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button(action: onRerun) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .disabled(isRunning)
                }
            }
        }
    }
}
#endif
