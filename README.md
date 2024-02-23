# Reference design for RPi Camera FMC

## Description

This project demonstrates the Opsero [RPi Camera FMC](https://camerafmc.com/docs/rpi-camera-fmc/overview/) used to
connect 4x Raspberry Pi cameras (or compatible cameras) to one of the target FPGA/MPSoC boards listed below. The 
designs contain:

* 4x MIPI CSI capture pipelines
* [VVAS MultiScaler] kernel for hardware accelerated image processing
* Video Mixer IP based display pipeline to DisplayPort output
* Video Codec Unit ([VCU])

![RPi Camera FMC](https://www.fpgadeveloper.com/camera-fmc-connecting-mipi-cameras-to-fpgas/images/rpi-camera-fmc-pynq-zu-1.jpg "RPi Camera FMC")

The high level block diagram below illustrates the design:
![RPi Camera FMC example design](docs/source/images/rpi-camera-fmc-architecture.png "RPi Camera FMC example design")

The video pipe sub-blocks are illustrated below:
![RPi Camera FMC video pipe](docs/source/images/rpi-camera-fmc-mipi-pipeline.png "RPi Camera FMC video pipe")

Important links:
* The RPi Camera FMC [datasheet](https://camerafmc.com/docs/rpi-camera-fmc/overview/)
* The [user guide](https://rpi.camerafmc.com) for these reference designs
* To [report an issue](https://github.com/fpgadeveloper/rpi-camera-fmc/issues)
* For technical support: [Contact Opsero](https://opsero.com/contact-us)

## Requirements

This project is designed for version 2022.1 of the Xilinx tools (Vivado/Vitis/PetaLinux). 
If you are using an older version of the Xilinx tools, then refer to the 
[release tags](https://github.com/fpgadeveloper/rpi-camera-fmc/tags "releases")
to find the version of this repository that matches your version of the tools.

In order to test this design on hardware, you will need the following:

* Vivado 2022.1
* Vitis 2022.1
* PetaLinux Tools 2022.1
* Linux PC for build
* One or more [Raspberry Pi Camera Module 2](https://www.raspberrypi.com/products/camera-module-v2/) and/or 
  [Digilent Pcam 5C](https://digilent.com/shop/pcam-5c-5-mp-fixed-focus-color-camera-module/) cameras
* 1x [RPi Camera FMC](https://camerafmc.com/buy/ "RPi Camera FMC")
* 1x DisplayPort monitor that supports 1080p video
* One of the supported target boards listed below

## Target designs

| Target board             | Target design | FMC slot used | Cameras | VCU |
|--------------------------|---------------|----------|---------|-----|
| [ZCU104][4]              | `zcu104`      | LPC   | 4 | YES |
| [ZCU102][9]              | `zcu102_hpc0` | HPC0  | 4 | NO |
| [ZCU102][9]              | `zcu102_hpc1` | HPC1  | 2 (note 1) | NO |
| [ZCU106][5]              | `zcu106_hpc0` | HPC0  | 4 | YES |
| [PYNQ-ZU][6]             | `pynqzu`      | LPC   | 2 (note 2) | NO |
| [Genesys-ZU][7]          | `genesyszu`   | LPC   | 2 (note 2) | YES |
| [UltraZed EV carrier][8] | `uzev`        | HPC   | 4 | YES |

Notes:
1. The HPC1 connector of the ZCU102 board can only support 2 cameras due to it's pin assignment. This design
   supports the `CAM0` and `CAM1` slots as labelled on the RPi Camera FMC.
2. The `pynqzu` and `genesyszu` target designs have video pipelines for only 2 cameras: `CAM1` and `CAM2` as
   labelled on the RPi Camera FMC. This is due to the resource limitations of the devices on these boards.

## Build instructions

This repo contains submodules. To clone this repo, run:
```
git clone --recursive https://github.com/fpgadeveloper/rpi-camera-fmc.git
```

Source Vivado and PetaLinux tools:

```
source <path-to-petalinux>/2022.1/settings.sh
source <path-to-vivado>/2022.1/settings64.sh
```

Build all (Vivado project, accelerator kernel and PetaLinux):

```
cd rpi-camera-fmc/PetaLinux
make petalinux TARGET=uzev
```

## Contribute

We strongly encourage community contribution to these projects. Please make a pull request if you
would like to share your work:
* if you've spotted and fixed any issues
* if you've added designs for other target platforms
* if you've added software support for other cameras

Thank you to everyone who supports us!

### The TODO list

* Develop PYNQ support
* Get a Genesys-ZU board and test the design on hardware.
* Software support for more cameras (this will be an ongoing task due to the number of cameras available).

## About us

[Opsero Inc.](https://opsero.com "Opsero Inc.") is a team of FPGA developers delivering FPGA products and 
design services to start-ups and tech companies. Follow our blog, 
[FPGA Developer](https://www.fpgadeveloper.com "FPGA Developer"), for news, tutorials and
updates on the awesome projects we work on.

[1]: https://www.fpgadrive.com/docs/fpga-drive-fmc-gen4/overview/
[2]: https://www.fpgadrive.com/docs/m2-mkey-stack-fmc/overview/
[3]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[4]: https://www.xilinx.com/zcu104
[5]: https://www.xilinx.com/zcu106
[6]: https://www.tulembedded.com/FPGA/ProductsPYNQ-ZU.html
[7]: https://digilent.com/shop/genesys-zu-zynq-ultrascale-mpsoc-development-board/
[8]: https://www.xilinx.com/products/boards-and-kits/1-y3n9v1.html
[Hailo-8 M.2 AI Acceleration Module]: https://hailo.ai/products/ai-accelerators/hailo-8-m2-ai-acceleration-module/
[9]: https://www.xilinx.com/zcu102
[AMD Xilinx MIPI CSI Controller Subsystem IP]: https://docs.xilinx.com/r/en-US/pg202-mipi-dphy
[RPi Camera FMC]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[GStreamer]: https://gstreamer.freedesktop.org/
[VVAS MultiScaler]: https://xilinx.github.io/VVAS/2.0/build/html/docs/common/Acceleration-Hardware.html#multiscaler-kernel
[VCU]: https://xilinx-wiki.atlassian.net/wiki/spaces/A/pages/18842546/Xilinx+Zynq+UltraScale+MPSoC+Video+Codec+Unit
[G-Streamer plugins]: https://xilinx.github.io/VVAS/2.0/build/html/docs/common/common_plugins.html

