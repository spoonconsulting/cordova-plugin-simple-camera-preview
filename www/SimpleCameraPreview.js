var exec = require("cordova/exec");
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function () {};

SimpleCameraPreview.videoInitialized = false;
SimpleCameraPreview.videoCallback = null;

SimpleCameraPreview.startVideoCapture = function (options, onSuccess, onError) {
  if (!SimpleCameraPreview.videoCallback) {
    console.error("Call initVideoCallback first");
    onError("Call initVideoCallback first");
    return;
  }

  if (!SimpleCameraPreview.videoInitialized) {
    console.error("videoCallback not initialized");
    onError("videoCallback not initialized");
    return;
  }
  
  options = options || {};
  options.recordWithAudio = options.recordWithAudio != null ? options.recordWithAudio : true;
  options.videoDurationMs = options.videoDurationMs != null ? options.videoDurationMs : 3000;
  exec(onSuccess, onError, PLUGIN_NAME, "startVideoCapture", [options]);
};

SimpleCameraPreview.stopVideoCapture = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "stopVideoCapture");
};

SimpleCameraPreview.initVideoCallback = function (onSuccess, onError, callback) {
    this.videoCallback = callback;
    exec(
            (info) => {
              if (info.videoCallbackInitialized) {
                SimpleCameraPreview.videoInitialized = true;
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

SimpleCameraPreview.setOptions = function (options, onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "setOptions", [options]);
};

SimpleCameraPreview.enable = function (options, onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "enable", [options]);
};

SimpleCameraPreview.disable = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "disable", []);
};

SimpleCameraPreview.capture = function (options, onSuccess, onError) {
  options = options || {};
  options.flash = options.flash || false;
  exec(onSuccess, onError, PLUGIN_NAME, "capture", [options.flash]);
};

SimpleCameraPreview.setSize = function (options, onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "setSize", [options]);
};

SimpleCameraPreview.torchSwitch = function (options, onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "torchSwitch", [options]);
};

SimpleCameraPreview.switchCameraTo = function (options, onSuccess, onError) {
  options = options || {};
  options.lens = options.lens || "default";
  options.direction = options.direction || 0;
  exec(onSuccess, onError, PLUGIN_NAME, "switchCameraTo", [options.lens, options.direction]);
};

SimpleCameraPreview.deviceHasFlash = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "deviceHasFlash", []);
};

SimpleCameraPreview.deviceHasUltraWideCamera = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "deviceHasUltraWideCamera", []);
};

module.exports = SimpleCameraPreview;
