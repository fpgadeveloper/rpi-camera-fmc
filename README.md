# Raspberry Pi Camera FMC example design

This is (the very early stage of) an example design for a new FMC product that we are developing.
The card will have four independent 2-lane MIPI interfaces for connection to Raspberry Pi cameras.
The main purpose of the design at the moment is to validate our product and it's compatibility
with the carriers that we intend to support.

At the moment, we intend to support the following boards:

* ZCU104 (LPC: 4x cameras)
* ZCU102 (HPC0: 4x cameras, HPC1: 2x camera)
* ZCU106 (HPC0: 4x cameras)
* PYNQ-ZU (LPC: 4x cameras)
* Genesys-ZU (LPC: 4x cameras)
* UltraZed EV carrier (HPC: 4x cameras)

That list may grow, but may also shrink depending on any issues that we come across during
development.

### List of things to fix/complete

* The example design has run out of PL-to-PS interrupts, so we need to add the AXI Interrupt Controller.
  The main challenge for the moment is adapting the software application to AXI Intc.
* The four cameras feed an AXI Switch which selects which video source to display on the monitor.
  Instead we want to add an IP to combine all four sources into a single 1080p video to display
  on the monitor.
* Eventually we want to use the Xilinx ISP to do some processing on the input videos to make the
  demo interesting.
