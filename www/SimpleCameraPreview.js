var exec = require("cordova/exec");
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function () {};

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

module.exports = SimpleCameraPreview;
