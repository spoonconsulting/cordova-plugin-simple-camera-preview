#import "CameraRenderController.h"
#import <MetalKit/MetalKit.h>
#import <CoreVideo/CoreVideo.h>

@interface CameraRenderController () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *mtkView;
@property (nonatomic, strong) id<MTLDevice> device;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, assign) CVMetalTextureCacheRef textureCache;
@property (nonatomic, strong) id<MTLTexture> cameraTexture;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;

@end

@implementation CameraRenderController

- (CameraRenderController *)init {
    if (self = [super init]) {
        self.renderLock = [NSLock new];
    }
    return self;
}

- (void)loadView {
    self.device = MTLCreateSystemDefaultDevice();
    self.mtkView = [[MTKView alloc] initWithFrame:CGRectZero device:self.device];
    self.mtkView.delegate = self;
    self.mtkView.framebufferOnly = NO;
    self.mtkView.contentMode = UIViewContentModeScaleToFill;
    self.mtkView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    [self.mtkView setBackgroundColor:[UIColor blackColor]];
    [self.mtkView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setView: self.mtkView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.commandQueue = [self.device newCommandQueue];
    CVMetalTextureCacheCreate(kCFAllocatorDefault, NULL, self.device, NULL, &_textureCache);
    
    // Load shaders from Shaders.metal
    id<MTLLibrary> defaultLibrary = [self.device newDefaultLibrary];
    id<MTLFunction> vertexFunction = [defaultLibrary newFunctionWithName:@"vertex_main"];
    id<MTLFunction> fragmentFunction = [defaultLibrary newFunctionWithName:@"fragment_main"];

    MTLRenderPipelineDescriptor *pipelineDescriptor = [MTLRenderPipelineDescriptor new];
    pipelineDescriptor.vertexFunction = vertexFunction;
    pipelineDescriptor.fragmentFunction = fragmentFunction;
    pipelineDescriptor.colorAttachments[0].pixelFormat = self.mtkView.colorPixelFormat;

    NSError *error = nil;
    self.pipelineState = [self.device newRenderPipelineStateWithDescriptor:pipelineDescriptor error:&error];
    if (error) {
        NSLog(@"Error creating pipeline state: %@", error);
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationIsActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    dispatch_async(self.sessionManager.sessionQueue, ^{
        if (!self.sessionManager.session.running) {
            NSLog(@"Starting session from viewWillAppear");
            [self.sessionManager.session startRunning];
        }
    });
}

- (void)applicationIsActive:(NSNotification *)notification {
    dispatch_async(self.sessionManager.sessionQueue, ^{
        if (!self.sessionManager.session.running){
            [self.sessionManager.session startRunning];
        }
    });
}

- (void)onAppWillResignActive {
    if (self.sessionManager.session.running){
      [self.sessionManager stopRecording];
    }
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([self.renderLock tryLock]) {
        CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
        if (!pixelBuffer) {
            [self.renderLock unlock];
            return;
        }
        
        CVMetalTextureRef textureRef = NULL;
        size_t width = CVPixelBufferGetWidth(pixelBuffer);
        size_t height = CVPixelBufferGetHeight(pixelBuffer);
        
        CVMetalTextureCacheCreateTextureFromImage(kCFAllocatorDefault, self.textureCache, pixelBuffer, NULL, MTLPixelFormatBGRA8Unorm, width, height, 0, &textureRef);
        
        if (textureRef) {
                self.cameraTexture = CVMetalTextureGetTexture(textureRef);
                CFRelease(textureRef);

                dispatch_async(dispatch_get_main_queue(), ^{
                    [self.mtkView draw];
                });
            }
        [self.renderLock unlock];
    }
}

- (void)drawInMTKView:(MTKView *)view {
    if (!self.cameraTexture) return;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *passDescriptor = view.currentRenderPassDescriptor;
    if (!passDescriptor) return;

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:passDescriptor];
    [encoder setRenderPipelineState:self.pipelineState];
    [encoder setFragmentTexture:self.cameraTexture atIndex:0];

    // Draw 2 triangles to make a full-screen quad (4 vertices)
    [encoder drawPrimitives:MTLPrimitiveTypeTriangleStrip vertexStart:0 vertexCount:4];
    
    [encoder endEncoding];
    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
    UIInterfaceOrientation orientation = [self.sessionManager getOrientation];
    [self.sessionManager updateOrientation:[self.sessionManager getCurrentOrientation:orientation]];
}

- (void)dealloc {
    if (_textureCache) {
        CVMetalTextureCacheFlush(_textureCache, 0);
        CFRelease(_textureCache);
        _textureCache = nil;
    }
    _mtkView.delegate = nil;
    _cameraTexture = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
