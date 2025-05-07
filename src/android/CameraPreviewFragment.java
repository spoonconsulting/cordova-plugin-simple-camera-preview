package com.spoon.simplecamerapreview;

import android.annotation.SuppressLint;
import android.content.Context;
import android.graphics.Bitmap;
import android.graphics.Canvas;
import android.graphics.Color;
import android.graphics.ImageFormat;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.hardware.camera2.params.StreamConfigurationMap;
import android.location.Location;
import android.media.ThumbnailUtils;
import android.net.Uri;
import android.os.Bundle;
import android.os.Handler;
import android.os.Looper;
import android.util.Log;
import android.util.Size;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import androidx.annotation.NonNull;
import androidx.annotation.Nullable;
import androidx.camera.camera2.internal.Camera2CameraInfoImpl;
import androidx.camera.core.AspectRatio;
import androidx.camera.core.Camera;
import androidx.camera.core.CameraInfo;
import androidx.camera.core.CameraSelector;
import androidx.camera.core.ImageCapture;
import androidx.camera.core.ImageCaptureException;
import androidx.camera.core.Preview;
import androidx.camera.core.ResolutionInfo;
import androidx.camera.core.resolutionselector.AspectRatioStrategy;
import androidx.camera.core.resolutionselector.ResolutionSelector;
import androidx.camera.core.resolutionselector.ResolutionStrategy;
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
import java.util.Arrays;
import java.util.Collections;
import java.util.List;
import java.util.UUID;
import java.util.concurrent.ExecutionException;

interface CameraCallback {
    void onCompleted(Exception err, String nativePath);
}

interface VideoCallback {
    void onStart(Boolean recording);
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
    private static final String TAG = "SimpleCameraPreview";
    private String lens;
    private double aspectRatio;
    private static final double ASPECT_RATIO_3_BY_4 = 1.3333;
    private static final double ASPECT_RATIO_9_BY_16 = 1.7777;
    private Size targetResolution = null;


    public CameraPreviewFragment() {

    }

    @SuppressLint("ValidFragment")
    public CameraPreviewFragment(JSONObject options, CameraStartedCallback cameraStartedCallback) {
        try {
            this.direction = options.getInt("direction");
        } catch (JSONException e) {
            e.printStackTrace();
            this.direction = CameraSelector.LENS_FACING_BACK;
        }
        try {
            this.targetSize = options.getInt("targetSize");
        } catch (JSONException e) {
            e.printStackTrace();
            this.targetSize = 0;
        }
        try {
            this.lens = options.getString("lens");
        } catch (JSONException e) {
            e.printStackTrace();
            this.lens = "default";
        }
        try {
            this.aspectRatio = options.getDouble("aspectRatio");
        } catch (JSONException e) {
            e.printStackTrace();
            this.aspectRatio = ASPECT_RATIO_3_BY_4;
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
        JSONObject options = new JSONObject();
        try {
            options.put("lens", lens);
        } catch (JSONException e) {
            startCameraCallback.onCameraStarted(new Exception("Unable to set the lens option"));
        }
        try {
            options.put("direction", direction);
        } catch (JSONException e) {
            startCameraCallback.onCameraStarted(new Exception("Unable to set the Direction option"));
        }

        setUpCamera(options, cameraProvider);
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

     public static Size calculateResolution(Context context, int desiredWidthPx, double aspectRatio) {
        int minWidthPx = 700;
        // get all supported JPEG output sizes
        Size[] supportedSizes = getSupportedResolutions(context, CameraSelector.LENS_FACING_BACK);

        // if none available, fall back to a simple ratioWidth:ratioHeight rectangle
        if (supportedSizes.length == 0) {
            int fallbackHeight = Math.round(
                    desiredWidthPx / (float) aspectRatio
            );
            return new Size(desiredWidthPx, fallbackHeight);
        }
        // collect only those sizes matching the exact ratio
         List<Size> matchingResolutions = new ArrayList<>();
         for (Size size : supportedSizes) {
             // Calculate the aspect ratio for the current resolution
             double calculatedAspectRatio = (double) size.getWidth() / size.getHeight();

             // Check if the calculated aspect ratio is close enough to the requested aspect ratio
             if (Math.abs(calculatedAspectRatio - (aspectRatio)) < 0.01 && size.getWidth() > minWidthPx) {
                 matchingResolutions.add(size);
             }
         }
         // if no exact matches, consider all supported sizes
        List<Size> candidateResolutions = matchingResolutions.isEmpty()
                ? Arrays.asList(supportedSizes)
                : matchingResolutions;

        // pick the one whose width is closest to desiredWidthPx
        Size bestMatch = candidateResolutions.get(0);
        int smallestDifference = Math.abs(bestMatch.getWidth() - desiredWidthPx);
        for (Size candidate : candidateResolutions) {
            int difference = Math.abs(candidate.getWidth() - desiredWidthPx);
            if (difference < smallestDifference) {
                smallestDifference = difference;
                bestMatch = candidate;
            }
        }
        return bestMatch;
    }

    public static Size[] getSupportedResolutions(Context context, int lensFacing) {
        try {
            CameraManager cameraManager = (CameraManager) context.getSystemService(Context.CAMERA_SERVICE);
            for (String cameraId : cameraManager.getCameraIdList()) {
                CameraCharacteristics characteristics = cameraManager.getCameraCharacteristics(cameraId);

                Integer facing = characteristics.get(CameraCharacteristics.LENS_FACING);
                if (facing != null && facing == lensFacing) {
                    StreamConfigurationMap map = characteristics.get(CameraCharacteristics.SCALER_STREAM_CONFIGURATION_MAP);
                    if (map != null) {
                        return map.getOutputSizes(ImageFormat.JPEG);
                    }
                }
            }
        } catch (CameraAccessException e) {
            e.printStackTrace();
        }
        return new Size[0];
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
        }
        try {
            camera.getCameraControl().enableTorch(torchOn).get();
            torchCallback.onEnabled(null);
        } catch (Exception e) {
            torchCallback.onEnabled(new Exception("Failed to switch " + (torchOn ? "on" : "off") + " torch: " + e.getMessage()));
            return;
        }

        torchActivated = torchOn;
    }

    public void hasFlash(HasFlashCallback hasFlashCallback) {
        hasFlashCallback.onResult(camera.getCameraInfo().hasFlashUnit());
    }

    public void startVideoCapture(VideoCallback videoCallback, boolean recordWithAudio, int videoDuration) {
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
        }, videoDuration);

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
                videoCallback.onStart(true);
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

        ResolutionInfo info = imageCapture.getResolutionInfo();
        if (info == null) { return thumbnailUri; }

        size = info.getResolution();
        if (this.targetSize > 0 && targetResolution != null) {
            size = targetResolution;
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

    public void switchCameraTo(JSONObject options, CameraSwitchedCallback cameraSwitchedCallback) {
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

            setUpCamera(options, cameraProvider);
            preview.setSurfaceProvider(viewFinder.getSurfaceProvider());
            cameraSwitchedCallback.onSwitch(true);
        });
    }

    @SuppressLint("RestrictedApi")
    public void setUpCamera(JSONObject options, ProcessCameraProvider cameraProvider){
        CameraSelector cameraSelector;
        try {
            lens = options.getString("lens");
        } catch (JSONException e) {
            lens = "default";
        }

        try {
            direction = options.getInt("direction");
        } catch (JSONException e) {
            direction = CameraSelector.LENS_FACING_BACK;
        }

        if (lens != null && lens.equals("wide") && direction != CameraSelector.LENS_FACING_FRONT) {
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

        targetResolution = calculateResolution(getContext(), targetSize, aspectRatio);

        Recorder recorder = new Recorder.Builder()
                .setQualitySelector(QualitySelector.from(Quality.LOWEST))
                .build();
        videoCapture = VideoCapture.withOutput(recorder);

        int cameraAspectRatio = calculateCameraAspect(aspectRatio);
        preview = new Preview.Builder().build();
        AspectRatioStrategy aspectRatioStrategy = new AspectRatioStrategy(
                cameraAspectRatio,
                AspectRatioStrategy.FALLBACK_RULE_AUTO
        );

        ResolutionStrategy resolutionStrategy = new ResolutionStrategy(
                targetResolution,
                ResolutionStrategy.FALLBACK_RULE_CLOSEST_HIGHER_THEN_LOWER
        );

        ResolutionSelector resolutionSelector = new ResolutionSelector.Builder()
                .setAspectRatioStrategy(aspectRatioStrategy)
                .setResolutionStrategy(resolutionStrategy)
                .build();

        imageCapture = new ImageCapture.Builder()
                .setResolutionSelector(resolutionSelector)
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

    private int calculateCameraAspect(double aspectRatio) {
        // Pick whichever constant is numerically closer to the requested ratio
        return Math.abs(aspectRatio - (ASPECT_RATIO_3_BY_4)) <= Math.abs(aspectRatio - (ASPECT_RATIO_9_BY_16))
                ? AspectRatio.RATIO_4_3
                : AspectRatio.RATIO_16_9;
    }

    @Override
    public void onPause() {
        super.onPause();
        this.stopVideoCapture();
    }
}
