import UIKit
import AVFoundation
import CoreLocation

@objc(DualCameraPreview) class DualCameraPreview: CDVPlugin, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    private var sessionManager: DualCameraSessionManager?
    private var previewBuilder: PreviewLayerBuilder?
    private var latestBackImage: UIImage?
    private var latestFrontImage: UIImage?
    private var captureCompletion: ((UIImage?, Error?) -> Void)?
    private var currentLocation: CLLocation?

    @objc(deviceSupportDualMode:)
    func deviceSupportDualMode(command: CDVInvokedUrlCommand) {
        let supportsMultiCam = AVCaptureMultiCamSession.isMultiCamSupported
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: supportsMultiCam)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(enableDualMode:)
    func enableDualMode(_ command: CDVInvokedUrlCommand) {
        sessionManager = DualCameraSessionManager()
        previewBuilder = PreviewLayerBuilder()

        guard let sessionManager = sessionManager, let previewBuilder = previewBuilder else {
            let pluginResult = CDVPluginResult(status: .error, messageAs: "Failed to initialize session.")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }

        sessionManager.setupSession(delegate: self)

        DispatchQueue.main.async {
            if let container = self.webView.superview {
                previewBuilder.setupPreview(on: container, session: sessionManager.session)
            } else {
                let pluginResult = CDVPluginResult(status: .error, messageAs: "Container view not set")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                return
            }

            sessionManager.startSession()
            let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode enabled successfully")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        }
    }

    @objc(disableDualMode:)
    func disableDualMode(_ command: CDVInvokedUrlCommand) {
        sessionManager?.stopSession()

        DispatchQueue.main.async {
            self.previewBuilder?.teardownPreview()
            self.sessionManager = nil
            self.previewBuilder = nil
            
            let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode disabled successfully")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
        }
    }
    
    func getGPSDictionaryForLocation() -> [String: Any]? {
        guard let location = currentLocation else { return nil }
        var gps: [String: Any] = [:]
        
        // GPS tag version
        gps[kCGImagePropertyGPSVersion as String] = "2.2.0.0"
        
        // Time and date must be provided as strings, not as an NSDate object
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss.SSSSSS"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        gps[kCGImagePropertyGPSTimeStamp as String] = formatter.string(from: location.timestamp)
        formatter.dateFormat = "yyyy:MM:dd"
        gps[kCGImagePropertyGPSDateStamp as String] = formatter.string(from: location.timestamp)
        
        // Latitude
        var latitude = location.coordinate.latitude
        if latitude < 0 {
            latitude = -latitude
            gps[kCGImagePropertyGPSLatitudeRef as String] = "S"
        } else {
            gps[kCGImagePropertyGPSLatitudeRef as String] = "N"
        }
        gps[kCGImagePropertyGPSLatitude as String] = latitude
        
        // Longitude
        var longitude = location.coordinate.longitude
        if longitude < 0 {
            longitude = -longitude
            gps[kCGImagePropertyGPSLongitudeRef as String] = "W"
        } else {
            gps[kCGImagePropertyGPSLongitudeRef as String] = "E"
        }
        gps[kCGImagePropertyGPSLongitude as String] = longitude
        
        // Altitude
        let altitude = location.altitude
        if !altitude.isNaN {
            if altitude < 0 {
                gps[kCGImagePropertyGPSAltitudeRef as String] = "1"
            } else {
                gps[kCGImagePropertyGPSAltitudeRef as String] = "0"
            }
            gps[kCGImagePropertyGPSAltitude as String] = altitude
        }
        
        if location.speed >= 0 {
            gps[kCGImagePropertyGPSSpeedRef as String] = "K"
            gps[kCGImagePropertyGPSSpeed as String] = location.speed * 3.6
        }
        
        // Heading
        if location.course >= 0 {
            gps[kCGImagePropertyGPSTrackRef as String] = "T"
            gps[kCGImagePropertyGPSTrack as String] = location.course
        }
        
        return gps
    }
    
    @objc(captureDual:)
    func captureDual(_ command: CDVInvokedUrlCommand) {
        self.captureDualImagesWithCompletion {
            [weak self] mergedImage, error in
            guard let self = self else { return }
            
            if let error = error {
                let errorResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            guard let mergedImage = mergedImage else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to capture image")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let imageData = mergedImage.jpegData(compressionQuality: 0.9) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to convert merged image")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            let cfData = imageData as CFData
            guard let imageSource = CGImageSourceCreateWithData(cfData, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to create image source")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let metaDict = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to get image properties")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            let mutableDict = NSMutableDictionary(dictionary: metaDict)
            
            if let gpsData = getGPSDictionaryForLocation() {
                mutableDict[kCGImagePropertyGPSDictionary as String] = gpsData
            }
            
            let paths = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true)
            guard let libraryDirectory = paths.first else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Library directory not found")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            let noCloudPath = (libraryDirectory as NSString).appendingPathComponent("NoCloud")
            let uniqueFileName = UUID().uuidString + ".jpg"
            let fullPath = (noCloudPath as NSString).appendingPathComponent(uniqueFileName)
            let dataPath = "file://" + fullPath
            
            guard let url = URL(string: dataPath) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Invalid file URL")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let uti = CGImageSourceGetType(imageSource) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to get image UTI")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, uti, 1, nil) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to create image destination")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }
            
            CGImageDestinationAddImageFromSource(destination, imageSource, 0, mutableDict)
            
            guard CGImageDestinationFinalize(destination) else {
                let errorResult = CDVPluginResult(status: .error, messageAs: "Failed to finalize image destination")
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
                return
            }

            let successResult = CDVPluginResult(status: .ok, messageAs: dataPath)
            self.commandDelegate.send(successResult, callbackId: command.callbackId)
            }
    }

    @objc func captureDualImagesWithCompletion(_ completion: @escaping (UIImage?, Error?) -> Void) {
        self.captureCompletion = completion
        self.latestFrontImage = nil
        self.latestBackImage = nil
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
       if self.captureCompletion != nil {
           guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer),
                 let sessionManager = self.sessionManager else { return }

           let ciImage = CIImage(cvImageBuffer: imageBuffer)
           let context = CIContext()
           guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

           let orientation = self.imageOrientationForCurrentDevice()
           let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: orientation)

           if output == sessionManager.backOutput {
               latestBackImage = image
           } else if output == sessionManager.frontOutput {
               latestFrontImage = image
           }

           if let front = latestFrontImage, let back = latestBackImage, let completion = captureCompletion {
               let merged = mergeImages(background: back, overlay: front)
               let rotated = rotateImage(merged)

               DispatchQueue.main.async {
                   completion(rotated, nil)
                   self.captureCompletion = nil
                   self.latestBackImage = nil
                   self.latestFrontImage = nil
               }
           }
       }
   }
    
    private func imageOrientationForCurrentDevice() -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        switch deviceOrientation {
        case .portraitUpsideDown:
            return .left
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        case .portrait:
            return .right
        default:
            return .right
        }
    }
    
    func mergeImages(background: UIImage, overlay: UIImage) -> UIImage {
        let size = background.size
        let overlayWidth: CGFloat = size.width * 0.3
        let overlayHeight = overlay.size.height * (overlayWidth / overlay.size.width)
        let padding: CGFloat = 16

        let overlayRect = CGRect(
            x: size.width - overlayWidth - padding,
            y: padding,
            width: overlayWidth,
            height: overlayHeight
        )

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        background.draw(in: CGRect(origin: .zero, size: size))
        overlay.draw(in: overlayRect)
        let merged = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        guard let merged = merged else {
            return background
        }
        return merged
    }
    
    func rotateImage(_ image: UIImage) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else {
            return image
        }

        context.translateBy(x: 0, y: size.height)
        context.rotate(by: -.pi / 2)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))

        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return rotatedImage ?? image
    }
    
}

extension CALayer {
    func snapshot() -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: self.bounds.size)
        return renderer.image { ctx in
            self.render(in: ctx.cgContext)
        }
    }
}
