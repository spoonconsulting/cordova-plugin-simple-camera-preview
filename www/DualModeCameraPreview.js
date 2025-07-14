var exec = require("cordova/exec");
var PLUGIN_NAME = "DualModeCameraPreview";
var DualModeCameraPreview = function () {};

DualModeCameraPreview.videoInitialized = false;
DualModeCameraPreview.videoCallback = null;

DualModeCameraPreview.initVideoCallback = function (onSuccess, onError, callback) {
    this.videoCallback = callback;
    exec(
            (info) => {
              if (info.videoCallbackInitialized) {
                DualMode.videoInitialized = true;
                onSuccess();
              }
              this.videoCallback(info);
            } ,
            onError,
            PLUGIN_NAME,
            "initVideoCallback",
            []
        );
}

DualModeCameraPreview.deviceSupportDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "deviceSupportDualMode", []);
};

DualModeCameraPreview.enableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "enableDualMode", []);
};

DualModeCameraPreview.captureDual = function (options, onSuccess, onError) {
  options = options || {};
  exec(onSuccess, onError, PLUGIN_NAME, "captureDual", [options.flash]);
};

DualModeCameraPreview.startVideoCaptureDual = function (options, onSuccess, onError) {
//   if (!DualModeCameraPreview.videoCallback) {
//     console.error("Call initVideoCallback first");
//     onError("Call initVideoCallback first");
//     return;
//   }

//   if (!DualModeCameraPreview.videoInitialized) {
//     console.error("videoCallback not initialized");
//     onError("videoCallback not initialized");
//     return;
//   }
  
//   options = options || {};
//   options.recordWithAudio = options.recordWithAudio != null ? options.recordWithAudio : true;
//   options.videoDurationMs = options.videoDurationMs != null ? options.videoDurationMs : 3000;
//   exec(onSuccess, onError, PLUGIN_NAME, "startVideoCaptureDual", [options]);
};

DualModeCameraPreview.stopVideoCaptureDual = function (onSuccess, onError) {
  // exec(onSuccess, onError, PLUGIN_NAME, "stopVideoCaptureDual");
};

DualModeCameraPreview.disableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "disableDualMode", []);
};

module.exports = DualModeCameraPreview;
