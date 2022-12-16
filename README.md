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
