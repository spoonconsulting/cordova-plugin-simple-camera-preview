import UIKit
import AVFoundation

@objc(DualModeCameraPreview) class DualModeCameraPreview: CDVPlugin, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    private var session: AVCaptureMultiCamSession!
    private let queue = DispatchQueue(label: "dualMode.session.queue")
    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?
    private var backOutput = AVCaptureVideoDataOutput()
    private var frontOutput = AVCaptureVideoDataOutput()
    private var backVideoPort: AVCaptureInput.Port?
    private var frontVideoPort: AVCaptureInput.Port?
    private var audioOutput: AVCaptureAudioDataOutput?
    private var audioInput: AVCaptureInput?
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    private var pipView: UIView?

    @objc(deviceSupportDualMode:)
    func deviceSupportDualMode(command: CDVInvokedUrlCommand) {
        let supportsMultiCam = AVCaptureMultiCamSession.isMultiCamSupported
        
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: supportsMultiCam)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }

    @objc(enableDualMode:)
    func enableDualMode(_ command: CDVInvokedUrlCommand) {
        session = AVCaptureMultiCamSession()
        queue.async {
            self.setupSession()
            DispatchQueue.main.async {
                if let container = self.webView.superview {
                    self.setupPreview(on: container)
                } else {
                    let pluginResult = CDVPluginResult(status: .error, messageAs: "Container view not set")
                    self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
                    return
                }
                
                self.session.startRunning()
                let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode enabled successfully")
                self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
            }
        }
    }

    private func setupSession() {
         session.beginConfiguration()
         defer { session.commitConfiguration() }
         setupBackCamera()
         setupFrontCamera()
         setupMicrophone()
     }

    private func setupBackCamera() {
        guard let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
          let backInput = try? AVCaptureDeviceInput(device: backCamera),
          session.canAddInput(backInput) else {
        return
        }

        configureCamera(backCamera, desiredWidth: 1920, desiredHeight: 1080)
        self.backInput = backInput
        session.addInputWithNoConnections(backInput)

        if let port = backInput.ports.first(where: { $0.mediaType == .video }) {
            self.backVideoPort = port
        }

        if session.canAddOutput(backOutput) {
            backOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            backOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(backOutput)

            if let port = self.backVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: backOutput)
                connection.videoOrientation = .portrait
                session.addConnection(connection)
            }
        }
    }

    private func setupFrontCamera() {
        guard let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
          let frontInput = try? AVCaptureDeviceInput(device: frontCamera),
          session.canAddInput(frontInput) else {
        return
        }

        configureCamera(frontCamera, desiredWidth: 1920, desiredHeight: 1080)
        self.frontInput = frontInput
        session.addInputWithNoConnections(frontInput)

        if let port = frontInput.ports.first(where: { $0.mediaType == .video }) {
            self.frontVideoPort = port
        }

        if session.canAddOutput(frontOutput) {
            frontOutput.videoSettings = [
                kCVPixelBufferPixelFormatTypeKey as String: Int(kCVPixelFormatType_32BGRA)
            ]
            frontOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(frontOutput)

            if let port = self.frontVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: frontOutput)
                connection.videoOrientation = .portrait
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = true
                session.addConnection(connection)
            }
        }
    }

    private func setupMicrophone() {
        guard let mic = AVCaptureDevice.default(for: .audio),
              let micInput = try? AVCaptureDeviceInput(device: mic),
              session.canAddInput(micInput) else {
            return
        }

        self.audioInput = micInput
        session.addInputWithNoConnections(micInput)

        let audioOutput = AVCaptureAudioDataOutput()
        if session.canAddOutput(audioOutput) {
            audioOutput.setSampleBufferDelegate(self, queue: queue)
            session.addOutputWithNoConnections(audioOutput)

            if let port = micInput.ports.first(where: { $0.mediaType == .audio }) {
                let audioConnection = AVCaptureConnection(inputPorts: [port], output: audioOutput)
                if session.canAddConnection(audioConnection) {
                    session.addConnection(audioConnection)
                }
            }

            self.audioOutput = audioOutput
        }
    }
        
    private func configureCamera(_ device: AVCaptureDevice, desiredWidth: Int32, desiredHeight: Int32) {
        for format in device.formats {
            let description = format.formatDescription
            let dimensions = CMVideoFormatDescriptionGetDimensions(description)
            if dimensions.width == desiredWidth && dimensions.height == desiredHeight {
                do {
                    try device.lockForConfiguration()
                    device.activeFormat = format
                    device.unlockForConfiguration()
                    print("Set \(device.localizedName) resolution to \(desiredWidth)x\(desiredHeight)")
                    break
                } catch {
                    print("Error locking configuration for \(device.localizedName): \(error)")
                }
            }
        }
    }
        
        
    func setupPreview(on view: UIView) {
        self.setupBackPreviewLayer(on: view)
        self.setupPiPView(on: view)
        self.setupFrontPreviewLayer()
    }

    private func setupBackPreviewLayer(on view: UIView) {
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.frame = view.bounds

        if let backLayer = backPreviewLayer {
            if let webViewLayer = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView })?.layer {
                view.layer.insertSublayer(backLayer, below: webViewLayer)
            } else {
                view.layer.insertSublayer(backLayer, at: 0)
            }
        }
    }

    private func setupPiPView(on view: UIView) {
        let pipWidth: CGFloat = 160
        let pipHeight: CGFloat = 240
        let pipX: CGFloat = 16
        let pipY: CGFloat = 60

        let pipView = UIView(frame: CGRect(x: pipX, y: pipY, width: pipWidth, height: pipHeight))
        self.pipView = pipView
        pipView.layer.cornerRadius = 12
        pipView.clipsToBounds = true
        pipView.backgroundColor = .black

        if let webView = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView }) {
            view.insertSubview(pipView, belowSubview: webView)
        } else {
            view.addSubview(pipView)
        }
    }

    private func setupFrontPreviewLayer() {
        guard let pipView = self.pipView else { return }

        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = pipView.bounds

        if let frontLayer = frontPreviewLayer {
            pipView.layer.addSublayer(frontLayer)
        }
    }

    @objc(disableDualMode:)
    func disableDualMode(_ command: CDVInvokedUrlCommand) {
       queue.async {
           self.session.stopRunning()
           self.session = nil
           self.backInput = nil
           self.frontInput = nil
           self.backVideoPort = nil
           self.frontVideoPort = nil
           
           self.backOutput = AVCaptureVideoDataOutput()
           self.frontOutput = AVCaptureVideoDataOutput()
           
           DispatchQueue.main.async {
               self.backPreviewLayer?.removeFromSuperlayer()
               self.backPreviewLayer = nil
               self.frontPreviewLayer?.removeFromSuperlayer()
               self.frontPreviewLayer = nil
               self.pipView?.removeFromSuperview()
               self.pipView = nil
               
               let pluginResult = CDVPluginResult(status: .ok, messageAs: "Dual mode disabled successfully")
               self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
           }
       }
    }
}
