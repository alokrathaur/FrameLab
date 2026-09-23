import Foundation
import CoreMedia
import CoreVideo
import AVFoundation
import FrameLabCore

@MainActor
func main() async {
    print("=======================================================")
    print("        FrameLab Video Engineering Test Suite          ")
    print("=======================================================")
    print("Host Target: arm64-apple-macos")
    print("Platform: macOS 14+ / iOS 17+ Multiplatform Core")
    print("Starting automated test execution...\n")

    var passCount = 0
    var failCount = 0

    func assertTest(_ name: String, _ condition: Bool, _ failureMessage: String = "") {
        if condition {
            print("  [PASS] \(name)")
            passCount += 1
        } else {
            print("  [FAIL] \(name): \(failureMessage)")
            failCount += 1
        }
    }

    // MARK: - 1. Timing Tests
    print("--- 1. Timing Tests (CMTime & Rational Math) ---")
    let t1 = CMTime(seconds: 4.25, preferredTimescale: 1000)
    assertTest("CMTime format 00:04.250", t1.formattedTimeString == "00:04.250", "Got \(t1.formattedTimeString)")

    let t2 = CMTime(seconds: 65.5, preferredTimescale: 1000)
    assertTest("CMTime format 01:05.500", t2.formattedTimeString == "01:05.500", "Got \(t2.formattedTimeString)")

    let tZero = CMTime.zero
    assertTest("CMTime format zero", tZero.formattedTimeString == "00:00.000", "Got \(tZero.formattedTimeString)")

    let tInvalid = CMTime.invalid
    assertTest("CMTime format invalid", tInvalid.formattedTimeString == "--:--.---", "Got \(tInvalid.formattedTimeString)")

    let tCode = CMTime(seconds: 4.5, preferredTimescale: 600)
    let tc = tCode.timecodeString(frameRate: 30.0)
    assertTest("Timecode 30 FPS at 4.5s", tc == "00:00:04:15", "Got \(tc)")

    let timing = FrameTimingInfo(presentationTimestamp: CMTime(seconds: 5.0, preferredTimescale: 600))
    let progress = timing.progressFraction(totalDuration: CMTime(seconds: 20.0, preferredTimescale: 600))
    assertTest("FrameTiming progress fraction", abs(progress - 0.25) < 0.001, "Got \(progress)")

    // MARK: - 2. Pixel Buffer Tests
    print("\n--- 2. Pixel Buffer Tests (Core Video & Pool) ---")
    let buf = PixelBufferTestUtilities.createSolidColorBuffer(width: 100, height: 50, blue: 200, green: 150, red: 100)
    assertTest("Pixel buffer creation", buf != nil, "Buffer creation failed")
    if let b = buf {
        assertTest("Buffer width 100", CVPixelBufferGetWidth(b) == 100)
        assertTest("Buffer height 50", CVPixelBufferGetHeight(b) == 50)
        assertTest("Buffer stride >= 400", CVPixelBufferGetBytesPerRow(b) >= 400)
        let pixel = PixelBufferTestUtilities.readBGRA(from: b, x: 10, y: 10)
        assertTest("Read pixel BGRA values", pixel?.b == 200 && pixel?.g == 150 && pixel?.r == 100 && pixel?.a == 255)
    }

    let pool = PixelBufferPool(width: 320, height: 240)
    let pBuf1 = pool.createPixelBuffer()
    let pBuf2 = pool.createPixelBuffer()
    assertTest("PixelBufferPool allocation", pBuf1 != nil && pBuf2 != nil)
    pool.flush()

    // MARK: - 3. Processing Correctness Tests
    print("\n--- 3. Processing Correctness Tests (All 5 Backends) ---")
    // Test Red: B=0, G=0, R=255. BT.601 integer: (77*255)>>8 = 76
    if let redBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 16, height: 16, blue: 0, green: 0, red: 255) {
        do {
            let swiftProc = SwiftFrameProcessor()
            let res = try await swiftProc.process(redBuf, presentationTime: .zero)
            let p = PixelBufferTestUtilities.readBGRA(from: res.pixelBuffer, x: 0, y: 0)
            assertTest("Swift Baseline Grayscale (BT.601)", p?.b == 76 && p?.g == 76 && p?.r == 76, "Got \(String(describing: p))")
        } catch {
            assertTest("Swift Baseline Grayscale", false, error.localizedDescription)
        }
    }

    // Test Green: B=0, G=255, R=0. BT.601 integer: (150*255)>>8 = 149
    if let greenBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 16, height: 16, blue: 0, green: 255, red: 0) {
        do {
            let cProc = CFrameProcessor()
            let res = try await cProc.process(greenBuf, presentationTime: .zero)
            let p = PixelBufferTestUtilities.readBGRA(from: res.pixelBuffer, x: 0, y: 0)
            assertTest("C Native Grayscale (BT.601)", p?.b == 149 && p?.g == 149 && p?.r == 149, "Got \(String(describing: p))")
        } catch {
            assertTest("C Native Grayscale", false, error.localizedDescription)
        }
    }

    // Test Blue: B=255, G=0, R=0. BT.601 integer: (29*255)>>8 = 28
    if let blueBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 16, height: 16, blue: 255, green: 0, red: 0) {
        do {
            let objcProc = ObjCFrameProcessor()
            let res = try await objcProc.process(blueBuf, presentationTime: .zero)
            let p = PixelBufferTestUtilities.readBGRA(from: res.pixelBuffer, x: 0, y: 0)
            assertTest("Objective-C Bridge Grayscale (BT.601)", p?.b == 28 && p?.g == 28 && p?.r == 28, "Got \(String(describing: p))")
        } catch {
            assertTest("Objective-C Bridge Grayscale", false, error.localizedDescription)
        }
    }

    // Test Accelerate vImage on White
    if let whiteBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 32, height: 32, blue: 255, green: 255, red: 255) {
        do {
            let accProc = AccelerateFrameProcessor()
            let res = try await accProc.process(whiteBuf, presentationTime: .zero)
            let p = PixelBufferTestUtilities.readBGRA(from: res.pixelBuffer, x: 0, y: 0)
            assertTest("Accelerate vImage Grayscale", (p?.b ?? 0) >= 254 && (p?.g ?? 0) >= 254 && (p?.r ?? 0) >= 254, "Got \(String(describing: p))")
        } catch {
            assertTest("Accelerate vImage Grayscale", false, error.localizedDescription)
        }
    }

    // Test Metal GPU Compute Kernel
    if MetalContext.shared.device != nil {
        if let whiteBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 32, height: 32, blue: 255, green: 255, red: 255) {
            do {
                let metalProc = MetalFrameProcessor()
                let res = try await metalProc.process(whiteBuf, presentationTime: .zero)
                let p = PixelBufferTestUtilities.readBGRA(from: res.pixelBuffer, x: 0, y: 0)
                assertTest("Metal GPU Compute Grayscale", (p?.b ?? 0) >= 250 && (p?.g ?? 0) >= 250 && (p?.r ?? 0) >= 250, "Got \(String(describing: p))")
            } catch {
                assertTest("Metal GPU Compute Grayscale", false, error.localizedDescription)
            }
        }
    } else {
        print("  [SKIP] Metal GPU test (No Metal device)")
    }

    // MARK: - 4. Concurrency & GCD Tests
    print("\n--- 4. Concurrency & GCD Tests (Backpressure & Serial Pipeline) ---")
    do {
        let pipeline = BoundedFramePipeline(processor: SwiftFrameProcessor())
        if let sampleBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 16, height: 16, blue: 10, green: 20, red: 30) {
            let f1 = VideoFrame(pixelBuffer: sampleBuf, presentationTime: CMTime(seconds: 0.1, preferredTimescale: 600))
            let f2 = VideoFrame(pixelBuffer: sampleBuf, presentationTime: CMTime(seconds: 0.2, preferredTimescale: 600))
            let f3 = VideoFrame(pixelBuffer: sampleBuf, presentationTime: CMTime(seconds: 0.3, preferredTimescale: 600))

            let (p1, d1) = await pipeline.submit(frame: f1)
            let (p2, d2) = await pipeline.submit(frame: f2)
            let (p3, d3) = await pipeline.submit(frame: f3)

            assertTest("BoundedPipeline initial accept", p1 && !d1)
            assertTest("BoundedPipeline second frame queue", !p2 && !d2)
            assertTest("BoundedPipeline third frame drops stale", !p3 && d3)

            let dropped = await pipeline.framesDropped
            assertTest("BoundedPipeline dropped count == 1", dropped == 1, "Got \(dropped)")
        }
    }

    do {
        let gcdPipeline = GCDFramePipeline(maxConcurrentFrames: 1)
        if let sampleBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 16, height: 16, blue: 50, green: 50, red: 50) {
            let f = VideoFrame(pixelBuffer: sampleBuf, presentationTime: .zero)
            let res = try await gcdPipeline.processAsync(frame: f, processor: CFrameProcessor())
            assertTest("GCDFramePipeline async continuation bridging", res.processingLatencyMs >= 0.0)
        }
    } catch {
        assertTest("GCDFramePipeline async execution", false, error.localizedDescription)
    }

    // MARK: - 5. Frame Export Tests
    print("\n--- 5. Frame Export Tests (ImageIO & CGImageDestination) ---")
    if let cb = PixelBufferTestUtilities.createColorBarsBuffer(width: 120, height: 80) {
        let exporter = FrameExporter()
        do {
            let pngData = try exporter.exportToData(pixelBuffer: cb, format: .png)
            assertTest("Export to PNG non-empty", !pngData.isEmpty)
            let header = [UInt8](pngData.prefix(4))
            assertTest("PNG magic bytes 0x89 0x50 0x4E 0x47", header == [0x89, 0x50, 0x4E, 0x47])
        } catch {
            assertTest("Export to PNG", false, error.localizedDescription)
        }

        do {
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_export_\(UUID().uuidString).jpg")
            defer { try? FileManager.default.removeItem(at: tempURL) }
            try exporter.export(pixelBuffer: cb, to: tempURL, format: .jpeg)
            let exists = FileManager.default.fileExists(atPath: tempURL.path)
            assertTest("Export to JPEG file on disk", exists)
        } catch {
            assertTest("Export to JPEG", false, error.localizedDescription)
        }
    }

    // MARK: - 6. Benchmark Tests
    print("\n--- 6. Benchmark Tests (Multi-Backend Profiler) ---")
    if let benchBuf = PixelBufferTestUtilities.createSolidColorBuffer(width: 64, height: 64, blue: 100, green: 100, red: 100) {
        do {
            let runner = BenchmarkRunner()
            let report = try await runner.run(on: benchBuf, iterations: 5, warmupIterations: 2)
            assertTest("Benchmark report non-empty", !report.results.isEmpty)
            assertTest("Benchmark report dimension 64x64", report.imageDimensions.width == 64 && report.imageDimensions.height == 64)

            for res in report.results {
                assertTest("Benchmark \(res.processorName) stats (min <= avg <= max)", res.minLatencyMs <= res.averageLatencyMs && res.averageLatencyMs <= res.maxLatencyMs)
            }
        } catch {
            assertTest("Benchmark runner", false, error.localizedDescription)
        }
    }

    // MARK: - 7. Video Asset & Streaming Tests
    print("\n--- 7. Video Asset & Streaming Tests (Synthetic Video Pipeline) ---")
    let testVideoURL = FileManager.default.temporaryDirectory.appendingPathComponent("test_stream_\(UUID().uuidString).mp4")
    defer { try? FileManager.default.removeItem(at: testVideoURL) }

    do {
        _ = try await PixelBufferTestUtilities.createSyntheticVideo(
            at: testVideoURL,
            durationSeconds: 0.5,
            fps: 30,
            width: 160,
            height: 120
        )
        assertTest("Generate synthetic .mp4 with AVAssetWriter", FileManager.default.fileExists(atPath: testVideoURL.path))

        let service = VideoAssetService()
        let metadata = try await service.extractMetadata(from: testVideoURL)
        assertTest("Extract metadata dimensions 160x120", metadata.dimensions.width == 160 && metadata.dimensions.height == 120)
        assertTest("Extract metadata FPS ~30", abs(metadata.nominalFrameRate - 30.0) < 1.0)
        assertTest("Extract metadata codec H.264", metadata.videoCodec == "H.264 / AVC")

        let reader = VideoFrameReader(url: testVideoURL)
        var frameCount = 0
        for try await frame in reader.frames() {
            frameCount += 1
            if frameCount == 1 {
                assertTest("First frame PTS valid", frame.presentationTime.isValid)
                assertTest("First frame dimensions 160x120", frame.width == 160 && frame.height == 120)
            }
        }
        assertTest("Streamed ~15 frames (got \(frameCount))", frameCount >= 14)
    } catch {
        assertTest("Synthetic video streaming pipeline", false, error.localizedDescription)
    }

    // MARK: - Summary
    print("\n=======================================================")
    print("                     TEST SUMMARY                      ")
    print("=======================================================")
    print("Total Tests Passed: \(passCount)")
    print("Total Tests Failed: \(failCount)")

    if failCount == 0 {
        print("RESULT: ALL TEST SUITES PASSED CLEANLY! (100% SUCCESS)")
        print("=======================================================\n")
        exit(0)
    } else {
        print("RESULT: FAILURES DETECTED! (\(failCount) failed)")
        print("=======================================================\n")
        exit(1)
    }
}

Task {
    await main()
}
RunLoop.main.run()
