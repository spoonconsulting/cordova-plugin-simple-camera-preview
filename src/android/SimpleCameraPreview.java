package com.spoon.simplecamerapreview;

import android.Manifest;
import android.app.FragmentTransaction;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Resources;
import android.graphics.Color;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.util.DisplayMetrics;
import androidx.core.content.ContextCompat;

import android.util.Log;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;


public class SimpleCameraPreview extends CordovaPlugin {

    private static final String TAG = "SimpleCameraPreview";
    private static final int GEO_REQ_CODE = 23;
    private static final int containerViewId = 20;
    private CameraPreviewFragment fragment;
    private ViewParent webViewParent;
    private LocationManager locationManager;
    private LocationListener mLocationCallback;


    public SimpleCameraPreview() {
        super();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            if (action.equals("enable")) {
                return enable((JSONObject) args.get(0), callbackContext);
            } else if (action.equals("capture")) {
                return capture(args.getBoolean(0), callbackContext);
            } else if (action.equals("disable")) {
                return disable(callbackContext);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    private boolean enable(JSONObject options, CallbackContext callbackContext) {
        try {
            Log.d(TAG, "start camera action");
            if (fragment != null) {
                callbackContext.error("Camera already started");
                return true;
            }
            fragment = new CameraPreviewFragment(new CameraStartedCallBack() {
                @Override
                public void onCameraStarted() {
                    PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
                    pluginResult.setKeepCallback(true);
                    callbackContext.sendPluginResult(pluginResult);
                }
            });
            cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    try {
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
                    } catch(Exception e) {
                        e.printStackTrace();
                        callbackContext.error(e.getMessage());
                        return;
                    }
                }
            });

            mLocationCallback = new LocationListener() {
                @Override
                public void onLocationChanged(Location location) {
                    if (fragment != null)
                        fragment.setLocation(location);
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
            if (cordova.hasPermission(Manifest.permission.ACCESS_FINE_LOCATION))
                fetchLocation();
            else
                cordova.requestPermission(this, GEO_REQ_CODE, Manifest.permission.ACCESS_FINE_LOCATION);
            return true;
        } catch(Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }
    
    private int getIntegerFromOptions(JSONObject options, String key){
        try {
            return options.getInt(key);
        } catch (JSONException error) {
            return 0;
        }
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) {
        if (grantResults.length < 1)
            return;
        if (grantResults[0] == PackageManager.PERMISSION_DENIED)
            return;

        if (requestCode == GEO_REQ_CODE)
            fetchLocation();
    }

    public void fetchLocation() {
        if (ContextCompat.checkSelfPermission(cordova.getActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            if (locationManager == null)
                locationManager = (LocationManager) cordova.getActivity().getSystemService(Context.LOCATION_SERVICE);
            Location cachedLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER);
            if (cachedLocation != null)
                fragment.setLocation(cachedLocation);
            locationManager.requestLocationUpdates(LocationManager.NETWORK_PROVIDER, 0, 0, mLocationCallback);
        }
    }

    private boolean capture(Boolean useFlash, CallbackContext callbackContext) {
        fragment.takePicture(useFlash, (Exception err, String fileName) -> {
            if (err == null) {
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, fileName);
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
            } else {
                callbackContext.error(err.getMessage());
            }
        });
        return true;
    }


    private boolean disable(CallbackContext callbackContext) {
        try {
            if (webViewParent != null) {
                cordova.getActivity().runOnUiThread(new Runnable() {
                    @Override
                    public void run() {
                        webView.getView().bringToFront();
                        webViewParent = null;
                        FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                        ((ViewGroup) containerView.getParent()).removeView(containerView);
                    }
                });
            }
            fragment.disableCamera();
            FragmentTransaction fragmentTransaction = cordova.getActivity().getFragmentManager().beginTransaction();
            fragmentTransaction.remove(fragment);
            fragmentTransaction.commit();
            fragment = null;

            callbackContext.success();
            return true;
        } catch(Exception e) {
            e.printStackTrace();
            callbackContext.error(e.getMessage());
            return false;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (locationManager != null)
            locationManager.removeUpdates(mLocationCallback);
        locationManager = null;
    }
}
