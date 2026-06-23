# Advanced: project structure and customization

This section is intended for users who want to modify the reference
designs — adding IP to the block design, changing constraints, modifying
the standalone application, or adding packages or drivers to the
PetaLinux project. It describes how the repository is laid out, how the
build flow works, how the Vitis and PetaLinux sides are
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
├── PetaLinux/
│   └── bsp/                   <- Per-board (and optional per-target) BSP fragments
│       └── pynqzu/, uzev/, zcu102/, zcu102_hpc1/, zcu104/, zcu106/
├── submodules/                <- Vendor board definition files (BDFs)
├── Vivado/
│   ├── scripts/
│   │   ├── build.tcl          <- Project creation + block design assembly
│   │   └── xsa.tcl            <- Synthesis, implementation, XSA export
│   └── src/
│       ├── bd/
│       │   ├── bd_mb.tcl      <- Block design for MicroBlaze targets
│       │   ├── bd_zynqmp.tcl  <- Block design for Zynq UltraScale+ targets
│       │   └── mipi_locs.tcl  <- Per-target MIPI lane placement constants
│       └── constraints/
│           └── <target>.xdc   <- One XDC per target (pin assignments, timing)
└── Vitis/
    ├── py/
    │   ├── args.json          <- Repo-specific Vitis flow configuration
    │   ├── build-vitis.py     <- Universal Vitis Python build driver
    │   └── make-boot.py       <- BOOT.BIN packaging
    ├── common/
    │   └── src/               <- Standalone application source (camera bring-up)
    └── <target>_workspace/    <- Per-target Vitis workspace (generated)
```

Per-target build outputs are written to `Vivado/<target>/`,
`Vitis/<target>_workspace/`, and `PetaLinux/<target>/`; packaged
boot-image zips are written to `bootimages/`. None of these are
committed.

There is no port-config overlay in this repository — there is at most
one Raspberry Pi camera array per design, and per-target customisation
is done via per-target BSP overlays where needed (see
[PetaLinux side](#petalinux-side) below).

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
the BSP under `PetaLinux/bsp/<board>/`.

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
| `project`    | Create the Vivado project (`.xpr`) and block design.                                   |
| `xsa`        | Synthesise, implement and export the hardware (`.xsa`).                                 |
| `standalone` | Create the Vitis workspace, build the baremetal app, package `BOOT.BIN` / `.mcs`.      |
| `petalinux`  | Create the PetaLinux project from the XSA, apply the BSP overlays, build and package.   |
| `package`    | Gather the built boot artifacts into `bootimages/*.zip`.                               |
| `all`        | Build every stage the target supports, then `package`.                                 |

Run `./build.sh list` to see the targets and their attributes, `./build.sh
status --target <t>` for per-stage artifact state, and `./build.sh --help`
for the full command list.

Each target is flagged in `config/data.json` for the stages it supports —
the MicroBlaze target (`auboard`) is baremetal-only (no PetaLinux), while
the ZynqMP targets support the PetaLinux flow as well. Because each stage
builds its prerequisites first, a single `./build.sh all --target <t>`
cascades the whole pipeline:

```
./build.sh all --target t
  -> xsa         : vivado creates the project (build.tcl), then synth/impl/XSA export (xsa.tcl)
  -> standalone  : vitis builds the platform + app, packages BOOT.BIN / .mcs
  -> petalinux   : petalinux-create -> -config --get-hw-description <XSA>
                   -> copy bsp/<board>/project-spec/* (and bsp/<target>/project-spec/* if present)
                   -> petalinux-build -> petalinux-package
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

The standalone (baremetal) build is a camera bring-up application —
it programmes the on-FMC clock generator (IDT 8T49N24x), the HDMI-out
re-driver (DP159), the camera sensor (IMX219 / OV5640), the
frame-buffer IP, and the HDMI pipeline. The source files in
`Vitis/common/src/` are grouped by device:

| File pair                  | Purpose                                |
|----------------------------|----------------------------------------|
| `i2c.[ch]`                 | Generic I²C helpers                    |
| `idt_8t49n24x.[ch]`        | Clock-generator programming            |
| `dp159.[ch]`               | HDMI re-driver programming             |
| `imx219.[ch]`              | Raspberry Pi v2 camera sensor          |
| `ov5640.[ch]`              | OmniVision sensor variant              |
| `rpi_cam.[ch]`             | High-level camera initialisation       |
| `pipe.[ch]`                | Video-pipeline setup                   |
| `frmbuf.[ch]`              | Frame-buffer IP control                |
| `xhdmi_edid.[ch]`          | HDMI EDID handling                     |
| `xhdmiphy1*.h`             | HDMI PHY register definitions          |
| `reset_gpio.h`             | GPIO reset macros                      |
| `platform*.[ch]`, `main.c` | Platform glue and entry point          |
| `config.h`                 | Build-time configuration switches      |

### Layout

```
Vitis/
├── py/
│   ├── args.json
│   ├── build-vitis.py        <- Universal Vitis Python build driver
│   └── make-boot.py          <- BOOT.BIN / .mcs packaging
├── common/
│   └── src/                  <- Application source (see table above)
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
* `src` — `"all": "common/src"`.
* `combine_bit_elf` — `false`.
* `stack_size` / `heap_size` — `0x10000` each, raised from the
  defaults so the camera-bring-up code has room.

### Modifying the standalone application

Edit `Vitis/common/src/*.c` (or `.h`) directly. The next `./build.sh
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
   `-` in the Makefile so a missing directory is not an error).
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

## Modifications layered on the stock BSPs

The board BSPs in this repository started as the corresponding stock
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
#### 2025.2 DP / Video Mixer pipeline fixes

In Vitis/PetaLinux 2025.2, the kernel DRM stack and the SDT BSP
generator both got stricter in ways that break the v_mix → dpsub
"live video" pipeline used by `displaycams.sh`. The following
modifications are layered on every ZynqMP BSP in this repo to keep
DP working. They are all gated to the v_mix DRM-bridge code path,
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

* **WILC WiFi driver overlay** under
  `recipes-modules/wilc/` with patch
  `0001-wilc-pynqzu.patch`, adding support for the WILC1000 module
  fitted on the PYNQ-ZU carrier.
* Like uzev, pynqzu already declares its DP refclk (`dp_clk` at
  "ref1") in its own `&psgtr { … }` block, so it does **not** need
  the `dp_phy_refclk` fixed-clock workaround.

### `zcu102_hpc1` per-target overlay

* **Per-target BSP at `bsp/zcu102_hpc1/`** (in addition to the base
  `bsp/zcu102/`) that overrides device-tree nodes to wire the camera
  pipeline through the HPC1 connector instead of HPC0. All other
  modifications (kernel patches, cmdline, dpsub/v_mix dtsi fixes)
  come from `bsp/zcu102/` unchanged via the Makefile's two-stage
  `cp -R bsp/$(TARGET_BOARD)/project-spec` + `cp -R bsp/$(TARGET)/project-spec`.

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
| `bootimages/`                       | Per-target zipped boot files.                                                   |

None of these directories are committed to the repository.
