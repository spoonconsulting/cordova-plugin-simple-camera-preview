#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>
#import "CameraSessionManager.h"
#import "CameraRenderController.h"
#import <CoreLocation/CoreLocation.h>

@interface SimpleCameraPreview : CDVPlugin <AVCapturePhotoCaptureDelegate, CLLocationManagerDelegate, AVCaptureFileOutputRecordingDelegate, DualModeRecordingDelegate>{
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
@property (nonatomic) CDVInvokedUrlCommand *videoCallbackContext;
@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) DualMode *dualmode;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;
@property (nonatomic) AVCapturePhotoSettings *photoSettings;
@property (nonatomic) NSString *onCameraEnabledHandlerId;
@property (nonatomic, assign) BOOL isDualModeEnabled;
@property (nonatomic, strong) DualMode *dualMode;
@property (nonatomic, strong) AVCaptureVideoPreviewLayer *previewLayer;

@end
