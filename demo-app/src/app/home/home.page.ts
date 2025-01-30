import { Component, Inject, OnInit } from '@angular/core';
import { Router } from '@angular/router';

@Component({
  selector: 'app-home',
  templateUrl: 'home.page.html',
  styleUrls: ['home.page.scss'],
  standalone: false,
})

export class HomePage {

  isToastOpen = false;
  toastMessage: string = '';

  constructor(private route: Router) {}
   handleToastMessage(message: string) {
    this.toastMessage = message;
    this.isToastOpen = true;  
  }

  setToastOpen(isOpen: boolean) {
    this.isToastOpen = isOpen;
  }

}
