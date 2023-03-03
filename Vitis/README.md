Vitis Project files
===================

### How to build the Vitis workspace

In order to make use of these source files, you must first generate
the Vivado project hardware design (the bitstream) and export the hardware.
Check the `Vivado` folder for instructions on doing this from Vivado.

Once the bitstream is generated and exported, then you can build the
Vitis workspace using the provided `build-vitis.tcl` script.

### Scripted build

The Vitis directory contains a `build-vitis.tcl` script which can be run to automatically
generate the Vitis workspace. Windows users can run the `build-vitis.bat` file which
launches the Tcl script. Linux users must use the following commands to run the build
script:
```
cd <path-to-repo>/Vitis
/<path-to-xilinx-tools>/Vitis/2020.2/bin/xsct build-vitis.tcl
```

The build script does three things:
1. Generates an empty application for each exported Vivado design
that is found in the ../Vivado directory. Most users will only have one exported
Vivado design.
2. Copies the sources from the "common/src" directory into the application.
3. Builds all applications.

### Run the application

1. Open Xilinx Vitis.
2. Power up your hardware platform and ensure that the JTAG is
connected properly.
3. Select Xilinx Tools->Program FPGA. You only have to do this
once, each time you power up your hardware platform.
4. Click Run from the toolbar to run your application. You can modify the code
and click Run as many times as you like, without going through
the other steps.

