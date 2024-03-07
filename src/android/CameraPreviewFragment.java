package com.spoon.simplecamerapreview;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Point;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraMetadata;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.util.Log;
import android.util.Size;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.RelativeLayout;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.annotation.OptIn;
import androidx.camera.camera2.interop.Camera2CameraInfo;
import androidx.camera.camera2.interop.ExperimentalCamera2Interop;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraInfo;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.FallbackStrategy;
import androidx.camera.video.Quality;
import androidx.camera.video.QualitySelector;
import androidx.camera.video.Recorder;
import androidx.camera.video.Recording;
import androidx.camera.video.VideoCapture;
import androidx.camera.video.VideoRecordEvent;
import androidx.camera.view.PreviewView;
import androidx.core.app.ActivityCompat;
import androidx.core.content.ContextCompat;
import androidx.exifinterface.media.ExifInterface;
import androidx.fragment.app.Fragment;

import com.google.common.util.concurrent.ListenableFuture;

import org.json.JSONException;
import org.json.JSONObject;

import java.io.File;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;
import java.util.concurrent.Executor;
import java.util.concurrent.Executors;
import java.util.stream.Collectors;

import android.content.ContentValues;
import android.provider.MediaStore;
import android.widget.Toast;

import androidx.camera.video.MediaStoreOutputOptions;

import java.text.SimpleDateFormat;
import java.util.Locale;

interface CameraCallback {
    void onCompleted(Exception err, String nativePath);
}

interface CameraStartedCallback {
    void onCameraStarted(Exception err);
}

interface TorchCallback {
    void onEnabled(Exception err);
}

interface HasFlashCallback {
    void onResult(boolean result);
}

public class CameraPreviewFragment extends Fragment {

    private PreviewView viewFinder;
    private Preview preview = null;
    private ImageCapture imageCapture;
    Recording recording = null;
    ProcessCameraProvider cameraProvider = null;
    CameraSelector cameraSelector = null;
    private Camera camera;
    private CameraStartedCallback startCameraCallback;
    private Location location;
    private int direction;
    private int targetSize;
    private boolean torchActivated = false;

    private static float ratio = (4 / (float) 3);
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

    public void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());

        try {
            cameraProvider = cameraProviderFuture.get();
        } catch (ExecutionException | InterruptedException e) {
            Log.e(TAG, "startCamera: " + e.getMessage());
            e.printStackTrace();
            startCameraCallback.onCameraStarted(new Exception("Unable to start camera"));
            return;
        }

        if (cameraSelector == null) {
            cameraSelector = new CameraSelector.Builder()
                    .requireLensFacing(direction)
                    .build();
        }

        Size targetResolution = null;
        if (targetSize > 0) {
            targetResolution = CameraPreviewFragment.calculateResolution(getContext(), targetSize);
        }

        preview = new Preview.Builder().build();
        imageCapture = new ImageCapture.Builder()
                .setTargetResolution(targetResolution)
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

    public static Size calculateResolution(Context context, int targetSize) {
        Size calculatedSize;
        if (getScreenOrientation(context) == Configuration.ORIENTATION_PORTRAIT) {
            calculatedSize = new Size((int) ((float) targetSize / ratio), targetSize);
        } else {
            calculatedSize = new Size(targetSize, (int) ((float) targetSize / ratio));
        }
        return calculatedSize;
    }

    private static int getScreenOrientation(Context context) {
        Display display = ((WindowManager) context.getSystemService(Context.WINDOW_SERVICE)).getDefaultDisplay();
        Point pointSize = new Point();
        display.getSize(pointSize);
        int orientation;
        if (pointSize.x < pointSize.y) {
            orientation = Configuration.ORIENTATION_PORTRAIT;
        } else {
            orientation = Configuration.ORIENTATION_LANDSCAPE;
        }
        return orientation;
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

    public void hasFlash(HasFlashCallback hasFlashCallback) {
        hasFlashCallback.onResult(camera.getCameraInfo().hasFlashUnit());
    }

    @OptIn(markerClass = ExperimentalCamera2Interop.class)
    public void recordVideo(boolean useFlash, CameraCallback takePictureCallback) {
        if (recording != null) {
            recording.stop();
            return;
        }
        QualitySelector qualitySelector = QualitySelector.fromOrderedList(
                Arrays.asList(Quality.UHD, Quality.FHD, Quality.HD, Quality.SD),
                FallbackStrategy.lowerQualityOrHigherThan(Quality.SD));
        List<CameraInfo> cameraInfos = cameraProvider.getAvailableCameraInfos();
        List<CameraInfo> backCameraInfos = new ArrayList<>();

        for (CameraInfo info : cameraInfos) {
            Integer lensFacing = Camera2CameraInfo.from(info).getCameraCharacteristic(CameraCharacteristics.LENS_FACING);
            if (lensFacing != null && lensFacing == CameraMetadata.LENS_FACING_BACK) {
                backCameraInfos.add(info);
            }
        }

        if (!backCameraInfos.isEmpty()) {
            List<Quality> supportedQualities = QualitySelector.getSupportedQualities(backCameraInfos.get(0));
            if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.N) {
                List<Quality> filteredQualities = Arrays.asList(Quality.UHD, Quality.FHD, Quality.HD, Quality.SD)
                        .stream()
                        .filter(supportedQualities::contains)
                        .collect(Collectors.toList());
            }
        }

        // Assuming cameraProvider, cameraExecutor, qualitySelector, and preview are already defined
        Executor cameraExecutor = Executors.newSingleThreadExecutor();
        Recorder recorder = new Recorder.Builder()
                .setExecutor(cameraExecutor)
                .setQualitySelector(qualitySelector)
                .build();

        VideoCapture<Recorder> videoCapture = VideoCapture.withOutput(recorder);

        this.getActivity().runOnUiThread(() -> {
            try {
                // Bind use cases to camera
                cameraProvider.unbindAll();
                cameraProvider.bindToLifecycle(
                        this, CameraSelector.DEFAULT_BACK_CAMERA, preview, videoCapture);
            } catch (Exception exc) {
                Log.e(TAG, "Use case binding failed", exc);
            }
        });


        String name = "CameraX-recording-" +
                new SimpleDateFormat("dd/mm/yyy", Locale.US)
                        .format(System.currentTimeMillis()) + ".mp4";
        ContentValues contentValues = new ContentValues();
        contentValues.put(MediaStore.Video.Media.DISPLAY_NAME, name);

        MediaStoreOutputOptions mediaStoreOutput = new MediaStoreOutputOptions.Builder(this.getContext().getContentResolver(),
                MediaStore.Video.Media.EXTERNAL_CONTENT_URI)
                .setContentValues(contentValues)
                .build();

// 2. Configure Recorder and Start recording to mediaStoreOutput
        if (ActivityCompat.checkSelfPermission(this.getContext(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this.getActivity(), new String[]{Manifest.permission.RECORD_AUDIO}, 200);
        }

        recording = videoCapture.getOutput()
                .prepareRecording(this.getContext().getApplicationContext(), mediaStoreOutput)
                .withAudioEnabled()
                .start(ContextCompat.getMainExecutor(this.getContext()), videoRecordEvent -> {
                    if (videoRecordEvent instanceof VideoRecordEvent.Start) {
                        // Recording has started
                    } else if (videoRecordEvent instanceof VideoRecordEvent.Finalize) {
                        VideoRecordEvent.Finalize finalizeEvent = (VideoRecordEvent.Finalize) videoRecordEvent;
                        if (finalizeEvent.hasError()) {
                            // Handle the error
                            int errorCode = finalizeEvent.getError();
                            Throwable errorCause = finalizeEvent.getCause();
                            Log.e(TAG, "Video recording error: " + errorCode, errorCause);
                        } else {
                            // Handle video saved
                            Uri savedUri = finalizeEvent.getOutputResults().getOutputUri();
                            Log.d(TAG, "Video saved to: " + savedUri);
                            Toast.makeText(this.getContext(), "Video stop" + savedUri, Toast.LENGTH_LONG).show();
                        }
                    }
                    // Other event types can be handled if needed
                });
        Toast.makeText(this.getContext(), "Video started" , Toast.LENGTH_LONG).show();
        takePictureCallback.onCompleted(null, "test.jpg");
    }

    private boolean hasRequiredPermissions() {
        return ActivityCompat.checkSelfPermission(
                this.getContext(),
                Manifest.permission.CAMERA
        ) == PackageManager.PERMISSION_GRANTED &&
                ActivityCompat.checkSelfPermission(
                        this.getContext(),
                        Manifest.permission.RECORD_AUDIO
                ) == PackageManager.PERMISSION_GRANTED;
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
