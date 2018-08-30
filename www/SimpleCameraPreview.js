var exec = require('cordova/exec');
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function() {};

SimpleCameraPreview.enable = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "enable", []);
};

SimpleCameraPreview.disable = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "disable", []);
};

SimpleCameraPreview.capture = function(flashMode,onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "capture",[flashMode]);
};

module.exports = SimpleCameraPreview;