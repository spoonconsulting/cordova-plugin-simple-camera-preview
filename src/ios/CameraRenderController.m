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
    self.context = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES2];
    if (!self.context)
        NSLog(@"Failed to create ES context");
    
    CVReturn err = CVOpenGLESTextureCacheCreate(kCFAllocatorDefault, NULL, self.context, NULL, &_videoTextureCache);
    if (err) {
        NSLog(@"Error at CVOpenGLESTextureCacheCreate %d", err);
        return;
    }
    
    GLKView *view = (GLKView *)self.view;
    view.context = self.context;
    view.drawableDepthFormat = GLKViewDrawableDepthFormat24;
    view.contentMode = UIViewContentModeScaleToFill;
    
    glGenRenderbuffers(1, &_renderBuffer);
    glBindRenderbuffer(GL_RENDERBUFFER, _renderBuffer);
    self.ciContext = [CIContext contextWithEAGLContext:self.context];
}

- (void) viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(appplicationIsActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(applicationEnteredForeground:) name:UIApplicationWillEnterForegroundNotification object:nil];
    
    UIInterfaceOrientation orientation= [UIApplication sharedApplication].statusBarOrientation;
    dispatch_async(self.sessionManager.sessionQueue, ^{
        if (!self.sessionManager.session.running){
            NSLog(@"Starting session from viewWillAppear");
            [self.sessionManager.session startRunning];
        }
        [self.sessionManager updateOrientation:[self.sessionManager getCurrentOrientation: orientation]];
    });
}

- (void) viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];
    
    dispatch_async(self.sessionManager.sessionQueue, ^{
        NSLog(@"Stopping session");
        [self.sessionManager.session stopRunning];
    });
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
    dispatch_async(self.sessionManager.sessionQueue, ^{
        NSLog(@"Stopping session");
        [self.sessionManager.session stopRunning];
    });
}

-(void)captureOutput:(AVCaptureOutput *)captureOutput didOutputSampleBuffer:(CMSampleBufferRef)sampleBuffer fromConnection:(AVCaptureConnection *)connection {
    if ([self.renderLock tryLock]) {
        CVPixelBufferRef pixelBuffer = (CVPixelBufferRef)CMSampleBufferGetImageBuffer(sampleBuffer);
        CIImage *image = [CIImage imageWithCVPixelBuffer:pixelBuffer];
        
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
        [(GLKView *)(self.view)display];
        [self.renderLock unlock];
    }
}

- (void)viewDidUnload {
    [super viewDidUnload];
    
    if ([EAGLContext currentContext] == self.context) {
        [EAGLContext setCurrentContext:nil];
    }
    self.context = nil;
}

- (BOOL)shouldAutorotate {
    return YES;
}

-(void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self.sessionManager updateOrientation:[self.sessionManager getCurrentOrientation:toInterfaceOrientation]];
}

@end
