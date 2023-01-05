#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "CameraSessionManager.h"
#import "CameraRenderController.h"
#import <CoreLocation/CoreLocation.h>
@interface SimpleCameraPreview : CDVPlugin <TakePictureDelegate,CLLocationManagerDelegate>{
    CLLocationManager *locationManager;
    CLLocation* currentLocation;
}

- (void) setOptions:(CDVInvokedUrlCommand*)command;
- (void) enable:(CDVInvokedUrlCommand*)command;
- (void) disable:(CDVInvokedUrlCommand*)command;
- (void) capture:(CDVInvokedUrlCommand*)command;
- (void) setSize:(CDVInvokedUrlCommand*)command;
- (void) torchSwitch: (CDVInvokedUrlCommand*)command;
- (void) deviceHasFlash: (CDVInvokedUrlCommand*)command;
@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;

@end
