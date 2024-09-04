## [2.0.26](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.25...v2.0.26) (2024-09-04)
* **Android:** Fix Android permission RECORD_AUDIO on startVideoCapture

## [2.0.25](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.24...v2.0.25) (2024-08-16)
* **Android:** Add video recording ability for Android

## [2.0.24](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.23...v2.0.24) (2024-07-29)
* **Android:** Remove ACCESS_FINE_LOCATION as a required permission

## [2.0.23](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.22...v2.0.23) (2024-07-17)
* **Android:** Use parameter lens with values wide or default
* **iOS:** Use parameter lens with values wide or default

## [2.0.22](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.21...v2.0.22) (2024-07-12)
* **iOS:** Release memory when exiting capture preview

## [2.0.21](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.20...v2.0.21) (2024-07-05)
* **iOS:** Release memory consumption

## [2.0.20](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.19...v2.0.20) (2024-07-05)
* **Android:** Null check

## [2.0.19](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.18...v2.0.19) (2024-06-17)

* **iOS:** Release unused memory after capture

## [2.0.18](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.17...v2.0.18) (2024-05-12)

* **iOS:** Added a method "switchCameraTo" to help switch between ultra-wide camera and default camera. ([#68](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/68))
* **Android:** Added a method "switchCameraTo" to help switch between ultra-wide camera and default camera. ([#68](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/68))
* **iOS:** Added a method "deviceHasUltraWideCamera" to check if device has ultra-wide camera. ([#68](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/68))
* **Android:** Added a method "deviceHasUltraWideCamera" to check if device has ultra-wide camera. ([#68](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/68))

## [2.0.17](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.16...v2.0.17) (2023-07-04)

* **iOS:** Use interfaceOrientation for ios 13+. ([#67](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/67))

## [2.0.16](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.15...v2.0.16) (2023-05-08)

* **iOS:** Added a NSNotification observer to check if app is interrupted by a drawer app on ipad. ([#66](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/66))

## [2.0.15](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.14...v2.0.15) (2023-01-30)

* **iOS:** Added a method deviceHasFlash to check if devices have a flash unit or no. ([#64](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/64))
* **Android:** Added a method deviceHasFlash to check if devices have a flash unit or no. ([#64](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/64))

## [2.0.14](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.13...v2.0.14) (2023-01-20)

* **iOS:** Use AVCapturePhotoOutput and Remove All Deprecated Libraries/Warnings. ([#62](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/62))

## [2.0.13](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.12...v2.0.13) (2022-11-18)

* **iOS:** Configurable Output Resolution Feature: Added getRatio function on plugin to return aspect ratio based on available resolution. ([#58](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/58))
* **Android:** Configurable Output Resolution Feature: Added getRatio function on plugin to return aspect ratio based on available resolution. ([#58](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/58))

## [2.0.12](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.11...v2.0.12) (2022-11-14)

* **iOS:** Fix Error: AVFoundationErrorDomain Code=-11803. ([#57](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/57))

## [2.0.11](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.10...v2.0.11) (2022-10-07)

* **Android:** Add requestFocus on WebView. ([#55](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/55))

## [2.0.10](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.9...v2.0.10) (2022-09-14)

* **Android:** Add configurable output resolution: Add If & Try/Catch statement for Integer.parseInt passing. ([#53](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/53))

## [2.0.9](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.8...v2.0.9) (2022-09-13)

* **iOS:** Add configurable output resolution: Add If statement for inValue passing. ([#51](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/51))

## [2.0.8](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.7...v2.0.8) (2022-09-13)

* **Android:** Add configurable output resolution. ([#43](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/43))
* **iOS:** Add configurable output resolution. ([#43](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/43))

## [2.0.7](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.6...v2.0.7) (2022-08-31)

* **iOS:** Use pausesLocationUpdatesAutomatically for improving location. ([#48](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/48))

## [2.0.6](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/compare/v2.0.5...v2.0.6) (2022-08-22)

* **Android:** Use FUSED_PROVIDER instead of NETWORK_PROVIDER for location. ([#46](https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview/pull/46))

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
