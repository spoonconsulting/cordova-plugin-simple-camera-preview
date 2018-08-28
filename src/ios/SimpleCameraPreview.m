
#import <Cordova/CDV.h>
#import <Cordova/CDVPlugin.h>
#import <Cordova/CDVInvokedUrlCommand.h>

#import "SimpleCameraPreview.h"

@implementation SimpleCameraPreview

-(void) pluginInitialize{
  // start as transparent
  self.webView.opaque = NO;
  self.webView.backgroundColor = [UIColor clearColor];
}

- (void) enable:(CDVInvokedUrlCommand*)command {

  CDVPluginResult *pluginResult;

  if (self.sessionManager != nil) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera already started!"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    return;
  }


    // Create the session manager
    self.sessionManager = [[CameraSessionManager alloc] init];

    // render controller setup
    self.cameraRenderController = [[CameraRenderController alloc] init];
    self.cameraRenderController.tapToTakePicture = NO;
    self.cameraRenderController.sessionManager = self.sessionManager;
    self.cameraRenderController.view.frame = CGRectMake(0, 0, self.viewController.view.frame.size.width, self.viewController.view.frame.size.height);
    self.cameraRenderController.delegate = self;

    [self.viewController addChildViewController:self.cameraRenderController];

   
      // display the camera below the webview

      // make transparent
      self.webView.opaque = NO;
      self.webView.backgroundColor = [UIColor clearColor];

      [self.webView.superview addSubview:self.cameraRenderController.view];
      [self.webView.superview bringSubviewToFront:self.webView];
    

    // Setup session
    self.sessionManager.delegate = self.cameraRenderController;

    [self.sessionManager setupSession:@"back" completion:^(BOOL started) {
      [self.commandDelegate sendPluginResult:[CDVPluginResult resultWithStatus:CDVCommandStatus_OK] callbackId:command.callbackId];

    }];


}

- (void) disable:(CDVInvokedUrlCommand*)command {
    
    NSLog(@"disable");
    
    [self.cameraRenderController.view removeFromSuperview];
    [self.cameraRenderController removeFromParentViewController];
    self.cameraRenderController = nil;
    
    [self.commandDelegate runInBackground:^{
        
        CDVPluginResult *pluginResult;
        if(self.sessionManager != nil) {
            
            for(AVCaptureInput *input in self.sessionManager.session.inputs) {
                [self.sessionManager.session removeInput:input];
            }
            
            for(AVCaptureOutput *output in self.sessionManager.session.outputs) {
                [self.sessionManager.session removeOutput:output];
            }
            
            [self.sessionManager.session stopRunning];
            self.sessionManager = nil;
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
        }
        else {
            pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
        }
        
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
    }];
}

- (void) setFlashMode:(CDVInvokedUrlCommand*)command {
  NSLog(@"Flash Mode");
  NSString *errMsg;
  CDVPluginResult *pluginResult;

  NSString *flashMode = [command.arguments objectAtIndex:0];

  if (self.sessionManager != nil) {
    if ([flashMode isEqual: @"off"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeOff];
    } else if ([flashMode isEqual: @"on"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeOn];
    } else if ([flashMode isEqual: @"auto"]) {
      [self.sessionManager setFlashMode:AVCaptureFlashModeAuto];
    } else if ([flashMode isEqual: @"torch"]) {
      [self.sessionManager setTorchMode];
    } else {
      errMsg = @"Flash Mode not supported";
    }
  } else {
    errMsg = @"Session not started";
  }

  if (errMsg) {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:errMsg];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (void) takePicture:(CDVInvokedUrlCommand*)command {
  NSLog(@"takePicture");
  CDVPluginResult *pluginResult;

  if (self.cameraRenderController != NULL) {
    self.onPictureTakenHandlerId = command.callbackId;

    CGFloat width = (CGFloat)[command.arguments[0] floatValue];
    CGFloat height = (CGFloat)[command.arguments[1] floatValue];
    CGFloat quality = (CGFloat)[command.arguments[2] floatValue] / 100.0f;

    [self capture:width withHeight:height withQuality:quality];
  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Camera not started"];
    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
  }
}

- (void) setPreviewSize: (CDVInvokedUrlCommand*)command {

    CDVPluginResult *pluginResult;

    if (self.sessionManager == nil) {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
        return;
    }

    if (command.arguments.count > 1) {
        CGFloat width = (CGFloat)[command.arguments[0] floatValue];
        CGFloat height = (CGFloat)[command.arguments[1] floatValue];

        self.cameraRenderController.view.frame = CGRectMake(0, 0, width, height);

        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK];
    } else {
        pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Invalid number of parameters"];
    }

    [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}

- (void) getSupportedPictureSizes:(CDVInvokedUrlCommand*)command {
  NSLog(@"getSupportedPictureSizes");
  CDVPluginResult *pluginResult;

  if(self.sessionManager != nil){
    NSArray *formats = self.sessionManager.getDeviceFormats;
    NSMutableArray *jsonFormats = [NSMutableArray new];
    int lastWidth = 0;
    int lastHeight = 0;
    for (AVCaptureDeviceFormat *format in formats) {
      CMVideoDimensions dim = format.highResolutionStillImageDimensions;
      if (dim.width!=lastWidth && dim.height != lastHeight) {
        NSMutableDictionary *dimensions = [[NSMutableDictionary alloc] init];
        NSNumber *width = [NSNumber numberWithInt:dim.width];
        NSNumber *height = [NSNumber numberWithInt:dim.height];
        [dimensions setValue:width forKey:@"width"];
        [dimensions setValue:height forKey:@"height"];
        [jsonFormats addObject:dimensions];
        lastWidth = dim.width;
        lastHeight = dim.height;
      }
    }
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsArray:jsonFormats];

  } else {
    pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_ERROR messageAsString:@"Session not started"];
  }

  [self.commandDelegate sendPluginResult:pluginResult callbackId:command.callbackId];
}


- (double)radiansFromUIImageOrientation:(UIImageOrientation)orientation {
  double radians;
    
    switch (UIDevice.currentDevice.orientation) {
        case UIDeviceOrientationPortrait:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationFaceUp:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationFaceDown:
            radians = M_PI_2;
            break;
        case UIDeviceOrientationLandscapeLeft:
            radians = 0.f;
            break;
        case UIDeviceOrientationLandscapeRight:
            radians = M_PI;
            break;
        case UIDeviceOrientationPortraitUpsideDown:
            radians = -M_PI_2;
            break;
        default:
            radians = M_PI;
            break;
    }

  return radians;
}

-(CGImageRef) CGImageRotated:(CGImageRef) originalCGImage withRadians:(double) radians {
  CGSize imageSize = CGSizeMake(CGImageGetWidth(originalCGImage), CGImageGetHeight(originalCGImage));
  CGSize rotatedSize;
  if (radians == M_PI_2 || radians == -M_PI_2) {
    rotatedSize = CGSizeMake(imageSize.height, imageSize.width);
  } else {
    rotatedSize = imageSize;
  }

  double rotatedCenterX = rotatedSize.width / 2.f;
  double rotatedCenterY = rotatedSize.height / 2.f;

  UIGraphicsBeginImageContextWithOptions(rotatedSize, NO, 1.f);
  CGContextRef rotatedContext = UIGraphicsGetCurrentContext();
  if (radians == 0.f || radians == M_PI) { // 0 or 180 degrees
    CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
    if (radians == 0.0f) {
      CGContextScaleCTM(rotatedContext, 1.f, -1.f);
    } else {
      CGContextScaleCTM(rotatedContext, -1.f, 1.f);
    }
    CGContextTranslateCTM(rotatedContext, -rotatedCenterX, -rotatedCenterY);
  } else if (radians == M_PI_2 || radians == -M_PI_2) { // +/- 90 degrees
    CGContextTranslateCTM(rotatedContext, rotatedCenterX, rotatedCenterY);
    CGContextRotateCTM(rotatedContext, radians);
    CGContextScaleCTM(rotatedContext, 1.f, -1.f);
    CGContextTranslateCTM(rotatedContext, -rotatedCenterY, -rotatedCenterX);
  }

  CGRect drawingRect = CGRectMake(0.f, 0.f, imageSize.width, imageSize.height);
  CGContextDrawImage(rotatedContext, drawingRect, originalCGImage);
  CGImageRef rotatedCGImage = CGBitmapContextCreateImage(rotatedContext);

  UIGraphicsEndImageContext();

  return rotatedCGImage;
}

- (void) invokeTapToFocus:(CGPoint)point {
  [self.sessionManager tapToFocus:point.x yPoint:point.y];
}

- (void) capture {
  [self capture:0.0 withHeight:0.0 withQuality:0.85];
}

- (void) captureOnFocus {
    // the sessionManager will call onFocus, as soon as the camera is done with focussing.
  [self.sessionManager takePictureOnFocus];
}

- (void) capture:(CGFloat) width withHeight:(CGFloat) height withQuality:(CGFloat) quality{
    AVCaptureConnection *connection = [self.sessionManager.stillImageOutput connectionWithMediaType:AVMediaTypeVideo];
    [self.sessionManager.stillImageOutput captureStillImageAsynchronouslyFromConnection:connection completionHandler:^(CMSampleBufferRef sampleBuffer, NSError *error) {

      NSLog(@"Done creating still image");

      if (error) {
        NSLog(@"%@", error);
      } else {
        NSData *imageData = [AVCaptureStillImageOutput jpegStillImageNSDataRepresentation:sampleBuffer];
        UIImage *capturedImage  = [[UIImage alloc] initWithData:imageData];

        CIImage *capturedCImage;
        //image resize

        if(width > 0 && height > 0){
          CGFloat scaleHeight = width/capturedImage.size.height;
          CGFloat scaleWidth = height/capturedImage.size.width;
          CGFloat scale = scaleHeight > scaleWidth ? scaleWidth : scaleHeight;

          CIFilter *resizeFilter = [CIFilter filterWithName:@"CILanczosScaleTransform"];
          [resizeFilter setValue:[[CIImage alloc] initWithCGImage:[capturedImage CGImage]] forKey:kCIInputImageKey];
          [resizeFilter setValue:[NSNumber numberWithFloat:1.0f] forKey:@"inputAspectRatio"];
          [resizeFilter setValue:[NSNumber numberWithFloat:scale] forKey:@"inputScale"];
          capturedCImage = [resizeFilter outputImage];
        }else{
          capturedCImage = [[CIImage alloc] initWithCGImage:[capturedImage CGImage]];
        }

        CIImage *imageToFilter;
        CIImage *finalCImage;

        //fix front mirroring
        if (self.sessionManager.defaultCamera == AVCaptureDevicePositionFront) {
          CGAffineTransform matrix = CGAffineTransformTranslate(CGAffineTransformMakeScale(1, -1), 0, capturedCImage.extent.size.height);
          imageToFilter = [capturedCImage imageByApplyingTransform:matrix];
        } else {
          imageToFilter = capturedCImage;
        }

        CIFilter *filter = [self.sessionManager ciFilter];
        if (filter != nil) {
          [self.sessionManager.filterLock lock];
          [filter setValue:imageToFilter forKey:kCIInputImageKey];
          finalCImage = [filter outputImage];
          [self.sessionManager.filterLock unlock];
        } else {
          finalCImage = imageToFilter;
        }

        CGImageRef finalImage = [self.cameraRenderController.ciContext createCGImage:finalCImage fromRect:finalCImage.extent];
        UIImage *resultImage = [UIImage imageWithCGImage:finalImage];

        double radians = [self radiansFromUIImageOrientation:resultImage.imageOrientation];
        CGImageRef resultFinalImage = [self CGImageRotated:finalImage withRadians:radians];

        CGImageRelease(finalImage); // release CGImageRef to remove memory leaks
        //write image to disk
        UIImage *image = [UIImage imageWithCGImage:resultFinalImage];
        NSData *pictureData = UIImageJPEGRepresentation(image, quality);
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES);
        NSString *libraryDirectory = [[paths objectAtIndex:0] stringByAppendingPathComponent:@"NoCloud"];
        NSString* uniqueFileName = [NSString stringWithFormat:@"%@.jpg",[[NSUUID UUID] UUIDString]];
        NSString *dataPath = [libraryDirectory stringByAppendingPathComponent:uniqueFileName];
        [pictureData writeToFile:dataPath atomically:YES];

        
        CGImageRelease(resultFinalImage); // release CGImageRef to remove memory leaks
          
        CDVPluginResult *pluginResult = [CDVPluginResult resultWithStatus:CDVCommandStatus_OK messageAsString:uniqueFileName];
        [pluginResult setKeepCallbackAsBool:true];
        [self.commandDelegate sendPluginResult:pluginResult callbackId:self.onPictureTakenHandlerId];
      }
    }];
}



@end
