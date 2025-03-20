#import <Cordova/CDV.h>
#import "SharinPix-Swift.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface DualModeManager : NSObject <AVCaptureVideoDataOutputSampleBufferDelegate>
@property (nonatomic, strong) AVCaptureMultiCamSession *session;
@property (nonatomic, strong) dispatch_queue_t sessionQueue;
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong) AVCapturePhotoOutput *frontPhotoOutput;
@property (nonatomic, strong) AVCapturePhotoOutput *backPhotoOutput;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *frontPreviewLayer;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *backPreviewLayer;
@property (nonatomic, strong) UIView *previewContainer;
@property (nonatomic, assign) CGRect frontPreviewFrame;
@property (nonatomic, strong) NSLock *filterLock;
@property (nonatomic) AVCaptureDevice *device;
@property (nonatomic, strong) UIImage *capturedFrontImage;
@property (nonatomic, strong) UIImage *capturedBackImage;
@property (nonatomic, copy) void (^captureCompletion)(UIImage *compositeImage);
@property (nonatomic, strong) EAGLContext *context;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, assign) GLuint renderBuffer;
@property (nonatomic, assign) CVOpenGLESTextureCacheRef videoTextureCache;
@property (nonatomic, assign) CVOpenGLESTextureRef lumaTexture;
@property (nonatomic, strong) NSLock *renderLock;
@property (nonatomic, strong) CIImage *latestFrontFrame;
@property (nonatomic, strong) CIImage *latestBackFrame;

+ (instancetype)sharedInstance;
- (void)toggleDualMode:(UIView *)webView;
- (BOOL)setupDualMode:(UIView *)webView;
- (void)stopDualMode;
- (void)captureDualImageWithCompletion:(void (^)(UIImage *compositeImage))completion;
- (void)deallocSession;

@end
