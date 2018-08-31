Cordova Plugin Simple Camera Preview
====================

Cordova plugin that allows simple camera preview and taking pictures from Javascript and HTML


# Installation

```
cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

ionic cordova plugin add https://github.com/spoonconsulting/cordova-plugin-simple-camera-preview.git

```

Make the webview html background color transparent
```css
html, body, .ion-app, .ion-content {
  background-color: transparent;
}
```


### Android
Uses camera2 api


# Methods

### enable([successCallback])

Starts the camera preview instance.
<br>

```javascript
CameraPreview.enable(()=>console.log('camera started'));
```

### disable([successCallback, errorCallback])

<info>Stops the camera preview instance.</info><br/>

```javascript
SimpleCameraPreview.disable();
```

### capture(options, successCallback, [errorCallback])

<info>Take the picture</info>

```javascript
let options  = {
  useFlash: true
}
SimpleCameraPreview.takePicture(options, (imageName)=>{
  //image will be in cordova data directory
});

```
