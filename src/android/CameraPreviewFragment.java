package com.spoon.simplecamerapreview;

import android.annotation.SuppressLint;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.view.PreviewView;
import androidx.core.content.ContextCompat;
import androidx.exifinterface.media.ExifInterface;
import androidx.fragment.app.Fragment;

import com.google.common.util.concurrent.ListenableFuture;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

interface CameraCallback {
    void onCompleted(Exception err, String nativePath);
}

interface CameraStartedCallback {
    void onCameraStarted(Exception err);
}

interface TorchCallback {
    void onEnabled(Exception err);
}

public class CameraPreviewFragment extends Fragment {

    private PreviewView viewFinder;
    private Preview preview;
    private ImageCapture imageCapture;
    private Camera camera;
    private CameraStartedCallback startCameraCallback;
    private Location location;
    private int direction;
    private int targetSize;
    private boolean torchActivated = false;
    private float aspectRatio = (4 / 3);

    private static final String TAG = "SimpleCameraPreview";

    public CameraPreviewFragment() {

    }

    @SuppressLint("ValidFragment")
    public CameraPreviewFragment(int cameraDirection, CameraStartedCallback cameraStartedCallback, JSONObject options) {
        this.direction = cameraDirection;
        try {
            this.targetSize = options.getInt("targetSize");
        } catch (JSONException e) {
            e.printStackTrace();
        }
        startCameraCallback = cameraStartedCallback;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        RelativeLayout containerView = new RelativeLayout(getActivity());
        RelativeLayout.LayoutParams containerLayoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_START);
        containerView.setLayoutParams(containerLayoutParams);

        viewFinder = new PreviewView(getActivity());
        viewFinder.setLayoutParams(new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT));
        containerView.addView(viewFinder);
        startCamera();

        return containerView;
    }

    @SuppressLint("RestrictedApi")
    public void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());
        ProcessCameraProvider cameraProvider = null;

        try {
            cameraProvider = cameraProviderFuture.get();
        } catch (ExecutionException | InterruptedException e) {
            Log.e(TAG, "startCamera: " + e.getMessage());
            e.printStackTrace();
            startCameraCallback.onCameraStarted(new Exception("Unable to start camera"));
            return;
        }

        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(direction)
                .build();

        Size targetResolution = null;
        if (targetSize > 0) {
            targetResolution = calculateResolution(targetSize);
        }

        preview = new Preview.Builder().build();
        imageCapture = new ImageCapture.Builder()
                .setDefaultResolution(targetResolution)
                .build();
        cameraProvider.unbindAll();
        try {
            camera = cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    preview,
                    imageCapture
            );
        } catch (IllegalArgumentException e) {
            // Error with result in capturing image with default resolution
            e.printStackTrace();
            imageCapture = new ImageCapture.Builder()
                    .build();
            camera = cameraProvider.bindToLifecycle(
                    this,
                    cameraSelector,
                    preview,
                    imageCapture
            );
        }

        preview.setSurfaceProvider(viewFinder.getSurfaceProvider());

        if (startCameraCallback != null) {
            startCameraCallback.onCameraStarted(null);
        }
    }

    public Size calculateResolution(int targetSize) {
        int orientation = getResources().getConfiguration().orientation;
        Size calculatedSize;
        if (orientation == 1) {
            calculatedSize = new Size((int) ((float) targetSize / aspectRatio), targetSize);
        } else {
            calculatedSize = new Size(targetSize, (int) ((float) targetSize / aspectRatio));
        }
        return calculatedSize;
    }

//    Another way to Calculate
//    @SuppressLint("RestrictedApi")
//    public Size calculateResolution(ProcessCameraProvider cameraProvider, CameraSelector cameraSelector, int targetSize) {
//        // tempCamera to calculate targetResolution
//        Preview tempPreview = new Preview.Builder().build();
//        ImageCapture tempImageCapture = new ImageCapture.Builder().build();
//        Camera tempCamera = cameraProvider.bindToLifecycle(
//                this,
//                cameraSelector,
//                tempPreview,
//                tempImageCapture
//        );
//
//        @SuppressLint("UnsafeOptInUsageError") CameraCharacteristics cameraCharacteristics = Camera2CameraInfo
//                .extractCameraCharacteristics(tempCamera.getCameraInfo());
//        StreamConfigurationMap streamConfigurationMap = cameraCharacteristics
//                .get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
//        List<Size> supportedSizes = Arrays.asList(streamConfigurationMap.getOutputSizes(ImageFormat.JPEG));
//        Collections.sort(supportedSizes, new Comparator<Size>(){
//            @Override
//            public int compare(Size size, Size t1) {
//                return Integer.compare(t1.getWidth(), size.getWidth());
//            }
//        });
//        for (Size size: supportedSizes) {
//            if (size.getWidth() <= targetSize) {
//                return size;
//            }
//        }
//        return supportedSizes.get(supportedSizes.size() - 1);
//    }

    public void torchSwitch(boolean torchOn, TorchCallback torchCallback) {
        if (!camera.getCameraInfo().hasFlashUnit()) {
            torchCallback.onEnabled(new Exception("No flash unit present"));
            return;
        } else {
            try {
                camera.getCameraControl().enableTorch(torchOn);
                torchCallback.onEnabled(null);
            } catch (Exception e) {
                torchCallback.onEnabled(new Exception("Failed to switch " + (torchOn ? "on" : "off") + " torch", e));
                return;
            }
            torchActivated = torchOn;
        }
      }

    public void takePicture(boolean useFlash, CameraCallback takePictureCallback) {
        if (torchActivated) {
            useFlash = true;
        } else {
            camera.getCameraControl().enableTorch(useFlash);
        }

        UUID uuid = UUID.randomUUID();

        File imgFile = new File(
                getActivity().getBaseContext().getFilesDir(),
                uuid.toString() + ".jpg"
        );

        if (imageCapture == null) {
            imageCapture = new ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MAXIMIZE_QUALITY)
                    .setTargetRotation(getActivity().getWindowManager().getDefaultDisplay().getRotation())
                    .build();
        }

        ImageCapture.OutputFileOptions outputOptions = new ImageCapture.OutputFileOptions.Builder(imgFile).build();
        imageCapture.takePicture(
                outputOptions,
                ContextCompat.getMainExecutor(getActivity().getApplicationContext()),
                new ImageCapture.OnImageSavedCallback() {
                    @Override
                    public void onImageSaved(@NonNull ImageCapture.OutputFileResults outputFileResults) {
                        if (camera.getCameraInfo().hasFlashUnit() && !torchActivated) {
                            camera.getCameraControl().enableTorch(false);
                        }

                        if (imgFile == null) {
                            takePictureCallback.onCompleted(new Exception("Unable to save image"), null);
                            return;
                        } else {

                            ExifInterface exif = null;
                            try {
                                exif = new ExifInterface(imgFile.getAbsolutePath());
                            } catch (IOException e) {
                                Log.e(TAG, "new ExifInterface err: " + e.getMessage());
                                e.printStackTrace();
                                takePictureCallback.onCompleted(new Exception("Unable to create exif object"), null);
                                return;
                            }

                            if (location != null) {
                                exif.setGpsInfo(location);
                                try {
                                    exif.saveAttributes();
                                } catch (IOException e) {
                                    Log.e(TAG, "save exif err: " + e.getMessage());
                                    e.printStackTrace();
                                    takePictureCallback.onCompleted(new Exception("Unable to save gps exif"), null);
                                    return;
                                }
                            }
                        }

                        takePictureCallback.onCompleted(null, Uri.fromFile(imgFile).toString());
                    }

                    @Override
                    public void onError(@NonNull ImageCaptureException exception) {
                        Log.e(TAG, "takePicture: " + exception.getMessage());
                        takePictureCallback.onCompleted(new Exception("Unable to take picture"), null);
                    }
                }
        );
    }

    public void setLocation(Location loc) {
        if (loc != null) {
            this.location = loc;
        }
    }
}
