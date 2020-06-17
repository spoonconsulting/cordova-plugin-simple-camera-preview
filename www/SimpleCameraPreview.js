var exec = require('cordova/exec');
var PLUGIN_NAME = "SimpleCameraPreview";
var SimpleCameraPreview = function() {};

SimpleCameraPreview.open = function(options, onSucces, onError) {
    exec(onSucces, onError, PLUGIN_NAME, "open", [options]);
}

SimpleCameraPreview.close = function(onSuccess, onError) {
    exec(onSuccess, onError, PLUGIN_NAME, "close", []);
}

SimpleCameraPreview.capture = function(options, onSucces, onError) {
    options = options || {};
    options.flash = options.flash || false;
    exec(onSucces, onError, PLUGIN_NAME, "capture", [options.flash]);
}

module.exports = SimpleCameraPreview;
