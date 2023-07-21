# Reference design for RPi Camera FMC

## Description

This project demonstrates the Opsero [RPi Camera FMC](https://camerafmc.com/docs/rpi-camera-fmc/overview/) used to
connect 4x Raspberry Pi cameras (or compatible cameras) to one of the target FPGA/MPSoC boards listed below.

![RPi Camera FMC](https://www.fpgadeveloper.com/camera-fmc-connecting-mipi-cameras-to-fpgas/images/rpi-camera-fmc-pynq-zu-1.jpg "RPi Camera FMC")

The high level block diagram below illustrates the design:
![RPi Camera FMC example design](https://rpi.camerafmc.com/en/latest/_images/block-diagram-top-level.png "RPi Camera FMC example design")

The video pipe sub-blocks are illustrated below:
![RPi Camera FMC video pipe](https://rpi.camerafmc.com/en/latest/_images/video-pipe-block-diagram.png "RPi Camera FMC video pipe")

Important links:
* The RPi Camera FMC [datasheet](https://camerafmc.com/docs/rpi-camera-fmc/overview/)
* The [user guide](https://rpi.camerafmc.com) for these reference designs
* To [report an issue](https://github.com/fpgadeveloper/rpi-camera-fmc/issues)
* For technical support: [Contact Opsero](https://opsero.com/contact-us)

## Requirements

This project is designed for version 2020.2 of the Xilinx tools (Vivado/Vitis/PetaLinux). 
If you are using an older version of the Xilinx tools, then refer to the 
[release tags](https://github.com/fpgadeveloper/rpi-camera-fmc/releases "releases")
to find the version of this repository that matches your version of the tools.

In order to test this design on hardware, you will need the following:

* Vivado 2020.2
* Vitis 2020.2
* PetaLinux Tools 2020.2
* One or more [Raspberry Pi Camera Module 2](https://www.raspberrypi.com/products/camera-module-v2/) and/or 
  [Digilent Pcam 5C](https://digilent.com/shop/pcam-5c-5-mp-fixed-focus-color-camera-module/) cameras
* One [RPi Camera FMC](https://camerafmc.com/buy/ "RPi Camera FMC")
* One of the supported target boards listed below

### Target boards

* [ZCU104](https://www.xilinx.com/zcu104) (LPC: 4x cameras) **VERIFIED ON HW**
* [ZCU102](https://www.xilinx.com/zcu102) (HPC0: 4x cameras, HPC1: 2x camera) **VERIFIED ON HW**
* [ZCU106](https://www.xilinx.com/zcu106) (HPC0: 4x cameras) **VERIFIED ON HW**
* [PYNQ-ZU](https://www.tulembedded.com/FPGA/ProductsPYNQ-ZU.html) (LPC: 4x cameras) **VERIFIED ON HW**
* [Genesys-ZU](https://digilent.com/shop/genesys-zu-zynq-ultrascale-mpsoc-development-board/) (LPC: 4x cameras)
* [UltraZed EV carrier](https://www.xilinx.com/products/boards-and-kits/1-y3n9v1.html) (HPC: 4x cameras)

## Contribute

We strongly encourage community contribution to these projects. Please make a pull request if you
would like to share your work:
* if you've spotted and fixed any issues
* if you've added designs for other target platforms
* if you've added software support for other cameras

Thank you to everyone who supports us!

### The TODO list

* Get a Genesys-ZU board and test the design on hardware.
* Develop the PetaLinux project and test on HW.
* Write the ref design documentation (build and usage instructions, troubleshooting, etc).
* Software support for more cameras (this will be an ongoing task due to the number of cameras available).
* Debug: We are having trouble getting the UltraZed EV Carrier DisplayPort working with the standalone
  application. More time needed to debug.
* The example design has run out of PL-to-PS interrupts, so we need to add the AXI Interrupt Controller and
  adapt the software application to AXI Intc.

## About us

[Opsero Inc.](https://opsero.com "Opsero Inc.") is a team of FPGA developers delivering FPGA products and 
design services to start-ups and tech companies. Follow our blog, 
[FPGA Developer](https://www.fpgadeveloper.com "FPGA Developer"), for news, tutorials and
updates on the awesome projects we work on.

