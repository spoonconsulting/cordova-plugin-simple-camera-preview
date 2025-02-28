#import "DualCameraRenderController.h"

@implementation DualCameraRenderController

- (instancetype)init {
    self = [super init];
    if (self) {
        self.sessionManager = [[DualCameraSessionManager alloc] init];
        self.renderLock = [[NSLock alloc] init];
        self.backPixelBuffer = NULL;
        self.frontPixelBuffer = NULL;
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];

    self.ciContext = [CIContext contextWithEAGLContext:self.context];
    self.view.contentMode = UIViewContentModeScaleToFill;
    
    [self setupDualCamera];
}

- (void)setupDualCamera {
    [self.sessionManager setupDualCameraSessionWithDelegate:self];
    [self.sessionManager startSession];
}

- (void)stopDualCamera {
    [self.sessionManager stopSession];
}

- (void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if (![self.renderLock tryLock]) return;

    CVPixelBufferRef pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer);
    if (!pixelBuffer) {
        [self.renderLock unlock];
        return;
    }

    if (connection == self.sessionManager.backCameraConnection) {
        if (self.backPixelBuffer) {
            CVPixelBufferRelease(self.backPixelBuffer);
        }
        self.backPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    } else if (connection == self.sessionManager.frontCameraConnection) {
        if (self.frontPixelBuffer) {
            CVPixelBufferRelease(self.frontPixelBuffer);
        }
        self.frontPixelBuffer = CVPixelBufferRetain(pixelBuffer);
    }

    dispatch_async(dispatch_get_main_queue(), ^{
        [self renderDualCameraPreview];
    });

    [self.renderLock unlock];
}

- (void)renderDualCameraPreview {
    if (!self.backPixelBuffer || !self.frontPixelBuffer) return;

    CIImage *backImage = [CIImage imageWithCVPixelBuffer:self.backPixelBuffer];
    CIImage *frontImage = [CIImage imageWithCVPixelBuffer:self.frontPixelBuffer];

    CGFloat overlayWidth = self.view.frame.size.width * 0.3;
    CGFloat overlayHeight = self.view.frame.size.height * 0.3;
    CGAffineTransform scaleTransform = CGAffineTransformMakeScale(0.3, 0.3);
    CGAffineTransform translateTransform = CGAffineTransformMakeTranslation(10, 50);
    frontImage = [frontImage imageByApplyingTransform:CGAffineTransformConcat(scaleTransform, translateTransform)];

    CIFilter *compositeFilter = [CIFilter filterWithName:@"CISourceOverCompositing"];
    [compositeFilter setValue:frontImage forKey:kCIInputImageKey];
    [compositeFilter setValue:backImage forKey:kCIInputBackgroundImageKey];

    CIImage *finalImage = [compositeFilter outputImage];

    CGFloat scale = [[UIScreen mainScreen] scale];
    CGRect destRect = CGRectMake(0, 0, self.view.frame.size.width * scale, self.view.frame.size.height * scale);
    
    [self.ciContext drawImage:finalImage inRect:destRect fromRect:[finalImage extent]];
    [self.context presentRenderbuffer:GL_RENDERBUFFER];

    [(GLKView *)(self.view) display];
}

@end
