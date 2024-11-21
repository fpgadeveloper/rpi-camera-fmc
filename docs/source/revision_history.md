# Revision History

## 2024.1 Changes

* Removed VVAS image processing accelerator from the design - no current support for VVAS in version
  2024.1.
* Added AXI4-Streaming Data FIFO to MIPI video pipes, between MIPI CSI2 RX and ISP Pipeline IPs
* Improved documentation, centralized target design info to JSON file
* RPi camera IOs are properly driven
* ISP Pipeline IP updated to version v2023.2_update1 of the Vitis_Libraries repo
* ISP Pipeline now uses built-in Linux driver (linux-xlnx/drivers/media/platform/xilinx/xilinx-isppipeline.c)
* Removed all Vitis-AI and VVAS recipes from BSPs

### 2022.1 2024-02-23 Changes

* Changed the video pipeline to use ISPPipeline - this improved the quality of the images
* Removed the standalone application
* Added VVAS accelerator and VCU to the designs to make them more useful
* Display pipeline fixed for use in PetaLinux and GStreamer
* Docs updated
* init_cams.sh script improved and displaycams.sh script added

## 2022.1 Changes

* Added Makefiles to improve the build experience for Linux users
* Consolidated Vivado batch files (user is prompted to select target design)
* Vitis build script now creates a separate workspace for each target design (improved user experience)
* Converted documentation to markdown (from reStructuredText)

