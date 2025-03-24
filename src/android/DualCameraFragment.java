public class DualCameraFragment extends Fragment {

    private PreviewView previewViewPrimary;
    private PreviewView previewViewSecondary;
    private ImageCapture imageCapturePrimary;
    private ImageCapture imageCaptureSecondary;
    private ProcessCameraProvider cameraProvider;
    private ExecutorService cameraExecutor;

    @Nullable
    @Override
    public View onCreateView(@NonNull LayoutInflater inflater, @Nullable ViewGroup container, @Nullable Bundle savedInstanceState) {
        FrameLayout root = new FrameLayout(getContext());

        previewViewPrimary = new PreviewView(getContext());
        previewViewPrimary.setLayoutParams(new FrameLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.MATCH_PARENT
        ));
        root.addView(previewViewPrimary);

        previewViewSecondary = new PreviewView(getContext());
        FrameLayout.LayoutParams secondaryParams = new FrameLayout.LayoutParams(400, 600);
        secondaryParams.setMargins(40, 40, 0, 0);
        previewViewSecondary.setLayoutParams(secondaryParams);
        root.addView(previewViewSecondary);

        cameraExecutor = Executors.newSingleThreadExecutor();

        startCamera();

        return root;
    }

    private void startCamera() {
        ListenableFuture<ProcessCameraProvider> cameraProviderFuture = ProcessCameraProvider.getInstance(getContext());

        cameraProviderFuture.addListener(() -> {
            try {
                cameraProvider = cameraProviderFuture.get();
                setupConcurrentCamera();
            } catch (ExecutionException | InterruptedException e) {
                Log.e("DualCameraFragment", "CameraX init failed", e);
            }
        }, ContextCompat.getMainExecutor(getContext()));
    }

    private void setupConcurrentCamera() {
        cameraProvider.unbindAll();

        CameraSelector primaryCameraSelector = null;
        CameraSelector secondaryCameraSelector = null;

        for (List<CameraInfo> cameraInfos : cameraProvider.getAvailableConcurrentCameraInfos()) {
            primaryCameraSelector = cameraInfos.stream()
                    .filter(info -> info.getLensFacing() == CameraSelector.LENS_FACING_BACK)
                    .findFirst().map(CameraInfo::getCameraSelector).orElse(null);

            secondaryCameraSelector = cameraInfos.stream()
                    .filter(info -> info.getLensFacing() == CameraSelector.LENS_FACING_FRONT)
                    .findFirst().map(CameraInfo::getCameraSelector).orElse(null);

            if (primaryCameraSelector != null && secondaryCameraSelector != null) break;
        }

        if (primaryCameraSelector == null || secondaryCameraSelector == null) {
            Log.e("DualCamera", "Concurrent dual camera not supported on this device.");
            return;
        }

        Preview primaryPreview = new Preview.Builder().build();
        Preview secondaryPreview = new Preview.Builder().build();

        imageCapturePrimary = new ImageCapture.Builder()
                .setTargetRotation(Surface.ROTATION_0)
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build();

        imageCaptureSecondary = new ImageCapture.Builder()
                .setTargetRotation(Surface.ROTATION_0)
                .setTargetAspectRatio(AspectRatio.RATIO_4_3)
                .build();

        primaryPreview.setSurfaceProvider(previewViewPrimary.getSurfaceProvider());
        secondaryPreview.setSurfaceProvider(previewViewSecondary.getSurfaceProvider());

        UseCaseGroup primaryUseCaseGroup = new UseCaseGroup.Builder()
                .addUseCase(primaryPreview)
                .addUseCase(imageCapturePrimary)
                .build();

        UseCaseGroup secondaryUseCaseGroup = new UseCaseGroup.Builder()
                .addUseCase(secondaryPreview)
                .addUseCase(imageCaptureSecondary)
                .build();

        ConcurrentCamera concurrentCamera = cameraProvider.bindToLifecycle(
                getViewLifecycleOwner(),
                Arrays.asList(
                        new ConcurrentCamera.SingleCameraConfig(
                                primaryCameraSelector, primaryUseCaseGroup,
                                new CompositionSettings.Builder()
                                        .setAlpha(1.0f)
                                        .setOffset(0f, 0f)
                                        .setScale(1f, 1f)
                                        .build(),
                                getViewLifecycleOwner()
                        ),
                        new ConcurrentCamera.SingleCameraConfig(
                                secondaryCameraSelector, secondaryUseCaseGroup,
                                new CompositionSettings.Builder()
                                        .setAlpha(1.0f)
                                        .setOffset(0.7f, -0.7f)
                                        .setScale(0.3f, 0.3f)
                                        .build(),
                                getViewLifecycleOwner()
                        )
                )
        );

        Log.d("DualCamera", "Dual camera setup complete");
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        cameraExecutor.shutdown();
    }
}
