================================
Stand-alone application
================================

The reference designs in this project can be used with a standalone application that runs on
the ARM processor of the Zynq UltraScale+ device. The purpose of the application is to configure
the cameras, the video pipes and the DisplayPort monitor. Once the application has configured
all the hardware, it goes into an infinite loop that regularly switches the monitor's video feed
from one camera to the next, every 8 seconds.

Building the Vitis workspace
================================

To build the Vitis workspace and standalone application, you must first generate
the Vivado project hardware design (the bitstream) and export the hardware.
Once the bitstream is generated and exported, then you can build the
Vitis workspace using the provided ``Vitis/build-vitis.tcl`` script.

Windows users
-------------

To build the Vitis workspace, Windows users can run the ``build-vitis.bat`` file which
launches the Tcl script.

Linux users
-----------

Linux users must use the following commands to run the build script:

.. code-block::

  cd <path-to-repo>/Vitis
  /<path-to-xilinx-tools>/Vitis/2020.2/bin/xsct build-vitis.tcl

Hardware setup
==============

Before running the application, you will need to setup the hardware. This involves connecting
one or more cameras to the `RPi Camera FMC`_ and then plugging it into the target board.
Instructions for doing this, including images of the correct flex cable orientation, can be 
found in the 
`Getting started <https://camerafmc.com/docs/rpi-camera-fmc/getting-started/#hardware-setup>`_
guide.

Run the application
===================

#. Open Xilinx Vitis.
#. Power up your hardware platform and ensure that the JTAG is connected properly.
#. In the Vitis Explorer panel, double-click on the System project that you want to run -
   this will reveal the applications contained in the project. The System project will have 
   the postfix "_system".
#. Now click on the application that you want to run. It should have the postfix "_app".
#. Select the option "Run Configurations" from the drop-down menu contained under the Run
   button on the toolbar (play symbol).
#. Double-click on "Single Application Debug" to create a run configuration for this 
   application. Then click "Run".

The run configuration will first program the FPGA with the bitstream, then load and run the 
application. You can view the UART output of the application in a console window.

UART settings
=============

To receive the UART output of this standalone application, you will need to connect the
USB-UART of the development board to your PC and run a console program such as 
`Putty`_. The UART speed must be set to 115200.




.. _RPi Camera FMC: https://camerafmc.com/docs/rpi-camera-fmc/overview/
.. _Putty: https://www.putty.org
