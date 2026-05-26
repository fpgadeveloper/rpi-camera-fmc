# Revision History

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

