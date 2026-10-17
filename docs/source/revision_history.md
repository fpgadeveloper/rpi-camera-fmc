# Revision History

## 2025.2 Versal designs

* Added three Versal target designs, built with the Yocto (AMD EDF) flow:
  `vck190_fmcp1` (VCK190 FMCP1, cameras `CAM0` and `CAM2`), `vck190_fmcp2` (VCK190 FMCP2,
  `CAM1`, `CAM2` and `CAM3`) and `vek280` (VEK280 FMCP, `CAM0`, `CAM1` and `CAM3`). The camera
  ports are limited by the MIPI D-PHY clocking rules of the Versal XPIO banks. See
  [Versal designs](versal).
* New DVI video output for the Versal designs (they have no DisplayPort): 1920x1080 at 60 Hz on
  the board's HDMI TX connector, built from free IP (Transceivers Wizard, Video Timing
  Controller, AXI4-Stream to Video Out) and an open-source TMDS encoder in this repository
  (`Vivado/src/hdl/dvi/`), with no HDMI IP license. The Linux image has the `dvi-init` service and
  the `dvi-status` command (status and colour-bar test pattern).
* VCK190: U-Boot sets the FMC VADJ rail to 1.2V. VEK280: the board's fixed 1.5V VADJ is used, with
  the `MIPI_DPHY` / `LVCMOS12` I/O standards as in AMD's VEK280 board file.
* The `displaycams.sh` script of the Versal images selects the RGB primary plane format of the
  Versal Video Mixer itself (the Zynq UltraScale+ designs use `NV16`).
* Baremetal application for the Versal targets (Cortex-A72, `./build.sh standalone`): shows the
  cameras in the quadrants of the HDMI monitor without Linux, and sets the VCK190 FMC VADJ itself.
  The Vitis sources are now split into `Vitis/common/src/` (camera sensor drivers),
  `Vitis/microblaze/src/` (AUBoard application) and `Vitis/versal/src/` (Versal application).
  See [Versal designs: Baremetal application](versal.md#baremetal-application).
* Documentation: new [Versal designs](versal) page and Versal display pipeline diagram.

## 2025.2 Yocto flow and fixes

* Added the Yocto / AMD EDF build flow for all of the Zynq UltraScale+ targets
  (`./build.sh yocto --target <target>`). It produces a complete SD card image
  (`rootfs.wic.xz` + `rootfs.wic.bmap`) and a `BOOT.BIN` for the first partition, and
  `./build.sh package` gathers them into `bootimages/rpi-camera-fmc_<target>_yocto-2025-2.zip`.
  `zcu102_hpc1` has its own Yocto BSP. See [Yocto](yocto).
* ISP Pipeline driver fixes (PetaLinux and Yocto BSPs, kernel patches 0004 and 0005):
  - Every camera picture had a magenta cast. The driver wrote the gamma tables to the wrong
    colour planes (`red_gamma` acted on blue, `green_gamma` on red, `blue_gamma` on green) and
    used a different default for green (1.5) than for red and blue (2.0). Each table now goes to
    its own plane and all three gammas default to 2.0.
  - The white balance gains and AWB threshold given in the device tree (`xlnx,rgain` = 128,
    `xlnx,bgain` = 210, `xlnx,pawb` = 350) were overwritten by fixed defaults at probe. They are
    now the defaults of the `red_gain`, `blue_gain` and `threshold` controls.
* Yocto images: the first display mode set crashed the kernel (`SError` in
  `xlnx_vtc_set_timing`). The device-tree fixed-clock overrides of the PL clocks `misc_clk_0`
  and `misc_clk_1` had their rates swapped for the Yocto flow, so the display Clocking Wizard was
  told its input was 100 MHz instead of 250 MHz and could not lock at the mode set. The rates
  now follow the numbering of the Yocto device-tree generator.
* Yocto images: the design's kernel command line arguments (`cma=1536M`, or `cma=1000M` on the
  UltraZed-EV, and `xlnx_mixer.connect_drm_bridge=1`) were not applied, because the EDF boot
  flow ignores `APPEND`. They are now added to the U-Boot boot script. The hostname is now
  `<board>-rpi-2025-2` (it was the EDF default, `amd-edf`).
* Yocto images: the three DRM / Video Mixer kernel patches of the PetaLinux BSPs are now also
  applied (they fix a kernel oops when the mixer probes and errors at shutdown and reboot), and
  the image includes `modetest` and the GStreamer plugins that `displaycams.sh` needs.
* Yocto images on the ZCU102, ZCU104 and ZCU106: the board Ethernet port linked at 1 Gb/s but
  passed no packets, because the generated device tree did not describe the TI DP83867 PHY and
  its RGMII delays. The PHY is now described, and the port has a fixed MAC address.
* Yocto image on the PYNQ-ZU: support for the on-board WILC3000 Wi-Fi (the board has no Ethernet
  port), with the `wifi-sta-setup` command to set the network credentials on the board. A fix
  in the driver makes the first bring-up of `wlan0` reliable. The login console now runs on
  `ttyPS0` only.
* `./build.sh package` now rewrites a boot image zip when the build artifacts are newer than the
  zip (it used to keep an existing zip, so a rebuilt image was not packaged).
* Documentation: new [Using and testing the design](testing) page for both Linux flows
  (camera enumeration, capture, display, ISP controls), the Yocto page rewritten, new
  troubleshooting entries, and the block diagrams redrawn from the block-design scripts by
  `docs/source/images/gen_block_diagram.py`.

## 2025.2 Changes

* Ported all designs to Vivado / Vitis / PetaLinux 2025.2 (Yocto scarthgap,
  Linux 6.12, U-Boot 2025.01).
* Added the AUBoard 15P (Artix UltraScale+) FPGA design with an HDMI output
  pipeline driven by a baremetal application, complementing the existing
  ZynqMP PetaLinux designs.
* Migrated the Vitis build flow to the universal Python-driven pipeline
  (`Vitis/py/build-vitis.py` + `make-boot.py`, configured via `args.json`).
* Reworked the PetaLinux BSPs to layer per-board overlays on top of the stock
  AMD reference BSPs (see [Advanced](advanced)). Per-target overlays
  (e.g. `bsp/zcu102_hpc1/`) are now applied on top of the per-board BSP
  by the PetaLinux Makefile.
* DRM / Video Mixer fixes for the v_mix → dpsub "live video" path required by
  `displaycams.sh`:
  - Three repo-local kernel patches against `linux-xlnx` that fix a probe-time
    NULL-deref and shutdown-time use-after-free in `xlnx_mixer`, drop a
    double-cleanup in `xlnx_drv`, and disable vblank before drm_managed
    teardown.
  - `xlnx,bridge` / `xlnx,video-format` properties added to
    `&display_pipeline_v_mix_0` to satisfy the 2025.2 xlnx-mixer driver.
  - The auto-generated `dp_port: port@0` removed from `&zynqmp_dpsub` and
    `&live_video` / `&out_dp` wired up explicitly in `system-user.dtsi`.
  - `xlnx_mixer.connect_drm_bridge=1` added to the kernel command line on
    every ZynqMP target to select the new DRM-bridge code path in the
    Video Mixer driver.
* ZCU102 / ZCU104 / ZCU106 BSPs now declare a 27 MHz `dp_phy_refclk`
  fixed-clock and override the auto-generated `&psgtr` node so that the
  2025.2 psgtr driver accepts refclk index 3 (otherwise dpsub probe fails
  with `Invalid reference clock number 3` / `failed to get PHY lane 0`).
* `displaycams.sh` rewritten to auto-discover DRM connector / CRTC / overlay
  plane IDs at run-time, so it works on any board without per-build edits.
* `media-ctl` topology output now includes `stream:0` prefixes and per-entity
  route counts — these are new in the 2025.2 Linux 6.12 media controller API
  (streams API support) and do not change the overall topology.
* `v4l2-ctl --list-devices` now alternates `Xilinx Video Composite Device` /
  `vcap_mipi_N_v_proc output 0` entries per connected camera (rather than the
  separated devices+media blocks of earlier releases). The init scripts and
  documentation have been updated to match.
* ISP-pipeline white-balance and gamma user controls (`red_gain`, `blue_gain`,
  `awb_en`, `threshold`, `red_gamma`, `green_gamma`, `blue_gamma`) are now
  exposed via `v4l2-ctl` on the video device.
* `cma=` raised to 1536M (1000M on UltraZed-EV) to provide headroom for four
  1080p frame buffers + DP framebuffers under the 2025.2 driver stack.
* Hostnames updated to `<board>-rpi-cam-fmc-2025-2`.

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

