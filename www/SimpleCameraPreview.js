var exec = require('cordova/exec');
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function() {};

SimpleCameraPreview.init = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "pluginInitialize", []);
};

SimpleCameraPreview.enable = function(options, onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "enable", [options]);
};

SimpleCameraPreview.disable = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "disable", []);
};

SimpleCameraPreview.capture = function(options,onSuccess, onError) {
    options = options || {};
    options.flash = options.flash || false;
    exec(onSuccess, onError, PLUGIN_NAME, "capture",[options.flash]);
};

SimpleCameraPreview.setSize = function(options, onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "setSize", [options]);
};

module.exports = SimpleCameraPreview;
