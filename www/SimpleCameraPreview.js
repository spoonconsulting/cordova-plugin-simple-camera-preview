  var exec = require("cordova/exec");
  var PLUGIN_NAME = "SimpleCameraPreview";
  var SimpleCameraPreview = function () {};
  
  SimpleCameraPreview.videoInitialized = false;
  SimpleCameraPreview.videoCallback = null;
  
  SimpleCameraPreview.startVideoCapture = function (onSuccess, onError) {
    if (!SimpleCameraPreview.videoCallback) {
      console.error("Call setVideoCallback first");
      onError("Call setVideoCallback first");
      return;
    }
  
    if (!SimpleCameraPreview.videoInitialized) {
      exec(
          (info) => {
            SimpleCameraPreview.videoInitialized = true;
            this.videoCallback(info);
          } ,
           (err) => {
              console.log("Error initializing video callback", err);
          },
          "SimpleCameraPreview",
          "initVideoCallback",
          []
      );
    }
    exec(onSuccess, onError, PLUGIN_NAME, "startVideoCapture");
  };
  
  SimpleCameraPreview.stopVideoCapture = function (onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "stopVideoCapture");
  };
  
  SimpleCameraPreview.setVideoCallback = function (callback) {
      this.videoCallback = callback;
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
    options.captureDevice = options.captureDevice || "default";
    exec(onSuccess, onError, PLUGIN_NAME, "switchCameraTo", [options.captureDevice]);
  };
  
  SimpleCameraPreview.deviceHasFlash = function (onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "deviceHasFlash", []);
  };
  
  SimpleCameraPreview.deviceHasUltraWideCamera = function (onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "deviceHasUltraWideCamera", []);
  };
  
  module.exports = SimpleCameraPreview;
  