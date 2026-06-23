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

## Boot: `modetest` reports zero connectors / monitor stays dark

If `modetest -M xlnx` lists no connectors, or `displaycams.sh` shows no video on the
monitor even though `init_cams.sh` succeeds, check the kernel command line:

```
cat /proc/cmdline
```

The string `xlnx_mixer.connect_drm_bridge=1` must be present. Without it the 2025.2
`xlnx_mixer` driver falls back to the legacy `xlnx,disp-bridge` lookup, which fails
on the 2025.2 dpsub. See
[the DP / Video Mixer pipeline notes](advanced.md#advanced-dp-bridge-fixes) for the
underlying cause and the patches / device-tree edits that make this work.

## Monitor goes dark when `modetest` picks a high-refresh mode

The pixel-clock wizard in the FPGA fabric is configured for **1080p60 only**. If you
let `modetest` pick the monitor's preferred mode (e.g. 144 Hz or 4K), the dpsub will
silently fail to drive valid pixels and the monitor will stay dark. Always pin the
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
