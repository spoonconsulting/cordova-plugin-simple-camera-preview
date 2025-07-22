import Foundation
import AVFoundation

protocol DualCameraSessionManagerDelegate: AnyObject {
    func sessionManager(_ manager: DualCameraSessionManager, didOutput sampleBuffer: CMSampleBuffer, from output: AVCaptureOutput)
}

class DualCameraSessionManager: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    let session = AVCaptureMultiCamSession()
    private let queue = DispatchQueue(label: "dualMode.session.queue")
    private(set) var backInput: AVCaptureDeviceInput?
    private(set) var frontInput: AVCaptureDeviceInput?
    private(set) var backOutput = AVCaptureVideoDataOutput()
    private(set) var frontOutput = AVCaptureVideoDataOutput()
    private(set) var backVideoPort: AVCaptureInput.Port?
    private(set) var frontVideoPort: AVCaptureInput.Port?
    private(set) var audioOutput: AVCaptureAudioDataOutput?
    private(set) var audioInput: AVCaptureInput?
    private var videoRecorder: VideoRecorder?
    var videoMixer = VideoMixer()
    private var latestBackBuffer: CMSampleBuffer?
    private var latestFrontBuffer: CMSampleBuffer?
    weak var delegate: DualCameraSessionManagerDelegate?

    func setupSession(delegate: DualCameraSessionManagerDelegate) {
        self.delegate = delegate
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        setupBackCamera()
        setupFrontCamera()
        setupMicrophone()

        backOutput.setSampleBufferDelegate(self, queue: queue)
        frontOutput.setSampleBufferDelegate(self, queue: queue)
        if let audioOutput = self.audioOutput {
            audioOutput.setSampleBufferDelegate(self, queue: queue)
        }
    }
    
    func startRecording(with recorder: VideoRecorder) {
        videoRecorder = recorder
        
        let isLandscape = UIDevice.current.orientation.isLandscape
        if isLandscape {
            videoMixer.pipFrame = CGRect(x: 0.03, y: 0.03, width: 0.25, height: 0.25)
        } else {
            videoMixer.pipFrame = CGRect(x: 0.05, y: 0.05, width: 0.3, height: 0.3)
        }
    }
    
    func stopRecording() {
        videoRecorder = nil
    }

    func startSession() {
        queue.async {
            self.session.startRunning()
        }
    }

    func stopSession() {
        queue.async {
            if self.session.isRunning {
                self.session.stopRunning()
            }
        }
    }

    func updateVideoOrientation(_ orientation: AVCaptureVideoOrientation) {
        queue.async {
            if let backConnection = self.backOutput.connection(with: .video) {
                if backConnection.isVideoOrientationSupported {
                    backConnection.videoOrientation = orientation
                }
            }
            
            if let frontConnection = self.frontOutput.connection(with: .video) {
                if frontConnection.isVideoOrientationSupported {
                    frontConnection.videoOrientation = orientation
                }
            }
        }
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
            session.addOutputWithNoConnections(backOutput)

            if let port = self.backVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: backOutput)
                connection.videoOrientation = getCurrentVideoOrientation()
                session.addConnection(connection)
            }
        }
    }
    
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let videoRecorder = self.videoRecorder {
            if output == backOutput {
                self.latestBackBuffer = sampleBuffer
            } else if output == frontOutput {
                self.latestFrontBuffer = sampleBuffer
            } else if output == audioOutput {
                videoRecorder.appendAudioBuffer(sampleBuffer)
                return
            }

            if self.videoMixer.inputFormatDescription == nil,
               let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer) {
                self.videoMixer.prepare(with: formatDesc, outputRetainedBufferCountHint: 6)
            }

            guard let front = latestFrontBuffer, let back = latestBackBuffer else { return }

            guard let frontBuffer = CMSampleBufferGetImageBuffer(front),
                  let backBuffer = CMSampleBufferGetImageBuffer(back) else { return }

            if let merged = self.videoMixer.mix(fullScreenPixelBuffer: backBuffer, pipPixelBuffer: frontBuffer, fullScreenPixelBufferIsFrontCamera: false) {
                videoRecorder.appendVideoPixelBuffer(merged, withPresentationTime: CMSampleBufferGetPresentationTimeStamp(back))
                latestFrontBuffer = nil
                latestBackBuffer = nil
            }
        }
        
        delegate?.sessionManager(self, didOutput: sampleBuffer, from: output)
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
            session.addOutputWithNoConnections(frontOutput)

            if let port = self.frontVideoPort {
                let connection = AVCaptureConnection(inputPorts: [port], output: frontOutput)
                connection.videoOrientation = getCurrentVideoOrientation()
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
    
    private func getCurrentVideoOrientation() -> AVCaptureVideoOrientation {
        let orientation = UIDevice.current.orientation
        switch orientation {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeLeft:
            return .landscapeRight
        case .landscapeRight:
            return .landscapeLeft
        default:
            return .portrait
        }
    }
}
