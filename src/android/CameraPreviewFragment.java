package com.spoon.simplecamerapreview;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Point;
import android.location.Location;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.util.Log;
import android.util.Size;
import android.view.Display;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.view.WindowManager;
import android.widget.RelativeLayout;
import android.widget.Toast;

import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.FileOutputOptions;
import androidx.camera.video.MediaStoreOutputOptions;
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
import java.util.UUID;
import java.util.concurrent.ExecutionException;

interface CameraCallback {
    void onCompleted(Exception err, String nativePath);
}

interface VideoCallback {
    void onStart(Exception err,Boolean recording, String nativePath);
    void onStop(Exception err, Boolean recording, String nativePath);
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
    private Preview preview;
    private ImageCapture imageCapture;
    private VideoCapture<Recorder> videoCapture;
    Recording recording = null;
    ProcessCameraProvider cameraProvider = null;
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


//    public void startCamera() {
//        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());
//        cameraProviderFuture.addListener(() -> {
//            try {
//                // Used to bind the lifecycle of cameras to the lifecycle owner
//                ProcessCameraProvider cameraProvider = cameraProviderFuture.get();
//
//                Recorder recorder = new Recorder.Builder()
//                        .setQualitySelector(QualitySelector.from(Quality.HIGHEST))
//                        .build();
//                videoCapture = VideoCapture.withOutput(recorder);
//                imageCapture = new ImageCapture.Builder().build();
//
//                // Select back camera as a default
//                CameraSelector cameraSelector = CameraSelector.DEFAULT_BACK_CAMERA;
//                try {
//                    // Unbind use cases before rebinding
//                    cameraProvider.unbindAll();
//                    // Bind use cases to camera
//                    cameraProvider.bindToLifecycle(
//                            this, cameraSelector, preview, imageCapture, videoCapture);
//                } catch (Exception exc) {
//                    Log.e(TAG, "Use case binding failed", exc);
//                }
//            } catch (Exception e) {
//                e.printStackTrace();
//            }
//        }, ContextCompat.getMainExecutor(this.getContext()));
//        if (startCameraCallback != null) {
//            startCameraCallback.onCameraStarted(null);
//        }
//    }
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

        CameraSelector cameraSelector = new CameraSelector.Builder()
                .requireLensFacing(direction)
                .build();

        Size targetResolution = null;
        if (targetSize > 0) {
            targetResolution = CameraPreviewFragment.calculateResolution(getContext(), targetSize);
        }

        Recorder recorder = new Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.HD))
                .build();
        videoCapture = VideoCapture.withOutput(recorder);


        preview = new Preview.Builder().build();
        imageCapture = new ImageCapture.Builder()
                .setTargetResolution(targetResolution)
                .build();
        this.getActivity().runOnUiThread(() -> {
            try {
                cameraProvider.unbindAll();
                camera = cameraProvider.bindToLifecycle(
                        this,
                        cameraSelector,
                        preview,
                        imageCapture,
                        videoCapture
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
                    imageCapture,
                    videoCapture
            );
            }

        });

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

    public void captureVideo(boolean useFlash, VideoCallback videoCallback) {
       if (torchActivated) {
           useFlash = true;
       } else {
           camera.getCameraControl().enableTorch(useFlash);
       }
        if (recording != null) {
            Toast.makeText(this.getContext(), "Video not null" , Toast.LENGTH_LONG).show();

            recording.stop();
            return;
        }
        UUID uuid = UUID.randomUUID();

        String filename = uuid.toString() + ".mp4";
        ContentValues contentValues = new ContentValues();
        contentValues.put(MediaStore.Video.Media.DISPLAY_NAME, filename);
// 2. Configure Recorder and Start recording to the mediaStoreOutput.
        if (ActivityCompat.checkSelfPermission(this.getContext(), Manifest.permission.RECORD_AUDIO) != PackageManager.PERMISSION_GRANTED) {
            ActivityCompat.requestPermissions(this.getActivity(), new String[]{Manifest.permission.RECORD_AUDIO}, 200);
        }
        File videoFile = new File(
                getContext().getApplicationContext().getFilesDir(),
                filename
        );

// Configure the recorder to save the video to the specified file
        FileOutputOptions outputOptions = new FileOutputOptions.Builder(videoFile).build();

        recording = videoCapture.getOutput()
                .prepareRecording(this.getContext().getApplicationContext(), outputOptions)
                .withAudioEnabled()
                .start(ContextCompat.getMainExecutor(this.getContext()), videoRecordEvent -> {
                    if (videoRecordEvent instanceof VideoRecordEvent.Start) {
                        videoCallback.onStart(null,true, null);
                        Toast.makeText(this.getContext(), "Video start" , Toast.LENGTH_LONG).show();

                    } else if (videoRecordEvent instanceof VideoRecordEvent.Finalize) {
                        Toast.makeText(this.getContext(), "Video fin" , Toast.LENGTH_LONG).show();
                        VideoRecordEvent.Finalize finalizeEvent = (VideoRecordEvent.Finalize) videoRecordEvent;
                        if (finalizeEvent.hasError()) {
                            // Handle the error
                            int errorCode = finalizeEvent.getError();
                            Throwable errorCause = finalizeEvent.getCause();
                            Log.e(TAG, "Video recording error: " + errorCode, errorCause);
                        } else {
                            // Handle video saved
                            videoCallback.onStop(null, false, Uri.fromFile(videoFile).toString());
                            Uri savedUri = finalizeEvent.getOutputResults().getOutputUri();
                            Log.d(TAG, "Video saved to: " + savedUri);
                            Toast.makeText(this.getContext(), "Video stop" + savedUri, Toast.LENGTH_LONG).show();
                            recording = null;
                        }
                    }
                    // Other event types can be handled if needed
                });

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
