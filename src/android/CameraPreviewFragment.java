package com.spoon.simplecamerapreview;

import android.content.ContextWrapper;
import android.os.Bundle;
import android.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import com.wonderkiln.camerakit.CameraKit;
import com.wonderkiln.camerakit.CameraKitImage;
import com.wonderkiln.camerakit.CameraView;
import java.io.File;
import java.io.FileOutputStream;
import java.util.UUID;

interface CameraCallBack {
    void onCompleted(Exception err, String fileName);
}

public class CameraPreviewFragment extends Fragment {
    CameraView camera;

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        RelativeLayout containerView = new RelativeLayout(getActivity());
        RelativeLayout.LayoutParams containerLayoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_START);
        containerView.setLayoutParams(containerLayoutParams);
        camera = new CameraView(getActivity());
        camera.setFocus(CameraKit.Constants.FOCUS_CONTINUOUS);
        camera.setLayoutParams(new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT));
        containerView.addView(camera);
        return containerView;
    }

    @Override
    public void onResume() {
        super.onResume();
        camera.start();
    }

    @Override
    public void onPause() {
        camera.stop();
        super.onPause();
    }

    public void disableCamera() {
        camera.stop();
    }

    public void takePicture(Boolean useFlash, CameraCallBack takePictureCallback) {
        camera.setFlash(useFlash ? CameraKit.Constants.FLASH_ON : CameraKit.Constants.FLASH_OFF);
        camera.captureImage((CameraKitImage cameraKitImage) -> {
            try {
                UUID uuid = UUID.randomUUID();
                File file = new File(new ContextWrapper(getActivity().getBaseContext()).getFilesDir(), uuid.toString() + ".jpg");
                file.createNewFile();
                FileOutputStream fileOutputStream = new FileOutputStream(file);
                fileOutputStream.write(cameraKitImage.getJpeg());
                fileOutputStream.flush();
                fileOutputStream.close();
                takePictureCallback.onCompleted(null, file.getName());
            } catch (Exception e) {
                takePictureCallback.onCompleted(e, null);
            }
        });
    }
}
