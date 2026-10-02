# Yocto

The Yocto / EDF flow (AMD's Embedded Development Framework) is the announced successor to
PetaLinux. It can be built for the Zynq UltraScale+ reference designs with the cross-platform
`build.py` runner at the root of the repository.

```{note}
For 2025.2 both the PetaLinux and Yocto flows are supported and produce an equivalent
image: the same camera and display drivers, the same kernel patches and the same example
scripts. From the next tool version onward, the PetaLinux flow for this repository will be retired
and Yocto will be the only supported flow — see [build instructions](build_instructions).
```

## Requirements

To build the Yocto projects you will need a physical or virtual machine running one of the
[supported Linux distributions], with Vivado 2025.2 and Vitis 2025.2 installed — the flow uses
`xsct`/`sdtgen` (which ship with Vitis) to generate a System Device Tree from the Vivado XSA. You
also need [Google's repo tool](https://gerrit.googlesource.com/git-repo/) on your `PATH`, and the
usual Yocto host packages. On Ubuntu 22.04 / 24.04:

```
sudo apt-get install repo gawk wget git diffstat unzip texinfo gcc \
    build-essential chrpath socat cpio python3 python3-pip python3-pexpect \
    xz-utils debianutils iputils-ping python3-git python3-jinja2 \
    python3-subunit zstd liblz4-tool file locales libacl1 bmap-tools
```

```{attention}
You cannot build the Yocto projects in the Windows operating system. Windows users
are advised to use a Linux virtual machine to build the Yocto projects.
```

The Yocto flow is provided for the **Zynq UltraScale+** reference designs (ZCU102, ZCU104, ZCU106,
PYNQ-ZU and UltraZed-EV). The baremetal FPGA designs (AUBoard) are not Linux targets and are
not built by this flow.

A Yocto workspace is large: the first build of a target downloads several GB of sources, and each
target's workspace needs several tens of GB of disk space.

## How to build

The build runner locates and sources the Vivado and Vitis settings itself, so there is no
need to source them by hand.

1. From a command terminal, clone the Git repository (with its submodules) and `cd` into it:
   ```
   git clone --recurse-submodules https://github.com/fpgadeveloper/rpi-camera-fmc.git
   cd rpi-camera-fmc
   ```
2. Build the Yocto image for your target by running the following command, replacing
   `<target>` with one of the target design labels:
   ```
   ./build.sh yocto --target <target>
   ```
   Valid targets for Yocto are:
   {% for design in data.designs if design.yocto and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

This command launches the corresponding Vivado build if that project has not already been
built and its hardware exported. It then creates the workspace in `Yocto/<target>/`
(`repo init` of the AMD `yocto-manifests`, release `rel-v2025.2`, and `repo sync`), generates
the System Device Tree from the XSA and a Yocto machine from it, layers the board's BSP from
`Yocto/bsp/` on top, and runs `bitbake edf-linux-disk-image`. The first build of a target takes
a while; subsequent builds are incremental. The runner also works around a host `tar` that the
Yocto fakeroot tool cannot handle (some recent distribution updates), automatically.

The output products are gathered into `Yocto/<target>/images/linux/`:

| File | Description |
| --- | --- |
| `BOOT.BIN` | Boot image (FSBL, PMU firmware, PL bitstream, Arm Trusted Firmware, U-Boot) |
| `boot.scr` | U-Boot boot script |
| `Image` | Linux kernel |
| `system.dtb` | Linux device tree |
| `u-boot.elf` | U-Boot |
| `rootfs.wic.xz` | Full SD-card disk image — this is what you flash |
| `rootfs.wic.bmap` | Block map for `bmaptool` |
| `rootfs.tar.gz` | Root filesystem tarball |

To gather the files you need for the SD card into a zip file, run
`./build.sh package --target <target>` (or build everything with `./build.sh all --target <target>`).
The zip, `bootimages/rpi-camera-fmc_<target>_yocto-2025-2.zip`, contains `rootfs.wic.xz`,
`rootfs.wic.bmap`, `BOOT.BIN` and a `readme.txt` with the SD card instructions below.

To free disk space after a successful build, `./build.sh clean --target <target> --keep-boot`
deletes the workspace except `images/`.

### Offline build

To build without access to the AMD sstate mirrors, put a local copy of the sstate-cache and
downloads in a directory with one sub-directory per architecture (e.g. `aarch64`) and a `downloads`
sub-directory, then create the file `Yocto/offline.txt` containing that path on its first line
(no trailing slash). The runner configures the build to use it as an sstate and source mirror.

## Boot from SD card

Unlike the PetaLinux flow (which produces separate boot files for a hand-partitioned card), the
Yocto flow produces a **full SD-card disk image** (`rootfs.wic.xz`) that already contains all
partitions: `esp` (FAT, partition 1), `boot` (ext4), `root` (ext4, partition 3) and `storage`.
You flash that image to the SD card's raw device, then copy `BOOT.BIN` onto the first (FAT)
partition: the BootROM loads `BOOT.BIN` from there, and the image does not put it there.

All the targets, including the PYNQ-ZU (which has no Ethernet port), are prepared the same way:
with the SD card in a card reader on your Linux PC.

### Prepare the SD card

```{warning}
Flashing writes directly to a raw block device and cannot be undone. Be absolutely
certain you have identified the SD card's device node before running the commands below — if you
use the wrong device you risk destroying data on one of your hard drives.
```

1. Identify the SD card device. With the card **un**plugged, run:
   ```
   lsblk -o NAME,SIZE,RM,TYPE,MOUNTPOINT
   ```
   Insert the card and run the same command again. The new entry — typically `/dev/sdX`, with
   `RM=1` (removable) and a size matching your card — is your target. Replace `sdX` with that
   device, and `<target>` with your target, throughout the steps below.

2. Unmount any partitions the desktop auto-mounted:
   ```
   for p in /dev/sdX?*; do sudo umount "$p" 2>/dev/null; done
   ```

3. Flash the wic image to the raw device. With `bmaptool` (fast — only writes the blocks that are
   actually used):
   ```
   sudo bmaptool copy --bmap Yocto/<target>/images/linux/rootfs.wic.bmap \
                            Yocto/<target>/images/linux/rootfs.wic.xz \
                            /dev/sdX
   ```
   Or, as a fallback with `dd` (slower — writes every block):
   ```
   xzcat Yocto/<target>/images/linux/rootfs.wic.xz \
       | sudo dd of=/dev/sdX bs=4M status=progress conv=fsync
   ```

4. **Install `BOOT.BIN` on the `esp` partition** (partition 1):
   ```
   sudo partprobe /dev/sdX
   sudo mkdir -p /mnt/sd_esp
   sudo mount /dev/sdX1 /mnt/sd_esp
   sudo cp Yocto/<target>/images/linux/BOOT.BIN /mnt/sd_esp/BOOT.BIN
   sync
   sudo umount /mnt/sd_esp && sudo rmdir /mnt/sd_esp
   ```
   If your desktop auto-mounted the partition (as `/media/<you>/esp`), you can copy `BOOT.BIN`
   there instead.

5. Eject the card cleanly so pending writes flush:
   ```
   sudo eject /dev/sdX
   ```

When you use the zip from `bootimages/`, the files are at the top level of the zip instead of
`Yocto/<target>/images/linux/`.

### Boot

1. Plug the SD card into the target board.
2. Set the board to boot from SD card. The boot-mode switch settings are the same regardless of
   the Linux flow — see the per-board switch settings under
   [Boot from SD card](petalinux.md#boot-from-sd-card).
3. Connect the [RPi Camera FMC] to the target board's FMC connector, and connect one or more
   [Raspberry Pi camera module v2] modules to the camera ports that the target supports.
4. Connect a DisplayPort monitor that supports 1920x1080 at 60 Hz to the board's DisplayPort output.
5. Connect the board's Ethernet port to your network (optional; not on the PYNQ-ZU).
6. Connect the USB-UART to your PC and open a terminal emulator at 115200 baud (8N1).

   ```{note}
   The **ZCU102 / ZCU106** USB-UART bridge exposes several serial ports; the console comes out on PSU
   UART0 (typically the lowest-numbered port). Open them all if you're not sure which is which.
   ```
7. Connect and power your hardware.

### What to expect on the console

U-Boot loads the kernel with the boot script, and Linux boots to a login prompt. A few lines
worth recognising (ZCU106, shortened):

```
[    2.364352] xlnx,bridge-vtc 80020000.v_tc_0: Xilinx VTC IP version : 0x0602000c
[    2.613557] xilinx-video amba_pl:vcap_mipi_0_v_proc: /amba_pl/vcap_mipi_0_v_proc/ports/port@0 initialization failed
[    2.618390] xilinx-video amba_pl:vcap_mipi_0_v_proc: DMA initialization failed
...
[    3.242649] zynqmp-dpsub fd4a0000.display: ZynqMP DisplayPort Subsystem driver probed
[    3.258460] xlnx-mixer a0000000.v_mix: Registered mixer CRTC with id: 47
[    3.278912] [drm] Initialized xlnx 1.0.0 for a0000000.v_mix on minor 0
[    3.285456] xlnx-mixer a0000000.v_mix: Xilinx Mixer driver probed success
...
AMD Embedded Development Framework Linux distribution 25.11.1+release-... zcu106-rpi-2025-2 ttyPS0

zcu106-rpi-2025-2 login:
```

The `port@0 initialization failed` / `DMA initialization failed` pair (one per capture pipeline) is
harmless: the capture pipelines are probed again a moment later, once all their parts are ready.

### Log in

Log in as **`amd-edf`**. On the first login you are asked to set a new password:

```
zcu106-rpi-2025-2 login: amd-edf
You are required to change your password immediately (administrator enforced).
New password:
Retype new password:
```

The hostname is `<board>-rpi-2025-2` (`zcu104-rpi-2025-2`, `zcu102-rpi-2025-2`,
`zcu102-hpc1-rpi-2025-2`, `zcu106-rpi-2025-2`, `pynqzu-rpi-2025-2`, `uzev-rpi-2025-2`).
The `amd-edf` user can use `sudo`.

The kernel command line is built by the boot script. Check it with `cat /proc/cmdline`; it ends with
the arguments that this design adds:

```
... root=/dev/mmcblk0p3 ro rootwait uio_pdrv_genirq.of_id=generic-uio cma=1536M xlnx_mixer.connect_drm_bridge=1
```

`cma=1536M` (`cma=1000M` on the UltraZed-EV) reserves contiguous memory for the video frame
buffers, and `xlnx_mixer.connect_drm_bridge=1` is needed by the display pipeline. The root
filesystem is mounted read-only first and then remounted read-write by systemd.

### Network

On the boards with an Ethernet port, the image requests an address by DHCP on the board's
Ethernet port (`end0`) and runs an SSH server, so you can log in with
`ssh amd-edf@<board-ip>` once you have set the password on the console. To copy files from the
board with `scp`, add the `-O` option (the image has no SFTP server).

On the ZCU102, ZCU104 and ZCU106 the device tree of the BSP describes the board's Ethernet PHY
and sets a fixed MAC address (`local-mac-address` in `system-user.dtsi`). If you connect more
than one board of the same type to a network, give each board a different MAC address.

### PYNQ-ZU: Wi-Fi

The PYNQ-ZU has no Ethernet port. Its network interface is the on-board Microchip WILC3000 Wi-Fi
module (`wlan0`), which the Yocto image supports. No Wi-Fi credentials are built into the image:
set them up once from the serial console:

```
sudo wifi-sta-setup <SSID> [<country>]
```

The command reads the passphrase from its standard input: type it and press *Enter*. `<country>`
is the two-letter regulatory country code (default `US`). For an open network, use
`sudo wifi-sta-setup --open <SSID> [<country>]`. The script writes
`/etc/wpa_supplicant/wpa_supplicant-wlan0.conf` (readable by root only, with the passphrase stored as
a hash), connects, and waits up to 60 seconds for a DHCP address, which it prints:

```
wlan0 up: <address>/<prefix length>
```

The board reconnects automatically at every boot. To check the connection, use
`wpa_cli -i wlan0 status` or `iw dev wlan0 link`; driver messages are shown by `dmesg | grep -i wilc`.
A template of the configuration file is in `/etc/wpa_supplicant/wpa_supplicant-wlan0.conf.example`
if you prefer to write it by hand.

On the PYNQ-ZU the login console is on the first UART (`ttyPS0`) only.

## Test the cameras

Continue with [Using and testing the design](testing): enumerate the cameras, configure the
pipelines with `init_cams.sh`, capture frames, and display all cameras on the monitor with
`sudo displaycams.sh`. The quickest check is:

```
sudo displaycams.sh
```

## BSP

The per-board layers of the Yocto flow are in `Yocto/bsp/<board>/` (`Yocto/bsp/zcu102_hpc1/` is a
complete BSP of its own for that target): `conf/local.conf.append` (hostname, kernel command line
arguments) and `meta-user/` (device tree, kernel configuration and patches, image packages and the
example scripts). They are described in [Advanced](advanced.md#yocto-side).

[RPi Camera FMC]: https://docs.opsero.com/op068/datasheet/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
