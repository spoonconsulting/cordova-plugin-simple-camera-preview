var argscheck = require('cordova/argscheck'),
    utils = require('cordova/utils'),
    exec = require('cordova/exec');

var PLUGIN_NAME = "SimpleCameraPreview";

var SimpleCameraPreview = function() {};

function isFunction(obj) {
    return !!(obj && obj.constructor && obj.call && obj.apply);
};

SimpleCameraPreview.startCamera = function(options, onSuccess, onError) {
    options = options || {};
    options.camera = options.camera || SimpleCameraPreview.CAMERA_DIRECTION.FRONT;
    options.toBack = options.toBack || false;
    exec(onSuccess, onError, PLUGIN_NAME, "startCamera", [options.camera, options.toBack]);
};

SimpleCameraPreview.stopCamera = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "stopCamera", []);
};

SimpleCameraPreview.switchCamera = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "switchCamera", []);
};

SimpleCameraPreview.hide = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "hideCamera", []);
};

SimpleCameraPreview.show = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "showCamera", []);
};

SimpleCameraPreview.takePicture = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "takePicture");
};

SimpleCameraPreview.setFlashMode = function(flashMode, onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "setFlashMode", [flashMode]);
};

SimpleCameraPreview.getFlashMode = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "getFlashMode", []);
};

SimpleCameraPreview.FLASH_MODE = {
    OFF: 'off',
    ON: 'on',
    AUTO: 'auto',
    RED_EYE: 'red-eye', // Android Only
    TORCH: 'torch'
};

SimpleCameraPreview.CAMERA_DIRECTION = {
    BACK: 'back',
    FRONT: 'front'
};

module.exports = SimpleCameraPreview;
