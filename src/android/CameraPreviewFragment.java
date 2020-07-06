package com.spoon.simplecamerapreview;

import android.annotation.SuppressLint;
import android.app.Fragment;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
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
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.google.common.util.concurrent.ListenableFuture;

import java.io.File;
import java.io.IOException;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

public class CameraPreviewFragment extends Fragment implements LifecycleOwner {

    private PreviewView viewFinder;
    private Preview preview;
    private ImageCapture imageCapture;
    private Camera camera;
    private LifecycleRegistry lifecycleRegistry;
    private CameraCallback capturePictureCallback;
    private CameraStartedCallback startCameraCallback;
    private Location location;
    private int direction;

    private static final String TAG = "SimpleCameraPreview";

    public CameraPreviewFragment() {

    }

    @SuppressLint("ValidFragment")
    public CameraPreviewFragment(int cameraDirection, CameraStartedCallback cameraStartedCallback) {
        this.direction = cameraDirection;
        this.startCameraCallback = cameraStartedCallback;
    }

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        lifecycleRegistry = new LifecycleRegistry(this::getLifecycle);
        lifecycleRegistry.setCurrentState(Lifecycle.State.CREATED);

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

    @Override
    public void onStart() {
        super.onStart();

        if (lifecycleRegistry.getCurrentState() == Lifecycle.State.CREATED) {
            lifecycleRegistry.setCurrentState(Lifecycle.State.STARTED);
        }
    }

    public void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());
        ProcessCameraProvider cameraProvider = null;

        try {
            cameraProvider = cameraProviderFuture.get();
        } catch (ExecutionException | InterruptedException e) {
            e.printStackTrace();
            Log.e(TAG, "startCamera: " + e.getMessage());
        }

        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(direction)
                .build();
        preview = new Preview.Builder().build();
        imageCapture = new ImageCapture.Builder().build();

        cameraProvider.unbindAll();
        camera = cameraProvider.bindToLifecycle(
                this::getLifecycle,
                cameraSelector,
                preview,
                imageCapture
        );

        preview.setSurfaceProvider(viewFinder.createSurfaceProvider(camera.getCameraInfo()));

        if (startCameraCallback != null) {
            startCameraCallback.onCameraStarted();
        }
    }

    public void takePicture(boolean useFlash, String cdvFilePath, CameraCallback takePictureCallback) {
        if (cdvFilePath != null) {
            takePictureCallback.onCompleted(null, cdvFilePath, true);
            return;
        }

        this.capturePictureCallback = takePictureCallback;
        camera.getCameraControl().enableTorch(useFlash);

        UUID uuid = UUID.randomUUID();

        File imgFile = new File(
                getActivity().getBaseContext().getFilesDir(),
                uuid.toString() + ".jpg"
        );

        if (imageCapture == null) {
            imageCapture = new ImageCapture.Builder()
                    .setCaptureMode(ImageCapture.CAPTURE_MODE_MINIMIZE_LATENCY)
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
                        if (camera.getCameraInfo().hasFlashUnit()) {
                            camera.getCameraControl().enableTorch(false);
                        }

                        if (imgFile == null) {
                            capturePictureCallback.onCompleted(new Exception("Unable to save image"), null, false);
                        } else {
                            try {
                                ExifInterface exif = new ExifInterface(imgFile.getAbsolutePath());

                                if (exif != null && location != null) {
                                    exif.setGpsInfo(location);
                                    exif.saveAttributes();
                                }
                            } catch (IOException e) {
                                e.printStackTrace();
                                Log.e(TAG, "onImageSaved: " + e.getMessage());
                            }
                        }

                        capturePictureCallback.onCompleted(null, Uri.fromFile(imgFile).toString(), false);
                    }

                    @Override
                    public void onError(@NonNull ImageCaptureException exception) {
                        Log.e(TAG, "takePicture: " + exception.getMessage());
                        capturePictureCallback.onCompleted(exception, null, false);
                    }
                }
        );
    }

    public void setLocation(Location loc) {
        if (loc != null) {
            this.location = loc;
        }
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
    }

    @Override
    public void onResume() {
        super.onResume();
        startCamera();
    }

    @NonNull
    @Override
    public Lifecycle getLifecycle() {
        return lifecycleRegistry;
    }

    interface CameraCallback {
        void onCompleted(Exception e, String filename, boolean convertState);
    }

    interface CameraStartedCallback {
        void onCameraStarted();
    }
}
