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

SimpleCameraPreview.torchSwitch = function (options, onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "torchSwitch", [options]);
};

SimpleCameraPreview.switchToUltraWideCamera = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "switchToUltraWideCamera", []);
};

SimpleCameraPreview.deviceHasFlash = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "deviceHasFlash", []);
};

SimpleCameraPreview.getMinZoomRatio = function (onSuccess, onError) {
  exec(onSuccess, onError, PLUGIN_NAME, "getMinZoomRatio", []);
};

SimpleCameraPreview.setZoomRatio = function (options, onSuccess, onError) {
  options = options || {};
  options.zoomRatio = options.zoomRatio || 1;
  exec(onSuccess, onError, PLUGIN_NAME, "setZoomRatio", [options.zoomRatio]);
};

module.exports = SimpleCameraPreview;
