package com.spoon.simplecamerapreview;

import android.content.ContextWrapper;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CaptureRequest;
import android.media.Image;
import android.os.Bundle;
import android.app.Fragment;
import android.util.Log;
import android.util.Size;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;

import com.avalancheevantage.android.camera3.AutoFitTextureView;
import com.avalancheevantage.android.camera3.Camera3;
import com.avalancheevantage.android.camera3.CaptureRequestConfiguration;
import com.avalancheevantage.android.camera3.OnImageAvailableListener;
import com.avalancheevantage.android.camera3.PreviewHandler;
import com.avalancheevantage.android.camera3.StillCaptureHandler;
import com.sharinpix.SharinPix.R;
import java.io.File;
import java.io.IOException;
import java.util.Collections;
import java.util.UUID;

interface CameraCallBack {
    void onCompleted(Exception err, String fileName);
}

public class CameraPreviewFragment extends Fragment {
    private Camera3 cameraManager;
    private static final String TAG = "Camera2BasicFragment";
    private  CameraCallBack takePictureCallback;
    private StillCaptureHandler captureSession;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        RelativeLayout containerView = new RelativeLayout(getActivity());
        RelativeLayout.LayoutParams containerLayoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_START);
        AutoFitTextureView previewTexture =  new AutoFitTextureView(getActivity());
        previewTexture.setFill(AutoFitTextureView.STYLE_FILL);
        previewTexture.setBackgroundColor(Color.BLUE);
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
        PreviewHandler previewHandler = new PreviewHandler(
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

    public void takePicture(String flashMode, CameraCallBack callback) {
        takePictureCallback = callback;
        CaptureRequestConfiguration config = new CaptureRequestConfiguration() {
            @Override
            public void configure(CaptureRequest.Builder request) {
                request.set(CaptureRequest.FLASH_MODE, flashMode.toLowerCase().equals("on")? CaptureRequest.FLASH_MODE_SINGLE: CaptureRequest.FLASH_MODE_OFF);
            }
        };
        cameraManager.captureImage(captureSession, Camera3.PRECAPTURE_CONFIG_NONE, config);
    }
}
  