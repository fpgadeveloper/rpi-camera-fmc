# Build instructions

## Source code

The source code for the reference designs is managed on this Github repository:

* [https://github.com/fpgadeveloper/rpi-camera-fmc](https://github.com/fpgadeveloper/rpi-camera-fmc)

As this repository has submodules, you must clone the repository with the `--recursive` option as below:
```
git clone --recursive https://github.com/fpgadeveloper/rpi-camera-fmc.git
```

## License requirements

The designs for all of the [target boards](supported_carriers) except the ZCU102 can be built with the Vivado ML Standard 
Edition **without a license**.

The ZCU102 board is not supported by the Vivado ML Standard Edition (aka. the Webpack or free version)
so to build the designs for the ZCU102 board, you will need to either buy a license or download
a 30-day evaluation license for Vivado ML Enterprise Edition.

(target-designs)=
## Target designs

This repo contains several designs that target the various supported development boards and their
FMC connectors. The table below lists the target design name, the camera ports supported by the design and 
the FMC connector on which to connect the RPi Camera FMC. The VCU column indicates which designs contain
the Video Codec Unit and which do not.

| Target board             | Target design | FMC slot | Cameras | VCU |
|--------------------------|---------------|----------|---------|-----|
| [ZCU104][4]              | `zcu104`      | LPC   | 4 | YES |
| [ZCU102][9]              | `zcu102_hpc0` | HPC0  | 4 | NO |
| [ZCU102][9]              | `zcu102_hpc1` | HPC1  | 2 (note 1) | NO |
| [ZCU106][5]              | `zcu106_hpc0` | HPC0  | 4 | YES |
| [PYNQ-ZU][6]             | `pynqzu`      | LPC   | 2 (note 2) | NO |
| [Genesys-ZU][7]          | `genesyszu`   | LPC   | 2 (note 2) | YES |
| [UltraZed EV carrier][8] | `uzev`        | HPC   | 4 | YES |

Notes:
1. The HPC1 connector of the ZCU102 board can only support 2 cameras due to it's pin assignment. This design uses
   `CAM0` and `CAM1` as labelled on the RPi Camera FMC.
2. The `pynqzu` and `genesyszu` target designs have video pipelines for only 2 cameras: `CAM1` and `CAM2` as
   labelled on the RPi Camera FMC. This is due to the resource limitations of the devices on these boards.

## Linux only

These projects can be built using a machine (either physical or virtual) with one of the 
[supported Linux distributions].

```{tip} The build steps can be completed in the order shown below, or
you can go directly to the [build PetaLinux](#build-petalinux-project) instructions below
to build the Vivado and PetaLinux projects with a single command.
```

### Build Vivado project

1. Open a command terminal and launch the setup script for Vivado:
   ```
   source <path-to-vivado-install>/2022.1/settings64.sh
   ```
2. Clone the Git repository and `cd` into the `Vivado` folder of the repo:
   ```
   git clone --recursive https://github.com/fpgadeveloper/rpi-camera-fmc.git
   cd rpi-camera-fmc/Vivado
   ```
3. Run make to create the Vivado project for the target board. You must replace `<target>` with a valid
   target (alternatively, skip to step 5):
   ```
   make project TARGET=<target>
   ```
   Valid targets are: `zcu104`, `zcu102_hpc0`, `zcu102_hpc1`, `zcu106_hpc0`, `pynqzu`, `genesyszu` and `uzev`.
   That will create the Vivado project and block design without generating a bitstream or exporting to XSA.
4. Open the generated project in the Vivado GUI and click **Generate Bitstream**. Once the build is
   complete, select **File->Export->Export Hardware** and be sure to tick **Include bitstream** and use
   the default name and location for the XSA file.
5. Alternatively, you can create the Vivado project, generate the bitstream and export to XSA (steps 3 and 4),
   all from a single command:
   ```
   make xsa TARGET=<target>
   ```
   
(build-petalinux-project)=
### Build PetaLinux project

These steps will build the PetaLinux project for the target design. You are not required to have built the
Vivado design before following these steps, as the Makefile triggers the Vivado build for the corresponding
design if it has not already been done.

1. Launch the setup script for Vivado (only if you skipped the Vivado build steps above):
   ```
   source <path-to-vivado-install>/2022.1/settings64.sh
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2022.1/settings.sh
   ```
3. Build the PetaLinux project for your specific target platform by running the following
   command, replacing `<target>` with a valid value from below:
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   Valid targets are: 
   `zcu104`, 
   `zcu102_hpc0`,
   `zcu102_hpc1`,
   `zcu106_hpc0`, 
   `pynqzu`, 
   `uzev`.
   Note that if you skipped the Vivado build steps above, the Makefile will first generate and
   build the Vivado project, and then build the PetaLinux project.

### PetaLinux offline build

If you need to build the PetaLinux projects offline (without an internet connection), you can
follow these instructions.

1. Download the sstate-cache artefacts from the Xilinx downloads site (the same page where you downloaded
   PetaLinux tools). There are four of them:
   * aarch64 sstate-cache (for ZynqMP designs)
   * arm sstate-cache (for Zynq designs)
   * microblaze sstate-cache (for Microblaze designs)
   * Downloads (for all designs)
2. Extract the contents of those files to a single location on your hard drive, for this example
   we'll say `/home/user/petalinux-sstate`. That should leave you with the following directory 
   structure:
   ```
   /home/user/petalinux-sstate
                             +---  aarch64
                             +---  arm
                             +---  downloads
                             +---  microblaze
   ```
3. Create a text file called `offline.txt` that contains a single line of text. The single line of text
   should be the path where you extracted the sstate-cache files. In this example, the contents of 
   the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is written with NO TRAILING 
   FORWARD SLASH.

Now when you use `make` to build the PetaLinux projects, they will be configured for offline build.

[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[FPGA Drive FMC Gen4]: https://fpgadrive.com
[1]: https://www.fpgadrive.com/docs/fpga-drive-fmc-gen4/overview/
[2]: https://www.fpgadrive.com/docs/m2-mkey-stack-fmc/overview/
[3]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[4]: https://www.xilinx.com/zcu104
[5]: https://www.xilinx.com/zcu106
[6]: https://www.tulembedded.com/FPGA/ProductsPYNQ-ZU.html
[7]: https://digilent.com/shop/genesys-zu-zynq-ultrascale-mpsoc-development-board/
[8]: https://www.xilinx.com/products/boards-and-kits/1-y3n9v1.html
[9]: https://www.xilinx.com/zcu102

