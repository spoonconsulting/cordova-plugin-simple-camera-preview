package com.spoon.simplecamerapreview;

import android.Manifest;
import android.app.AlertDialog;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.net.Uri;
import android.os.Bundle;
import android.provider.Settings;
import android.util.DisplayMetrics;
import android.util.Log;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;
import androidx.camera.core.CameraSelector;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PermissionHelper;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.concurrent.FutureTask;
import java.util.concurrent.RunnableFuture;
import java.util.regex.Matcher;
import java.util.regex.Pattern;

public class SimpleCameraPreview extends CordovaPlugin {

    private CameraPreviewFragment fragment;
    private JSONObject options;
    private CallbackContext enableCallbackContext;
    private LocationManager locationManager;
    private LocationListener mLocationCallback;
    private ViewParent webViewParent;
    private CallbackContext videoCallbackContext;
    private static final int containerViewId = 20;
    private static final int REQUEST_CODE_PERMISSIONS = 4582679;
    private static final int VIDEO_REQUEST_CODE_PERMISSIONS = 200;
    private static final String REQUIRED_PERMISSION = Manifest.permission.CAMERA;
    private static final double DEFAULT_ASPECT_RATIO = 3.0 / 4.0;

    public SimpleCameraPreview() {
        super();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            switch (action) {

                case "enable":
                    return enable((JSONObject) args.get(0), callbackContext);

                case "disable":
                    return disable(callbackContext);

                case "capture":
                    return capture(args.getBoolean(0), callbackContext);

                case "torchSwitch":
                    return torchSwitch(args.getBoolean(0), callbackContext);

                case "initVideoCallback":
                    return initVideoCallback(callbackContext);

                case "startVideoCapture":
                    return startVideoCapture((JSONObject) args.get(0), callbackContext);

                case "stopVideoCapture":
                    return stopVideoCapture(callbackContext);

                case "deviceHasFlash":
                    return deviceHasFlash(callbackContext);

                case "deviceHasUltraWideCamera":
                    return deviceHasUltraWideCamera(callbackContext);

                case "switchCameraTo":
                    return switchCameraTo((JSONObject) args.get(0), callbackContext);
                default:
                    break;
            }
            return false;

        } catch (JSONException e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }

    private boolean initVideoCallback(CallbackContext callbackContext) {
        this.videoCallbackContext = callbackContext;
        JSONObject data = new JSONObject();
        try {
            data.put("videoCallbackInitialized", true);
        } catch (JSONException e) {
            e.printStackTrace();
            videoCallbackContext.error("Cannot initialize video callback");
            return false;
        }
        PluginResult result = new PluginResult(PluginResult.Status.OK, data);
        result.setKeepCallback(true);
        this.videoCallbackContext.sendPluginResult(result);
        return true;
    }

    private boolean startVideoCapture(JSONObject options, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed");
            return true;
        }

        boolean recordWithAudio;
        try {
            recordWithAudio = options.getBoolean("recordWithAudio");
        } catch (JSONException e) {
            e.printStackTrace();
            recordWithAudio = false;
        }

        int videoDuration;
        try {
            videoDuration = options.getInt("videoDurationMs");
        } catch (JSONException e) {
            e.printStackTrace();
            videoDuration = 3000;
        }

        if (recordWithAudio && !PermissionHelper.hasPermission(this, Manifest.permission.RECORD_AUDIO)) {
            String[] permissions = {Manifest.permission.RECORD_AUDIO};
            PermissionHelper.requestPermissions(this, VIDEO_REQUEST_CODE_PERMISSIONS, permissions);
            callbackContext.success();
            return true;
        }

        if (this.videoCallbackContext != null) {
            fragment.startVideoCapture(new VideoCallback() {
                public void onStart(Boolean recording) {
                    JSONObject data = new JSONObject();
                    if (recording) {
                        try {
                            data.put("recording", true);
                        } catch (JSONException e) {
                            e.printStackTrace();
                            videoCallbackContext.error("Cannot send recording data");
                            return;
                        }

                        PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, data);
                        pluginResult.setKeepCallback(true);
                        videoCallbackContext.sendPluginResult(pluginResult);
                    }
                }

                public void onStop(Boolean recording, String nativePath, String thumbnail) {
                    JSONObject data = new JSONObject();
                    try {
                        data.put("recording", false);
                        data.put("nativePath", nativePath);
                        data.put("thumbnail", thumbnail);
                    } catch (JSONException e) {
                        e.printStackTrace();
                        videoCallbackContext.error("Cannot send recording data");
                        return;
                    }
                    PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, data);
                    pluginResult.setKeepCallback(true);
                    videoCallbackContext.sendPluginResult(pluginResult);
                }

                @Override
                public void onError(String errMessage) {
                    JSONObject data = new JSONObject();
                    try {
                        data.put("error", errMessage);
                    } catch (JSONException e) {
                        e.printStackTrace();
                        return;
                    }
                    PluginResult pluginResult = new PluginResult(PluginResult.Status.ERROR, data);
                    pluginResult.setKeepCallback(true);
                    videoCallbackContext.sendPluginResult(pluginResult);
                }
            }, recordWithAudio, videoDuration);
        }
        callbackContext.success();
        return true;
    }

    private boolean stopVideoCapture(CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed");
            return true;
        }

        if (this.videoCallbackContext != null) {
            fragment.stopVideoCapture();
        }

        callbackContext.success();
        return true;
    }

    private boolean enable(JSONObject options, CallbackContext callbackContext) {
        webView.getView().setBackgroundColor(0x00000000);
        // Request focus on webView as page needs to be clicked/tapped to get focus on page events
        webView.getView().requestFocus();
        if (!PermissionHelper.hasPermission(this, REQUIRED_PERMISSION)) {
            this.enableCallbackContext = callbackContext;
            this.options = options;
            this.requestPermissions();
            return true;
        }

        if (fragment != null) {
            callbackContext.error("Camera already started");
            return true;
        }

        int cameraDirection = getCameraDirection(options);
        int targetSize = 0;
        try {
            if (options.getString("targetSize") != null && !options.getString("targetSize").equals("null")) {
                targetSize = Integer.parseInt(options.getString("targetSize"));
            }
        } catch (JSONException | NumberFormatException e) {
            e.printStackTrace();
        }

        double aspectRatio = DEFAULT_ASPECT_RATIO; // Default aspect ratio 3:4
        String aspectRatioOption = null;
        try {
            aspectRatioOption = options.getString("aspectRatio");
        } catch (JSONException e) {
            Log.e("Error", "enable: " + e.getMessage());
        }
        if (aspectRatioOption != null && !aspectRatioOption.equals("null")) {
            aspectRatio = getAspectRatio(aspectRatioOption);
        }

        String lens = "default";
        try {
            if (options.getString("lens") != null && !options.getString("lens").equals("null")) {
                lens = options.getString("lens");
            }
        } catch (JSONException | NumberFormatException e) {
            e.printStackTrace();
        }

        JSONObject cameraPreviewOptions = new JSONObject();
        try {
            cameraPreviewOptions.put("targetSize", targetSize);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        try {
            cameraPreviewOptions.put("lens", lens);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        try {
            cameraPreviewOptions.put("direction", cameraDirection);
        } catch (JSONException e) {
            e.printStackTrace();
        }
        try {
            cameraPreviewOptions.put("aspectRatio", aspectRatio);
        } catch (JSONException e) {
            e.printStackTrace();
        }

        fragment = new CameraPreviewFragment(cameraPreviewOptions, (err) -> {
            if (err != null) {
                callbackContext.error(err.getMessage());
                return;
            }
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
            callbackContext.sendPluginResult(pluginResult);
        });

        try {
            updateContainerView(options);
            fetchLocation();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }

    private int getIntegerFromOptions(JSONObject options, String key) {
        try {
            return options.getInt(key);
        } catch (JSONException error) {
            return 0;
        }
    }

    public void fetchLocation() {
        if (ContextCompat.checkSelfPermission(cordova.getActivity(), Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            mLocationCallback = new LocationListener() {
                @Override
                public void onLocationChanged(Location location) {
                    if (fragment != null) {
                        fragment.setLocation(location);
                    }
                }

                @Override
                public void onStatusChanged(String provider, int status, Bundle extras) {

                }

                @Override
                public void onProviderEnabled(String provider) {

                }

                @Override
                public void onProviderDisabled(String provider) {

                }
            };
            if (locationManager == null) {
                locationManager = (LocationManager) cordova.getActivity().getSystemService(Context.LOCATION_SERVICE);
            }
            Location cachedLocation = locationManager.getLastKnownLocation(LocationManager.FUSED_PROVIDER);
            if (cachedLocation != null) {
                fragment.setLocation(cachedLocation);
            }
            locationManager.requestLocationUpdates(LocationManager.FUSED_PROVIDER, 0, 0, mLocationCallback);
        }
    }

    private boolean capture(boolean useFlash, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed");
            return true;
        }

        fragment.takePicture(useFlash, (Exception err, String nativePath) -> {
            if (err == null) {
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, nativePath);
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
            } else {
                callbackContext.error(err.getMessage());
            }
        });
        return true;
    }

    private boolean deviceHasFlash(CallbackContext callbackContext) {
        fragment.hasFlash((boolean result) -> {
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, result);
            callbackContext.sendPluginResult(pluginResult);
        });
        return true;
    }

    private boolean deviceHasUltraWideCamera(CallbackContext callbackContext) {
        fragment.deviceHasUltraWideCamera((boolean result) -> {
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, result);
            callbackContext.sendPluginResult(pluginResult);
        });
        return true;
    }

    private boolean torchSwitch(boolean torchState, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed, cannot switch " + torchState + " torch");
            return true;
        }

        fragment.torchSwitch(torchState, (Exception err) -> {
            if (err == null) {
                callbackContext.success();
            } else {
                callbackContext.error(err.getMessage());
            }
        });
        return torchState;
    }

    private boolean disable(CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera already closed");
            return true;
        }

        try {
            if (webViewParent != null) {
                RunnableFuture<Void> removeViewTask = new FutureTask<>(
                    new Runnable() {
                        @Override
                        public void run() {
                            webView.getView().bringToFront();
                            webViewParent = null;
                            FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                            ((ViewGroup) containerView.getParent()).removeView(containerView);
                        }
                    },
                    null
                );
                cordova.getActivity().runOnUiThread(removeViewTask);
                removeViewTask.get();
            }
            cordova.getActivity().getSupportFragmentManager().beginTransaction().remove(fragment).commitAllowingStateLoss();
            fragment = null;

            callbackContext.success();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }

    private static int getCameraDirection(JSONObject options) {
        try {
            return options.getString("direction").equals("front")
                    ? CameraSelector.LENS_FACING_FRONT
                    : CameraSelector.LENS_FACING_BACK;
        } catch (JSONException e) {
            return CameraSelector.LENS_FACING_BACK;
        }
    }

    private static double getAspectRatio(String aspectRatio) {
        Pattern pattern = Pattern.compile("\\b([1-9]\\d*):([1-9]\\d*)\\b");
        Matcher matcher = pattern.matcher(aspectRatio);
        if (!matcher.matches()) {
            return DEFAULT_ASPECT_RATIO;
        }

        String[] ratioParts = aspectRatio.split(":");
        double width = Double.parseDouble(ratioParts[0]);
        double height = Double.parseDouble(ratioParts[1]);
        return width / height;
    }

    private boolean switchCameraTo(JSONObject options, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed, cannot switch camera");
            return true;
        }

        int cameraDirection = getCameraDirection(options);
        try {
            options.put("direction", cameraDirection);
        } catch (JSONException e) {
            callbackContext.error("Unable to set direction in options");
            return true;
        }

        double aspectRatio = DEFAULT_ASPECT_RATIO; // Default aspect ratio 3:4
        String aspectRatioOption = null;
        try {
            aspectRatioOption = options.getString("aspectRatio");
        } catch (JSONException e) {
            Log.e("Error", "switchCameraTo: " + e.getMessage());
        }
        if (aspectRatioOption != null && !aspectRatioOption.equals("null")) {
            aspectRatio = getAspectRatio(aspectRatioOption);
        }

        try {
            options.put("aspectRatio", aspectRatio);
        } catch (JSONException e) {
            callbackContext.error("Unable to set aspectRatio in options");
            return true;
        }

        if (aspectRatio != fragment.getAspectRatio()) {
            try {
                updateContainerView(options);
            } catch (Exception e) {
                Log.e("Error", "switchCameraTo: " + e.getMessage());
                callbackContext.error("Failed to update camera preview size: " + e.getMessage());
                return false;
            }
        }

        fragment.switchCameraTo(options, (boolean result) -> {
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, result);
            callbackContext.sendPluginResult(pluginResult);
        });
        return true;
    }

    private void updateContainerView(JSONObject options) throws Exception {
        RunnableFuture<Void> updateViewTask = new FutureTask<>(
            new Runnable() {
                @Override
                public void run() {
                    DisplayMetrics metrics = new DisplayMetrics();
                    cordova.getActivity().getWindowManager().getDefaultDisplay().getMetrics(metrics);

                    int x = Math.round(getIntegerFromOptions(options, "x") * metrics.density);
                    int y = Math.round(getIntegerFromOptions(options, "y") * metrics.density);
                    int width = Math.round(getIntegerFromOptions(options, "width") * metrics.density);
                    int height = Math.round(getIntegerFromOptions(options, "height") * metrics.density);

                    FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                    if (containerView == null) {
                        containerView = new FrameLayout(cordova.getActivity().getApplicationContext());
                        containerView.setId(containerViewId);
                        FrameLayout.LayoutParams containerLayoutParams = new FrameLayout.LayoutParams(width, height);
                        containerLayoutParams.setMargins(x, y, 0, 0);
                        cordova.getActivity().addContentView(containerView, containerLayoutParams);
                        ViewGroup parent = (ViewGroup) webView.getView().getParent();
                        parent.bringToFront();
                    } else {
                        FrameLayout.LayoutParams containerLayoutParams = new FrameLayout.LayoutParams(width, height);
                        containerLayoutParams.setMargins(x, y, 0, 0);
                        containerView.setLayoutParams(containerLayoutParams);
                    }

                    cordova.getActivity().getWindow().getDecorView().setBackgroundColor(Color.BLACK);
                    webView.getView().bringToFront();
                    cordova.getActivity().getSupportFragmentManager().beginTransaction().replace(containerViewId, fragment).commitAllowingStateLoss();
                }
            },
            null
        );
        cordova.getActivity().runOnUiThread(updateViewTask);
        updateViewTask.get();
    }


    public void requestPermissions() {
        String[] permissions = {REQUIRED_PERMISSION};
        PermissionHelper.requestPermissions(this, REQUEST_CODE_PERMISSIONS, permissions);
    }

    public boolean permissionsGranted(int[] grantResults) {
        if (grantResults.length > 0) {
            for (int result : grantResults) {
                if (result != PackageManager.PERMISSION_GRANTED) {
                    return false;
                }
            }
        }
        return true;
    }

    public void showAlertPermissionAlwaysDenied() {
        AlertDialog.Builder builder = new AlertDialog.Builder(cordova.getContext());
        builder.setTitle("Permissions required")
                .setMessage("Please grant the Camera permission for this app from your Settings.")
                .setCancelable(false)
                .setPositiveButton("App info", ((dialogInterface, i) -> {
                    Intent intent = new Intent(
                            Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            Uri.fromParts("package", cordova.getActivity().getPackageName(), null)
                    );
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    cordova.getActivity().startActivity(intent);
                    cordova.getActivity().finish();
                }))
                .setNegativeButton("Cancel", ((dialogInterface, i) -> {
                    cordova.getActivity().finish();
                }))
                .create()
                .show();
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_CODE_PERMISSIONS && this.enableCallbackContext != null) {
            if (grantResults.length < 1) { return; }
            boolean permissionsGranted = this.permissionsGranted(grantResults);

            if (!permissionsGranted) {
                boolean permissionAlwaysDenied = false;

                for (String permission : permissions) {
                    if (ActivityCompat.shouldShowRequestPermissionRationale(cordova.getActivity(), permission)) {
                        this.requestPermissions();
                    } else {
                        if (ActivityCompat.checkSelfPermission(cordova.getContext(), permission) == PackageManager.PERMISSION_DENIED) {
                            permissionAlwaysDenied = true;
                        }
                    }
                }

                if (permissionAlwaysDenied) {
                    this.showAlertPermissionAlwaysDenied();
                }
            } else {
                enable(this.options, this.enableCallbackContext);
            }
        }
        if (requestCode == VIDEO_REQUEST_CODE_PERMISSIONS && this.videoCallbackContext != null) {
            if (grantResults.length < 1) { return; }

            boolean permissionsGranted = this.permissionsGranted(grantResults);
            JSONObject data = new JSONObject();
            try {
                data.put("restartVideoCaptureWithAudio", permissionsGranted);
            } catch (JSONException e) {
                e.printStackTrace();
                videoCallbackContext.error("Cannot start video");
                return;
            }

            PluginResult result = new PluginResult(PluginResult.Status.OK, data);
            result.setKeepCallback(true);
            this.videoCallbackContext.sendPluginResult(result);
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (locationManager != null) {
            locationManager.removeUpdates(mLocationCallback);
        }
        locationManager = null;
    }
}
