function convertPath(nativePath) {
    return new Promise((resolve,reject) => {
        window.resolveLocalFileSystemURL(nativePath , function(entry){
            resolve(entry.toInternalURL());
        }), function(error) {
            reject(error);
        }
    }).then(function(success) {
        const params = {
            flash: false,
            cdvFilePath: success
        }
        cordova.exec(function() {}, function() {}, "SimpleCameraPreview", "capture", [params]);
     }, function(error) {
        console.log(error);
     });
}