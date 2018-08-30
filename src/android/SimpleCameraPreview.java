package com.spoon.simplecamerapreview;

import android.app.FragmentTransaction;
import android.util.Log;
import android.view.ViewGroup;
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
    private Camera2BasicFragment fragment;
    private ViewParent webViewParent;

    public SimpleCameraPreview() {
        super();
    }

    @Override
    public boolean execute(String action, JSONArray args, CallbackContext callbackContext) {
        try {
            if (START_CAMERA_ACTION.equals(action)) {
                return enable(callbackContext);
            } else if (TAKE_PICTURE_ACTION.equals(action)) {
                return capture(args.getString(0), callbackContext);
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
        fragment = new Camera2BasicFragment();
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
                PluginResult pluginResult = new PluginResult(PluginResult.Status.OK, "Camera started");
                pluginResult.setKeepCallback(true);
                callbackContext.sendPluginResult(pluginResult);
            }
        });

        return true;
    }


    private boolean capture(String flashMode, CallbackContext callbackContext) {
        fragment.takePicture(flashMode, (Exception err, String fileName) -> {
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
}