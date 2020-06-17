package com.spoon.simplecamerapreview;

import android.Manifest;
import android.content.pm.PackageManager;
import android.util.DisplayMetrics;
import android.view.ViewGroup;
import android.widget.FrameLayout;

import androidx.core.content.ContextCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

public class SimpleCameraPreview extends CordovaPlugin {

    private CameraPreviewFragment fragment;
    private JSONObject options;
    private CallbackContext callbackContext;
    private static final int containerViewId = 20;
    private static final int REQUEST_CODE_PERMISSIONS = 10;
    private static final String[] REQUIRED_PERMISSIONS = {Manifest.permission.CAMERA};

    public SimpleCameraPreview() {
        super();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            if (!allPermissionsGranted()) {
                this.options = (JSONObject) args.get(0);
                this.callbackContext = callbackContext;

                cordova.requestPermissions(this, REQUEST_CODE_PERMISSIONS, REQUIRED_PERMISSIONS);
                return false;
            }

            switch (action) {
                case "open":
                    return openCamera((JSONObject) args.get(0), callbackContext);

                case "close":
                    return closeCamera(callbackContext);

                case "capture":
                    return capturePhoto(args.getBoolean(0), callbackContext);

                default:
                    break;
            }
        } catch (Exception e) {
            e.printStackTrace();
        }

        return false;
    }

    private boolean allPermissionsGranted() {
        for (String permission : REQUIRED_PERMISSIONS) {
            return ContextCompat.checkSelfPermission(cordova.getContext(), permission) == PackageManager.PERMISSION_GRANTED;
        }

        return false;
    }

    private boolean openCamera(JSONObject options, CallbackContext callbackContext) {
        if (fragment != null) {
            callbackContext.error("Camera already started");
            return true;
        }

        fragment = new CameraPreviewFragment(() -> {
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
            pluginResult.setKeepCallback(true);
            callbackContext.sendPluginResult(pluginResult);
        });

        cordova.getActivity().runOnUiThread(() -> {
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
            }

            cordova.getActivity().getFragmentManager().beginTransaction().replace(containerViewId, fragment).commit();
        });

        return true;
    }

    private int getIntegerFromOptions(JSONObject options, String key) {
        try {
            return options.getInt(key);
        } catch (JSONException error) {
            return 0;
        }
    }

    private boolean closeCamera(CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera already closed");
            return true;
        }

        cordova.getActivity().getFragmentManager().beginTransaction().remove(fragment).commit();
        fragment = null;

        cordova.getActivity().runOnUiThread(() -> {
            webView.getView().bringToFront();
            FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
            ((ViewGroup) containerView.getParent()).removeView(containerView);
        });

        callbackContext.success();
        return true;
    }

    private boolean capturePhoto(boolean useFlash, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed");
            return true;
        }

        fragment.capturePhoto(useFlash, (Exception e, String fileName) -> {
            if (e == null) {
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, fileName);
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
            } else {
                callbackContext.error(e.getMessage());
            }
        });

        return true;
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults[0] == PackageManager.PERMISSION_DENIED) {
                cordova.requestPermissions(this, REQUEST_CODE_PERMISSIONS, REQUIRED_PERMISSIONS);
            } else {
                openCamera(this.options, this.callbackContext);
            }
        }
    }
}
