package com.spoon.simplecamerapreview;

import android.Manifest;
import android.content.Context;
import android.content.pm.PackageManager;
import android.graphics.Color;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.Base64;
import android.util.DisplayMetrics;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.webkit.WebView;
import android.widget.FrameLayout;

import androidx.core.content.ContextCompat;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import java.io.IOException;
import java.io.InputStream;

public class SimpleCameraPreview extends CordovaPlugin {

    private CameraPreviewFragment fragment;
    private JSONObject options;
    private CallbackContext callbackContext;
    private CallbackContext tmpCallbackContext;
    private LocationManager locationManager;
    private LocationListener mLocationCallback;
    private ViewParent webViewParent;
    private WebView cdvWebView;

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
        if (!allPermissionsGranted()) {
            this.options = (JSONObject) args.get(0);
            this.callbackContext = callbackContext;

            cordova.requestPermissions(this, REQUEST_CODE_PERMISSIONS, REQUIRED_PERMISSIONS);
            return false;
        }

        switch (action) {
            case "enable":
                return enable((JSONObject) args.get(0), callbackContext);

            case "disable":
                return disable(callbackContext);

            case "capture":
                return capture((JSONObject) args.get(0), callbackContext);

            default:
                break;
        }

        return false;
    }

    private boolean allPermissionsGranted() {
        for (int i = 0; i < REQUIRED_PERMISSIONS.length; i++) {
            boolean isGranted = ContextCompat.checkSelfPermission(cordova.getContext(), REQUIRED_PERMISSIONS[i]) == PackageManager.PERMISSION_GRANTED;

            if (!isGranted) {
                return false;
            }
        }

        return true;
    }

    private boolean enable(JSONObject options, CallbackContext callbackContext) {
        if (fragment != null) {
            callbackContext.error("Camera already started");
            return true;
        }

        cdvWebView = (WebView) webView.getView();
        cordova.getActivity().runOnUiThread(() -> {
            try {
                InputStream inputStream = cordova.getContext().getAssets().open("cdvfile.js");
                byte[] buffer = new byte[inputStream.available()];
                inputStream.read(buffer);
                inputStream.close();

                String encoded = Base64.encodeToString(buffer, Base64.NO_WRAP);
                cdvWebView.loadUrl("javascript:(function() {" +
                        "var parent = document.getElementsByTagName('head').item(0);" +
                        "var script = document.createElement('script');" +
                        "script.type = 'text/javascript';" +
                        "script.innerHTML = window.atob('" + encoded + "');" +
                        "parent.appendChild(script)" +
                        "})()");
            } catch (IOException e) {
                e.printStackTrace();
            }
        });

        int cameraDirection;

        try {
            cameraDirection = options.getString("direction").equals("front") ? SimpleCameraPreview.DIRECTION_FRONT : SimpleCameraPreview.DIRECTION_BACK;
        } catch (JSONException e) {
            cameraDirection = SimpleCameraPreview.DIRECTION_BACK;
        }

        fragment = new CameraPreviewFragment(cameraDirection, () -> {
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

            cordova.getActivity().getWindow().getDecorView().setBackgroundColor(Color.BLACK);
            webView.getView().setBackgroundColor(0x00000000);
            webViewParent = webView.getView().getParent();
            webView.getView().bringToFront();
            cordova.getActivity().getFragmentManager().beginTransaction().replace(containerViewId, fragment).commit();
        });

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
    }

    private int getIntegerFromOptions(JSONObject options, String key) {
        try {
            return options.getInt(key);
        } catch (JSONException error) {
            return 0;
        }
    }

    private boolean disable(CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera already closed");
            return true;
        }

        cordova.getActivity().getFragmentManager().beginTransaction().remove(fragment).commit();
        fragment = null;

        if (webViewParent != null) {
            cordova.getActivity().runOnUiThread(() -> {
                webView.getView().bringToFront();
                webViewParent = null;
                FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                ((ViewGroup) containerView.getParent()).removeView(containerView);
            });
        }

        callbackContext.success();
        return true;
    }

    private boolean capture(JSONObject options, CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("Camera is closed");
            return true;
        }

        boolean useFlash = false;
        String cdvFilePath = null;

        try {
            useFlash = options.getBoolean("flash");
            cdvFilePath = options.getString("cdvFilePath");
        } catch (JSONException e) {
            e.printStackTrace();
        }

        fragment.takePicture(useFlash, cdvFilePath, (Exception e, String filePath, boolean convertState) -> {
            if (e == null) {
                if (convertState == false) {
                    tmpCallbackContext = callbackContext;
                    cdvWebView.evaluateJavascript(String.format("javascript: convertPath('%s');", filePath), null);
                } else {
                    PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, filePath);
                    pluginResult.setKeepCallback(true);
                    tmpCallbackContext.sendPluginResult(pluginResult);
                    tmpCallbackContext = null;
                }
            } else {
                callbackContext.error(e.getMessage());
            }
        });

        return true;
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode == REQUEST_CODE_PERMISSIONS) {
            if (grantResults[0] == PackageManager.PERMISSION_DENIED || grantResults[1] == PackageManager.PERMISSION_DENIED) {
                cordova.requestPermissions(this, REQUEST_CODE_PERMISSIONS, REQUIRED_PERMISSIONS);
            } else {
                enable(this.options, this.callbackContext);
                fetchLocation();
            }
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

    @Override
    public void onDestroy() {
        super.onDestroy();

        if (locationManager != null) {
            locationManager.removeUpdates(mLocationCallback);
        }

        locationManager = null;
    }
}
