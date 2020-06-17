package com.spoon.simplecamerapreview;

import android.annotation.SuppressLint;
import android.app.Fragment;
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
import androidx.lifecycle.Lifecycle;
import androidx.lifecycle.LifecycleOwner;
import androidx.lifecycle.LifecycleRegistry;

import com.google.common.util.concurrent.ListenableFuture;

import java.io.File;
import java.text.SimpleDateFormat;
import java.util.Locale;

public class CameraPreviewFragment extends Fragment implements LifecycleOwner {

    private PreviewView viewFinder;
    private Preview preview;
    private ImageCapture imageCapture;
    private Camera camera;
    private File outputDirectory;

    private static final String TAG = "TAG";
    private static final String FILENAME_FORMAT = "yyyy-MM-dd-HH-mm-ss-SSS";

    private LifecycleRegistry lifecycleRegistry;

    private CameraCallback mCameraCallback;
    private CameraStartedCallback cameraStartedCallback;

    public CameraPreviewFragment() {

    }

    @SuppressLint("ValidFragment")
    public CameraPreviewFragment(CameraStartedCallback cameraStartedCallback) {
        this.cameraStartedCallback = cameraStartedCallback;
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

        outputDirectory = getOutputDirectory();

        return containerView;
    }

    @Override
    public void onStart() {
        super.onStart();
        lifecycleRegistry.setCurrentState(Lifecycle.State.STARTED);
    }

    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());

        try {
            ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
            preview = new Preview.Builder().build();
            imageCapture = new ImageCapture.Builder().build();
            CameraSelector cameraSelector = new CameraSelector.Builder().requireLensFacing(CameraSelector.LENS_FACING_BACK).build();
            cameraProvider.unbindAll();
            camera = cameraProvider.bindToLifecycle(
                    this::getLifecycle,
                    cameraSelector,
                    preview,
                    imageCapture
            );

            preview.setSurfaceProvider(viewFinder.createSurfaceProvider(camera.getCameraInfo()));

            if (cameraStartedCallback != null) {
                cameraStartedCallback.onCameraStarted();
            }
        } catch (Exception e) {
            Log.e(TAG, "startCamera: " + e.getMessage());
        }
    }

    private File getOutputDirectory() {
        File filesDir = getActivity().getExternalFilesDir("Camerax");
        File cacheDir = getActivity().getExternalCacheDir();

        return (filesDir != null && filesDir.exists()) ? filesDir : cacheDir;
    }

    public void capturePhoto(boolean useFlash, CameraCallback callback) {
        this.mCameraCallback = callback;
        camera.getCameraControl().enableTorch(useFlash);

        File imgFile = new File(
                outputDirectory,
                new SimpleDateFormat(FILENAME_FORMAT, Locale.US)
                        .format(System.currentTimeMillis()) + ".jpg"
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
                            mCameraCallback.onCompleted(new Exception("Unable to save image"), null);
                        }

                        mCameraCallback.onCompleted(null, imgFile.getName());
                    }

                    @Override
                    public void onError(@NonNull ImageCaptureException exception) {
                        Log.e(TAG, "capturePhoto: " + exception.getMessage());
                    }
                }
        );
    }

    @NonNull
    @Override
    public Lifecycle getLifecycle() {
        return lifecycleRegistry;
    }

    interface CameraCallback {
        void onCompleted(Exception e, String filename);
    }

    interface CameraStartedCallback {
        void onCameraStarted();
    }
}
