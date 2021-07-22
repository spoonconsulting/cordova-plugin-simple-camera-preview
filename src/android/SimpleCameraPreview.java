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
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;

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

public class SimpleCameraPreview extends CordovaPlugin {

    private CameraPreviewFragment fragment;
    private JSONObject options;
    private CallbackContext enableCallbackContext;
    private LocationManager locationManager;
    private LocationListener mLocationCallback;
    private ViewParent webViewParent;

    private static final int containerViewId = 20;
    private static final int DIRECTION_FRONT = 0;
    private static final int DIRECTION_BACK = 1;
    private static final int REQUEST_CODE_PERMISSIONS = 4582679;
    private static final String[] REQUIRED_PERMISSIONS = {Manifest.permission.CAMERA, Manifest.permission.ACCESS_FINE_LOCATION};

    public SimpleCameraPreview() {
        super();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {
        switch (action) {
            case "enable":
                return enable((JSONObject) args.get(0), callbackContext);

            case "disable":
                return disable(callbackContext);

            case "capture":
                return capture(args.getBoolean(0), callbackContext);

            default:
                break;
        }

        return false;
    }

    private boolean enable(JSONObject options, CallbackContext callbackContext) {
        if (!this.hasAllPermissions()) {
            this.enableCallbackContext = callbackContext;
            this.options = options;
            this.requestPermissions();
            return true;
        }

        if (fragment != null) {
            callbackContext.error("Camera already started");
            return true;
        }

        int cameraDirection;

        try {
            cameraDirection = options.getString("direction").equals("front") ? SimpleCameraPreview.DIRECTION_FRONT : SimpleCameraPreview.DIRECTION_BACK;
        } catch (JSONException e) {
            cameraDirection = SimpleCameraPreview.DIRECTION_BACK;
        }

        fragment = new CameraPreviewFragment(cameraDirection, (err) -> {
            if (err != null) {
                callbackContext.error(err.getMessage());
                return;
            }
            PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
            callbackContext.sendPluginResult(pluginResult);
        });

        try {
            RunnableFuture<Void> addViewTask = new FutureTask<>(
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
                        }
                        cordova.getActivity().getWindow().getDecorView().setBackgroundColor(Color.BLACK);
                        webView.getView().setBackgroundColor(0x00000000);
                        webViewParent = webView.getView().getParent();
                        webView.getView().bringToFront();
                        cordova.getActivity().getFragmentManager().beginTransaction().replace(containerViewId, fragment).commitAllowingStateLoss();
                    }
                },
                null
            );
            cordova.getActivity().runOnUiThread(addViewTask);
            addViewTask.get();

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
        if (ContextCompat.checkSelfPermission(cordova.getActivity(), REQUIRED_PERMISSIONS[1]) == PackageManager.PERMISSION_GRANTED) {
            if (locationManager == null) {
                locationManager = (LocationManager) cordova.getActivity().getSystemService(Context.LOCATION_SERVICE);
            }
            Location cachedLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER);
            if (cachedLocation != null) {
                fragment.setLocation(cachedLocation);
            }
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0, 0, mLocationCallback);
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
            cordova.getActivity().getFragmentManager().beginTransaction().remove(fragment).commitAllowingStateLoss();
            fragment = null;

            callbackContext.success();
            return true;
        } catch (Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }

    public boolean hasAllPermissions() {
        for(String p : REQUIRED_PERMISSIONS) {
            if(!PermissionHelper.hasPermission(this, p)) {
                return false;
            }
        }
        return true;
    }

    public void requestPermissions() {
        PermissionHelper.requestPermissions(this, REQUEST_CODE_PERMISSIONS, REQUIRED_PERMISSIONS);
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
