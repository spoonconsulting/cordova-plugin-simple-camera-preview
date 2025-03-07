#import <Cordova/CDV.h>
#import "SharinPix-Swift.h"

#import <Foundation/Foundation.h>
#import <AVFoundation/AVFoundation.h>
#import <UIKit/UIKit.h>

@interface DualModeManager : NSObject

@property (nonatomic, strong, readwrite) AVCaptureMultiCamSession *session;
@property (nonatomic, strong) AVCaptureDeviceInput *frontCameraInput;
@property (nonatomic, strong) AVCaptureDeviceInput *backCameraInput;
@property (nonatomic, strong, readwrite) AVCaptureVideoPreviewLayer *backPreviewLayer;
@property (nonatomic, strong, readwrite) AVCaptureVideoPreviewLayer *frontPreviewLayer;
@property (nonatomic, strong, readwrite) UIView *previewContainer;

+ (instancetype)sharedInstance;
- (void)toggleDualMode:(UIView *)webView;
- (BOOL)setupDualMode:(UIView *)webView;
- (void)stopDualMode;

@end
