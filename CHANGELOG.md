## [2.0.5](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.4...v2.0.5) (2022-06-22)

* **Android:** Add torch functionality. ([#40](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/40))
* **iOS:** Add torch functionality. ([#40](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/40))

## [2.0.4](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.3...v2.0.4) (2022-03-21)

* **iOS:** Check if ParentViewController has already been removed. ([#41](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/41))

## [2.0.3](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.2...v2.0.3) (2021-12-16)

* **Android:** Remove lifecycle owner and used androidx fragment. ([#38](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/38))

## [2.0.2](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.0...v2.0.2) (2021-10-27)

* **Android:** Added try catch to cordova exec method implementation. ([#36](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/36))

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
