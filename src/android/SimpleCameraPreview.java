package com.spoon.simplecamerapreview;

import android.Manifest;
import android.app.FragmentTransaction;
import android.content.Context;
import android.content.pm.PackageManager;
import android.location.Location;
import android.location.LocationListener;
import android.location.LocationManager;
import android.os.Bundle;
import android.support.v4.content.ContextCompat;
import android.util.Log;
import android.view.ViewParent;
import android.widget.FrameLayout;
import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;


public class SimpleCameraPreview extends CordovaPlugin {

    private static final String TAG = "SimpleCameraPreview";
    private static final String START_CAMERA_ACTION = "enable";
    private static final String STOP_CAMERA_ACTION = "disable";
    private static final String TAKE_PICTURE_ACTION = "capture";
    private static final int GEO_REQ_CODE = 23;
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
            if (START_CAMERA_ACTION.equals(action)) {
                return enable(callbackContext);
            } else if (TAKE_PICTURE_ACTION.equals(action)) {
                return capture(args.getBoolean(0), callbackContext);
            } else if (STOP_CAMERA_ACTION.equals(action)) {
                return disable(callbackContext);
            }
        } catch (Exception e) {
            e.printStackTrace();
        }
        return false;
    }

    private boolean enable(CallbackContext callbackContext) {
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
                int containerViewId = 20;
                //create or update the layout params for the container view
                FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                if (containerView == null) {
                    containerView = new FrameLayout(cordova.getActivity().getApplicationContext());
                    containerView.setId(containerViewId);
                    FrameLayout.LayoutParams containerLayoutParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
                    cordova.getActivity().addContentView(containerView, containerLayoutParams);
                }

                webView.getView().setBackgroundColor(0x00000000);
                webViewParent = webView.getView().getParent();
                webView.getView().bringToFront();
                cordova.getActivity().getFragmentManager().beginTransaction().replace(containerViewId, fragment).commit();

            }
        });

        mLocationCallback = new LocationListener() {
            @Override
            public void onLocationChanged(Location location) {
                if (fragment!=null)
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
    }

    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults){
        if (grantResults[0]== PackageManager.PERMISSION_DENIED)
            return;

        if (requestCode == GEO_REQ_CODE)
            fetchLocation();
    }

    public void fetchLocation(){
        if (ContextCompat.checkSelfPermission(cordova.getActivity(), android.Manifest.permission.ACCESS_FINE_LOCATION) == PackageManager.PERMISSION_GRANTED) {
            if (locationManager == null)
                locationManager = (LocationManager) cordova.getActivity().getSystemService(Context.LOCATION_SERVICE);
            Location cachedLocation = locationManager.getLastKnownLocation(LocationManager.NETWORK_PROVIDER);
            if (cachedLocation !=null)
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
        if (webViewParent != null) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    webView.getView().bringToFront();
                    webViewParent = null;
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
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        if (locationManager != null)
            locationManager.removeUpdates(mLocationCallback);
        locationManager = null;
    }
}