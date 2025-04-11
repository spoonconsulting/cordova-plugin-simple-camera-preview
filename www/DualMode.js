var exec = require("cordova/exec");
var PLUGIN_NAME = "DualMode";
var DualMode = function () {};

DualMode.videoInitialized = false;
DualMode.videoCallback = null;

DualMode.initVideoCallback = function (onSuccess, onError, callback) {
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

DualMode.enableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "enableDualMode", []);
};

DualMode.captureDual = function (options, onSuccess, onError) {
  options = options || {};
  exec(onSuccess, onError, PLUGIN_NAME, "captureDual", [options.flash]);
};

DualMode.startVideoCaptureDual = function (options, onSuccess, onError) {
  if (!DualMode.videoCallback) {
    console.error("Call initVideoCallback first");
    onError("Call initVideoCallback first");
    return;
  }

  if (!DualMode.videoInitialized) {
    console.error("videoCallback not initialized");
    onError("videoCallback not initialized");
    return;
  }
  
  options = options || {};
  options.recordWithAudio = options.recordWithAudio != null ? options.recordWithAudio : true;
  options.videoDurationMs = options.videoDurationMs != null ? options.videoDurationMs : 3000;
  exec(onSuccess, onError, PLUGIN_NAME, "startVideoCaptureDual", [options]);
};

DualMode.stopVideoCaptureDual = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "stopVideoCaptureDual");
};

DualMode.disableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "disableDualMode", []);
};

module.exports = DualMode;