var exec = require("cordova/exec");
var PLUGIN_NAME = "DualCameraPreview";
var DualCameraPreview = function () {};


DualCameraPreview.deviceSupportDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "deviceSupportDualMode", []);
};

DualCameraPreview.enableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "enableDualMode", []);
};

DualCameraPreview.captureDual = function (options, onSuccess, onError) {
  options = options || {};
  exec(onSuccess, onError, PLUGIN_NAME, "captureDual", [options.flash]);
};

DualCameraPreview.disableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "disableDualMode", []);
};

DualCameraPreview.startVideoCaptureDual = function (options, onSuccess, onError) {
  if (!DualCameraPreview.videoCallback) {
    console.error("Call initVideoCallback first");
    onError("Call initVideoCallback first");
    return;
  }

  if (!DualCameraPreview.videoInitialized) {
    console.error("videoCallback not initialized");
    onError("videoCallback not initialized");
    return;
  }
  
  options = options || {};
  options.recordWithAudio = options.recordWithAudio != null ? options.recordWithAudio : true;
  options.videoDurationMs = options.videoDurationMs != null ? options.videoDurationMs : 3000;
  exec(onSuccess, onError, PLUGIN_NAME, "startVideoCaptureDual", [options]);
};

DualCameraPreview.stopVideoCaptureDual = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "stopVideoCaptureDual");
};


module.exports = DualCameraPreview;
