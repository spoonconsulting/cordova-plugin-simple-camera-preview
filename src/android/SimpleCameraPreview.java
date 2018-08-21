package com.spoonconsulting.simplecamerapreview;

import android.Manifest;
import android.annotation.TargetApi;
import android.app.Fragment;
import android.content.Context;
import android.content.pm.PackageManager;
import android.app.FragmentManager;
import android.app.FragmentTransaction;
import android.graphics.Color;
import android.hardware.Camera;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.CameraMetadata;
import android.os.Build;
import android.util.DisplayMetrics;
import android.util.Log;
import android.util.TypedValue;
import android.view.ViewGroup;
import android.view.ViewParent;
import android.widget.FrameLayout;

import com.sharinpix.SharinPix.R;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONObject;
import org.json.JSONArray;
import org.json.JSONException;

import java.util.List;
import java.util.Arrays;

public class SimpleCameraPreview extends CordovaPlugin {

    private static final String TAG = "SimpleCameraPreview";
    private static final String START_CAMERA_ACTION = "startCamera";
    private static final String STOP_CAMERA_ACTION = "stopCamera";
    private static final String TAKE_PICTURE_ACTION = "takePicture";
    private static final String SHOW_CAMERA_ACTION = "showCamera";
    private static final String HIDE_CAMERA_ACTION = "hideCamera";


    private static final int CAM_REQ_CODE = 0;

    private static final String[] permissions = {
            Manifest.permission.CAMERA
    };

    private Camera2BasicFragment fragment;
    private CallbackContext startCameraCallbackContext;
    private CallbackContext execCallback;
    private JSONArray execArgs;
    private ViewParent webViewParent;

    public SimpleCameraPreview() {
        super();
        Log.d(TAG, "Constructing");
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) throws JSONException {

        if (START_CAMERA_ACTION.equals(action)) {
            if (cordova.hasPermission(permissions[0])) {
                return startCamera(callbackContext);
            } else {
                this.execCallback = callbackContext;
                this.execArgs = args;
                cordova.requestPermissions(this, CAM_REQ_CODE, permissions);
                return true;
            }
        } else if (TAKE_PICTURE_ACTION.equals(action)) {
            return takePicture(callbackContext);
        } else if (STOP_CAMERA_ACTION.equals(action)) {
            return stopCamera(callbackContext);
        } else if (SHOW_CAMERA_ACTION.equals(action)) {
            return showCamera(callbackContext);
        } else if (HIDE_CAMERA_ACTION.equals(action)) {
            return hideCamera(callbackContext);
        }
        return false;
    }

    @Override
    public void onRequestPermissionResult(int requestCode, String[] permissions, int[] grantResults) throws JSONException {
        for (int r : grantResults) {
            if (r == PackageManager.PERMISSION_DENIED) {
                execCallback.sendPluginResult(new PluginResult(PluginResult.Status.ILLEGAL_ACCESS_EXCEPTION));
                return;
            }
        }
        if (requestCode == CAM_REQ_CODE) {
            startCamera(this.execCallback);
        }
    }

    private boolean hasView(CallbackContext callbackContext) {
        if (fragment == null) {
            callbackContext.error("No preview");
            return false;
        }

        return true;
    }


    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    public boolean allowCamera2Support(int cameraId) {
        CameraManager manager = (CameraManager) cordova.getActivity().getSystemService(Context.CAMERA_SERVICE);
        try {
            String cameraIdS = manager.getCameraIdList()[cameraId];
            CameraCharacteristics characteristics = manager.getCameraCharacteristics(cameraIdS);
            int support = characteristics.get(CameraCharacteristics.INFO_SUPPORTED_HARDWARE_LEVEL);

            if (support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LEGACY)
                Log.d(TAG, "Camera " + cameraId + " has LEGACY Camera2 support");
            else if (support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED)
                Log.d(TAG, "Camera " + cameraId + " has LIMITED Camera2 support");
            else if (support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_FULL)
                Log.d(TAG, "Camera " + cameraId + " has FULL Camera2 support");
            else
                Log.d(TAG, "Camera " + cameraId + " has unknown Camera2 support?!");

            return support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_LIMITED || support == CameraMetadata.INFO_SUPPORTED_HARDWARE_LEVEL_FULL;
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
        return false;
    }

    @TargetApi(Build.VERSION_CODES.LOLLIPOP)
    private void checkCamera2Support() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
            int numberOfCameras = 0;
            CameraManager manager = (CameraManager) cordova.getActivity().getSystemService(Context.CAMERA_SERVICE);

            try {
                numberOfCameras = manager.getCameraIdList().length;
            } catch (CameraAccessException e) {
                e.printStackTrace();
            } catch (AssertionError e) {
                e.printStackTrace();
            }

            if (numberOfCameras == 0) {
                Log.d(TAG, "0 cameras");
            } else {
                for (int i = 0; i < numberOfCameras; i++) {
                    if (!allowCamera2Support(i)) {
                        Log.d(TAG, "camera " + i + " doesn't have limited or full support for Camera2 API");
                    } else {
                        // here you can get ids of cameras that have limited or full support for Camera2 API
                    }
                }
            }
        }
    }


    private boolean startCamera(CallbackContext callbackContext) {
        Log.d(TAG, "start camera action");
        if (fragment != null) {
            callbackContext.error("Camera already started");
            return true;
        }
        fragment = Camera2BasicFragment.newInstance();
        cordova.getActivity().runOnUiThread(new Runnable() {
            @Override
            public void run() {
                int containerViewId = 20;
                //create or update the layout params for the container view
                FrameLayout containerView = cordova.getActivity().findViewById(containerViewId);
                if (containerView == null) {
                    containerView = new FrameLayout(cordova.getActivity().getApplicationContext());
                    containerView.setId(containerViewId);
                    containerView.setBackgroundColor(Color.BLUE);
                    FrameLayout.LayoutParams containerLayoutParams = new FrameLayout.LayoutParams(FrameLayout.LayoutParams.MATCH_PARENT, FrameLayout.LayoutParams.MATCH_PARENT);
                    cordova.getActivity().addContentView(containerView, containerLayoutParams);
                }

                webView.getView().setBackgroundColor(0x00000000);
                webViewParent = webView.getView().getParent();
                webView.getView().bringToFront();
                cordova.getActivity().getFragmentManager().beginTransaction().replace(containerViewId, fragment).commit();
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
            }
        });

        return true;
    }


    private boolean takePicture(CallbackContext callbackContext) {
        fragment.takePicture((Exception err, String fileName) -> {
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


    private boolean stopCamera(CallbackContext callbackContext) {

        if (webViewParent != null) {
            cordova.getActivity().runOnUiThread(new Runnable() {
                @Override
                public void run() {
                    ((ViewGroup) webView.getView()).bringToFront();
                    webViewParent = null;
                }
            });
        }

        if (this.hasView(callbackContext) == false) {
            return true;
        }

        FragmentManager fragmentManager = cordova.getActivity().getFragmentManager();
        FragmentTransaction fragmentTransaction = fragmentManager.beginTransaction();
        fragmentTransaction.remove(fragment);
        fragmentTransaction.commit();
        fragment = null;

        callbackContext.success();
        return true;
    }

    private boolean showCamera(CallbackContext callbackContext) {
        if (this.hasView(callbackContext) == false) {
            return true;
        }

        FragmentManager fragmentManager = cordova.getActivity().getFragmentManager();
        FragmentTransaction fragmentTransaction = fragmentManager.beginTransaction();
        fragmentTransaction.show(fragment);
        fragmentTransaction.commit();

        callbackContext.success();
        return true;
    }

    private boolean hideCamera(CallbackContext callbackContext) {
        if (this.hasView(callbackContext) == false) {
            return true;
        }

        FragmentManager fragmentManager = cordova.getActivity().getFragmentManager();
        FragmentTransaction fragmentTransaction = fragmentManager.beginTransaction();
        fragmentTransaction.hide(fragment);
        fragmentTransaction.commit();

        callbackContext.success();
        return true;
    }

}
