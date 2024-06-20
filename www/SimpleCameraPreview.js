var exec = require("cordova/exec");
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function () {};

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

SimpleCameraPreview.startVideo = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "startVideo", []);
};

SimpleCameraPreview.stopVideo = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "stopVideo", []);
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
