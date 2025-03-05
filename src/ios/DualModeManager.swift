import AVFoundation
import UIKit

@objc class DualModeManager: NSObject {
    
    private var session: AVCaptureMultiCamSession?
    private var frontCameraInput: AVCaptureDeviceInput?
    private var backCameraInput: AVCaptureDeviceInput?
    
    private var backPreviewLayer: AVCaptureVideoPreviewLayer?
    private var frontPreviewLayer: AVCaptureVideoPreviewLayer?
    
    private var previewContainer: UIView?
    
    @objc static let shared = DualModeManager()

    @objc func toggleDualMode(_ webView: UIView) {
        DispatchQueue.main.async {
            if let session = self.session, session.isRunning {
                print("[DualModeManager] Stopping Dual Mode...")
                self.stopDualMode()
                _ = self.setupDualMode(webView)  // Restart Dual Mode
            } else {
                print("[DualModeManager] Restarting Dual Mode...")
                self.session = nil  // Ensure old session is fully reset
                _ = self.setupDualMode(webView)
            }
        }
    }

    @objc func setupDualMode(_ webView: UIView) -> Bool {
        print("[DualModeManager] Setting up Dual Mode...")
        
        guard AVCaptureMultiCamSession.isMultiCamSupported else {
            print("[DualModeManager] ERROR: MultiCam not supported on this device.")
            return false
        }

        // Ensure session is always recreated
        session = AVCaptureMultiCamSession()
        session?.beginConfiguration()

        do {
            // Setup Back Camera
            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session!.canAddInput(backCameraInput) {
                    session!.addInput(backCameraInput)
                    self.backCameraInput = backCameraInput
                    print("[DualModeManager] Back Camera added successfully.")
                } else {
                    print("[DualModeManager] ERROR: Cannot add back camera input.")
                }
            } else {
                print("[DualModeManager] ERROR: Back camera not found.")
            }

            // Setup Front Camera
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                let frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if session!.canAddInput(frontCameraInput) {
                    session!.addInput(frontCameraInput)
                    self.frontCameraInput = frontCameraInput
                    print("[DualModeManager] Front Camera added successfully.")
                } else {
                    print("[DualModeManager] ERROR: Cannot add front camera input.")
                }
            } else {
                print("[DualModeManager] ERROR: Front camera not found.")
            }

            session?.commitConfiguration()
            session?.startRunning()

            DispatchQueue.main.async {
                self.setupPreviewLayers(webView)
            }

            print("[DualModeManager] Dual Mode started successfully.")
            return true

        } catch {
            print("[DualModeManager] ERROR: Failed to setup dual mode - \(error.localizedDescription)")
            self.cleanupOnError()
            return false
        }
    }


    private func setupPreviewLayers(_ webView: UIView) {
        DispatchQueue.main.async {
            guard let session = self.session, let rootView = webView.superview else {
                print("[DualModeManager] ERROR: WebView superview not found.")
                return
            }

            // Remove any existing previewContainer before creating a new one
            self.previewContainer?.removeFromSuperview()
            self.previewContainer = UIView(frame: rootView.bounds)
            self.previewContainer?.backgroundColor = .black
            rootView.insertSubview(self.previewContainer!, belowSubview: webView)

            // Setup Back Camera Preview Layer
            self.backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            self.backPreviewLayer?.videoGravity = .resizeAspectFill
            self.backPreviewLayer?.frame = self.previewContainer!.bounds
            self.previewContainer?.layer.addSublayer(self.backPreviewLayer!)

            // Create a smaller front camera preview overlay
            let frontFrame = CGRect(x: 10, y: 50, width: 150, height: 200)
            let frontView = UIView(frame: frontFrame)
            frontView.backgroundColor = .clear
            self.previewContainer?.addSubview(frontView)

            self.frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
            self.frontPreviewLayer?.videoGravity = .resizeAspectFill
            self.frontPreviewLayer?.frame = frontView.bounds
            self.frontPreviewLayer?.cornerRadius = 10
            self.frontPreviewLayer?.masksToBounds = true
            frontView.layer.addSublayer(self.frontPreviewLayer!)

            print("[DualModeManager] Preview layers set up successfully.")
        }
    }


    @objc func stopDualMode() {
        DispatchQueue.main.async {
            print("[DualModeManager] Stopping Dual Mode and cleaning up session...")

            self.session?.stopRunning()
            self.session = nil  // Fully release session

            // Remove preview layers safely
            self.backPreviewLayer?.removeFromSuperlayer()
            self.backPreviewLayer = nil

            self.frontPreviewLayer?.removeFromSuperlayer()
            self.frontPreviewLayer = nil

            // ✅ Ensure preview container is removed
            self.previewContainer?.removeFromSuperview()
            self.previewContainer = nil

            print("[DualModeManager] Dual Mode fully disabled.")
        }
    }

    /// Cleans up session in case of error
    private func cleanupOnError() {
        DispatchQueue.main.async {
            print("[DualModeManager] ERROR: Cleaning up due to failure...")

            self.session?.stopRunning()
            self.session = nil  // Fully release session

            self.backPreviewLayer?.removeFromSuperlayer()
            self.backPreviewLayer = nil

            self.frontPreviewLayer?.removeFromSuperlayer()
            self.frontPreviewLayer = nil

            self.previewContainer?.removeFromSuperview()
            self.previewContainer = nil

            print("[DualModeManager] Cleanup complete.")
        }
    }
}
