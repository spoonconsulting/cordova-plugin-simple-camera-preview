#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "CameraSessionManager.h"
#import "CameraRenderController.h"

@interface SimpleCameraPreview : CDVPlugin <TakePictureDelegate, FocusDelegate>

- (void) enable:(CDVInvokedUrlCommand*)command;
- (void) disable:(CDVInvokedUrlCommand*)command;
- (void) setFlashMode:(CDVInvokedUrlCommand*)command;
- (void) capture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality;
- (void) capture;

@property (nonatomic) CameraSessionManager *sessionManager;
@property (nonatomic) CameraRenderController *cameraRenderController;
@property (nonatomic) NSString *onPictureTakenHandlerId;

@end
