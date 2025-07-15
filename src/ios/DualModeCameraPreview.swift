import UIKit
import AVFoundation
import Cordova

@objc(DualModeCameraPreview) class DualModeCameraPreview: CDVPlugin {
    
    @objc(deviceSupportDualMode:)
    func deviceSupportDualMode(command: CDVInvokedUrlCommand) {
        let supportsMultiCam = AVCaptureMultiCamSession.isMultiCamSupported
        let pluginResult = CDVPluginResult(status: CDVCommandStatus_OK, messageAs: supportsMultiCam)
        self.commandDelegate.send(pluginResult, callbackId: command.callbackId)
    }
}