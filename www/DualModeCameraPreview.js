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

DualModeCameraPreview.disableDualMode = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "disableDualMode", []);
};

module.exports = DualModeCameraPreview;
