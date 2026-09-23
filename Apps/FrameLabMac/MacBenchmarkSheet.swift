#if os(macOS)
import SwiftUI
import FrameLabCore

@MainActor
public struct MacBenchmarkSheet: View {
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
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Processing Performance Benchmark")
                        .font(.title2.bold())
                    if let rep = report {
                        Text("Input Resolution: \(Int(rep.imageDimensions.width)) × \(Int(rep.imageDimensions.height)) | Iterations: 25 | Warmup: 5")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding(.horizontal)
            .padding(.top)

            if isRunning {
                VStack(spacing: 12) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 400)
                    Text("Benchmarking GPU and CPU pipelines... \(Int(progress * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            } else if let report = report {
                // Table of results
                Table(report.results) {
                    TableColumn("Engine", value: \.processorName)
                    TableColumn("Avg (ms)") { res in
                        Text(String(format: "%.2f", res.averageLatencyMs))
                            .monospacedDigit()
                    }
                    TableColumn("Median (ms)") { res in
                        Text(String(format: "%.2f", res.medianLatencyMs))
                            .monospacedDigit()
                    }
                    TableColumn("p95 (ms)") { res in
                        Text(String(format: "%.2f", res.p95LatencyMs))
                            .monospacedDigit()
                    }
                    TableColumn("Min / Max (ms)") { res in
                        Text(String(format: "%.2f / %.2f", res.minLatencyMs, res.maxLatencyMs))
                            .monospacedDigit()
                    }
                    TableColumn("Est. FPS") { res in
                        Text(String(format: "%.1f", res.estimatedFPS))
                            .bold()
                            .foregroundColor(res.estimatedFPS >= 60 ? .green : (res.estimatedFPS >= 30 ? .orange : .red))
                    }
                }
                .frame(minHeight: 240)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "gauge.with.needle")
                        .font(.system(size: 44))
                        .foregroundColor(.secondary)
                    Text("No benchmark data available.")
                        .font(.headline)
                    Text("Run the benchmark to compare Swift, C, Obj-C, Accelerate, and Metal.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 250)
            }

            // Footer actions
            HStack {
                Button(action: onRerun) {
                    Label(isRunning ? "Running..." : "Rerun Benchmark", systemImage: "arrow.clockwise")
                }
                .disabled(isRunning)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(minWidth: 700, minHeight: 400)
    }
}
#endif
