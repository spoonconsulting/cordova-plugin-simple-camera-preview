import { Component, EventEmitter, OnInit, Output } from '@angular/core';
import { ToastController } from '@ionic/angular';

declare var cordova: any; 
declare var SimpleCameraPreview: any; 

@Component({
  selector: 'app-camera',
  templateUrl: './camera.component.html',
  styleUrls: ['./camera.component.scss'],
})

export class CameraComponent  implements OnInit {
  @Output() toastMessageEmitter: EventEmitter<string> = new EventEmitter<string>();
  isToastOpen = false;
  toastMessage: string = '';
  constructor(private toastController: ToastController) {}

  ngOnInit() {
    document.addEventListener('deviceready', this.onDeviceReady.bind(this), false);
  }

  onDeviceReady() {
    const cameraSize = this.getCameraSize();
      if (typeof cordova !== 'undefined' && typeof SimpleCameraPreview !== 'undefined') {
          const params = {           
          targetSize: 1024,
          direction: 'back',
          ...cameraSize,  
        };
        this.enableCamera(params);
      } else {
        console.warn('SimpleCameraPreview plugin not available. This feature is only supported on mobile devices.');
      }   
      const captureButton = document.getElementById('capturePicture');
        if (captureButton) {
          captureButton.addEventListener('click', () => this.capturePicture());
        }
      }

    enableCamera(params:any){
      try {
        SimpleCameraPreview.setOptions(params);
        SimpleCameraPreview.enable(params, () => {
          document.body.classList.add('camera-preview');
        }, (err: any) => {
          console.error('Error enabling camera:', err);
        });
      } catch (error) {
        console.error('Error setting camera options:', error);
      }
    }
    
    capturePicture() {
      const options = {
        flash: true,
      };
      if (typeof SimpleCameraPreview !== 'undefined') {
        SimpleCameraPreview.capture(options, (imageNativePath: string) => {
          this.displayToastMesssage(imageNativePath);
          //implements capture and save logic here...
          
        }, (err: any) => {
          console.error('Error capturing image:', err);
        });
      } else {
        console.warn('SimpleCameraPreview plugin not available.');
      }
    }

    displayToastMesssage(imagePath: string){
      const message = `Picture taken at: ${imagePath}`;
      this.toastMessageEmitter.emit(message); 
      this.toastMessage = `Picture taken at: ${imagePath}`;
      this.showToast('top');
    }
    
    getCameraSize() {
      let height;
      let width;
      const ratio = 4 / 3;
      const min = Math.min(window.innerWidth, window.innerHeight);

      [width, height] = [min, Math.round(min * ratio)];
      if (this.isLandscape()) {
        [width, height] = [height, width];
      }

      return {
        x: (window.innerWidth - width) / 2,
        y: (window.innerHeight - height) / 2,
        width,
        height,
      };
    }

    async showToast(position: 'top' | 'middle' | 'bottom') {
      const toast = await this.toastController.create({
        message: this.toastMessage,
        duration: 3000,
        position: position,
      });
      await toast.present();
    }

    isLandscape() {
      return Math.abs(window.orientation % 180) === 90;
    }
}
