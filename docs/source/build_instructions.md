# Build instructions

## Source code

The source code for the reference designs is managed on this Github repository:

* [https://github.com/fpgadeveloper/rpi-camera-fmc](https://github.com/fpgadeveloper/rpi-camera-fmc)

To get the code, you can follow the link and use the **Download ZIP** option, or you can clone it
using this command:
```
git clone https://github.com/fpgadeveloper/rpi-camera-fmc.git
```

## License requirements

The designs for all of the [target boards](supported_carriers) except the ZCU102 can be built with the Vivado ML Standard 
Edition **without a license**.

The ZCU102 board is not supported by the Vivado ML Standard Edition (aka. the Webpack or free version)
so to build the designs for the ZCU102 board, you will need to either buy a license or download
a 30-day evaluation license for Vivado ML Enterprise Edition.

## Target designs

This repo contains several designs that target the various supported development boards and their
FMC connectors. The table below lists the target design name, the camera ports supported by the design and 
the FMC connector on which to connect the RPi Camera FMC.

| Target design | Camera ports   | Target board and connector                                           |
|---------------|----------------|----------------------------------------------------------------------|
| `zcu104`      | CAM0,1,2,3     | ZCU104  |
| `zcu102_hpc0` | CAM0,1,2,3     | ZCU102, HPC0 connector |
| `zcu102_hpc1` | CAM0,1         | ZCU102, HPC1 connector |
| `zcu106_hpc0` | CAM0,1,2,3     | ZCU106, HPC0 connector |
| `pynqzu`      | CAM0,1,2,3     | PYNQ-ZU  |
| `genesyszu`   | CAM0,1,2,3     | Genesys-ZU  |
| `uzev`        | CAM0,1,2,3     | UltraZed-EV Carrier |
| `zcu106_pcie` | CAM1,2,3       | ZCU106, HPC0 connector<br> and [FPGA Drive FMC Gen4] on HPC1 |

The `zcu106_pcie` design is unique in that it supports the use of the [FPGA Drive FMC Gen4] alongside
the RPi Camera FMC. The [FPGA Drive FMC Gen4] allows an M.2 PCIe module to be connected to the board
and can be used for a solid-state drive (SSD) or accelerator module. To use this design, you will need
to have the [FPGA Drive FMC Gen4] mezzanine card.

## Windows users

Windows users will be able to build the Vivado projects and compile the standalone applications,
however Linux is required to build the PetaLinux projects. 

```{tip} If you wish to build the PetaLinux projects,
we recommend that you build the entire project (including the Vivado project) on a machine (either 
physical or virtual) running one of the [supported Linux distributions].
```

### Build Vivado project in Windows

1. Download the repo as a zip file and extract the files to a directory
   on your hard drive --OR-- clone the repo to your hard drive
2. Open Windows Explorer, browse to the repo files on your hard drive.
3. In the `Vivado` directory, you will find multiple batch files (.bat).
   Double click on the batch file that corresponds to your hardware,
   for example, double-click `build-pynqzu.bat` if you are using the PYNQ-ZU.
   This will generate a Vivado project for your hardware platform.
4. Run Vivado and open the project that was just created.
5. Click Generate bitstream.
6. When the bitstream is successfully generated, select **File->Export->Export Hardware**.
   In the window that opens, tick **Include bitstream** and use the default name and location
   for the XSA file.

### Build Vitis workspace in Windows

1. Return to Windows Explorer and browse to the Vitis directory in the repo.
2. Double click the `build-vitis.bat` batch file. The batch file will run the
   `build-vitis.tcl` script and build the Vitis workspace containing the hardware
   design and the software application.

## Linux users

These projects can be built using a machine (either physical or virtual) with one of the 
[supported Linux distributions].

```{tip} The build steps can be completed in the order shown below, or
you can go directly to the [build PetaLinux](#build-petalinux-project-in-linux) instructions below
to build the Vivado and PetaLinux projects with a single command.
```

### Build Vivado project in Linux

1. Open a command terminal and launch the setup script for Vivado:
   ```
   source <path-to-vivado-install>/2022.1/settings64.sh
   ```
2. Clone the Git repository and `cd` into the `Vivado` folder of the repo:
   ```
   git clone https://github.com/fpgadeveloper/rpi-camera-fmc.git
   cd rpi-camera-fmc/Vivado
   ```
3. Run make to create the Vivado project for the target board. You must replace `<target>` with a valid
   target (alternatively, skip to step 5):
   ```
   make project TARGET=<target>
   ```
   Valid targets are: `zcu104`, `zcu102_hpc0`, `zcu102_hpc1`, `zcu106_hpc0`, `pynqzu`, `genesyszu`,
   `uzev` and `zcu106_pcie`.
   That will create the Vivado project and block design without generating a bitstream or exporting to XSA.
4. Open the generated project in the Vivado GUI and click **Generate Bitstream**. Once the build is
   complete, select **File->Export->Export Hardware** and be sure to tick **Include bitstream** and use
   the default name and location for the XSA file.
5. Alternatively, you can create the Vivado project, generate the bitstream and export to XSA (steps 3 and 4),
   all from a single command:
   ```
   make xsa TARGET=<target>
   ```
   
### Build Vitis workspace in Linux

The following steps are required if you wish to build and run the [standalone application](standalone). You can
skip to the following section if you instead want to use PetaLinux. We are assuming that you have 
completed the above steps and an XSA file has been generated for your selected target.

1. Launch the setup scripts for Vitis:
   ```
   source <path-to-vitis-install>/2022.1/settings64.sh
   ```
2. To build the Vitis workspace, `cd` to the Vitis directory in the repo,
   then run make to create the Vitis workspace and compile all applications within:
   ```
   cd rpi-camera-fmc/Vitis
   make workspace
   ```
   Note that this will create a Vitis workspace with standalone applications for each of the target
   Vivado designs that were built and exported in the previous section.

### Build PetaLinux project in Linux

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
   commands and replacing `<target>` with one of the following: `zcu104`, `zcu102_hpc0`, `zcu102_hpc1`,
   `zcu106_hpc0`, `pynqzu`, `uzev`, `zcu106_pcie`
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   Note that if you skipped the Vivado build steps above, the Makefile will first generate and
   and build the Vivado project, and then build the PetaLinux project.

[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[FPGA Drive FMC Gen4]: https://fpgadrive.com

