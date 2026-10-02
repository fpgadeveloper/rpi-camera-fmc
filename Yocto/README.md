# Yocto / EDF builds

This folder builds Linux images for the RPi Camera FMC reference designs
using the AMD Yocto / Embedded Development Framework (EDF) flow — the
announced successor to PetaLinux Tools. It covers the Zynq UltraScale+
target boards (ZCU102, ZCU104, ZCU106, PYNQ-ZU and the Avnet UltraZed-EV);
the bare-metal FPGA designs are not Linux targets and are not built here.

## How it works: the parse-sdt flow

The build generates a **custom Yocto MACHINE directly from the Vivado XSA** —
there is no dependency on an AMD-provided machine config. This is what lets
the design serve any board (including third-party boards with no AMD machine,
like the Avnet UltraZed-EV) and lets a customer change the PS in Vivado and
have it flow through automatically:

```
XSA  --sdtgen-->  System Device Tree  --gen-machineconf parse-sdt-->  MACHINE + DTS
```

`scripts/configure-build.sh` runs `xsct`/`sdtgen` on the XSA to produce a
System Device Tree (which includes `pl.dtsi`, the PL hardware extracted from
the design), then runs `gen-machineconf parse-sdt` to emit
`conf/machine/rpi-<target>.conf` plus the lopper-pruned per-domain device
trees (`cortexa53-linux.dts` on these ZynqMP boards). The PL camera and
display hardware — the MIPI CSI-2 capture pipelines, the ISP / VPSS scaler
chain, and the Video Mixer + VTC display pipeline — therefore come from the
design's own SDT, no hand-curated device tree. Because no PL overlay is
requested, the Vivado boot artifact (the `.bit`) is embedded into `BOOT.BIN`
(the FSBL programs the PL at boot, before Linux comes up).

The only per-board hand-written file is `system-user.dtsi`, which carries the
camera/display sensor bindings and SoC-side board quirks the XSA doesn't
encode (see "Per-board fixups" below).

## Prerequisites

Host packages on Ubuntu 22.04 / 24.04:

```
sudo apt-get install repo gawk wget git diffstat unzip texinfo gcc \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 bmap-tools
```

Plus Vivado 2025.2 (used to produce the XSA this flow consumes) and Vitis
2025.2 — `sdtgen`/`xsct` (used to turn the XSA into a System Device Tree)
ship with Vitis, not Vivado, in 2025.2. The build runner locates and sources
the Vitis environment itself; sourcing it manually is only needed when
running the `scripts/` engine by hand:

```
source <xilinx-install>/2025.2/Vitis/settings64.sh
```

## Build

Yocto images are built with the cross-platform build runner at the repo root
(this stage requires a native Linux machine; on Windows the runner refuses
it up front and prints the hand-off command):

```
./build.sh yocto --target zcu106_hpc0    # or any target from `./build.sh list`
```

The runner builds the Vivado XSA first if one isn't already present, then
sequences the four scripts in `scripts/` — the engine of the flow
(init-workspace, configure-build, build-image, package-output). The legacy
`cd Yocto && make yocto TARGET=<target>` still works on Linux (the Makefile
is now a thin wrapper around `build.sh`) but is deprecated.

The first build for a target:

1. Builds the Vivado project and exports the XSA if one isn't already
   present.
2. Initializes a manifest workspace under `Yocto/<TARGET>/` with
   `repo init -u https://github.com/Xilinx/yocto-manifests.git -b rel-v2025.2 -m default-edf.xml`
   and `repo sync` (≈5 GB of git history).
3. Sources `edf-init-build-env` to set up the bitbake environment.
4. Generates the System Device Tree from the XSA and runs
   `gen-machineconf parse-sdt` to create `MACHINE = "rpi-<target>"`
   (gen-machineconf builds its own native helpers — `kconfig-frontends-native`,
   `lopper`, etc. — via bitbake on first run).
5. Layers `bsp/<board>/conf/local.conf.append` (hostname, kernel cmdline) and
   `bsp/<board>/meta-user/` (kernel config, `system-user.dtsi` camera/display
   bindings + board fixups, image bbappend) over the EDF default config.
6. Runs `bitbake edf-linux-disk-image`.
7. Gathers `BOOT.BIN` (with the PL bitstream embedded), `Image`, `system.dtb`,
   `boot.scr`, `u-boot.elf`, `rootfs.tar.gz`, `rootfs.wic.xz`, and
   `rootfs.wic.bmap` into `Yocto/<TARGET>/images/linux/`.

Subsequent builds skip `repo sync`. To force a re-config (e.g. after editing
`bsp/<board>/conf/local.conf.append`), remove `Yocto/<TARGET>/configdone.txt`.

`./build.sh yocto --target all` builds every Yocto target; `./build.sh status --target all`
reports which are built.

## Per-board fixups (`system-user.dtsi`)

Each board's `bsp/<board>/meta-user/recipes-bsp/device-tree/files/system-user.dtsi`
is layered onto the generated Linux device tree (via `EXTRA_DT_INCLUDE_FILES`,
guarded so it only applies to the Linux domain DT — the FSBL/PMU domain DTs
don't define the SoC peripheral labels). It carries the camera/display sensor
bindings and SoC-side board quirks, not the PL hardware addresses (which come
from the XSA's SDT):

* **Camera + display pipeline** (all boards): the SDT gives the PL IP its
  addresses but not the driver-specific bindings, so `system-user.dtsi` wires
  up the IMX219 (`sony,imx219`) sensor nodes on the per-MIPI I2C buses, the
  MIPI CSI-2 RX subsystem, the ISP pipeline, the VPSS scaler, and the Video
  Mixer + VTC display path. It also enables and wires `&zynqmp_dpsub` to the
  Video Mixer CRTC and the DisplayPort connector so the live-video output
  comes up (the 2025.2 `zynqmp-dpsub` requires the endpoints inside the
  generated `ports/port@N` children).
* **UART** (all boards): the 2025.2 flow emits `port-number = <0>` on both
  `uart0` and `uart1`, leaving the `ttyPS0`/`ttyPS1` mapping to probe order.
  Each board pins the port numbers and serial aliases so the console is
  deterministic on `ttyPS0`.
* **DisplayPort PS-GTR ref clock** (`zcu104`, `zcu106`): the generated
  `pcw.dtsi` references PS-GTR refclk 3 for DP but declares no clocks on the
  `&psgtr` node, so DP probe fails with `-EINVAL` ("Invalid reference clock
  number 3"). These boards declare a 27 MHz fixed-clock (the rate FSBL
  programs the on-board Si5341 to output) and attach it as `ref3`. (`pynqzu`
  already declares its PS-GTR refclks, so it doesn't need this.)
* **SD card** (`zcu104`): the design's XSA exports a minimal `sdhci1` node, so
  `system-user.dtsi` adds the missing properties (`no-1-8-v`, `disable-wp`,
  `broken-cd`, `max-frequency = 50 MHz`, capability mask) — without them the
  kernel times out initialising the SD card with "error -110".
* **`pynqzu` only**: the TUL PYNQ-ZU is a third-party board, so its
  `system-user.dtsi` is larger — board model, CMA reserved-memory, the
  WILC3000 SDIO Wi-Fi, USB gadget/host on the PS-GTR, and the I2C power/clock
  tree. This board has video pipelines for only two cameras (`CAM1`, `CAM2`).
* **`uzev` only**: the Avnet UltraZed-EV is a third-party SOM+carrier, so its
  `system-user.dtsi` is the largest — external GTR reference clocks + `&psgtr`
  mapping, MAC EEPROM, the I2C power/clock tree, and the rest of the carrier
  peripherals. It is ported from the proven PetaLinux `uzev` BSP.

The `bsp/<board>/meta-user/recipes-kernel/linux/linux-xlnx/bsp.cfg` fragment
enables the camera sensor drivers in the kernel (`CONFIG_VIDEO_IMX219`,
`CONFIG_VIDEO_OV5640`).

## Flashing to SD card

The build produces a full wic disk image (`rootfs.wic.xz`). Flash it to the SD
card's raw device; per-partition file copies do **not** work because the boot
script boots from the device it finds itself on.

These are all Zynq UltraScale+ targets, which use the 4-partition EDF layout —
`esp` (vfat), `boot` (ext4), `root` (ext4), `storage` (vfat). The EDF wks
leaves the `esp` partition empty, and `BOOT.BIN` is installed onto the ext4
`boot` partition (which the BootROM cannot read). The BootROM reads `BOOT.BIN`
from the first FAT partition (`esp`) — so after flashing you must drop
`BOOT.BIN` onto `esp` by hand (step 4 below). The kernel command line mounts
the rootfs from `/dev/mmcblk0p3`.

### 1. Identify the SD card device — carefully

This is the step that will eat one of your hard drives if you get it wrong.
`dd`-style writes to a block device cannot be undone.

With the SD card **un**plugged, list the block devices and note what's there:

```
lsblk -o NAME,SIZE,RM,TYPE,MOUNTPOINT
```

Now insert the SD card and re-run the same command. The new entry (typically
`/dev/sdX`, with `RM=1` for removable, and a size that matches your card) is
your target. Confirm with:

```
udevadm info --query=property --name=/dev/sdX | grep -E "ID_BUS|ID_MODEL"
```

`ID_BUS=usb` and a model like `SDXC/MMC` or your card-reader's name is what you
want to see. **Do not proceed until you are certain `/dev/sdX` is your SD card
and not an internal disk.** Throughout the rest of this section, replace `sdX`
with the actual device letter, and `<TARGET>` with your board.

### 2. Unmount any auto-mounted partitions

```
for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
```

### 3. Flash the wic image to the raw device

Preferred: `bmaptool` only writes the blocks that are actually used, so it
finishes in a minute or two on a fast card:

```
sudo bmaptool copy \
    --bmap Yocto/<TARGET>/images/linux/rootfs.wic.bmap \
          Yocto/<TARGET>/images/linux/rootfs.wic.xz \
          /dev/sdX
```

Fallback (slower, writes every block):

```
xzcat Yocto/<TARGET>/images/linux/rootfs.wic.xz \
    | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
```

### 4. Install BOOT.BIN on the esp partition

```
sudo partprobe /dev/sdX
```

Most desktops will now expose `/media/<you>/esp` (and `boot`, `root`,
`storage`). Copy `BOOT.BIN` onto `esp`:

```
cp Yocto/<TARGET>/images/linux/BOOT.BIN /media/<you>/esp/BOOT.BIN
sync
```

If your desktop didn't auto-mount, mount `esp` (the first partition) manually:

```
sudo mkdir -p /mnt/sd_esp
sudo mount /dev/sdX1 /mnt/sd_esp
sudo cp Yocto/<TARGET>/images/linux/BOOT.BIN /mnt/sd_esp/BOOT.BIN
sync
sudo umount /mnt/sd_esp && sudo rmdir /mnt/sd_esp
```

### 5. Eject and boot

Eject the card cleanly (`sudo eject /dev/sdX`) so pending writes flush. Insert
it into the board, set the boot mode switches to SD, attach the RPi Camera FMC
(with one or more cameras) to the FMC connector and a 1080p DisplayPort
monitor to the board's DisplayPort output, power-cycle, and attach a UART
terminal at 115200 8N1. Once Linux is up, `sudo displaycams.sh` streams every
connected camera to the monitor (see the [Yocto docs](../docs/source/yocto.md)).

## Offline / faster builds

Place the absolute path to a directory containing an extracted AMD sstate-cache
mirror in `Yocto/offline.txt` — `configure-build.sh` auto-detects which
architecture subdirs exist under it and wires one `SSTATE_MIRRORS` entry per
arch (plus `SOURCE_MIRROR_URL` if a `downloads/` dir is present).

Expected layout under that path:

```
<sstate root>/
  aarch64/           (ZynqMP Linux)
  microblaze/        (the PMU firmware multiconfig)
  downloads/         (optional — the source-mirror tarballs)
```

Both `aarch64` and `microblaze` are needed: the generated MACHINE builds the
PMU firmware as a MicroBlaze multiconfig. The sstate-cache and downloads
archives are available behind login at the AMD Embedded Design Tools download
page under "sstate-cache & Downloads - 2025.2".

A warm sstate-cache typically gives a high hit rate; because each target uses a
distinct generated MACHINE name, the machine-specific recipes still rebuild
(architecture-level recipes hit the cache), so a first build is moderate rather
than from-scratch.

## Layout

```
Yocto/
  Makefile                  deprecated thin wrapper around ../build.sh
  README.md                 this file
  .gitignore                excludes per-target workspaces + local state
  offline.txt               (optional, gitignored) path to an extracted sstate mirror
  scripts/
    init-workspace.sh       repo init + sync
    configure-build.sh      sdtgen + gen-machineconf parse-sdt + apply BSP + sstate
    build-image.sh          bitbake the image recipe
    package-output.sh       gather deploy artifacts into images/linux/
  bsp/
    <board>/                one per board (zcu102 is shared by the hpc0 + hpc1
                            targets)
      conf/
        local.conf.append   board overrides (hostname, kernel cmdline)
      meta-user/            Yocto layer: kernel cfg (camera sensor drivers),
                            system-user.dtsi (camera/display bindings + board
                            fixups), image bbappend
  <TARGET>/                 (gitignored) per-target workspace built by make
  tools/                    (gitignored) helper checkouts
  logs/                     (gitignored) build logs
```

## Architectural notes

* **The MACHINE is generated from the XSA** by `gen-machineconf parse-sdt`
  (the flow AMD recommends; `parse-xsa` is deprecated). This is the only
  build flow — there is no pinned AMD-validated MACHINE and no per-target
  flow selection. The custom machine is named `rpi-<target>`.

* **The bitstream lives in BOOT.BIN**, not loaded at runtime via FPGA manager.
  Because no PL overlay is requested, `fpga-overlay` is left out of
  `MACHINE_FEATURES`, so `xilinx-bootbin`'s `BIF_BITSTREAM_ATTR` defaults to
  `bitstream` and the bitstream `sdtgen` extracted from the XSA is embedded
  automatically. FSBL programs the PL during boot so the camera and display
  pipeline is live before Linux starts.

* **`system-user.dtsi` is scoped to the Linux device tree** (via a guard on
  `CONFIG_DTFILE`). The FSBL and PMU domain device-trees don't define the SoC
  peripheral labels (`uart0`/`uart1`, `sdhci1`, `&zynqmp_dpsub`, …) the
  overrides reference, so including it there makes `dtc` fail with
  "Label or path … not found".

* **Adding a target**: set `"yocto": true` for the design in
  `config/data.json` and run `config/update.py` (regenerates the README
  table), then create `bsp/<board>/` following an existing board (start from
  `zcu106` for a stock AMD board; `uzev` shows the pattern for a board needing
  a rich `system-user.dtsi`).
