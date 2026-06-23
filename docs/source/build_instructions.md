# Build instructions

## Source code

The source code for the reference designs is managed on this Github repository:

* [https://github.com/fpgadeveloper/rpi-camera-fmc](https://github.com/fpgadeveloper/rpi-camera-fmc)

As this repository has submodules, you must clone the repository with the `--recursive` option as below:
```
git clone --recursive https://github.com/fpgadeveloper/rpi-camera-fmc.git
```

The `--recursive` flag pulls in `submodules/avnet-bdf` (the Avnet board definition
files, required for the AUBoard target — these are not yet in the AMD Board Store),
along with the other submodules. If you used **Download ZIP**, you'll need to clone
the submodules separately, or download the board files from the Avnet BDF repository
and place them under `submodules/avnet-bdf/`.

## License requirements

The designs for all of the [target boards](supported_carriers) except the ZCU102 can be built with the Vivado ML Standard 
Edition **without a license**.

The ZCU102 board is not supported by the Vivado ML Standard Edition (aka. the Webpack or free version)
so to build the designs for the ZCU102 board, you will need to either buy a license or download
a 30-day evaluation license for Vivado ML Enterprise Edition.

(target-designs)=

Additionally, some designs use IP cores that are licensed separately from the Vivado edition itself (for example: TEMAC, XXV Ethernet, HDMI). The **IP License** column in the tables below indicates the designs that require such a license to generate a bitstream; evaluation licenses are generally available from AMD for testing.

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

| Target board        | Target design     | Cameras | FMC Slot    | VCU | Vivado<br> Edition | IP<br>License |
|---------------------|-------------------|---------|-------------|-----|-----|-----|
{% for design in data.designs %}{% if design.group == group.label and design.publish %}| [{{ design.board }}]({{ design.link }}) | `{{ design.label }}` | {{ design.cams | length }} | {{ design.connector }} | {% if design.vcu %} ✅ {% else %} ❌ {% endif %} | {{ "Enterprise" if design.license else "Standard 🆓" }} | {{ "Required" if design.ip_license else "-" }} |
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

## Cross-platform build runner

All builds are driven by the `build.py` runner at the root of the repository,
on **both Windows and Linux** — the build instructions are the same for the
two operating systems. Each command builds whatever it depends on
automatically, skips anything that is already built, and locates the AMD
tools itself, so there is no need to source the settings scripts beforehand.

On Linux and on Windows (git bash), commands are run with the `build.sh`
shim, which finds a suitable Python 3 automatically (including the
interpreter bundled with the AMD tools). Windows users who prefer not to
use git bash can run the same commands from Command Prompt or PowerShell
using `build.bat` instead — the commands and arguments are otherwise
identical, for example `build.bat xsa --target <target>`.

This repository uses git submodules: clone it with `--recurse-submodules`,
or run `git submodule update --init` in an existing clone, before building.

To see the available targets and the state of a build:

```
./build.sh list                       # list the targets and their attributes
./build.sh status --target <target>   # show the per-stage artifact state
./build.sh clean --target <target>    # delete a target's generated outputs
```

```{note}
The embedded Linux images (PetaLinux) can only be built on a
native Linux machine; everything else builds on Windows too. On Windows, the
runner refuses the Linux-only stages up front and prints the exact command
to run on the Linux machine.
```

```{attention}
The legacy `make` interface described in previous versions of
this documentation still works on Linux — each Makefile is now a thin
wrapper around `build.sh` — but it is deprecated and will be removed at the
next version update.
```

### Build Vivado project

This single command creates the Vivado project, generates the bitstream and
exports the hardware to an XSA file:

```
./build.sh xsa --target <target>
```

Valid targets are:
{% for design in data.designs if design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The HLS IP on which the design depends is generated automatically before
the project is created. It can also be generated on its own with
`./build.sh ip --target <target>`.

If you want the Vivado project and block design without generating a
bitstream — for example, to explore or modify the design in the Vivado GUI —
run `./build.sh project --target <target>` instead, then open the project
from `Vivado/<target>/`.

### Build Vitis workspace

This creates the Vitis workspace and compiles the standalone application,
producing the baremetal boot file (`BOOT.BIN` or bit file, depending on the
device family). The Vivado XSA is built first if it does not already exist:

```
./build.sh standalone --target <target>
```

Valid targets for the standalone application are:
{% for design in data.designs if design.baremetal and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The workspace is created in `Vitis/<target>_workspace` and the boot files
are gathered in `Vitis/boot/<target>/`.

### Build PetaLinux

The PetaLinux build requires a native Linux machine (one of the [supported
Linux distributions]) with PetaLinux Tools 2025.2 installed. The runner
locates and sources the PetaLinux `settings.sh` itself, and builds the
Vivado XSA first if it does not already exist:

```
./build.sh petalinux --target <target>
```

Valid targets for PetaLinux are:
{% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

The output products are written to `PetaLinux/<target>/images/linux/`.

#### PetaLinux offline build

If you need to build the PetaLinux projects offline (without an internet
connection), you can follow these instructions.

1. Download the sstate-cache artefacts from the Xilinx downloads site (the
   same page where you downloaded PetaLinux tools). There are four of them:
   * aarch64 sstate-cache (for ZynqMP designs)
   * arm sstate-cache (for Zynq designs)
   * microblaze sstate-cache (for Microblaze designs)
   * Downloads (for all designs)
2. Extract the contents of those files to a single location on your hard
   drive, for this example we'll say `/home/user/petalinux-sstate`. That
   should leave you with the following directory structure:
   ```
   /home/user/petalinux-sstate
                             +---  aarch64
                             +---  arm
                             +---  downloads
                             +---  microblaze
   ```
3. Create a text file called `offline.txt` in the `PetaLinux` directory of
   the project repository. The file should contain a single line of text
   specifying the path where you extracted the sstate-cache files. In this
   example, the contents of the file would be:
   ```
   /home/user/petalinux-sstate
   ```
   It is important that the file contain only one line and that the path is
   written with NO TRAILING FORWARD SLASH.

The PetaLinux builds will then be configured for offline build.

### Build everything

This builds everything that the target supports — the Vivado project and XSA,
the standalone application and the PetaLinux image — and gathers the boot
images into `bootimages/*.zip`:

```
./build.sh all --target <target>
./build.sh all --target all      # every target in the repo
```

On Windows, `all` builds everything that the host can build and reports the
Linux-only stages as `BLOCKED` rather than failing.

[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment

## Launch the baremetal application (FPGA / AUBoard)

The standalone application produced by `./build.sh standalone --target auboard` is a
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


