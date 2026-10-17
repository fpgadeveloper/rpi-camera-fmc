# Advanced: project structure and customization

This section is intended for users who want to modify the reference
designs — adding IP to the block design, changing constraints, modifying
the standalone application, or adding packages or drivers to the
PetaLinux project. It describes how the repository is laid out, how the
build flow works, how the Vitis, PetaLinux and Yocto sides are
organised, and what modifications have been added on top of the stock
AMD BSPs.

The actual *build* instructions are in [build_instructions](build_instructions);
this section is about understanding the project well enough to modify
it.

## Repository layout

```
.
├── build.py                   <- Cross-platform build runner (the build logic)
├── build.sh / build.bat       <- Shims that invoke build.py (Linux/git bash, Windows)
├── Makefile                   <- Deprecated thin wrapper around build.sh (removed next version)
├── README.md
├── config/                    <- Source-of-truth design metadata and auto-generation
│   ├── data.json
│   └── update.py
├── docs/                      <- This documentation (Sphinx + Read the Docs)
│   └── source/images/
│       └── gen_block_diagram.py <- Generates the block diagrams of these docs
├── PetaLinux/
│   └── bsp/                   <- Per-board (and optional per-target) BSP fragments
│       └── pynqzu/, uzev/, zcu102/, zcu102_hpc1/, zcu104/, zcu106/
├── Yocto/
│   ├── bsp/                   <- Per-board (and per-target) Yocto BSP layers
│   │   ├── pynqzu/, uzev/, zcu102/, zcu102_hpc1/, zcu104/, zcu106/
│   │   ├── vck190_fmcp1/, vck190_fmcp2/, vek280/   <- Versal targets (one BSP per target)
│   │   └── dvi-out/           <- DVI output layer of the Versal targets (dvi-init, device tree)
│   ├── scripts/               <- Engine of the Yocto flow (workspace, configure, build, package)
│   └── README.md
├── submodules/                <- Vendor board definition files (BDFs), Vitis Libraries
├── Vivado/
│   ├── ip/isppipeline/        <- HLS build of the ISP Pipeline IP (stage 'ip')
│   ├── scripts/
│   │   ├── build.tcl          <- Project creation + block design assembly
│   │   └── xsa.tcl            <- Synthesis, implementation, XSA export
│   └── src/
│       ├── bd/
│       │   ├── bd_mb.tcl      <- Block design for MicroBlaze targets
│       │   ├── bd_zynqmp.tcl  <- Block design for Zynq UltraScale+ targets
│       │   ├── bd_versal.tcl  <- Block design for Versal targets
│       │   ├── dvi_out.tcl    <- DVI output hierarchy of the Versal targets
│       │   └── mipi_locs.tcl  <- Per-target MIPI lane placement constants
│       ├── constraints/
│       │   ├── <target>.xdc   <- One XDC per target (pin assignments, timing)
│       │   └── dvi_<board>.xdc <- HDMI TX pins of the Versal boards (added by dvi_out.tcl)
│       └── hdl/dvi/           <- TMDS encoder, gearbox and transceiver reset RTL (Versal DVI output)
└── Vitis/
    ├── py/
    │   ├── args.json          <- Repo-specific Vitis flow configuration
    │   ├── build-vitis.py     <- Universal Vitis Python build driver
    │   └── make-boot.py       <- BOOT.BIN packaging
    ├── common/
    │   └── src/               <- Camera sensor drivers shared by the standalone applications
    ├── microblaze/src/        <- AUBoard standalone application
    ├── versal/src/            <- Versal standalone application (VCK190, VEK280)
    └── <target>_workspace/    <- Per-target Vitis workspace (generated)
```

Per-target build outputs are written to `Vivado/<target>/`,
`Vitis/<target>_workspace/`, `PetaLinux/<target>/` and `Yocto/<target>/`; packaged
boot-image zips are written to `bootimages/`. None of these are
committed.

There is no port-config overlay in this repository — there is at most
one Raspberry Pi camera array per design, and per-target customisation
is done via per-target BSP overlays where needed (see
[PetaLinux side](#petalinux-side) and [Yocto side](#yocto-side) below).

## Target naming

A *target label* is the canonical handle for a single design and is passed
to every build command via `--target`. It encodes the board and, for
boards with multiple FMC connectors, the connector:

```
<board>[_<connector>]
```

Examples: `uzev`, `zcu102_hpc0`, `zcu102_hpc1`, `zcu104`, `pynqzu`,
`auboard`, `genesyszu`. The first underscore-delimited token is taken
as the *target board* and is what the build runner uses to select
the BSP under `PetaLinux/bsp/<board>/` and `Yocto/bsp/<board>/`.

The complete list of valid targets comes from `config/data.json`; run
`./build.sh list` (or `./build.sh labels` for one per line) to print it.

## `config/data.json` and `config/update.py`

`config/data.json` is the canonical source of truth for the set of
supported designs and their per-target metadata (board name, processor
family, FMC connector, baremetal-vs-PetaLinux support, etc.). The
`build.py` runner reads it directly at runtime, so the target list is
never hand-maintained.

`config/update.py` reads `data.json` and regenerates the auto-managed
documentation and metadata that is *not* read at runtime: the target
tables in the top-level `README.md`, the `.gitignore`, and the per-board
sections still embedded in `PetaLinux/Makefile` — each delimited by
`UPDATER START` / `UPDATER END` comment markers.

When adding or modifying a target, edit `data.json` and re-run
`update.py`. Do not hand-edit content between the `UPDATER START` /
`UPDATER END` markers; it will be overwritten on the next regeneration.

## Build runner

All build stages are driven by the cross-platform `build.py` runner at the
root of the repository, invoked through the `build.sh` shim on Linux / git
bash or `build.bat` on Windows (identical arguments). It reads the target
list and per-target attributes straight from `config/data.json`, builds
whatever a requested stage depends on automatically, skips anything already
built, and locates and sources the AMD tools itself — so there is no need to
source the Vivado / Vitis / PetaLinux settings scripts beforehand.

The build is organised into stages, each available as a sub-command:

| Command      | Stage                                                                                  |
|--------------|----------------------------------------------------------------------------------------|
| `ip`         | Build the HLS IP of the design (the ISP Pipeline) with Vitis HLS.                       |
| `project`    | Create the Vivado project (`.xpr`) and block design.                                   |
| `xsa`        | Synthesise, implement and export the hardware (`.xsa`).                                 |
| `standalone` | Create the Vitis workspace, build the baremetal app, package `BOOT.BIN` / `.mcs`.      |
| `petalinux`  | Create the PetaLinux project from the XSA, apply the BSP overlays, build and package.   |
| `yocto`      | Create the Yocto / AMD EDF workspace, generate a machine from the XSA, apply the BSP, build the SD card image. |
| `package`    | Gather the built boot artifacts into `bootimages/*.zip`.                               |
| `all`        | Build every stage the target supports, then `package`.                                 |
| `clean`      | Delete a target's generated outputs (`--stage <s>` for one stage, `--keep-boot` to keep the deliverables). |

Run `./build.sh list` to see the targets and their attributes, `./build.sh
status --target <t>` for per-stage artifact state, and `./build.sh --help`
for the full command list.

Each target is flagged in `config/data.json` for the stages it supports —
the MicroBlaze target (`auboard`) is baremetal-only (no PetaLinux), while
the ZynqMP targets support the PetaLinux and Yocto flows. Because each stage
builds its prerequisites first, a single `./build.sh all --target <t>`
cascades the whole pipeline:

```
./build.sh all --target t
  -> xsa         : vivado creates the project (build.tcl), then synth/impl/XSA export (xsa.tcl)
  -> standalone  : vitis builds the platform + app, packages BOOT.BIN / .mcs
  -> petalinux   : petalinux-create -> -config --get-hw-description <XSA>
                   -> copy bsp/<board>/project-spec/* (and bsp/<target>/project-spec/* if present)
                   -> petalinux-build -> petalinux-package
  -> yocto       : repo init/sync (rel-v2025.2 EDF manifest) -> sdtgen + gen-machineconf parse-sdt
                   -> bsp/<target>/ (or bsp/<board>/) -> bitbake edf-linux-disk-image
  -> package     : zip the boot files into bootimages/
```

Build a single stage on its own with `./build.sh <stage> --target <t>`; the
runner still builds any missing prerequisite stages first.

Per-target lock files (`.<target>.lock` at the repository root) prevent two
concurrent builds of the same target from clobbering each other — so two
terminals can safely both run `./build.sh all --target all`.

## Vivado side

### Block design

The block-design scripts live under `Vivado/src/bd/`:

* `bd_mb.tcl`     — MicroBlaze targets (`auboard`).
* `bd_zynqmp.tcl` — Zynq UltraScale+ targets.
* `bd_versal.tcl` — Versal targets (`vck190_fmcp1`, `vck190_fmcp2`, `vek280`). It sources
  `dvi_out.tcl`, which builds the DVI output hierarchy and adds the RTL from `Vivado/src/hdl/dvi/`
  and the board's `dvi_<board>.xdc` to the project. On Versal the MIPI pins come only from the
  target's XDC (`mipi_locs.tcl` is not used).
* `mipi_locs.tcl` — Tcl dictionary mapping each target to its MIPI
  lane placement, sourced by the family scripts.

Each family script contains per-board conditional blocks where a
target needs to deviate from the family defaults — typically for clock
routing, PS configuration, or PL pinout.

After sourcing the BD script, `scripts/build.tcl` runs
`validate_bd_design -force`, which triggers parameter propagation and
fills in connection-automation rules. As a result the final
implemented design may contain nets that aren't visible in the BD TCL
source — to see the actual netlist as built, inspect the saved `.bd`
file under `Vivado/<target>/<target>.srcs/sources_1/bd/<bd_name>/` or
use `write_bd_tcl` to export a complete script from an open project.

### Constraints

`Vivado/src/constraints/<target>.xdc` contains pin assignments and any
target-specific timing constraints. Constraints common to all targets
of a given family are not factored out — each target's XDC is
self-contained.

### Build scripts

* `Vivado/scripts/build.tcl` creates the Vivado project, adds the
  target's XDC, sources the appropriate `bd_*.tcl`, and validates the
  block design. Invoked via `./build.sh project --target <t>`.
* `Vivado/scripts/xsa.tcl` opens the existing project, runs synthesis
  and implementation, exports the XSA, and writes the bitstream into
  the implementation run directory. Invoked via `./build.sh xsa --target <t>`.

Both scripts check `XILINX_VIVADO` to confirm the installed Vivado
version matches the `version_required` constant at the top of the
file.

### Modifying the block design

Edit the block-design script for the appropriate processor family
directly. If the change applies only to some targets in the family,
wrap the additions in the appropriate per-board conditional block.

Once the script is edited, delete any existing per-target Vivado
project directory (`rm -rf Vivado/<target>`) and re-run the Vivado
build:

```
./build.sh xsa --target <target>
```

This re-creates the project, sources the modified BD script, runs
`validate_bd_design`, synthesises, implements, and re-exports the XSA.
Downstream Vitis / PetaLinux / boot-image steps will pick up the new
XSA on the next build.

### Adding or modifying constraints

Edit `Vivado/src/constraints/<target>.xdc` directly. If a constraint
applies to all targets in a family, it still needs to be replicated to
each target's XDC.

## Vitis side

The standalone (baremetal) build is a camera bring-up application. There are two
applications, chosen by the processor in the hardware design (`src` in `args.json`):

* **AUBoard (MicroBlaze)**, `Vitis/microblaze/src/`: programmes the on-board clock generator
  (IDT 8T49N24x), the HDMI-out re-driver (DP159), the camera sensors, the frame-buffer IP and
  the HDMI TX pipeline.
* **Versal (Cortex-A72)**, `Vitis/versal/src/`: sets the FMC VADJ (VCK190), brings up the DVI
  output (8T49N241 clock, SN65DP159 / TMDS1204, transceivers), the Video Mixer and VTC, and the
  camera pipelines (ISP, scalers, frame buffers). See
  [Versal designs: Baremetal application](versal.md#baremetal-application).

The camera sensor drivers in `Vitis/common/src/` are shared by both applications:

| File pair                  | Purpose                                |
|----------------------------|----------------------------------------|
| `i2c.h`                    | I²C interface used by the sensor drivers (each application has its own `i2c.c`) |
| `imx219.[ch]`              | Raspberry Pi v2 camera sensor          |
| `ov5640.[ch]`              | OmniVision sensor variant              |
| `rpi_cam.[ch]`             | Sensor detection and configuration     |

AUBoard application (`Vitis/microblaze/src/`):

| File pair                  | Purpose                                |
|----------------------------|----------------------------------------|
| `i2c.c`                    | Interrupt-driven AXI IIC / PS IIC back end |
| `idt_8t49n24x.[ch]`        | Clock-generator programming            |
| `dp159.[ch]`               | HDMI re-driver programming             |
| `pipe.[ch]`                | Video-pipeline setup                   |
| `frmbuf.[ch]`              | Frame-buffer IP control                |
| `xhdmi_edid.[ch]`          | HDMI EDID handling                     |
| `xhdmiphy1*.h`             | HDMI PHY register definitions          |
| `reset_gpio.h`             | GPIO reset macros                      |
| `platform*.[ch]`, `main.c` | Platform glue and entry point          |
| `config.h`                 | Build-time configuration switches      |

Versal application (`Vitis/versal/src/`):

| File pair                  | Purpose                                |
|----------------------------|----------------------------------------|
| `main.c`                   | Bring-up order, frame-buffer polling, UART status |
| `vadj.[ch]`                | FMC VADJ (VCK190 IR38164 over the PS I2C) |
| `resets.[ch]`              | IP resets on the PMC GPIO EMIO         |
| `dvi.[ch]`                 | 8T49N241, retimer/redriver, DVI status/control |
| `display.[ch]`             | Video Mixer and VTC                    |
| `cam_pipe.[ch]`            | Camera pipelines (ISP, scalers, frame buffers) |
| `i2c.c`                    | Polled AXI IIC back end                |
| `config.h`                 | Resolutions, buffers, ISP settings, reset bit map |

### Layout

```
Vitis/
├── py/
│   ├── args.json
│   ├── build-vitis.py        <- Universal Vitis Python build driver
│   └── make-boot.py          <- BOOT.BIN / .mcs packaging
├── common/
│   └── src/                  <- Camera sensor drivers (all applications)
├── microblaze/
│   └── src/                  <- AUBoard application
├── versal/
│   └── src/                  <- Versal application
├── boot/<target>/            <- Per-target packaged boot files
└── <target>_workspace/       <- Generated Vitis workspace per target
```

### `args.json`

Key fields:

* `bd_name` — block-design name (`rpi`).
* `app_name` — name of the Vitis application (`test_app`).
* `app_template` — `"None"`: the build driver creates an empty
  application project and adds source files explicitly rather than
  scaffolding from a Vitis template.
* `src` — `"all": "common/src"`, `"mb": "microblaze/src"`, `"versal": "versal/src"`:
  the common files plus the files of the target's processor.
* `combine_bit_elf` — `false`.
* `stack_size` / `heap_size` — `0x10000` each, raised from the
  defaults so the camera-bring-up code has room.

### Modifying the standalone application

Edit the files in `Vitis/common/src/`, `Vitis/microblaze/src/` or `Vitis/versal/src/` directly. The next `./build.sh
standalone --target <t>` rebuilds the application against the existing
platform; if you've changed the hardware (XSA) you'll need a fresh
workspace (`./build.sh clean --target <t> --stage standalone` first).

## PetaLinux side

### BSP composition

The PetaLinux project for a given target is composed at build time
from up to two BSP fragments copied into the target's project
directory:

1. A **board BSP** at `PetaLinux/bsp/<board>/` — always applied.
   Provides board-specific kernel and U-Boot configuration, the
   system device-tree fragment for the board, the `initcams` startup
   scripts (`recipes-apps/initcams/`), and any board-specific patches.
2. An **optional per-target BSP overlay** at `PetaLinux/bsp/<target>/`
   — applied only if the directory exists (the `cp` is prefixed with
   `-` in `PetaLinux/Makefile`, which the build runner calls for this
   stage, so a missing directory is not an error).
   Currently `zcu102_hpc1/` is the only such overlay, used to
   override the base `zcu102/` BSP for the `zcu102_hpc1` target.

There is no port-config overlay here; the structure of the imaging
pipeline doesn't vary per port the way the Ethernet-FMC ports do.

### Layout of a board BSP

```
PetaLinux/bsp/<board>/project-spec/
├── configs/
│   ├── config                <- petalinux-config: bootargs, rootfs, hostname
│   ├── rootfs_config         <- petalinux-config -c rootfs: included packages
│   ├── init-ifupdown/
│   │   └── interfaces        <- /etc/network/interfaces
│   └── busybox/
│       └── inetd.conf
└── meta-user/
    ├── conf/
    │   ├── user-rootfsconfig <- declares additional rootfs config options
    │   ├── petalinuxbsp.conf
    │   └── layer.conf
    ├── recipes-apps/
    │   └── initcams/         <- Camera-init / display-camera shell scripts
    │       ├── initcams.bb
    │       └── files/
    │           ├── init_cams.sh
    │           └── displaycams.sh
    ├── recipes-bsp/
    │   ├── device-tree/
    │   │   ├── device-tree.bbappend
    │   │   └── files/
    │   │       └── system-user.dtsi    <- board-specific DT additions
    │   ├── u-boot/
    │   │   ├── u-boot-xlnx_%.bbappend
    │   │   └── files/
    │   │       ├── bsp.cfg
    │   │       ├── platform-top.h
    │   │       └── *.patch
    │   └── embeddedsw/                 <- (zcu104 only)
    │       ├── fsbl-firmware_%.bbappend
    │       └── files/
    │           └── zcu104_vadj_fsbl.patch
    ├── recipes-kernel/
    │   └── linux/
    │       ├── linux-xlnx_%.bbappend
    │       └── linux-xlnx/
    │           └── bsp.cfg             <- kernel Kconfig additions
    └── recipes-modules/                <- (pynqzu only)
        └── wilc/                       <- WiFi driver source patches
```

### Adding a package to the root filesystem

1. Append the new option to `bsp/<board>/project-spec/configs/rootfs_config`.
2. If the package is not in the default `petalinux-config -c rootfs`
   menu, also append a declaration line to
   `bsp/<board>/project-spec/meta-user/conf/user-rootfsconfig`.
3. If the package is not provided by an existing meta-layer, add a
   recipe under
   `bsp/<board>/project-spec/meta-user/recipes-apps/<package>/<package>.bb`.

### Adding a kernel config option

Append the option to
`bsp/<board>/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg`.

### Adding a device-tree fragment

Edit
`bsp/<board>/project-spec/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`.
If you add new files, ensure they are listed in `SRC_URI:append` in
`device-tree.bbappend`.

### Adding a kernel patch or out-of-tree driver

1. Drop the patch file into
   `bsp/<board>/project-spec/meta-user/recipes-kernel/linux/linux-xlnx/`.
2. Add `SRC_URI:append = " file://<your-patch>.patch"` to
   `recipes-kernel/linux/linux-xlnx_%.bbappend`.

For full out-of-tree modules, add a recipe under
`recipes-modules/<modname>/` (see `bsp/pynqzu/.../recipes-modules/wilc/`
as a working example — it builds the WILC WiFi driver and applies a
PYNQ-ZU-specific patch).

### Modifying U-Boot

The same pattern as the kernel, under
`bsp/<board>/project-spec/meta-user/recipes-bsp/u-boot/`. `bsp.cfg`
adds U-Boot Kconfig options; `platform-top.h` overrides the U-Boot
platform header; patches are listed in `SRC_URI:append` in
`u-boot-xlnx_%.bbappend`.

## Yocto side

The Yocto flow (AMD Embedded Development Framework, release 2025.2)
generates its own machine configuration from the Vivado XSA: `sdtgen`
turns the XSA into a System Device Tree, and `gen-machineconf parse-sdt`
creates the machine `rpi-<target>` and the Linux device tree from it.
The PL hardware (capture pipelines, Video Mixer, VTC, Clocking Wizard)
therefore comes from the design itself. The bitstream is embedded in
`BOOT.BIN` and the FSBL programs the PL at boot. The engine is in
`Yocto/scripts/` (`init-workspace.sh`, `configure-build.sh`,
`build-image.sh`, `package-output.sh`); `Yocto/README.md` describes
it in more detail.

### BSP composition

The runner uses `Yocto/bsp/<target>/` when that directory exists, and
`Yocto/bsp/<board>/` otherwise. `zcu102_hpc1/` is a complete BSP for
that target (the HPC1 design has only two capture pipelines); the
other Zynq UltraScale+ targets use their board's BSP. Each Versal
target has its own BSP (`vck190_fmcp1/`, `vck190_fmcp2/`, `vek280/`),
because the camera set differs per target; their `bblayers-extra.txt`
adds the `Yocto/bsp/dvi-out/` layer (the `dvi-init` service and
`dvi-status` tool, the DVI output device tree with the `panel-dpi`
bridge and the 8T49N241 clock, and a Video Mixer kernel patch). On
Versal the kernel command line is the `options` line of the
systemd-boot entry; the BSP appends `BSP_EXTRA_BOOTARGS` to it, and
the VCK190 BSPs add the U-Boot commands that set VADJ to 1.2V.

```
Yocto/bsp/<board>/
├── conf/
│   └── local.conf.append      <- hostname, kernel command line arguments (BSP_EXTRA_BOOTARGS)
└── meta-user/
    ├── conf/layer.conf
    ├── recipes-apps/initcams/ <- init_cams.sh, displaycams.sh (same as PetaLinux)
    ├── recipes-bsp/
    │   ├── device-tree/files/system-user.dtsi   <- camera / display bindings, board fixups
    │   ├── u-boot/u-boot-edf-scr_%.bbappend     <- adds BSP_EXTRA_BOOTARGS to boot.scr
    │   ├── embeddedsw/                          <- (zcu104 only) FSBL VADJ patch
    │   ├── wilc3000-firmware/                   <- (pynqzu only) Wi-Fi firmware
    │   └── ...
    ├── recipes-connectivity/wifi-sta-config/    <- (pynqzu only) wlan0 + wifi-sta-setup
    ├── recipes-core/images/edf-linux-disk-image.bbappend  <- image packages
    └── recipes-kernel/linux/
        ├── linux-xlnx_%.bbappend               <- kernel config fragment + patches
        └── linux-xlnx/                         <- bsp.cfg and the kernel patches
```

### What the Yocto BSPs add

* **Kernel command line.** In the EDF boot flow the kernel command
  line is built by the U-Boot boot script (`boot.scr`) from the device
  tree's `/chosen/bootargs` and the root device; `APPEND` in
  `local.conf` is not used. `u-boot-edf-scr_%.bbappend` appends
  `BSP_EXTRA_BOOTARGS` from `local.conf.append` to the script:
  `cma=1536M xlnx_mixer.connect_drm_bridge=1` (`cma=1000M` on the
  UltraZed-EV).
* **Hostname** `<board>-rpi-2025-2`, set with
  `hostname:pn-base-files:forcevariable` (a plain
  `hostname:pn-base-files` is overridden by the EDF distribution's
  default, `amd-edf`).
* **Device tree (`system-user.dtsi`)**: the IMX219 sensors on the
  camera I2C buses and the bindings of the CSI-2 RX, ISP, VPSS and
  capture pipelines; the Video Mixer, VTC and DisplayPort wiring (as
  for PetaLinux, see [DisplayPort and Video Mixer pipeline
  fixes](#displayport-and-video-mixer-pipeline-fixes)); the 27 MHz
  DP reference clock of the PS-GTR on the ZCU102, ZCU104, ZCU106 and
  UltraZed-EV;
  a deterministic `ttyPS0` console; SD card fixes on the ZCU104.
* **PL clock rates.** Like the PetaLinux BSPs, the Yocto BSPs override
  the PL clocks `misc_clk_N` of the generated device tree with fixed clocks. The
  device-tree generator of the Yocto flow numbers the 250 MHz video
  clock `misc_clk_0` and the 100 MHz AXI-Lite clock `misc_clk_1`, the
  reverse of the PetaLinux flow, so the Yocto BSPs set
  `misc_clk_0` = 250 MHz and `misc_clk_1` = 100 MHz. The display
  Clocking Wizard's input is `misc_clk_0`, and the `clk-wizard` driver
  computes its settings from that rate (see
  [Troubleshooting](troubleshooting.md#kernel-panic-at-the-display-mode-set)).
* **Board Ethernet (ZCU102, ZCU104, ZCU106).** The generated device
  tree does not describe the board's TI DP83867 Ethernet PHY, so Linux
  used the generic PHY driver and never programmed the RGMII clock
  delays: the link came up at 1 Gb/s but passed no packets. The BSPs
  add the PHY node with its delay settings (both possible PHY
  addresses on the ZCU102, which depend on the board revision) and a
  fixed MAC address.
* **Kernel patches**: the three DRM patches and the two ISP Pipeline
  driver patches described below, the same as in the PetaLinux BSPs.
* **Kernel configuration (`bsp.cfg`)**: the IMX219 and OV5640 sensor
  drivers, and on the PYNQ-ZU the Wi-Fi driver.
* **Image packages**: `v4l-utils`, `media-ctl`, `libcamera`, the
  `initcams` scripts, `modetest` (`libdrm-tests`) and GStreamer with
  `v4l2src`, `kmssink`, compositor, videoconvertscale and
  videotestsrc; `gstreamer-vcu-examples` on targets with a VCU.
* **PYNQ-ZU Wi-Fi.** The on-board Microchip WILC3000 is supported by
  the in-tree `wilc1000` driver with a backport of the mainline
  WILC3000 support (`0010-wifi-wilc1000-backport-WILC3000-support.patch`),
  the WILC3000 firmware, and a power-up sequence in the device tree
  that uses only standard kernel drivers (chip enable as the SD
  interface's supply regulator, reset through `mmc-pwrseq-simple`).
  A second patch
  (`0011-wifi-wilc1000-refuse-config-requests-before-the-first-open.patch`)
  fixes the first bring-up of `wlan0`: a configuration request sent
  before the firmware was loaded broke the first firmware start.
  The `wifi-sta-config` recipe ships `wifi-sta-setup`, a DHCP
  configuration for `wlan0`, and starts `wpa_supplicant` for `wlan0`
  once credentials exist. The console getty runs on `ttyPS0` only
  (the default second getty on `ttyPS1` kept failing, as that UART does
  not reach the USB-UART on this board).

## Modifications layered on the stock BSPs

The PetaLinux board BSPs in this repository started as the corresponding stock
AMD reference BSPs and have been modified in the following ways. This
list is the answer to *"what would I lose if I overwrote the BSP with
the stock one?"* — it is what to re-apply if you ever do that.

### All BSPs

#### Camera / userspace

* **Hostname / product name** set in `configs/config` via
  `CONFIG_SUBSYSTEM_HOSTNAME` and `CONFIG_SUBSYSTEM_PRODUCT`.
* **SD-card root filesystem** configured in `configs/config`:
  `CONFIG_SUBSYSTEM_ROOTFS_EXT4`, `CONFIG_SUBSYSTEM_SDROOT_DEV`,
  `CONFIG_SUBSYSTEM_USER_CMDLINE` (with `cma=` raised for the video
  frame buffers, and `xlnx_mixer.connect_drm_bridge=1` to select the
  DRM-bridge code path in the Video Mixer driver — see kernel patches
  below).
* **Custom `system-user.dtsi`** with device-tree nodes for the
  RPi-camera I²C bus, the camera sensors, the clock generator, and
  the frame-buffer / video pipeline.
* **`recipes-apps/initcams/`** providing the `init_cams.sh` and
  `displaycams.sh` startup scripts (init the cameras, bring up the
  display pipeline).
* **`v4l-utils` and `yavta`** packages added to `rootfs_config`
  under the project customizations marker.
* **U-Boot patch `0001-ubifs-distroboot-support.patch`**.

(advanced-dp-bridge-fixes)=
#### DisplayPort and Video Mixer pipeline fixes

In Vitis/PetaLinux 2025.2, the kernel DRM stack and the SDT BSP
generator both got stricter in ways that break the v_mix → dpsub
"live video" pipeline used by `displaycams.sh`. The following
modifications are layered on every ZynqMP BSP in this repo (PetaLinux
and Yocto) to keep DP working. They are all gated to the v_mix DRM-bridge code path,
so they are no-ops on any board that doesn't use it.

* **Device-tree additions to `system-user.dtsi`**:
  - **Remove** the auto-generated `dp_port: port@0` block from inside
    `&zynqmp_dpsub` — the 2025.2 dpsub driver expects port endpoints
    inside the generated `ports { … }` subnode, not as a stray
    `port@0` at the dpsub root.
  - **Wire `&live_video`** (port@0 of dpsub's `ports`) endpoint to
    the v_mix CRTC port.
  - **Wire `&out_dp`** (port@5 of dpsub's `ports`) endpoint to a new
    top-level `dp-connector` node — the driver requires *some* sink
    on the DP output side or it fails probe with `DP output port not
    connected`.
  - **`xlnx,bridge = <&display_pipeline_v_tc_0>;`** and
    **`xlnx,video-format = <2>;`** added to `&display_pipeline_v_mix_0`
    — the 2025.2 xlnx-mixer driver requires both (otherwise probe
    fails with `vtc bridge property not present` /
    `'xlnx,video-format' property missing`). The value `2` selects
    YUV422, which matches the NV16 primary layer.
* **Kernel patches** in
  `recipes-kernel/linux/linux-xlnx/`, registered in
  `linux-xlnx_%.bbappend`:
  - `0001-drm-xlnx-mixer-fix-NULL-deref-in-connector_init.patch` —
    fixes a kernel NULL deref at probe time in
    `xlnx_mix_connector_init()` and fixes shutdown-time
    use-after-free ordering by switching the encoder allocation from
    `devm_kzalloc(&mixer->master->dev, …)` (where `mixer->master`
    is NULL during bind) to `drmm_kzalloc(mixer->drm, …)`, and from
    `drm_simple_encoder_init()` to `drmm_encoder_init()` (so the
    encoder cleanup is registered as a drm_managed action and runs
    in the right LIFO order during teardown).
  - `0002-drm-xlnx-drv-drop-mode_config_cleanup-on-unbind.patch` —
    removes the manual `drm_mode_config_cleanup(drm)` call from
    `xlnx_unbind()`. The 2025.2 `drm_bridge_connector_init()`
    registers the connector via drm_managed, and calling
    `drm_mode_config_cleanup` manually before `drm_dev_put` causes
    a double cleanup of the connector (`ida_free called for id=0
    which is not allocated`, then NULL deref in
    `drm_connector_cleanup_action`).
  - `0003-drm-xlnx-drv-disable-vblank-before-cleanup-on-shutdown.patch`
    — adds `drm_atomic_helper_shutdown(drm)` at the start of
    `xlnx_unbind()` so vblank is disabled before drm_managed
    teardown runs. Without this, shutdown emits a non-fatal but
    noisy `drm_WARN_ON(vblank->enabled && …)` in
    `drm_vblank_init_release`.
* **`xlnx_mixer.connect_drm_bridge=1`** added to
  `CONFIG_SUBSYSTEM_USER_CMDLINE`. This kernel module parameter
  selects the new DRM-bridge code path in `xlnx_mixer.c` (the
  legacy path tries to look up the dpsub via `xlnx,disp-bridge`,
  but the 2025.2 dpsub no longer registers as an `xlnx_bridge` —
  so that lookup fails, the mixer's encoder/connector never get
  set up, and `modetest` reports zero connectors).

#### ISP Pipeline driver fixes

Two kernel patches to the ISP Pipeline driver
(`drivers/media/platform/xilinx/xilinx-isppipeline.c`) are in
`recipes-kernel/linux/linux-xlnx/` of every ZynqMP BSP (PetaLinux and
Yocto) and registered in `linux-xlnx_%.bbappend`:

* `0004-media-xilinx-isppipeline-fix-gamma-LUT-plane-order.patch` —
  the core holds one 256-entry gamma table per colour plane, in the
  B, G, R plane order of its internal pixel (blue at offset `0x800`,
  green at `0x900`, red at `0xA00`). The driver wrote the red table to
  the blue plane, the blue table to the green plane and the green
  table to the red plane, so `red_gamma` acted on blue, `green_gamma`
  on red and `blue_gamma` on green. Combined with a default green
  gamma of 1.5 (red and blue 2.0), this gave every camera picture a
  magenta cast. The patch writes each table to its own plane and sets
  the green default to 2.0, so the default output is colour neutral.
* `0005-media-xilinx-isppipeline-use-the-DT-gain-and-threshold.patch` —
  the driver reads the `xlnx,rgain`, `xlnx,bgain` and `xlnx,pawb`
  device-tree properties, but then created the `red_gain`, `blue_gain`
  and `threshold` controls with fixed defaults (100, 350 and 512),
  which overwrote the device-tree values at probe. The patch uses the
  device-tree values as the control defaults (128, 210 and 350 in the
  BSPs of this design).

### ZCU104 BSP

* **FSBL patch `zcu104_vadj_fsbl.patch`** in
  `recipes-bsp/embeddedsw/files/`, registered via
  `fsbl-firmware_%.bbappend`. The ZCU104 does not expose VADJ
  control to user logic, so the FSBL is patched to program the
  on-board IRPS5401 PMBus regulator to 1.8V before the FMC PHYs come
  out of reset.
* **27 MHz `dp_phy_refclk` fixed-clock** declared in
  `system-user.dtsi`, with `&psgtr { clocks = <&dp_phy_refclk>;
  clock-names = "ref3"; };` overriding the auto-generated psgtr
  node. See [ZCU106 BSP](#zcu106-bsp) below for the rationale —
  this is the same fix.

(zcu106-bsp)=
### ZCU106 BSP

* **27 MHz `dp_phy_refclk` fixed-clock** in `system-user.dtsi`,
  wired to `&psgtr { clocks = <&dp_phy_refclk>; clock-names = "ref3"; };`.
  The auto-generated `pcw.dtsi` enables `&psgtr` and tells the
  dpsub to consume refclk index 3 (`xlnx,phys = <&psgtr X 6 X 3>`),
  but does not declare any clocks on the psgtr node itself. As a
  result the 2025.2 psgtr driver's `xpsgtr_xlate()` rejects refclk
  3 at `devm_phy_get` time with `Invalid reference clock number 3`,
  and the dpsub fails to probe (`failed to get PHY lane 0`).
  Declaring a fixed-clock at the rate FSBL programs the on-board
  Si5341 to emit on the DP ref-clock pin (27 MHz) makes the
  psgtr driver's SSC lookup succeed.

### ZCU102 BSP

* Used as the base BSP for both the `zcu102_hpc0` target and
  (overlaid by `bsp/zcu102_hpc1/`) the `zcu102_hpc1` target.
* **27 MHz `dp_phy_refclk` fixed-clock** in `system-user.dtsi`,
  same fix as documented under [ZCU106 BSP](#zcu106-bsp). The
  ZCU102 has the same auto-generated psgtr-without-clocks problem
  and needs the same workaround.

### UltraZed-EV (uzev) BSP

* **`CONFIG_YOCTO_MACHINE_NAME="zynqmp-generic"`** in `configs/config`
  (the UZ-EV is not a stock Xilinx eval board).
* **SD-card device set to `/dev/mmcblk1p2`** rather than the ZynqMP
  default `mmcblk0p2`.
* **`PRIMARY_SD_PSU_SD_1_SELECT=y`** to route the boot SD interface
  through PSU SD1 instead of SD0.
* **Custom `system-user.dtsi`** with UZ-EV-specific peripheral
  configuration. Note: uzev already declares `gtr_clk3` as a
  27 MHz fixed-clock and assigns it to `&psgtr` `clock-names =
  "ref3"`, so it does **not** need the `dp_phy_refclk` workaround
  that ZCU104 / ZCU106 / ZCU102 use — the dpsub probe succeeds on
  uzev out of the box.

### PYNQ-ZU BSP

* **WILC Wi-Fi driver recipe** under
  `recipes-modules/wilc/` with patch
  `0001-wilc-pynqzu.patch`, which builds Microchip's out-of-tree
  `wilc1000` driver for the PYNQ-ZU. It is not part of the default
  root filesystem; the Yocto BSP supports the on-board Wi-Fi instead
  (see [Yocto side](#yocto-side)).
* Like uzev, pynqzu already declares its DP refclk (`dp_clk` at
  "ref1") in its own `&psgtr { … }` block, so it does **not** need
  the `dp_phy_refclk` fixed-clock workaround.

### `zcu102_hpc1` per-target overlay

* **Per-target BSP at `bsp/zcu102_hpc1/`** (in addition to the base
  `bsp/zcu102/`) that overrides device-tree nodes to wire the camera
  pipeline through the HPC1 connector instead of HPC0. All other
  modifications (kernel patches, cmdline, dpsub/v_mix dtsi fixes)
  come from `bsp/zcu102/` unchanged via the two-stage copy in
  `PetaLinux/Makefile`: `cp -R bsp/$(TARGET_BOARD)/project-spec` +
  `cp -R bsp/$(TARGET)/project-spec`.

## Where build outputs land

| Path                                | Contents                                                                       |
|-------------------------------------|--------------------------------------------------------------------------------|
| `Vivado/<target>/`                  | Vivado project. `<bd_name>_wrapper.xsa` is the export.                          |
| `Vivado/<target>/<target>.runs/impl_1/<bd_name>_wrapper.bit` | Bitstream.                                              |
| `Vivado/logs/`                      | Per-target Vivado build logs.                                                   |
| `Vitis/<target>_workspace/`         | Per-target Vitis workspace.                                                     |
| `Vitis/boot/<target>/`              | Packaged Vitis boot files (`BOOT.BIN` for Zynq/ZynqMP, `.mcs` for MicroBlaze).  |
| `PetaLinux/<target>/`               | PetaLinux project. All Yocto build state lives here.                            |
| `PetaLinux/<target>/images/linux/`  | `BOOT.BIN`, `image.ub`, `boot.scr`, `rootfs.tar.gz`, etc.                       |
| `PetaLinux/<target>/build/build.log`| PetaLinux build log.                                                            |
| `Yocto/<target>/`                   | Yocto workspace (sources, `build/`, generated machine and System Device Tree).  |
| `Yocto/<target>/images/linux/`      | `BOOT.BIN`, `boot.scr`, `Image`, `system.dtb`, `rootfs.wic.xz`, `rootfs.wic.bmap`, `rootfs.tar.gz`. |
| `bootimages/`                       | Per-target zipped boot files.                                                   |

None of these directories are committed to the repository.
