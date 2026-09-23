import Foundation
import Dispatch
import CoreMedia

/**
 * GCDFramePipeline demonstrates the integration of Grand Central Dispatch (GCD)
 * with modern Swift Concurrency.
 *
 * Why GCD here?
 * 1. Serial FIFO execution guarantees strict frame order without lock contention.
 * 2. Dedicated QoS (.userInitiated) prevents thread starvation under heavy system load.
 * 3. Bridges naturally with legacy Apple C/Obj-C APIs (e.g., AVCaptureVideoDataOutput sample buffer delegates).
 */
public final class GCDFramePipeline: @unchecked Sendable {
    private let processingQueue: DispatchQueue
    private let maxInFlightSemaphore: DispatchSemaphore

    public init(maxConcurrentFrames: Int = 1) {
        self.processingQueue = DispatchQueue(
            label: "com.framelab.gcd.processing",
            qos: .userInitiated,
            autoreleaseFrequency: .workItem
        )
        self.maxInFlightSemaphore = DispatchSemaphore(value: maxConcurrentFrames)
    }

    /**
     * Executes frame processing on the serial GCD queue and bridges the result
     * back to Swift Concurrency via `withCheckedThrowingContinuation`.
     */
    public func processAsync(
        frame: VideoFrame,
        processor: any FrameProcessor
    ) async throws -> ProcessedFrame {
        try await withCheckedThrowingContinuation { continuation in
            // Enqueue work item on GCD queue
            processingQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(throwing: FrameLabError.cancelled)
                    return
                }

                self.maxInFlightSemaphore.wait()
                defer { self.maxInFlightSemaphore.signal() }

                let task = Task {
                    do {
                        let result = try await processor.process(
                            frame.pixelBuffer,
                            presentationTime: frame.presentationTime
                        )
                        continuation.resume(returning: result)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }

                _ = task
            }
        }
    }

    /**
     * Submits a synchronous processing task directly to the GCD serial queue,
     * useful when called from a legacy C/CoreVideo callback.
     */
    public func processSync(
        frame: VideoFrame,
        processor: any FrameProcessor
    ) throws -> ProcessedFrame {
        var outcome: Result<ProcessedFrame, Error>?

        processingQueue.sync {
            let semaphore = DispatchSemaphore(value: 0)
            Task {
                do {
                    let result = try await processor.process(
                        frame.pixelBuffer,
                        presentationTime: frame.presentationTime
                    )
                    outcome = .success(result)
                } catch {
                    outcome = .failure(error)
                }
                semaphore.signal()
            }
            semaphore.wait()
        }

        switch outcome {
        case .success(let frame):
            return frame
        case .failure(let err):
            throw err
        case .none:
            throw FrameLabError.processingFailed("GCD sync execution returned no result.")
        }
    }
}
