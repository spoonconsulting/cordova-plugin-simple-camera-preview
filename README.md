Cordova Plugin Simple Camera Preview
====================

Cordova plugin that allows camera interaction from Javascript and HTML


# Installation

To install the master version with latest fixes and features

```
cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

ionic cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

```

#### iOS Quirks
If you are developing for iOS 10+ you must also add the following to your config.xml

```xml
<config-file platform="ios" target="*-Info.plist" parent="NSCameraUsageDescription" overwrite="true">
  <string>Allow the app to use your camera</string>
</config-file>

<!-- or for Phonegap -->

<gap:config-file platform="ios" target="*-Info.plist" parent="NSCameraUsageDescription" overwrite="true">
  <string>Allow the app to use your camera</string>
</gap:config-file>
```

### Android
Uses camera2 api


# Methods

### startCamera(options, [successCallback, errorCallback])

Starts the camera preview instance.
<br>

```javascript
CameraPreview.startCamera(options);
```

When setting the toBack to true, remember to add the style below on your app's HTML or body element:

```css
html, body, .ion-app, .ion-content {
  background-color: transparent;
}
```

### stopCamera([successCallback, errorCallback])

<info>Stops the camera preview instance.</info><br/>

```javascript
SimpleCameraPreview.stopCamera();
```

### switchCamera([successCallback, errorCallback])

<info>Switch between the rear camera and front camera, if available.</info><br/>

```javascript
SimpleCameraPreview.switchCamera();
```

### show([successCallback, errorCallback])

<info>Show the camera preview box.</info><br/>

```javascript
SimpleCameraPreview.show();
```

### hide([successCallback, errorCallback])

<info>Hide the camera preview box.</info><br/>

```javascript
SimpleCameraPreview.hide();
```

### takePicture(options, successCallback, [errorCallback])

<info>Take the picture</info>

```javascript
SimpleCameraPreview.takePicture( function(base64PictureData){
  
});

```
