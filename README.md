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
Uses cameraX api


# Methods

### open(options, successCallback, errorCallback)

Starts the camera preview instance.
<br>

```javascript
const params = {
  // 0: lens facing front
  // 1: lens facing back
  camera: 0 
}

SimpleCameraPreview.enable(params, () => {
  console.log("Camera opened");
});
```

### close(successCallback, errorCallback)

<info>Stops the camera preview instance.</info><br/>

```javascript
SimpleCameraPreview.disable(params, () => {
  console.log("Camera closed");
});
```

### capture(options, successCallback, errorCallback)

<info>Take the picture</info>

```javascript
let options = {
  flash: true
};

SimpleCameraPreview.capture(options, (imageName) => {
  console.log(imageName);
});
```
