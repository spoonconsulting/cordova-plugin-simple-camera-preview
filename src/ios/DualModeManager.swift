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
    
    @objc func setupDualMode(in webView: UIView) -> Bool {
        
        if !AVCaptureMultiCamSession.isMultiCamSupported {
            print("MultiCam is not supported on this device.")
            return false
        }
        
        session = AVCaptureMultiCamSession()
        session?.beginConfiguration()
        
        do {
            // Setup Back Camera
            if let backCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
                let backCameraInput = try AVCaptureDeviceInput(device: backCamera)
                if session!.canAddInput(backCameraInput) {
                    session!.addInput(backCameraInput)
                    self.backCameraInput = backCameraInput
                }
            }
            
            // Setup Front Camera
            if let frontCamera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) {
                let frontCameraInput = try AVCaptureDeviceInput(device: frontCamera)
                if session!.canAddInput(frontCameraInput) {
                    session!.addInput(frontCameraInput)
                    self.frontCameraInput = frontCameraInput
                }
            }
            
            setupPreviewLayers(in: webView)
            
            session?.commitConfiguration()
            session?.startRunning()
            
            return true
            
        } catch {
            print("Error setting up dual mode: \(error.localizedDescription)")
            return false
        }
    }
    
    private func setupPreviewLayers(in webView: UIView) {
        guard let session = session, let rootView = webView.superview else { return }
        
        // Create a container view behind the web view
        if previewContainer == nil {
            previewContainer = UIView(frame: rootView.bounds)
            previewContainer?.backgroundColor = .black
            rootView.insertSubview(previewContainer!, belowSubview: webView)
        }
        
        // Setup Back Camera Preview Layer
        backPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        backPreviewLayer?.videoGravity = .resizeAspectFill
        backPreviewLayer?.frame = previewContainer!.bounds
        previewContainer?.layer.addSublayer(backPreviewLayer!)
        
        // Create a smaller front camera preview overlay
        let frontFrame = CGRect(x: 10, y: 50, width: 150, height: 200)
        let frontView = UIView(frame: frontFrame)
        frontView.backgroundColor = .clear
        previewContainer?.addSubview(frontView)
        
        frontPreviewLayer = AVCaptureVideoPreviewLayer(session: session)
        frontPreviewLayer?.videoGravity = .resizeAspectFill
        frontPreviewLayer?.frame = frontView.bounds
        frontPreviewLayer?.cornerRadius = 10
        frontPreviewLayer?.masksToBounds = true
        frontView.layer.addSublayer(frontPreviewLayer!)
    }
    
    @objc func stopDualMode() {
        print("Stopping dual mode and disabling session...")

        // Stop the camera session
        session?.stopRunning()
        session = nil  // Completely disable the session

        // Remove preview layers
        backPreviewLayer?.removeFromSuperlayer()
        frontPreviewLayer?.removeFromSuperlayer()

        // Remove the preview container
        previewContainer?.removeFromSuperview()
        previewContainer = nil

        print("Dual mode fully disabled.")
    }

}
