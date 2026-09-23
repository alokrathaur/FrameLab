import Foundation
import CoreVideo
import CoreMedia
import Metal

/// Thread-safe context managing Metal resources, shader compilation, and texture cache.
public final class MetalContext: @unchecked Sendable {
    public static let shared = MetalContext()

    public let device: MTLDevice?
    public let commandQueue: MTLCommandQueue?
    public private(set) var textureCache: CVMetalTextureCache?
    public private(set) var computePipelineState: MTLComputePipelineState?

    private let lock = NSLock()
    private var isInitialized = false

    public static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    kernel void grayscale_compute(
        texture2d<float, access::read> inTexture [[texture(0)]],
        texture2d<float, access::write> outTexture [[texture(1)]],
        uint2 gid [[thread_position_in_grid]]
    ) {
        if (gid.x >= inTexture.get_width() || gid.y >= inTexture.get_height()) {
            return;
        }
        float4 color = inTexture.read(gid);
        // ITU-R BT.709 HDTV Luminance
        float gray = dot(color.rgb, float3(0.2126f, 0.7152f, 0.0722f));
        outTexture.write(float4(gray, gray, gray, color.a), gid);
    }
    """

    private init() {
        guard let defaultDevice = MTLCreateSystemDefaultDevice() else {
            self.device = nil
            self.commandQueue = nil
            return
        }
        self.device = defaultDevice
        self.commandQueue = defaultDevice.makeCommandQueue()
        setupTextureCache(for: defaultDevice)
        setupPipeline(for: defaultDevice)
    }

    private func setupTextureCache(for device: MTLDevice) {
        var cache: CVMetalTextureCache?
        let status = CVMetalTextureCacheCreate(
            kCFAllocatorDefault,
            nil,
            device,
            nil,
            &cache
        )
        if status == kCVReturnSuccess {
            self.textureCache = cache
        }
    }

    private func setupPipeline(for device: MTLDevice) {
        // Try loading from default library first, fallback to runtime compile
        var library = device.makeDefaultLibrary()
        if library?.makeFunction(name: "grayscale_compute") == nil {
            library = try? device.makeLibrary(source: Self.shaderSource, options: nil)
        }

        if let function = library?.makeFunction(name: "grayscale_compute") {
            self.computePipelineState = try? device.makeComputePipelineState(function: function)
        }
    }

    /// Flushes the underlying texture cache to reclaim memory.
    public func flushTextureCache() {
        lock.lock()
        defer { lock.unlock() }
        if let cache = textureCache {
            CVMetalTextureCacheFlush(cache, 0)
        }
    }
}

/// GPU-accelerated frame processor using Metal compute shaders and zero-copy CVMetalTextureCache.
public final class MetalFrameProcessor: FrameProcessor, @unchecked Sendable {
    public let name = "Metal GPU Compute"
    public let filterType: FilterType = .metal
    private let context: MetalContext
    private var bufferPool: PixelBufferPool?
    private let lock = NSLock()

    public init(context: MetalContext = .shared) {
        self.context = context
    }

    public func process(_ pixelBuffer: CVPixelBuffer, presentationTime: CMTime) async throws -> ProcessedFrame {
        guard context.device != nil,
              let commandQueue = context.commandQueue,
              let pipelineState = context.computePipelineState,
              let textureCache = context.textureCache else {
            throw FrameLabError.metalDeviceUnavailable
        }

        let startTime = ContinuousClock.now

        let format = CVPixelBufferGetPixelFormatType(pixelBuffer)
        guard format == kCVPixelFormatType_32BGRA || format == kCVPixelFormatType_32RGBA else {
            throw FrameLabError.unsupportedPixelFormat(format)
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        guard width > 0 && height > 0 else {
            throw FrameLabError.invalidDimensions(width: width, height: height)
        }

        let outputBuffer = try getOrCreateOutputBuffer(width: width, height: height, format: format)

        // Zero-copy texture mapping for input
        let mtlPixelFormat: MTLPixelFormat = (format == kCVPixelFormatType_32BGRA) ? .bgra8Unorm : .rgba8Unorm

        var inCVTexture: CVMetalTexture?
        let inStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            pixelBuffer,
            nil,
            mtlPixelFormat,
            width,
            height,
            0,
            &inCVTexture
        )

        guard inStatus == kCVReturnSuccess,
              let inCV = inCVTexture,
              let inMTLTexture = CVMetalTextureGetTexture(inCV) else {
            throw FrameLabError.metalBufferCreationFailed
        }

        // Zero-copy texture mapping for output
        var outCVTexture: CVMetalTexture?
        let outStatus = CVMetalTextureCacheCreateTextureFromImage(
            kCFAllocatorDefault,
            textureCache,
            outputBuffer,
            nil,
            mtlPixelFormat,
            width,
            height,
            0,
            &outCVTexture
        )

        guard outStatus == kCVReturnSuccess,
              let outCV = outCVTexture,
              let outMTLTexture = CVMetalTextureGetTexture(outCV) else {
            throw FrameLabError.metalBufferCreationFailed
        }

        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let computeEncoder = commandBuffer.makeComputeCommandEncoder() else {
            throw FrameLabError.metalBufferCreationFailed
        }

        computeEncoder.label = "FrameLab Grayscale Kernel"
        computeEncoder.setComputePipelineState(pipelineState)
        computeEncoder.setTexture(inMTLTexture, index: 0)
        computeEncoder.setTexture(outMTLTexture, index: 1)

        let threadExecutionWidth = pipelineState.threadExecutionWidth
        let maxThreads = pipelineState.maxTotalThreadsPerThreadgroup
        let threadgroupHeight = max(1, maxThreads / threadExecutionWidth)
        let threadsPerThreadgroup = MTLSize(width: threadExecutionWidth, height: threadgroupHeight, depth: 1)
        let threadsPerGrid = MTLSize(width: width, height: height, depth: 1)

        computeEncoder.dispatchThreads(threadsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        computeEncoder.endEncoding()

        await withCheckedContinuation { continuation in
            commandBuffer.addCompletedHandler { _ in
                continuation.resume()
            }
            commandBuffer.commit()
        }

        let elapsedTime = ContinuousClock.now - startTime
        let latencyMs = Double(elapsedTime.components.attoseconds) / 1_000_000_000_000_000.0 + Double(elapsedTime.components.seconds) * 1000.0

        return ProcessedFrame(
            pixelBuffer: outputBuffer,
            presentationTime: presentationTime,
            processingLatencyMs: latencyMs,
            processorName: name,
            filterType: filterType
        )
    }

    private func getOrCreateOutputBuffer(width: Int, height: Int, format: OSType) throws -> CVPixelBuffer {
        lock.lock()
        defer { lock.unlock() }

        if let pool = bufferPool, pool.width == width, pool.height == height, pool.pixelFormat == format {
            if let buf = pool.createPixelBuffer() {
                return buf
            }
        }

        let newPool = PixelBufferPool(width: width, height: height, pixelFormat: format)
        self.bufferPool = newPool
        if let buf = newPool.createPixelBuffer() {
            return buf
        }

        throw FrameLabError.missingPixelBuffer
    }
}
