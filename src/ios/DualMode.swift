import UIKit
import AVFoundation

@objc class DualMode: NSObject {
    private var session: AVCaptureMultiCamSession!
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?

    private var backInput: AVCaptureDeviceInput?
    private var frontInput: AVCaptureDeviceInput?

    private var backOutput = AVCaptureVideoDataOutput()
    private var frontOutput = AVCaptureVideoDataOutput()
    
    private var backVideoPort: AVCaptureInput.Port?
    private var frontVideoPort: AVCaptureInput.Port?

    
    private let queue = DispatchQueue(label: "dualMode.session.queue")

    @objc func enableDualMode(on view: UIView) {
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("Multicam not supported")
            return
        }

        session = AVCaptureMultiCamSession()
        queue.async {
            self.setupSession()
            DispatchQueue.main.async {
                self.setupPreview(on: view)
                self.session.startRunning()
            }
        }
    }

    private func setupSession() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        // Back Camera
        if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
           let backInput = try? AVCaptureDeviceInput(device: backCamera),
           session.canAddInput(backInput) {

            self.backInput = backInput
            session.addInputWithNoConnections(backInput)

            if session.canAddOutput(backOutput) {
                backOutput.setSampleBufferDelegate(nil, queue: queue)
                session.addOutputWithNoConnections(backOutput)

                if let port = self.backVideoPort, let layer = backPreviewLayer {
                    let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
                    conn.videoOrientation = .portrait
                    session.addConnection(conn)
                }

            }
        }

        // Front Camera
        if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
           let frontInput = try? AVCaptureDeviceInput(device: frontCamera),
           session.canAddInput(frontInput) {

            self.frontInput = frontInput
            session.addInputWithNoConnections(frontInput)

            if session.canAddOutput(frontOutput) {
                frontOutput.setSampleBufferDelegate(nil, queue: queue)
                session.addOutputWithNoConnections(frontOutput)

                if let port = self.frontVideoPort, let layer = frontPreviewLayer {
                    let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
                    conn.videoOrientation = .portrait
                    conn.automaticallyAdjustsVideoMirroring = false
                    conn.isVideoMirrored = true

                    session.addConnection(conn)
                }


            }
        }
    }

    private func setupPreview(on view: UIView) {
        // BACK - Fullscreen
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.frame = view.bounds

        if let backLayer = backPreviewLayer {
            // Insert BELOW the webView layer
            if let webViewLayer = view.subviews.first(where: { $0 is WKWebView || $0 is UIWebView })?.layer {
                view.layer.insertSublayer(backLayer, below: webViewLayer)
            } else {
                view.layer.insertSublayer(backLayer, at: 0)
            }
        }

        // FRONT - PiP
        let pipView = UIView(frame: CGRect(x: view.bounds.width - 160 - 16, y: 60, width: 160, height: 240))
        pipView.layer.cornerRadius = 12
        pipView.clipsToBounds = true
        pipView.backgroundColor = .black // Optional fallback background
        view.addSubview(pipView)

        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = pipView.bounds

        if let frontLayer = frontPreviewLayer {
            pipView.layer.addSublayer(frontLayer)
        }

        // FRONT layer connection
        if let port = self.frontVideoPort, let layer = frontPreviewLayer {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
            conn.videoOrientation = .portrait
            conn.automaticallyAdjustsVideoMirroring = false
            conn.isVideoMirrored = true
            session.addConnection(conn)
        }

        // BACK layer connection
        if let port = self.backVideoPort, let layer = backPreviewLayer {
            let conn = AVCaptureConnection(inputPort: port, videoPreviewLayer: layer)
            conn.videoOrientation = .portrait
            session.addConnection(conn)
        }
    }
    
    
    @objc func disableDualMode() {
        print("Disable 3")
        queue.async {
            // Stop the session if it's running
            if self.session.isRunning {
                self.session.stopRunning()
            }

            self.session.beginConfiguration()

            // Remove all connections
            for connection in self.session.connections {
                self.session.removeConnection(connection)
            }

            // Remove inputs
            for input in self.session.inputs {
                self.session.removeInput(input)
            }

            // Remove outputs
            for output in self.session.outputs {
                self.session.removeOutput(output)
            }

            self.session.commitConfiguration()

            // Clean up session and references
            self.session = nil
            self.backInput = nil
            self.frontInput = nil
            self.backVideoPort = nil
            self.frontVideoPort = nil
            self.backOutput = AVCaptureVideoDataOutput()
            self.frontOutput = AVCaptureVideoDataOutput()

            // Remove preview layers on main thread
            DispatchQueue.main.async {
                self.backPreviewLayer?.removeFromSuperlayer()
                self.backPreviewLayer = nil

                if let frontLayer = self.frontPreviewLayer {
                    let pipView = frontLayer.superlayer?.superlayer?.delegate as? UIView
                    pipView?.removeFromSuperview()
                }
                self.frontPreviewLayer?.removeFromSuperlayer()
                self.frontPreviewLayer = nil
            }
        }
        
        print("Disable 4")
        
    }


}
