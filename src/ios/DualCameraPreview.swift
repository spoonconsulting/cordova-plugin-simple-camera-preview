import UIKit
import AVFoundation
import CoreLocation

@objc(DualCameraPreview) class DualCameraPreview: CDVPlugin, DualCameraSessionManagerDelegate {
    private var sessionManager: DualCameraSessionManager?
    private var previewBuilder: DualCameraRenderController?
    private var latestBackImage: UIImage?
    private var latestFrontImage: UIImage?
    private var captureCompletion: ((UIImage?, Error?) -> Void)?
    private var currentLocation: CLLocation?
    var videoCallbackContext: CDVInvokedUrlCommand?
    private var videoRecorder: VideoRecorder?
    private var recordingCompletion: ((String, String?, Error?) -> Void)?
    private var recordingTimer: Timer?

    @objc(deviceSupportDualMode:)
    func deviceSupportDualMode(command: CDVInvokedUrlCommand) {
        let supportsMultiCam = AVCaptureMultiCamSession.isMultiCamSupported
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: supportsMultiCam)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(initVideoCallback:)
    func initVideoCallback(_ command: CDVInvokedUrlCommand) {
        self.videoCallbackContext = command
        let data: [String: Any] = ["videoCallbackInitialized": true]
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: data)
        pluginResult?.setKeepCallbackAs(true)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(enableDualMode:)
    func enableDualMode(_ command: CDVInvokedUrlCommand) {
        sessionManager = DualCameraSessionManager()
        previewBuilder = DualCameraRenderController()

        guard let sessionManager = sessionManager, let previewBuilder = previewBuilder else {
            let pluginResult = CDVPluginResult(status: .error, messageAs: "Failed to initialize session.")
            self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            return
        }

        sessionManager.setupSession(delegate: self)

        // Add orientation observer
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleOrientationChange),
            name: UIDevice.orientationDidChangeNotification,
            object: nil
        )

        DispatchQueue.main.async {
            if let container = self.webView.superview {
                previewBuilder.setupPreview(on: container, session: sessionManager.session, sessionManager: sessionManager)
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
        // Remove orientation observer
        NotificationCenter.default.removeObserver(self, name: UIDevice.orientationDidChangeNotification, object: nil)
        
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

    func sessionManager(_ manager: DualCameraSessionManager, didOutput sampleBuffer: CMSampleBuffer, from output: AVCaptureOutput) {
        if self.captureCompletion != nil {
           guard let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

           let ciImage = CIImage(cvImageBuffer: imageBuffer)
           let context = CIContext()
           guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

           let orientation = getImageOrientationForCapture(connection: nil)
           let image = UIImage(cgImage: cgImage, scale: UIScreen.main.scale, orientation: orientation)

           if output == manager.backOutput {
               latestBackImage = image
           } else if output == manager.frontOutput {
               latestFrontImage = image
           }

           if let front = latestFrontImage, let back = latestBackImage, let completion = captureCompletion {
               let merged = mergeImages(background: back, overlay: front)
               let finalImage: UIImage
               // Rotate to portrait if the current orientation is portrait and merged image is landscape
               if !UIDevice.current.orientation.isLandscape {
                   finalImage = rotateImageToPortrait(merged)
               } else {
                   finalImage = merged
               }
               DispatchQueue.main.async {
                   completion(finalImage, nil)
                   self.captureCompletion = nil
                   self.latestBackImage = nil
                   self.latestFrontImage = nil
               }
            }
        }
    }

    // Rotate image by 90 degrees counter-clockwise to convert landscape to portrait
    private func rotateImageToPortrait(_ image: UIImage) -> UIImage {
        let size = CGSize(width: image.size.height, height: image.size.width)
        UIGraphicsBeginImageContextWithOptions(size, false, image.scale)
        guard let context = UIGraphicsGetCurrentContext() else { return image }
        context.translateBy(x: 0, y: size.height)
        context.rotate(by: -.pi / 2)
        image.draw(in: CGRect(x: 0, y: 0, width: image.size.width, height: image.size.height))
        let rotatedImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return rotatedImage ?? image
    }

    private func imageOrientation(for videoOrientation: AVCaptureVideoOrientation) -> UIImage.Orientation {
        switch videoOrientation {
        case .portrait:
            return .up
        case .portraitUpsideDown:
            return .down
        case .landscapeRight:
            return .right
        case .landscapeLeft:
            return .left
        @unknown default:
            return .up
        }
    }

    private func getImageOrientationForCapture(connection: AVCaptureConnection?) -> UIImage.Orientation {
        let deviceOrientation = UIDevice.current.orientation
        let isLandscape = deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight
        
        if !isLandscape {
            if let connection = connection {
                return imageOrientation(for: connection.videoOrientation)
            } else {
                return .right
            }
        }
            
        switch deviceOrientation {
        case .landscapeLeft:
            return .up
        case .landscapeRight:
            return .down
        default:
            return .up
        }
    }

    private func getImageOrientationFromConnection(_ connection: AVCaptureConnection) -> UIImage.Orientation {
        return imageOrientation(for: connection.videoOrientation)
    }

    func mergeImages(background: UIImage, overlay: UIImage) -> UIImage {
        let size = background.size
        let deviceOrientation = UIDevice.current.orientation
        let isLandscape = deviceOrientation == .landscapeLeft || deviceOrientation == .landscapeRight
        let padding: CGFloat = 16
        var overlayWidth: CGFloat
        var overlayHeight: CGFloat
        var overlayRect: CGRect

        overlayWidth = size.width * 0.3
        overlayHeight = overlay.size.height * (overlayWidth / overlay.size.width)

        if isLandscape {
            overlayRect = CGRect(x: padding,
                                 y: padding,
                                 width: overlayWidth,
                                 height: overlayHeight)
        } else {
            // Portrait capture (image will be rotated later) – place overlay top-right so it lands top-left after rotation
            overlayRect = CGRect(x: size.width - overlayWidth - padding,
                                 y: padding,
                                 width: overlayWidth,
                                 height: overlayHeight)
        }

        UIGraphicsBeginImageContextWithOptions(size, false, 0)
        background.draw(in: CGRect(origin: .zero, size: size))
        overlay.draw(in: overlayRect)
        let merged = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return merged ?? background
    }
    
    @objc(startVideoCaptureDual:)
     func startVideoCaptureDual(_ command: CDVInvokedUrlCommand) {
        guard let options = command.arguments.first as? [String: Any] else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Missing options")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        let recordWithAudio = options["recordWithAudio"] as? Bool ?? true
        let videoDurationMs = options["videoDurationMs"] as? Int ?? 3000
        
        guard self.sessionManager != nil else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Dual mode not enabled")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            let event: [String: Any] = ["recording": true]
            let recordingStarted = CDVPluginResult(status: .ok, messageAs: event)!
            recordingStarted.setKeepCallbackAs(true)
            self.commandDelegate.send(recordingStarted, callbackId: callbackId)
        } else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Video callback context not initialized")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            return
        }
        
        self.startDualVideoRecordingWithAudio(recordWithAudio, duration: videoDurationMs) { [weak self] (videoPath, thumbnailPath, error) in
            guard let self = self else { return }
            if let error = error {
                let errorResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)!
                self.commandDelegate.send(errorResult, callbackId: command.callbackId)
            } else {
                let result: [String: Any] = [
                    "nativePath": videoPath,
                    "thumbnail": thumbnailPath ?? NSNull()
                ]
                let pluginResult = CDVPluginResult(status: .ok, messageAs: result)!
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    @objc func startDualVideoRecordingWithAudio(
        _ recordWithAudio: Bool,
        duration: Int,
        completion: @escaping (String, String?, Error?) -> Void
    ) {
        self.videoRecorder = VideoRecorder()
        self.recordingCompletion = completion
        self.videoRecorder?.startWriting(audioEnabled: recordWithAudio) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                completion("", nil, error)
                return
            }

            if let recorder = self.videoRecorder {
                self.sessionManager?.startRecording(with: recorder)
            }

            let durationInSeconds = TimeInterval(duration) / 1000.0
            self.recordingTimer = Timer.scheduledTimer(
                timeInterval: durationInSeconds,
                target: self,
                selector: #selector(self.stopVideoCaptureDualTimer),
                userInfo: nil,
                repeats: false
            )
        }
    }
    
    @objc(stopVideoCaptureDual:)
    func stopVideoCaptureDual(_ command: CDVInvokedUrlCommand) {
        if self.sessionManager != nil {
            self.stopDualVideoRecording()
            let result = CDVPluginResult(status: .ok)!
            self.commandDelegate.send(result, callbackId: command.callbackId)
        } else {
            let errorResult = CDVPluginResult(status: .error, messageAs: "Dual mode not enabled")!
            self.commandDelegate.send(errorResult, callbackId: command.callbackId)
        }
    }
    
    @objc func stopVideoCaptureDualTimer() {
        self.stopDualVideoRecording()
    }
    
    func stopDualVideoRecording() {
        recordingTimer?.invalidate()
        recordingTimer = nil

        self.sessionManager?.stopRecording()

        self.videoRecorder?.stopWriting { [weak self] path, thumb, err in
            guard let self = self else { return }

            self.recordingCompletion?(path, thumb, err)
            self.recordingCompletion = nil

            if let error = err {
                self.dualModeRecordingDidFail(withError: error)
            } else {
                self.dualModeRecordingDidFinish(withVideoPath: path, thumbnailPath: thumb)
            }
            self.videoRecorder = nil
        }
    }

    @objc func dualModeRecordingDidFinish(withVideoPath videoPath: String, thumbnailPath: String?) {
        let result: [String: Any] = [
            "nativePath": videoPath,
            "thumbnail": thumbnailPath ?? NSNull()
        ]
        
        let pluginResult = CDVPluginResult(status: .ok, messageAs: result)!
        pluginResult.setKeepCallbackAs(true)
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            self.commandDelegate.send(pluginResult, callbackId: callbackId)
        } else {
            print("videoCallbackContext not set; cannot send result.")
        }
    }

    @objc func dualModeRecordingDidFail(withError error: Error) {
        let pluginResult = CDVPluginResult(status: .error, messageAs: error.localizedDescription)!
        
        if let callbackId = self.videoCallbackContext?.callbackId {
            self.commandDelegate.send(pluginResult, callbackId: callbackId)
        } else {
            print("videoCallbackContext not set; cannot send error.")
        }
    }
    
    @objc private func handleOrientationChange() {
        if videoRecorder != nil {
            let isLandscape = UIDevice.current.orientation.isLandscape
            if isLandscape {
                sessionManager?.videoMixer.pipFrame = CGRect(x: 0.03, y: 0.03, width: 0.25, height: 0.25)
            } else {
                sessionManager?.videoMixer.pipFrame = CGRect(x: 0.05, y: 0.05, width: 0.3, height: 0.3)
            }
        }
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
