import Foundation
import CoreVideo
import CoreMedia

/// Statistical metrics recorded for a single processor benchmark run.
public struct BenchmarkResult: Identifiable, Sendable, Equatable {
    public var id: String { processorName }

    public let processorName: String
    public let filterType: FilterType
    public let iterations: Int
    public let warmupIterations: Int
    public let minLatencyMs: Double
    public let maxLatencyMs: Double
    public let averageLatencyMs: Double
    public let medianLatencyMs: Double
    public let p95LatencyMs: Double
    public let standardDeviationMs: Double
    public let estimatedFPS: Double

    public init(
        processorName: String,
        filterType: FilterType,
        iterations: Int,
        warmupIterations: Int,
        latencies: [Double]
    ) {
        self.processorName = processorName
        self.filterType = filterType
        self.iterations = iterations
        self.warmupIterations = warmupIterations

        let sorted = latencies.sorted()
        let count = sorted.count

        if count > 0 {
            self.minLatencyMs = sorted.first ?? 0.0
            self.maxLatencyMs = sorted.last ?? 0.0
            let sum = sorted.reduce(0.0, +)
            let avg = sum / Double(count)
            self.averageLatencyMs = avg

            // Median
            if count % 2 == 1 {
                self.medianLatencyMs = sorted[count / 2]
            } else {
                self.medianLatencyMs = (sorted[(count / 2) - 1] + sorted[count / 2]) / 2.0
            }

            // 95th Percentile
            let p95Index = min(count - 1, Int((Double(count) * 0.95).rounded(.up)) - 1)
            self.p95LatencyMs = sorted[max(0, p95Index)]

            // Standard deviation
            let variance = sorted.reduce(0.0) { $0 + pow($1 - avg, 2) } / Double(count)
            self.standardDeviationMs = sqrt(variance)

            self.estimatedFPS = avg > 0.0 ? (1000.0 / avg) : 0.0
        } else {
            self.minLatencyMs = 0.0
            self.maxLatencyMs = 0.0
            self.averageLatencyMs = 0.0
            self.medianLatencyMs = 0.0
            self.p95LatencyMs = 0.0
            self.standardDeviationMs = 0.0
            self.estimatedFPS = 0.0
        }
    }
}

/// Comprehensive benchmark report comparing multiple processing backends on identical input.
public struct BenchmarkReport: Identifiable, Sendable {
    public let id = UUID()
    public let date: Date
    public let imageDimensions: CGSize
    public let results: [BenchmarkResult]

    public init(imageDimensions: CGSize, results: [BenchmarkResult]) {
        self.date = Date()
        self.imageDimensions = imageDimensions
        self.results = results
    }
}

/// Benchmark harness for measuring and comparing CPU vs GPU frame processing performance.
public final class BenchmarkRunner: Sendable {
    public init() {}

    public func run(
        on pixelBuffer: CVPixelBuffer,
        iterations: Int = 30,
        warmupIterations: Int = 5,
        progress: (@Sendable (Double) -> Void)? = nil
    ) async throws -> BenchmarkReport {
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let dimensions = CGSize(width: width, height: height)

        let candidateTypes: [FilterType] = [
            .swift,
            .c,
            .objc,
            .accelerate,
            .metal
        ]

        var results: [BenchmarkResult] = []
        let totalSteps = Double(candidateTypes.count)
        var currentStep = 0.0

        for filterType in candidateTypes {
            let processor = ProcessorFactory.makeProcessor(for: filterType)

            // Warmup passes
            for _ in 0..<warmupIterations {
                _ = try await processor.process(pixelBuffer, presentationTime: .zero)
            }

            // Measurement passes
            var latencies: [Double] = []
            latencies.reserveCapacity(iterations)

            for _ in 0..<iterations {
                let start = ContinuousClock.now
                _ = try await processor.process(pixelBuffer, presentationTime: .zero)
                let elapsed = ContinuousClock.now - start
                let ms = Double(elapsed.components.attoseconds) / 1_000_000_000_000_000.0 + Double(elapsed.components.seconds) * 1000.0
                latencies.append(ms)
            }

            let result = BenchmarkResult(
                processorName: processor.name,
                filterType: filterType,
                iterations: iterations,
                warmupIterations: warmupIterations,
                latencies: latencies
            )
            results.append(result)

            currentStep += 1.0
            progress?(currentStep / totalSteps)
        }

        return BenchmarkReport(imageDimensions: dimensions, results: results)
    }
}
