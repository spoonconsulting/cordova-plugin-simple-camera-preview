package com.spoon.simplecamerapreview;


import android.content.Context;
import android.content.ContextWrapper;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.ImageFormat;
import android.hardware.SensorManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CaptureRequest;
import android.media.Image;
import android.os.Bundle;
import android.app.Fragment;
import android.util.Log;
import android.util.Size;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.OrientationEventListener;
import android.view.Surface;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.RelativeLayout;
import com.avalancheevantage.android.camera3.AutoFitTextureView;
import com.avalancheevantage.android.camera3.Camera3;
import com.avalancheevantage.android.camera3.CaptureRequestConfiguration;
import com.avalancheevantage.android.camera3.OnImageAvailableListener;
import com.avalancheevantage.android.camera3.PreviewHandler;
import com.avalancheevantage.android.camera3.StillCaptureHandler;
import java.io.File;
import java.io.IOException;
import java.util.Collections;
import java.util.UUID;

interface CameraCallBack {
    void onCompleted(Exception err, String fileName);
}

public class CameraPreviewFragment extends Fragment {
    private Camera3 cameraManager;
    private static final String TAG = "CameraPreviewFragment";
    private  CameraCallBack takePictureCallback;
    private StillCaptureHandler captureSession;
    private int mLastRotation;
    private AutoFitTextureView previewTexture;
    private Size cameraSize;
    PreviewHandler previewHandler;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        WindowManager mWindowManager = (WindowManager) getActivity().getSystemService(Context.WINDOW_SERVICE);
        OrientationEventListener orientationEventListener = new OrientationEventListener(getActivity(), SensorManager.SENSOR_DELAY_NORMAL) {
            @Override
            public void onOrientationChanged(int orientation) {
                Display display = mWindowManager.getDefaultDisplay();
                int rotation = display.getRotation();
                if (rotation != mLastRotation) {
                    //rotation changed
                    if (cameraSize == null)
                        return;
                    if (rotation == Surface.ROTATION_90 || rotation == Surface.ROTATION_270) {
                        //landscape
                        previewTexture.setAspectRatio(cameraSize.getWidth(), cameraSize.getHeight());
                    } else {
                       //portrait
                        previewTexture.setAspectRatio(cameraSize.getHeight(), cameraSize.getWidth());
                    }
                }
                mLastRotation = rotation;
            }
        };

        if (orientationEventListener.canDetectOrientation())
            orientationEventListener.enable();

        RelativeLayout containerView = new RelativeLayout(getActivity());
        RelativeLayout.LayoutParams containerLayoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_START);
        previewTexture =  new AutoFitTextureView(getActivity());
        previewTexture.setFill(AutoFitTextureView.STYLE_FILL);
        containerView.addView(previewTexture);
        cameraManager =  new Camera3(this.getActivity(), Camera3.ERROR_HANDLER_DEFAULT);
        String cameraId = null;
        try {
            cameraId = cameraManager.getAvailableCameras().get(0);
        } catch (CameraAccessException e) {
            e.printStackTrace();

        }

        previewTexture.setFill(AutoFitTextureView.STYLE_FILL);

        // Handler to control everything about the preview
        previewHandler = new PreviewHandler(
                // The preview will automatically be rendered to this texture
                previewTexture,
                // No preferred size
                null,
                // No special configuration
                null,
                // Once a preview resolution has been selected, this callback will be called
                new Camera3.PreviewSizeCallback() {
                    @Override
                    public void previewSizeSelected(int orientation, Size size) {
                        // Once the preview size has been determined, scale the preview TextureView accordingly
                        Log.d(TAG, "preview size == " + size);
                        cameraSize = size;
                        if (orientation == Configuration.ORIENTATION_LANDSCAPE) {
                            previewTexture.setAspectRatio(size.getWidth(), size.getHeight());
                        } else {
                            previewTexture.setAspectRatio(size.getHeight(), size.getWidth());
                        }
                    }
                }
        );

        captureSession =
                new StillCaptureHandler(ImageFormat.JPEG,
                        cameraManager.getLargestAvailableImageSize(cameraId, ImageFormat.JPEG),
                        new OnImageAvailableListener() {
                            @Override
                            public ImageAction onImageAvailable(Image image) {
                                File imageFile = createMediaFile();
                                cameraManager.saveImageSync(image, imageFile);
                                takePictureCallback.onCompleted(null,imageFile.getName());
                                return ImageAction.CLOSE_IMAGE;
                            }
                        });
        cameraManager.startCaptureSession(cameraId, previewHandler, Collections.singletonList(captureSession));
        return containerView;
    }

    public void disableCamera(){
        cameraManager.pause();
    }

    private File createMediaFile() {
        try {
            UUID uuid = UUID.randomUUID();
            File mFile = new File(new ContextWrapper(getActivity().getBaseContext()).getFilesDir(), uuid.toString() + ".jpg");
            mFile.createNewFile();
            return  mFile;
        } catch (IOException e) {
            e.printStackTrace();
            return null;
        }
    }

    @Override
    public void onResume() {
        super.onResume();
        Log.d(TAG, "onResume");
        // Restart the camera when the activity is re-opened
        if (cameraManager.captureConfigured()) {
            cameraManager.resume();
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        cameraManager.pause();
    }

    public void takePicture(Boolean useFlash, CameraCallBack callback) {
        takePictureCallback = callback;

        previewHandler.updateRequestConfig(new CaptureRequestConfiguration() {
            @Override
            public void configure(CaptureRequest.Builder request) {
                request.set(CaptureRequest.FLASH_MODE,  useFlash ? CaptureRequest.FLASH_MODE_SINGLE : CaptureRequest.FLASH_MODE_OFF);
            }
        });
        CaptureRequestConfiguration config = new CaptureRequestConfiguration() {
            @Override
            public void configure(CaptureRequest.Builder request) {
                request.set(CaptureRequest.FLASH_MODE, useFlash ? CaptureRequest.CONTROL_AE_MODE_ON_ALWAYS_FLASH: CaptureRequest.FLASH_MODE_OFF);
            }
        };
        cameraManager.captureImage(captureSession, Camera3.PRECAPTURE_CONFIG_NONE, config);
    }
}
  
