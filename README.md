Cordova Plugin Simple Camera Preview
====================

Cordova plugin that allows simple camera preview and taking pictures from Javascript and HTML


# Installation

```
cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

ionic cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

```

Make the webview html background color transparent.
```css
html, body, .ion-app, .ion-content {
  background-color: transparent;
}
```


### Android
Uses Google's CameraX API


# Methods

### setOptions(options, successCallback, errorCallback)

Get the ratio for the camera preview instance (4:3, 16:9, ....).
<br>

```javascript
const params = {
  targetSize: 1024,
}

SimpleCameraPreview.setOptions(params, (ratio) => {
  console.log(ratio);
});
```

### enable(options, successCallback, errorCallback)

Starts the camera preview instance.
<br>

```javascript
const params = {
  targetSize: 1024,
  direction: 'back', // Camera direction (front or back). Default is back.
}

SimpleCameraPreview.enable(params, () => {
  console.log("Camera enabled");
});
```

### disable(successCallback, errorCallback)

<info>Stops the camera preview instance.</info><br/>

```javascript
SimpleCameraPreview.disable(params, () => {
  console.log("Camera disabled");
});
```

### capture(options, successCallback, errorCallback)

<info>Take the picture</info><br>

```javascript
let options = {
  flash: true,
};

SimpleCameraPreview.capture(options, (imagaeNativePath) => {
  console.log(imagaeNativePath);
});
```

### setSize(options, successCallback, errorCallback)

Set the camera frame size
<br>

```javascript
let size = {
  x: 0,
  y: 0,
  width: 1080,
  height: 1920,
};

SimpleCameraPreview.setSize(size, () => {
  console.log("Camera frame size set");
});
```

### deviceHasUltraWideCamera(successCallback, errorCallback)

Check if device has ultra-wide camera
<br>

```javascript

SimpleCameraPreview.deviceHasUltraWideCamera(size, (value: boolean) => {
  console.log("Device has ultra-wide camera?: ", value);
});
```

### switchCameraTo(option, successCallback, errorCallback)

Switch camera between ultra-wide or default

The variable captureDevice can take two values:
```javascript
  "ultra-wide-angle"

  or

  "default"
```
<br>

```javascript

const params = {
  captureDevice: "ultra-wide-angle",
}

SimpleCameraPreview.switchCameraTo(
  params, 
  (value: unknown) => {
    return (typeof value === "boolean" ? value : false);
  },
  (e: unknown) => {
    console.log("cannot switch camera: ", e);
  }
);
```
