package com.spoon.simplecamerapreview;

import android.Manifest;
import android.annotation.SuppressLint;
import android.content.ContentValues;
import android.content.Context;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.Point;
import android.hardware.camera2.CameraCharacteristics;
import android.location.Location;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Bundle;
import android.provider.MediaStore;
import android.os.Handler;
import android.os.Looper;
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
import androidx.camera.camera2.internal.Camera2CameraInfoImpl;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraInfo;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.core.ResolutionInfo;
import androidx.camera.lifecycle.ProcessCameraProvider;
import androidx.camera.video.FileOutputOptions;
import androidx.camera.video.PendingRecording;
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
import java.io.FileOutputStream;
import java.io.IOException;
import java.util.ArrayList;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

interface CameraCallback {
    void onCompleted(Exception err, String nativePath);
}

interface VideoCallback {
    void onStart(Boolean recording, String nativePath);
    void onStop(Boolean recording, String nativePath, String thumbnail);
    void onError(String errMessage);
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

interface CameraSwitchedCallback {
    void onSwitch(boolean result);
}

interface HasUltraWideCameraCallback {
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
    private String lens;

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
        try {
            this.lens = options.getString("lens");
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
        setUpCamera(lens,cameraProvider);

        preview.setSurfaceProvider(viewFinder.getSurfaceProvider());

        if (startCameraCallback != null) {
            startCameraCallback.onCameraStarted(null);
        }
    }

    @SuppressLint("RestrictedApi")
    public void deviceHasUltraWideCamera(HasUltraWideCameraCallback hasUltraWideCameraCallback) {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());
        ProcessCameraProvider cameraProvider = null;

        try {
            cameraProvider = cameraProviderFuture.get();
        } catch (ExecutionException | InterruptedException e) {
            Log.e(TAG, "Error occurred while trying to obtain the camera provider: " + e.getMessage());
            e.printStackTrace();
            hasUltraWideCameraCallback.onResult(false);
            return;
        }
        List<CameraInfo> cameraInfos = cameraProvider.getAvailableCameraInfos();

        boolean defaultCamera = false;
        boolean ultraWideCamera = false;
        List<Camera2CameraInfoImpl> backCameras = new ArrayList<>();
        for (CameraInfo cameraInfo : cameraInfos) {
            if (cameraInfo instanceof Camera2CameraInfoImpl) {
                Camera2CameraInfoImpl camera2CameraInfo = (Camera2CameraInfoImpl) cameraInfo;
                if (camera2CameraInfo.getLensFacing() == CameraSelector.LENS_FACING_BACK) {
                    backCameras.add(camera2CameraInfo);
                }
            }
        }

        for (Camera2CameraInfoImpl backCamera : backCameras) {
            if (backCamera.getCameraCharacteristicsCompat().get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)[0] >= 2.4) {
                defaultCamera = true;
            } else if( backCamera.getCameraCharacteristicsCompat().get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)[0] < 2.4) {
                ultraWideCamera = true;
            }
        }

        hasUltraWideCameraCallback.onResult(defaultCamera == true && ultraWideCamera == true);
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

    public void startVideoCapture(VideoCallback videoCallback, boolean recordWithAudio) {
        if (recording != null) {
            recording.stop();
            recording = null;
            return;
        }

        UUID uuid = UUID.randomUUID();
        String filename = uuid.toString() + ".mp4";

        File videoFile = new File(
                getContext().getFilesDir(),
                filename
        );

        FileOutputOptions outputOptions = new FileOutputOptions.Builder(videoFile).build();

        final Handler handler = new Handler(Looper.getMainLooper());
        handler.postDelayed(new Runnable() {
            @Override
            public void run() {
                stopVideoCapture();
            }
        }, 30000);

        PendingRecording pendingRecording = videoCapture.getOutput()
                .prepareRecording(this.getContext().getApplicationContext(), outputOptions);
        if (recordWithAudio) {
            try {
                pendingRecording.withAudioEnabled();
            } catch (SecurityException e) {
                videoCallback.onError(e.getMessage());
            }
        }
        recording = pendingRecording.start(ContextCompat.getMainExecutor(this.getContext()), videoRecordEvent -> {
            if (videoRecordEvent instanceof VideoRecordEvent.Start) {
                videoCallback.onStart(true, null);
            } else if (videoRecordEvent instanceof VideoRecordEvent.Finalize) {
                VideoRecordEvent.Finalize finalizeEvent = (VideoRecordEvent.Finalize) videoRecordEvent;
                handler.removeCallbacksAndMessages(null);
                if (finalizeEvent.hasError()) {
                    int errorCode = finalizeEvent.getError();
                    Throwable errorCause = finalizeEvent.getCause();
                    videoCallback.onError(errorCode + " " + errorCause);
                } else {
                    videoCallback.onStop(false, Uri.fromFile(videoFile).toString(), generateVideoThumbnail(videoFile));
                    Uri savedUri = finalizeEvent.getOutputResults().getOutputUri();
                }
                recording = null;
            }
        });
    }

    public void stopVideoCapture() {
        if (recording != null) {
            recording.stop();
            recording = null;
        }
    }

    public String generateVideoThumbnail(File videoFile) {
        String thumbnailUri = "";
        if (getContext() == null) { return thumbnailUri; }

        String filename = "video_thumb_" + UUID.randomUUID().toString() + ".jpg";
        File thumbnail = new File(getContext().getFilesDir(), filename);
        Bitmap bitmap = null;
        Size size = null;

        if (this.targetSize > 0) {
            size = calculateResolution(getContext(), this.targetSize);
        } else {
            ResolutionInfo info = imageCapture.getResolutionInfo();
            if (info == null) { return thumbnailUri; }
            
            size = info.getResolution();
        }

        if (android.os.Build.VERSION.SDK_INT >= android.os.Build.VERSION_CODES.Q) {
            try {
                bitmap = ThumbnailUtils.createVideoThumbnail(videoFile, size, null);
            } catch (IOException e) {
                bitmap = generateColoredBitmap(new Size(500, 500), Color.DKGRAY);
            }
        } else {
            bitmap = generateColoredBitmap(new Size(500, 500), Color.DKGRAY);
        }

        try (FileOutputStream out = new FileOutputStream(thumbnail)) {
            bitmap.compress(Bitmap.CompressFormat.JPEG, 80, out);
            out.flush();
        } catch (Exception e) {
            return thumbnailUri;
        }

        thumbnailUri = Uri.fromFile(thumbnail).toString();
        return thumbnailUri;
    }


    public Bitmap generateColoredBitmap(Size size, int color) {
        Bitmap bitmap = Bitmap.createBitmap(size.getWidth(), size.getHeight(), Bitmap.Config.ARGB_8888);
        Canvas canvas = new Canvas(bitmap);
        canvas.drawColor(color);

        return bitmap;
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


    public void switchCameraTo(String device, CameraSwitchedCallback cameraSwitchedCallback) {
        Handler mainHandler = new Handler(Looper.getMainLooper());
        mainHandler.post(() -> {
            ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getActivity());
            ProcessCameraProvider cameraProvider = null;
            try {
                cameraProvider = cameraProviderFuture.get();
            } catch (ExecutionException | InterruptedException e) {
                Log.e(TAG, "Error occurred while trying to obtain the camera provider: " + e.getMessage());
                e.printStackTrace();
                cameraSwitchedCallback.onSwitch(false);
                return;
            }

            setUpCamera(device,cameraProvider);

            preview.setSurfaceProvider(viewFinder.getSurfaceProvider());
            cameraSwitchedCallback.onSwitch(true);
        });
    }
    
    @SuppressLint("RestrictedApi")
    public void setUpCamera(String lens, ProcessCameraProvider cameraProvider) {
        CameraSelector cameraSelector;
        if (lens != null && lens.equals("wide")) {
            cameraSelector = new CameraSelector.Builder()
                    .addCameraFilter(cameraInfos -> {
                        List<Camera2CameraInfoImpl> backCameras = new ArrayList<>();
                        for (CameraInfo cameraInfo : cameraInfos) {
                            if (cameraInfo instanceof Camera2CameraInfoImpl) {
                                Camera2CameraInfoImpl camera2CameraInfo = (Camera2CameraInfoImpl) cameraInfo;
                                if (camera2CameraInfo.getLensFacing() == CameraSelector.LENS_FACING_BACK) {
                                    backCameras.add(camera2CameraInfo);
                                }
                            }
                        }

                        Camera2CameraInfoImpl selectedCamera = Collections.min(backCameras, (o1, o2) -> {
                            Float focalLength1 = o1.getCameraCharacteristicsCompat().get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)[0];
                            Float focalLength2 = o2.getCameraCharacteristicsCompat().get(CameraCharacteristics.LENS_INFO_AVAILABLE_FOCAL_LENGTHS)[0];
                            return Float.compare(focalLength1, focalLength2);
                        });

                        if (selectedCamera != null) {
                            return Collections.singletonList(selectedCamera);
                        } else {
                            return cameraInfos;
                        }
                    })
                    .build();
        } else {
            cameraSelector = new CameraSelector.Builder()
                    .requireLensFacing(direction)
                    .build();
        }

        Size targetResolution = null;
        if (targetSize > 0) {
            targetResolution = CameraPreviewFragment.calculateResolution(getContext(), targetSize);
        }

        Recorder recorder = new Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.LOWEST))
                .build();
        videoCapture = VideoCapture.withOutput(recorder);


        preview = new Preview.Builder().build();
        imageCapture = new ImageCapture.Builder()
                .setTargetResolution(targetResolution)
                .build();
        cameraProvider.unbindAll();
        try {
            camera = cameraProvider.bindToLifecycle(
                    getActivity(),
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
                    getActivity(),
                    cameraSelector,
                    preview,
                    imageCapture,
                    videoCapture
            );
        }
    }

    @Override
    public void onPause() {
        super.onPause();
        this.stopVideoCapture();
    }
}
