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
const aspectRatio = 3/4; // or 9/16
const cameraSize = this.getCameraSize(aspectRatio);

getCameraSize(aspectRatio) {
    let height;
    let width;
    const ratio = 4 / 3;
    const min = Math.min(window.innerWidth, window.innerHeight);

    [width, height] = [min, Math.round(min / aspectRatio)];
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

### enable(options, successCallback, errorCallback)

Starts the camera preview instance.
<br>

```javascript
const params = {
  targetSize: 1024,
  lens: 'auto', // Camera lens (auto or wide). Default is auto.
  direction: 'back', // Camera direction (front or back). Default is back.
  aspectRatio: '3:4', // Camera aspect ratoio (3:4 or 9:16). Default is 3:4.
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

Switch camera between wide or auto and set the camera direction (front or back) dynamically. Change camera aspect ratio.

The options variable can take the following keys:
#### Available options:

- **lens:**
  - `"wide"` – Use a wide-angle lens.
  - `"auto"` – Automatically select the best available lens.

- **direction:**
  - `"front"` – Use the front-facing camera.
  - `"back"` – Use the rear-facing camera.

- **aspectRatio:**
  - `"3:4"` – Display 3/4 preview.
  - `"9:16"` – Display 9/16 preview.

### Note:
Currently, the wide-angle lens functionality is not supported for the front-facing camera. If the `lens` is set to `"wide"` and the `direction` is set to `"front"`, the camera will default to the `"auto"` lens instead of switching to the wide lens.

```javascript
const params = {
  lens: "wide",
  direction: "back", // Specify camera direction
  aspectRatio: "9:16", 
  ...cameraSize,
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
