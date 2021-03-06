package com.spoon.simplecamerapreview;

import android.content.ContextWrapper;
import android.location.Location;
import android.os.Bundle;
import android.app.Fragment;
import android.view.LayoutInflater;
import android.view.View;
import android.view.ViewGroup;
import android.widget.RelativeLayout;
import com.otaliastudios.cameraview.CameraOptions;
import java.io.File;
import java.util.UUID;
import com.otaliastudios.cameraview.CameraListener;
import com.otaliastudios.cameraview.CameraView;
import com.otaliastudios.cameraview.PictureResult;
import com.otaliastudios.cameraview.controls.Audio;
import com.otaliastudios.cameraview.controls.Flash;


interface CameraCallBack {
    void onCompleted(Exception err, String fileName);
}

interface CameraStartedCallBack {
    void onCameraStarted();
}

public class CameraPreviewFragment extends Fragment {
    CameraView camera;
    CameraCallBack capturePictureCallback;
    CameraStartedCallBack startCameraCallback;

    public CameraPreviewFragment(){

    }


    public CameraPreviewFragment(CameraStartedCallBack cb){
        this.startCameraCallback = cb;
    }

    @Override
    public View onCreateView(LayoutInflater inflater, ViewGroup container, Bundle savedInstanceState) {
        RelativeLayout containerView = new RelativeLayout(getActivity());
        RelativeLayout.LayoutParams containerLayoutParams = new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_TOP);
        containerLayoutParams.addRule(RelativeLayout.ALIGN_PARENT_START);
        containerView.setLayoutParams(containerLayoutParams);
        camera = new CameraView(getActivity());
        camera.setAudio(Audio.OFF);
        camera.addCameraListener(new CameraListener() {
            @Override
            public void onCameraOpened(CameraOptions options) {
                if (startCameraCallback != null)
                    startCameraCallback.onCameraStarted();
            }
            @Override
            public void onPictureTaken(PictureResult result) {
                UUID uuid = UUID.randomUUID();
                File file = new File(new ContextWrapper(getActivity().getBaseContext()).getFilesDir(), uuid.toString() + ".jpg");
                result.toFile(file, (File mfile)->{
                    if (mfile == null){
                        capturePictureCallback.onCompleted(new Exception("unable to save image"), null);
                    }
                    capturePictureCallback.onCompleted(null, mfile.getName());
                });

            }
        });
        camera.setLayoutParams(new RelativeLayout.LayoutParams(RelativeLayout.LayoutParams.MATCH_PARENT, RelativeLayout.LayoutParams.MATCH_PARENT));
        containerView.addView(camera);
        return containerView;
    }

    @Override
    public void onResume() {
        super.onResume();
        camera.open();
    }

    @Override
    public void onPause() {
        super.onPause();
        camera.close();
    }

    @Override
    public void onDestroy() {
        super.onDestroy();
        camera.destroy();
    }

    public void setLocation(Location loc){
        if (camera != null && loc != null)
            camera.setLocation(loc);
    }

    public void disableCamera() {
        camera.close();
    }

    public void takePicture(Boolean useFlash, CameraCallBack takePictureCallback) {
        this.capturePictureCallback = takePictureCallback;
        camera.setFlash(useFlash ? Flash.ON : Flash.OFF);
        camera.takePicture();
    }

}
