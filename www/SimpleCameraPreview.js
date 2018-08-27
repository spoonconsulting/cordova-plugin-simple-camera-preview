var exec = require('cordova/exec');
var PLUGIN_NAME = "SimpleCameraPreview";

var SimpleCameraPreview = function() {};

SimpleCameraPreview.enable = function(options, onSuccess, onError) {
    options = options || {};
    options.camera = options.camera || SimpleCameraPreview.CAMERA_DIRECTION.FRONT;
    options.toBack = options.toBack || false;
    exec(onSuccess, onError, PLUGIN_NAME, "enable", [options.camera, options.toBack]);
};

SimpleCameraPreview.disable = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "disable", []);
};

SimpleCameraPreview.capture = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "capture");
};

SimpleCameraPreview.setFlashMode = function(flashMode, onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "setFlashMode", [flashMode]);
};

SimpleCameraPreview.FLASH_MODE = {
    OFF: 'off',
    ON: 'on',
    AUTO: 'auto',
    TORCH: 'torch'
};
module.exports = SimpleCameraPreview;
