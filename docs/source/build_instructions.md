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

{% for group in data.groups %}
    {% set designs_in_group = [] %}
    {% for design in data.designs %}
        {% if design.group == group.label and design.publish %}
            {% set _ = designs_in_group.append(design.label) %}
        {% endif %}
    {% endfor %}
    {% if designs_in_group | length > 0 %}
### {{ group.name }} designs

| Target board        | Target design     | Cameras | FMC Slot    | VCU | Vivado<br> Edition |
|---------------------|-------------------|---------|-------------|-----|-----|
{% for design in data.designs %}{% if design.group == group.label and design.publish %}| [{{ design.board }}]({{ design.link }}) | `{{ design.label }}` | {{ design.cams | length }} | {{ design.connector }} | {% if design.vcu %} ✅ {% else %} ❌ {% endif %} | {{ "Enterprise" if design.license else "Standard 🆓" }} |
{% endif %}{% endfor %}
{% endif %}
{% endfor %}

Notes:
1. The Vivado Edition column indicates which designs are supported by the Vivado *Standard* Edition, the
   FREE edition which can be used without a license. Vivado *Enterprise* Edition requires
   a license however a 30-day evaluation license is available from the AMD Xilinx Licensing site.
2. The HPC1 connector of the ZCU102 board can only support 2 cameras due to it's pin assignment. This design uses
   `CAM0` and `CAM1` as labelled on the RPi Camera FMC.
3. The `pynqzu` target design has video pipelines for only 2 cameras: `CAM1` and `CAM2` as
   labelled on the RPi Camera FMC. This is due to the resource limitations of the device on this board.

## Linux only

These projects must be built on a machine (either physical or virtual) with one of the
[supported Linux distributions]. The PetaLinux flow does not work on Windows; the Vitis
baremetal flow can work on Windows.

```{tip} The build steps can be completed in the order shown below, or
you can go directly to the [build PetaLinux](#build-petalinux-project) instructions below
to build the Vivado and PetaLinux projects with a single command. For the FPGA / AUBoard
target, jump to [Build the Vitis workspace](#build-vitis-workspace) instead.
```

### Build Vivado project

1. Open a command terminal and launch the setup script for Vivado:
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
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
   Valid target labels are:
   {% for design in data.designs if design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
   That will create the Vivado project and block design without generating a bitstream or exporting to XSA.
4. Open the generated project in the Vivado GUI and click **Generate Bitstream**. Once the build is
   complete, select **File->Export->Export Hardware** and be sure to tick **Include bitstream** and use
   the default name and location for the XSA file.
5. Alternatively, you can create the Vivado project, generate the bitstream and export to XSA (steps 3 and 4),
   all from a single command:
   ```
   make xsa TARGET=<target>
   ```
   
(build-vitis-workspace)=
### Build the Vitis workspace (baremetal targets)

The FPGA / baremetal targets (currently `auboard`) are built through the Vitis
workspace rather than PetaLinux. The same Vivado project is used as input.

1. Launch the setup script for Vivado and Vitis (only if you skipped the Vivado
   build steps above):
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   source <path-to-xilinx-tools>/2025.2/Vitis/settings64.sh
   ```
2. Build the Vitis workspace for the target:
   ```
   cd Vitis
   make workspace TARGET=<target>
   ```
   Valid baremetal target labels are:
   {% for design in data.designs if design.baremetal and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
   If the Vivado XSA does not yet exist, the Vitis Makefile will trigger the
   Vivado build first.
3. To produce a programmable boot file (e.g. `.bit` for MicroBlaze targets) run:
   ```
   make bootfile TARGET=<target>
   ```
   The packaged boot files end up under `Vitis/boot/<target>/`. Launch the
   resulting application from the Vitis GUI or `xsct` and connect a UART
   terminal at 115200 baud to observe the baremetal output (see the
   [auboard launch instructions](#launch-baremetal-app)).

(build-petalinux-project)=
### Build PetaLinux project

These steps will build the PetaLinux project for the target design. You are not required to have built the
Vivado design before following these steps, as the Makefile triggers the Vivado build for the corresponding
design if it has not already been done.

1. Launch the setup script for Vivado (only if you skipped the Vivado build steps above):
   ```
   source <path-to-xilinx-tools>/2025.2/Vivado/settings64.sh
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-petalinux-install>/2025.2/settings.sh
   ```
3. Build the PetaLinux project for your specific target platform by running the following
   command, replacing `<target>` with a valid value from below:
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   Valid target labels for PetaLinux projects are:
   {% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
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
3. Create a text file called `offline.txt` in the `PetaLinux` directory of the project repository. The file should contain
   a single line of text specifying the path where you extracted the sstate-cache files. In this example, the contents of 
   the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is written with NO TRAILING 
   FORWARD SLASH.

Now when you use `make` to build the PetaLinux projects, they will be configured for offline build.

(launch-baremetal-app)=
## Launch the baremetal application (FPGA / AUBoard)

The standalone application produced by `make workspace TARGET=auboard` is a
camera-bring-up program that:

* programs the on-FMC IDT 8T49N24x clock generator,
* programs the DP159 HDMI re-driver,
* initialises the connected RPi cameras (IMX219 or OV5640),
* configures the MIPI / frame-buffer / mixer / HDMI pipeline,
* and continuously composes the live video onto an HDMI monitor.

To run it:

1. Connect the [RPi Camera FMC] to the AUBoard FMC connector, attach one or
   more [Raspberry Pi camera module v2] modules to the FMC, and connect an
   HDMI monitor to the FMC's HDMI output.
2. Connect the USB-UART and open a terminal at 115200 baud.
3. Power the board and program the bitstream / ELF from the Vitis GUI
   (Run As → Launch Hardware) or with `xsct` and the generated
   `boot.tcl` under `Vitis/auboard_workspace/`.

Expected UART output (with two cameras attached to CAM0 and CAM2 of the
RPi Camera FMC):

```
################################################
#    Raspberry Pi Camera to HDMI Example       #
#    For the Opsero RPi Camera FMC (OP068)     #
################################################

Detected 2 connected cameras:
  - CAM0: Raspberry Pi Camera v2   to Mixer layer 1
  - CAM2: Raspberry Pi Camera v2   to Mixer layer 2

Configuring cameras:
  - CAM0: SUCCESS
  - CAM2: SUCCESS

TX stream is up
```

The repeated `VERBOSITY is disabled : 0` lines emitted by the underlying
HDMI / video-processing driver code are benign and can be ignored.

[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment

