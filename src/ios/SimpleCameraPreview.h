#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "CameraSessionManager.h"
#import "CameraRenderController.h"
#import "DualModeManager.h"
#import <CoreLocation/CoreLocation.h>
#import <AVFoundation/AVFoundation.h>

@interface SimpleCameraPreview : CDVPlugin <AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate, AVCaptureFileOutputRecordingDelegate>{
    CLLocationManager *locationManager;
    CLLocation* currentLocation;
}

- (void) setOptions:(CDVInvokedUrlCommand*)command;
- (void) enable:(CDVInvokedUrlCommand*)command;
- (void) disable:(CDVInvokedUrlCommand*)command;
- (void) capture:(CDVInvokedUrlCommand*)command;
- (void) setSize:(CDVInvokedUrlCommand*)command;
- (void) torchSwitch: (CDVInvokedUrlCommand*)command;
- (void) switchCameraTo: (CDVInvokedUrlCommand*) command;
- (void) deviceHasUltraWideCamera: (CDVInvokedUrlCommand*) command;
- (void) deviceHasFlash: (CDVInvokedUrlCommand*)command;
- (void)switchMode:(CDVInvokedUrlCommand*)command;
@property (nonatomic) CDVInvokedUrlCommand *videoCallbackContext;
@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;
@property (nonatomic) AVCapturePhotoSettings *photoSettings;
@property (nonatomic) NSString *onCameraEnabledHandlerId;
@property (nonatomic, strong) NSArray<UIViewController*> *dualPreviewControllers;
@property (nonatomic, assign) BOOL dualModeEnabled;
@property (nonatomic, strong) DualModeManager *dualModeManager;

@end
