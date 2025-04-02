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

for newer version ionic use the following:
```css
html, body, .ion-app, .ion-content {
 --background: transparent;
}

```

Make sure to set up the camera size as follows:

```javascript
const cameraSize = this.getCameraSize();

getCameraSize() {
    let height;
    let width;
    const ratio = 4 / 3;
    const min = Math.min(window.innerWidth, window.innerHeight);

    [width, height] = [min, Math.round(min * ratio)];
    if (this.isLandscape()) {
    [width, height] = [height, width];
    }

    return {
    x: (window.innerWidth - width) / 2,
    y: (window.innerHeight - height) / 2,
    width,
    height,
    };    
}

isLandscape() {
    return Math.abs(window.orientation % 180) === 90;
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
    ...cameraSize, // use camera size 
};

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
  ...cameraSize,
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

### switchCameraTo(options, successCallback, errorCallback)

Switch camera between wide or auto and set the camera direction (front or back) dynamically.

The options variable can take the following keys:
#### Available options:

- **lens:**
  - `"wide"` – Use a wide-angle lens.
  - `"auto"` – Automatically select the best available lens.

- **direction:**
  - `"front"` – Use the front-facing camera.
  - `"back"` – Use the rear-facing camera.


### Note:
Currently, the wide-angle lens functionality is not supported for the front-facing camera. If the `lens` is set to `"wide"` and the `direction` is set to `"front"`, the camera will default to the `"auto"` lens instead of switching to the wide lens.

```javascript
const params = {
  lens: "wide",
  direction: "back", // Specify camera direction
};

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
