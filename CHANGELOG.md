## [2.0.1](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.0...v2.0.1) (2021-10-15)


* **Android:** Update CameraX libraries. ([#23](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/35))

    - androidx.exifinterface:exifinterface

    - androidx.camera:camera-camera2

    - androidx.camera:camera-lifecycle

    - androidx.camera:camera-view

## [2.0.0](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v1.0.1...v2.0.0) (2021-08-04)


* **Android:** Integratoin of CameraX library. ([#23](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/23))

### BREAKING CHANGES

* ``SimpleCameraPreview.capture`` method now returns a native path instead of the file name
```
SimpleCameraPreview.camera({}, (imageNativePath) => console.log(imageNativePath), (err) => console.log(err);
```

## [1.0.1](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v1.0.0...v1.0.1) (2020-09-16)


### Bug Fixes

* **WKWebView:** Camera preview not working due to opaque background of WKWebView. ([#27](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/27))
