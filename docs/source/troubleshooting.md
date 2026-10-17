# Troubleshooting

## Build failures

Check the following if the project fails to build or generate a bitstream:

1. **Are you using the correct version of Vivado for this version of the repository?**
   Check the version specified in the [Requirements](requirements) section. The 2025.2
   branch of this repository requires Vivado / Vitis / PetaLinux 2025.2 — older versions
   are not supported.

2. **Did you follow the** [build instructions](build_instructions) **?**
   If it still doesn't build, please let us know and provide details of your setup and the error message(s).

## PetaLinux build fails with `bitbake petalinux-image-minimal failed` and sstate fetch errors

If a `./build.sh petalinux --target <board>` run ends with errors like

```
ERROR: <package>-<ver>-r0 do_..._setscene: Fetcher failure: Unable to find file file://.../sstate:...
[ERROR] Command bitbake petalinux-image-minimal failed
```

the actual build is not broken. These `_setscene` errors come from bitbake trying to
pull prebuilt artefacts from the public Xilinx sstate-cache mirror, which occasionally
returns 404 for individual packages. Bitbake falls back to building those packages
locally and succeeds, but still exits non-zero because of the failed fetches — so the
build runner stops before the `petalinux-package` step that produces `BOOT.BIN`.

**Fix: just re-run the same command.** The second attempt finds the missing packages
in the local sstate cache (populated by the first run) and completes cleanly,
producing `BOOT.BIN`. The reference design itself is fine; this is a transient issue
with the public mirror. If you build offline (see
[PetaLinux offline build](build_instructions.md#petalinux-offline-build)) the problem
does not occur.

## The board does not boot from the SD card

* Check the boot-mode switches (see [Boot from SD card](petalinux.md#boot-from-sd-card)).
* **Yocto image:** check that `BOOT.BIN` is on the first (FAT, `esp`) partition of the card.
  Flashing `rootfs.wic.xz` alone is not enough; see [Prepare the SD card](yocto.md#prepare-the-sd-card).
* **PetaLinux image:** the first partition must be FAT32 and hold `BOOT.BIN`, `boot.scr` and
  `image.ub`; the root filesystem goes on the second (ext4) partition.
* **Versal (VCK190, VEK280):** the first partition must also hold `EFI/BOOT/BOOTAA64.EFI`, or the
  boot stops at the U-Boot prompt; use a card of 16 GB or more. See
  [Versal designs](versal.md#troubleshooting).

## Harmless boot messages

Each capture pipeline logs this pair of messages about 2 to 3 seconds into the boot:

```
xilinx-video amba_pl:vcap_mipi_0_v_proc: /amba_pl/vcap_mipi_0_v_proc/ports/port@0 initialization failed
xilinx-video amba_pl:vcap_mipi_0_v_proc: DMA initialization failed
```

They are harmless: the pipeline is probed again a moment later, once the parts it depends on are
ready, and the camera then appears in `v4l2-ctl --list-devices`.

## A camera is not detected

If `v4l2-ctl --list-devices` or `init_cams.sh` lists fewer cameras than you connected:

* Check that the camera is on a port that the target supports: CAM0 and CAM1 only on
  `zcu102_hpc1`, CAM1 and CAM2 only on `pynqzu` (and CAM0 and CAM2 on `auboard`).
* Check the orientation and seating of the camera's ribbon cable at both ends.
* Look for the sensor and the CSI-2 receiver in the kernel log:
  `dmesg | grep -iE "imx219|csi"`.
* Check that the FMC is powered (VADJ). On the ZCU102 and ZCU106 the VADJ voltage is set
  automatically from the FMC's EEPROM at power-up; the PYNQ-ZU and UltraZed-EV carriers have a fixed
  VADJ (see [Supported carriers](supported_carriers)). On the **ZCU104**, the FSBL of this design is patched so that it
  reads the FMC's EEPROM and turns VADJ on (the stock 2025.2 FSBL does not); if you replace the BSP,
  keep the patch (`zcu104_vadj_fsbl.patch`), otherwise the FMC is not powered and no camera is
  detected.

## Kernel panic at the display mode set

**Symptom:** the first display mode set (`modetest -s ...` or `displaycams.sh`) crashes the
kernel with an `SError Interrupt` inside `xlnx_vtc_set_timing`. The board must then be
power-cycled.

**Cause:** the Clocking Wizard of the display pipeline was not able to lock to the new pixel
clock, so the Video Timing Controller was still held in reset when the driver wrote its
registers. The `clk-wizard` driver computes the new settings from the rate of the wizard's
input clock that is described in the device tree. In the Yocto BSPs of this design, the
device-tree fixed-clock overrides of the two PL clocks `misc_clk_0` and `misc_clk_1` had
their rates swapped (the device-tree generator of the Yocto flow numbers these clocks the
other way round from the PetaLinux flow), so the driver assumed a 100 MHz input instead of
250 MHz. This is fixed in the current Yocto BSPs (`misc_clk_0` = 250 MHz, `misc_clk_1` =
100 MHz); the PetaLinux BSPs were not affected.

**Check:** before any mode set, read the clock summary:

```
sudo grep clk_wiz /sys/kernel/debug/clk/clk_summary
```

The `clk_in1` of the display Clocking Wizard must run at 250 MHz, and its output
(`80010000.clk_wiz_out0`) at about 262.7 MHz after boot. An output of about 105 MHz means
that the device tree gives the wizard a 100 MHz input, and the mode set will crash. After a
good 1920x1080 60 Hz mode set the output reads 148.5 MHz. If you modify the block design or the
BSP, make sure the rates of the `misc_clk_N` overrides in `system-user.dtsi` match the clocks
of the generated device tree of your build.

## `modetest` reports zero connectors / monitor stays dark

If `modetest -M xlnx` lists no connectors, or `displaycams.sh` shows no video on the
monitor even though `init_cams.sh` succeeds, check the kernel command line:

```
cat /proc/cmdline
```

The string `xlnx_mixer.connect_drm_bridge=1` must be present. Without it the 2025.2
`xlnx_mixer` driver falls back to the legacy `xlnx,disp-bridge` lookup, which fails
on the 2025.2 dpsub. See
[the DP / Video Mixer pipeline notes](advanced.md#displayport-and-video-mixer-pipeline-fixes) for the
underlying cause and the patches / device-tree edits that make this work.

If `displaycams.sh` stops with `ERROR: could not discover DRM ids`, no connected monitor was found
(check the cable and that the monitor is on) or the display drivers did not load.

On the Versal designs, check the DVI output with `sudo dvi-status` and
`sudo dvi-status pattern on`; see [Versal designs](versal.md#troubleshooting).

## Monitor goes dark when `modetest` picks a high-refresh mode

The display pipeline is configured for **1080p60 only**. If you let `modetest` pick the
monitor's preferred mode (e.g. 144 Hz or 4K), the monitor will stay dark. Always pin the
refresh rate with the `-60` suffix:

```
modetest -M xlnx -D a0000000.v_mix -s <conn>@<crtc>:1920x1080-60@NV16
```

## `kmssink` ignores `render-rectangle` (video drawn centred on screen)

In the 2025.2 GStreamer build, two `kmssink` properties became strict:

* `render-rectangle` must use the spaced `"< x, y, w, h >"` syntax (with the spaces).
* `can-scale=true` must be set; the previous default of `false` causes
  `render-rectangle` to be silently dropped.

If your video appears centred and full-size on the screen instead of in the
requested rectangle, check both of those.

## The picture has a colour tint

**All cameras have a magenta (pink / lavender) cast**, with white walls looking pink and warm
scenes saturated red: the image was built without the ISP driver fix of this release. The
Linux driver of the ISP Pipeline wrote the three gamma tables to the wrong colour planes
(`red_gamma` acted on blue, `green_gamma` on red and `blue_gamma` on green), and its default
green gamma (1.5) differed from red and blue (2.0), which lifted the red channel. The kernel
patch `0004-media-xilinx-isppipeline-fix-gamma-LUT-plane-order.patch` in the BSPs fixes the
plane order and sets all three defaults to 2.0. Rebuild the image, or as a workaround on an
older image set equal gammas on every camera:

```
for v in $(v4l2-ctl --list-devices | grep -A1 vcap_mipi | grep -o '/dev/video[0-9]*'); do
  sudo v4l2-ctl -d $v --set-ctrl=red_gamma=20,green_gamma=20,blue_gamma=20
done
```

On a fixed image the controls read `red_gamma`, `green_gamma` and `blue_gamma` = 20 and
`red_gain` = 128, `blue_gain` = 210, `threshold` = 350 after boot (`v4l2-ctl -d /dev/video0 --list-ctrls`).

**Only one camera has a tint:** the automatic white balance of the ISP assumes that the
scene averages to grey, so a scene dominated by one colour, or a dark scene lit by coloured
light, can tint that camera's picture. Point the camera at a more varied scene, or set the
white balance by hand (see [ISP controls](testing.md#isp-controls)).

To rule out the display path, show a test pattern on the monitor (see
[Check the display path with a test pattern](testing.md#check-the-display-path-with-a-test-pattern)):
its colour bars must look correct.

## PYNQ-ZU: no Wi-Fi connection

* `wifi-sta-setup` reports `wlan0 not present`: check the driver messages with
  `dmesg | grep -i wilc`.
* No address after 60 seconds: check the network name, passphrase and country code, and the
  state of the connection with `wpa_cli -i wlan0 status`. Run `wifi-sta-setup` again to replace
  the credentials.
* The Wi-Fi support is part of the Yocto image of the PYNQ-ZU; see
  [PYNQ-ZU: Wi-Fi](yocto.md#pynq-zu-wi-fi).

## `scp` to or from the Yocto image fails

The Yocto image runs an SSH server without SFTP support. Use `scp -O` (legacy SCP protocol).
