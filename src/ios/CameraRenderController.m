#import "CameraRenderController.h"
#import <CoreVideo/CVOpenGLESTextureCache.h>
#import <GLKit/GLKit.h>
#import <OpenGLES/ES2/glext.h>

@implementation CameraRenderController
@synthesize context = _context;

- (CameraRenderController *)init {
    if (self = [super init])
        self.renderLock = [[NSLock alloc] init];
    return self;
}

- (void)loadView {
    GLKView *glkView = [[GLKView alloc] init];
    [glkView setBackgroundColor:[UIColor blackColor]];
    [glkView setAutoresizingMask:UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight];
    [self setView:glkView];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
    if (!self.context)
        NSLog(@"Failed to create ES context");
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
        return;
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormatNone;
    view.contentMode = UIViewContentModeScaleToFill;
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    self.ciContext = [CIContext contextWithEAGLContext:self.context];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appplicationIsActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(onAppWillResignActive) name:UIApplicationWillResignActiveNotification object:nil];
    
    dispatch_async(self.sessionManager.sessionQueue, ^{
        if (!self.sessionManager.session.running){
            NSLog(@"Starting session from viewWillAppear");
            [self.sessionManager.session startRunning];
        }
        UIInterfaceOrientation orientation = [self.sessionManager getOrientation];
        [self.sessionManager updateOrientation:[self.sessionManager getCurrentOrientation: orientation]];
    });
}

- (void)onAppWillResignActive {
    [self.sessionManager stopRecording];
}


- (void) appplicationIsActive:(NSNotification *)notification {
    dispatch_async(self.sessionManager.sessionQueue, ^{
        if (!self.sessionManager.session.running){
            NSLog(@"Starting session");
            [self.sessionManager.session startRunning];
        }
    });
}

- (void) applicationEnteredForeground:(NSNotification *)notification {
    [self.view removeFromSuperview];
    [EAGLContext setCurrentContext:nil];
    self.context = nil;
    [self deallocateRenderMemory];
    self.ciContext = nil;
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([self.renderLock tryLock]) {
        _pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *image = [CIImage imageWithCVPixelBuffer:_pixelBuffer];
        
        __block CGRect frame;
        dispatch_sync(dispatch_get_main_queue(), ^{
            frame = self.view.frame;
        });
        
        CGFloat scaleHeight = frame.size.height/image.extent.size.height;
        CGFloat scaleWidth = frame.size.width/image.extent.size.width;
        
        CGFloat scale, x, y;
        if (scaleHeight < scaleWidth) {
            scale = scaleWidth;
            x = 0;
            y = ((scale * image.extent.size.height) - frame.size.height ) / 2;
        } else {
            scale = scaleHeight;
            x = ((scale * image.extent.size.width) - frame.size.width )/ 2;
            y = 0;
        }
        
        // scale - translate
        CGAffineTransform xscale = CGAffineTransformMakeScale(scale, scale);
        CGAffineTransform xlate = CGAffineTransformMakeTranslation(-x, -y);
        CGAffineTransform xform =  CGAffineTransformConcat(xscale, xlate);
        
        CIFilter *centerFilter = [CIFilter filterWithName:@"CIAffineTransform"  keysAndValues:
                                  kCIInputImageKey, image,
                                  kCIInputTransformKey, [NSValue valueWithBytes:&xform objCType:@encode(CGAffineTransform)],
                                  nil];
        
        CIImage *transformedImage = [centerFilter outputImage];
        
        // crop
        CIFilter *cropFilter = [CIFilter filterWithName:@"CICrop"];
        CIVector *cropRect = [CIVector vectorWithX:0 Y:0 Z:frame.size.width W:frame.size.height];
        [cropFilter setValue:transformedImage forKey:kCIInputImageKey];
        [cropFilter setValue:cropRect forKey:@"inputRectangle"];
        CIImage *croppedImage = [cropFilter outputImage];
        
        //fix front mirroring
        if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
            CGAffineTransform matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(-1, 1), 0, croppedImage.extent.size.height);
            croppedImage = [croppedImage imageByApplyingTransform:matrix];
        }
        
        self.latestFrame = croppedImage;
        
        CGFloat pointScale;
        if ([[UIScreen mainScreen] respondsToSelector:@selector(nativeScale)]) {
            pointScale = [[UIScreen mainScreen] nativeScale];
        } else {
            pointScale = [[UIScreen mainScreen] scale];
        }
        CGRect dest = CGRectMake(0, 0, frame.size.width*pointScale, frame.size.height*pointScale);
        
        [self.ciContext drawImage:croppedImage inRect:dest fromRect:[croppedImage extent]];
        //[self.ciContext drawImage:image inRect:dest fromRect:[image extent]];
        [self.context presentRenderbuffer:GL_RENDERBUFFER];
        dispatch_async(dispatch_get_main_queue(), ^{
            [(GLKView *)(self.view)display];
        });
        [self.renderLock unlock];
    }
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(void) viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    __block UIInterfaceOrientation toInterfaceOrientation;
    [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        toInterfaceOrientation = [self.sessionManager getOrientation];

    } completion:^(id<UIViewControllerTransitionCoordinatorContext> context) {
        [self.sessionManager updateOrientation:[self.sessionManager getCurrentOrientation:toInterfaceOrientation]];
    }];
}

-(void) deallocateRenderMemory {
    if (_renderBuffer) {
        glDeleteRenderbuffers(1, &_renderBuffer);
        _renderBuffer = 0;
    }
    if (_videoTextureCache) {
        CVOpenGLESTextureCacheFlush(_videoTextureCache, 0);
        CFRelease(_videoTextureCache);
        _videoTextureCache = nil;
    }
    if(_lumaTexture) {
        CVOpenGLESTextureCacheFlush(_lumaTexture, 0);
        CFRelease(_lumaTexture);
        _lumaTexture = nil;
    }
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    [self.view removeFromSuperview];
    [EAGLContext setCurrentContext:nil];
    self.context = nil;
    self.ciContext = nil;
}

@end
