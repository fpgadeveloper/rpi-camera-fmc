# Raspberry Pi Camera FMC example design

This is the example design for the [RPi Camera FMC](https://camerafmc.com), an add-on card for FPGA dev boards that
has four independent 2-lane MIPI interfaces for connection to Raspberry Pi cameras.

![RPi Camera FMC](https://www.fpgadeveloper.com/camera-fmc-connecting-mipi-cameras-to-fpgas/images/rpi-camera-fmc-pynq-zu-1.jpg "RPi Camera FMC")

The design is still under development but has been verified on most of the target platforms (see below).

### Target boards

* [ZCU104](https://www.xilinx.com/zcu104) (LPC: 4x cameras) **VERIFIED ON HW**
* [ZCU102](https://www.xilinx.com/zcu102) (HPC0: 4x cameras, HPC1: 2x camera) **VERIFIED ON HW**
* [ZCU106](https://www.xilinx.com/zcu106) (HPC0: 4x cameras) **VERIFIED ON HW**
* [PYNQ-ZU](https://www.tulembedded.com/FPGA/ProductsPYNQ-ZU.html) (LPC: 4x cameras) **VERIFIED ON HW**
* [Genesys-ZU](https://digilent.com/shop/genesys-zu-zynq-ultrascale-mpsoc-development-board/) (LPC: 4x cameras)
* [UltraZed EV carrier](https://www.xilinx.com/products/boards-and-kits/1-y3n9v1.html) (HPC: 4x cameras)

That list may grow, but may also shrink depending on any issues that we come across during
development.

### List of things to fix/complete

* We are having trouble getting the UltraZed EV Carrier DisplayPort working with the standalone
  application. More time needed to debug.
* The example design has run out of PL-to-PS interrupts, so we need to add the AXI Interrupt Controller.
  The main challenge for the moment is adapting the software application to AXI Intc.
* The four cameras feed an AXI Switch which selects which video source to display on the monitor.
  Instead we want to add an IP to combine all four sources into a single 1080p video to display
  on the monitor.
* Eventually we want to use the Vitis Vision Library to do some processing on the input videos to make the
  demo interesting.
