import CoreMedia
import CoreVideo

class VideoMixer {
    var description = "Video Mixer"
    private(set) var isPrepared = false
    var pipFrame = CGRect.zero
    private(set) var inputFormatDescription: CMFormatDescription?
    var outputFormatDescription: CMFormatDescription?
    private var outputPixelBufferPool: CVPixelBufferPool?
    private let metalDevice = MTLCreateSystemDefaultDevice()
    private var textureCache: CVMetalTextureCache?
    internal var lockedOrientation: UIDeviceOrientation?
    private lazy var commandQueue: MTLCommandQueue? = {
        guard let metalDevice = metalDevice else {
            return nil
        }
        
        return metalDevice.makeCommandQueue()
    }()
    
    private var fullRangeVertexBuffer: MTLBuffer?
    private var computePipelineState: MTLComputePipelineState?

    init() {
        guard let metalDevice = metalDevice,
            let defaultLibrary = metalDevice.makeDefaultLibrary(),
            let kernelFunction = defaultLibrary.makeFunction(name: "reporterMixer") else {
                return
        }
        
        do {
            computePipelineState = try metalDevice.makeComputePipelineState(function: kernelFunction)
        } catch {
            print("Could not create compute pipeline state: \(error)")
        }
    }
    
    func prepare(with videoFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int, targetWidth: Int32? = nil, targetHeight: Int32? = nil) {
        reset()
        
        (outputPixelBufferPool, _, outputFormatDescription) = allocateOutputBufferPool(with: videoFormatDescription,
                                                                                       outputRetainedBufferCountHint: outputRetainedBufferCountHint,
                                                                                       targetWidth: targetWidth,
                                                                                       targetHeight: targetHeight)
        if outputPixelBufferPool == nil {
            return
        }
        inputFormatDescription = videoFormatDescription
        
        guard let metalDevice = metalDevice else {
                return
        }
        
        var metalTextureCache: CVMetalTextureCache?
        if CVMetalTextureCacheCreate(kCFAllocatorDefault, nil, metalDevice, nil, &metalTextureCache) != kCVReturnSuccess {
            assertionFailure("Unable to allocate video mixer texture cache")
        } else {
            textureCache = metalTextureCache
        }
        
        isPrepared = true
    }
    
    func reset() {
        outputPixelBufferPool = nil
        outputFormatDescription = nil
        inputFormatDescription = nil
        textureCache = nil
        lockedOrientation = nil
        isPrepared = false
    }
    
    func lockOrientation() {
        let currentOrientation = UIDevice.current.orientation
        
        switch currentOrientation {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            lockedOrientation = currentOrientation
        case .faceUp, .faceDown, .unknown:
            lockedOrientation = .portrait
        @unknown default:
            lockedOrientation = .portrait
        }
    }
    
    func unlockOrientation() {
        lockedOrientation = nil
    }
    
    struct MixerParameters {
        var pipPosition: SIMD2<Float>
        var pipSize: SIMD2<Float>
    }
    
    func mix(fullScreenPixelBuffer: CVPixelBuffer, pipPixelBuffer: CVPixelBuffer, fullScreenPixelBufferIsFrontCamera: Bool) -> CVPixelBuffer? {
        guard isPrepared,
            let outputPixelBufferPool = outputPixelBufferPool else {
                assertionFailure("Invalid state: Not prepared")
                return nil
        }
        
        var newPixelBuffer: CVPixelBuffer?
        CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, outputPixelBufferPool, &newPixelBuffer)
        guard let outputPixelBuffer = newPixelBuffer else {
            print("Allocation failure: Could not get pixel buffer from pool (\(self.description))")
            return nil
        }
        
        guard let outputTexture = makeTextureFromCVPixelBuffer(pixelBuffer: outputPixelBuffer),
            let fullScreenTexture = makeTextureFromCVPixelBuffer(pixelBuffer: fullScreenPixelBuffer),
            let pipTexture = makeTextureFromCVPixelBuffer(pixelBuffer: pipPixelBuffer) else {
                return nil
        }

        let adjustedPipFrame = getAdjustedPipFrame(for: fullScreenTexture)
        let pipPosition = SIMD2(Float(adjustedPipFrame.origin.x), Float(adjustedPipFrame.origin.y))
        let pipSize = SIMD2(Float(adjustedPipFrame.size.width), Float(adjustedPipFrame.size.height))
        var parameters = MixerParameters(pipPosition: pipPosition, pipSize: pipSize)
        
        guard let commandQueue = commandQueue,
            let commandBuffer = commandQueue.makeCommandBuffer(),
            let commandEncoder = commandBuffer.makeComputeCommandEncoder(),
            let computePipelineState = computePipelineState else {
                print("Failed to create Metal command encoder")
                
                if let textureCache = textureCache {
                    CVMetalTextureCacheFlush(textureCache, 0)
                }
                
                return nil
        }
        
        commandEncoder.label = "PiP Video Mixer"
        commandEncoder.setComputePipelineState(computePipelineState)
        commandEncoder.setTexture(fullScreenTexture, index: 0)
        commandEncoder.setTexture(pipTexture, index: 1)
        commandEncoder.setTexture(outputTexture, index: 2)
        withUnsafeMutablePointer(to: &parameters) { parametersRawPointer in
            commandEncoder.setBytes(parametersRawPointer, length: MemoryLayout<MixerParameters>.size, index: 0)
        }
        
        // Set up thread groups as described in https://developer.apple.com/reference/metal/mtlcomputecommandencoder
        let width = computePipelineState.threadExecutionWidth
        let height = computePipelineState.maxTotalThreadsPerThreadgroup / width
        let threadsPerThreadgroup = MTLSizeMake(width, height, 1)
        let threadgroupsPerGrid = MTLSize(width: (fullScreenTexture.width + width - 1) / width,
                                          height: (fullScreenTexture.height + height - 1) / height,
                                          depth: 1)
        commandEncoder.dispatchThreadgroups(threadgroupsPerGrid, threadsPerThreadgroup: threadsPerThreadgroup)
        
        commandEncoder.endEncoding()
        commandBuffer.commit()
        
        return outputPixelBuffer
    }
    
    private func getAdjustedPipFrame(for fullScreenTexture: MTLTexture) -> CGRect {
        let orientationToUse = lockedOrientation ?? UIDevice.current.orientation
        
        let validOrientation: UIDeviceOrientation
        switch orientationToUse {
        case .portrait, .portraitUpsideDown, .landscapeLeft, .landscapeRight:
            validOrientation = orientationToUse
        case .faceUp, .faceDown, .unknown:
            validOrientation = .portrait
        @unknown default:
            validOrientation = .portrait
        }
        
        let isLandscape = validOrientation.isLandscape
        let textureWidth = Float(fullScreenTexture.width)
        let textureHeight = Float(fullScreenTexture.height)
        
        if isLandscape {
            let pipWidth = textureWidth * Float(pipFrame.size.width)
            let pipHeight = textureHeight * Float(pipFrame.size.height)
            let pipX = textureWidth * Float(pipFrame.origin.x)
            let pipY = textureHeight * Float(pipFrame.origin.y)
            
            return CGRect(x: CGFloat(pipX), y: CGFloat(pipY), width: CGFloat(pipWidth), height: CGFloat(pipHeight))
        } else {
            let pipWidth = textureWidth * Float(pipFrame.size.width)
            let pipHeight = textureHeight * Float(pipFrame.size.height)
            let pipX = textureWidth * Float(pipFrame.origin.x)
            let pipY = textureHeight * Float(pipFrame.origin.y)
            
            return CGRect(x: CGFloat(pipX), y: CGFloat(pipY), width: CGFloat(pipWidth), height: CGFloat(pipHeight))
        }
    }
    
    private func makeTextureFromCVPixelBuffer(pixelBuffer: CVPixelBuffer) -> MTLTexture? {
        guard let textureCache = textureCache else {
            print("No texture cache")
            return nil
        }
        
        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        
        var cvTextureOut: CVMetalTexture?
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, textureCache, pixelBuffer, nil, .bgra8Unorm, width, height, 0, &cvTextureOut)
        guard let cvTexture = cvTextureOut, let texture = CVMetalTextureGetTexture(cvTexture) else {
            print("Video mixer failed to create preview texture")
            
            CVMetalTextureCacheFlush(textureCache, 0)
            return nil
        }
        
        return texture
    }
    
    func allocateOutputBufferPool(with inputFormatDescription: CMFormatDescription, outputRetainedBufferCountHint: Int, targetWidth: Int32? = nil, targetHeight: Int32? = nil) -> (
        outputBufferPool: CVPixelBufferPool?,
        outputColorSpace: CGColorSpace?,
        outputFormatDescription: CMFormatDescription?) {
            
            let inputMediaSubType = CMFormatDescriptionGetMediaSubType(inputFormatDescription)
            if inputMediaSubType != kCVPixelFormatType_Lossy_32BGRA && inputMediaSubType != kCVPixelFormatType_Lossless_32BGRA &&
                inputMediaSubType != kCVPixelFormatType_32BGRA {
                assertionFailure("Invalid input pixel buffer type \(inputMediaSubType)")
                return (nil, nil, nil)
            }
            
            // Use target dimensions if provided, otherwise use input dimensions
            let inputDimensions = CMVideoFormatDescriptionGetDimensions(inputFormatDescription)
            let outputWidth = targetWidth ?? inputDimensions.width
            let outputHeight = targetHeight ?? inputDimensions.height
            
            var pixelBufferAttributes: [String: Any] = [
                kCVPixelBufferPixelFormatTypeKey as String: UInt(inputMediaSubType),
                kCVPixelBufferWidthKey as String: Int(outputWidth),
                kCVPixelBufferHeightKey as String: Int(outputHeight),
                kCVPixelBufferIOSurfacePropertiesKey as String: [:]
            ]
            
            // Get pixel buffer attributes and color space from the input format description
            var cgColorSpace: CGColorSpace? = CGColorSpaceCreateDeviceRGB()
            if let inputFormatDescriptionExtension = CMFormatDescriptionGetExtensions(inputFormatDescription) as Dictionary? {
                let colorPrimaries = inputFormatDescriptionExtension[kCVImageBufferColorPrimariesKey]
                
                if let colorPrimaries = colorPrimaries {
                    var colorSpaceProperties: [String: AnyObject] = [kCVImageBufferColorPrimariesKey as String: colorPrimaries]
                    
                    if let yCbCrMatrix = inputFormatDescriptionExtension[kCVImageBufferYCbCrMatrixKey] {
                        colorSpaceProperties[kCVImageBufferYCbCrMatrixKey as String] = yCbCrMatrix
                    }
                    
                    if let transferFunction = inputFormatDescriptionExtension[kCVImageBufferTransferFunctionKey] {
                        colorSpaceProperties[kCVImageBufferTransferFunctionKey as String] = transferFunction
                    }
                    
                    pixelBufferAttributes[kCVBufferPropagatedAttachmentsKey as String] = colorSpaceProperties
                }
                
                if let cvColorspace = inputFormatDescriptionExtension[kCVImageBufferCGColorSpaceKey],
                    CFGetTypeID(cvColorspace) == CGColorSpace.typeID {
                    cgColorSpace = (cvColorspace as! CGColorSpace)
                } else if (colorPrimaries as? String) == (kCVImageBufferColorPrimaries_P3_D65 as String) {
                    cgColorSpace = CGColorSpace(name: CGColorSpace.displayP3)
                }
            }
            
            // Create a pixel buffer pool with the same pixel attributes as the input format description.
            let poolAttributes = [kCVPixelBufferPoolMinimumBufferCountKey as String: outputRetainedBufferCountHint]
            var cvPixelBufferPool: CVPixelBufferPool?
            CVPixelBufferPoolCreate(kCFAllocatorDefault, poolAttributes as NSDictionary?, pixelBufferAttributes as NSDictionary?, &cvPixelBufferPool)
            guard let pixelBufferPool = cvPixelBufferPool else {
                assertionFailure("Allocation failure: Could not allocate pixel buffer pool.")
                return (nil, nil, nil)
            }
            
            preallocateBuffers(pool: pixelBufferPool, allocationThreshold: outputRetainedBufferCountHint)
            
            // Get the output format description
            var pixelBuffer: CVPixelBuffer?
            var outputFormatDescription: CMFormatDescription?
            let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: outputRetainedBufferCountHint] as NSDictionary
            CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pixelBufferPool, auxAttributes, &pixelBuffer)
            if let pixelBuffer = pixelBuffer {
                CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault,
                                                             imageBuffer: pixelBuffer,
                                                             formatDescriptionOut: &outputFormatDescription)
            }
            pixelBuffer = nil
            
            return (pixelBufferPool, cgColorSpace, outputFormatDescription)
    }
    
    private func preallocateBuffers(pool: CVPixelBufferPool, allocationThreshold: Int) {
        var pixelBuffers = [CVPixelBuffer]()
        var error: CVReturn = kCVReturnSuccess
        let auxAttributes = [kCVPixelBufferPoolAllocationThresholdKey as String: allocationThreshold] as NSDictionary
        var pixelBuffer: CVPixelBuffer?
        while error == kCVReturnSuccess {
            error = CVPixelBufferPoolCreatePixelBufferWithAuxAttributes(kCFAllocatorDefault, pool, auxAttributes, &pixelBuffer)
            if let pixelBuffer = pixelBuffer {
                pixelBuffers.append(pixelBuffer)
            }
            pixelBuffer = nil
        }
        pixelBuffers.removeAll()
    }
}
