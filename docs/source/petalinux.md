# PetaLinux

PetaLinux can be built for the Zynq UltraScale+ reference designs with the cross-platform
`build.py` runner at the root of the repository. The same designs can also be built with the
[Yocto / AMD EDF flow](yocto); both flows produce an image with the same camera and display
software.

## Requirements

To build the PetaLinux projects, you will need a physical or virtual machine running one of the 
[supported Linux distributions] with PetaLinux Tools 2025.2 and Vivado 2025.2 installed.

```{attention}
You cannot build the PetaLinux projects in the Windows operating system. Windows
users are advised to use a Linux virtual machine to build the PetaLinux projects.
```

## How to build

The build runner locates and sources the PetaLinux and Vivado settings itself, so there
is no need to source them by hand. See the [build instructions](build_instructions) for
the full description of the runner.

1. From a command terminal, clone the Git repository (with its submodules) and `cd` into it:
   ```
   git clone --recurse-submodules https://github.com/fpgadeveloper/rpi-camera-fmc.git
   cd rpi-camera-fmc
   ```
2. Build the PetaLinux image for your target by running the following command and replacing
   `<target>` with one of the target design labels found in the build instructions:
   ```
   ./build.sh petalinux --target <target>
   ```
   Valid targets for PetaLinux are:
   {% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}

This will also launch the build process for the corresponding Vivado project if that project
has not already been built and its hardware exported.

The output products are written to `PetaLinux/<target>/images/linux/`. To gather the boot files
into a zip file under `bootimages/`, run `./build.sh package --target <target>` (or build
everything with `./build.sh all --target <target>`). The zip contains a `boot/` folder (`BOOT.BIN`,
`boot.scr`, `image.ub`) and a `root/` folder (`rootfs.tar.gz`).

Note that there currently is no PetaLinux project for the Genesys-ZU board, because there is currently
no PetaLinux BSP available for that board.

## Prepare the SD card

Once the build process is complete, you must prepare the SD card for booting PetaLinux.

1. The SD card must first be prepared with two partitions: one for the boot files and another 
   for the root file system.

   * Plug the SD card into your computer and find its device name using the `dmesg` command.
     The SD card should be found at the end of the log, and its device name should be something
     like `/dev/sdX`, where `X` is a letter such as a,b,c,d, etc. Note that you should replace
     the `X` in the following instructions.
     
```{warning}
Do not continue these steps until you are certain that you have found the correct
device name for the SD card. If you use the wrong device name in the following steps, you risk
losing data on one of your hard drives.
```
   * Run `fdisk` by typing the command `sudo fdisk /dev/sdX`
   * Make the `boot` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number and first sector. For the last sector, type 
     `+1G` to allocate 1GB to this partition.
   * Make the `boot` partition bootable by typing `a`
   * Make the `root` partition: typing `n` to create a new partition, then type `p` to make 
     it primary, then use the default partition number, first sector and last sector.
   * Save the partition table by typing `w`
   * Format the `boot` partition (FAT32) by typing `sudo mkfs.vfat -F 32 -n boot /dev/sdX1`
   * Format the `root` partition (ext4) by typing `sudo mkfs.ext4 -L root /dev/sdX2`

2. Copy the following files to the `boot` partition of the SD card:
   Assuming the `boot` partition was mounted to `/media/user/boot`, follow these instructions:
   ```
   $ cd /media/user/boot/
   $ sudo cp /<petalinux-project>/images/linux/BOOT.BIN .
   $ sudo cp /<petalinux-project>/images/linux/boot.scr .
   $ sudo cp /<petalinux-project>/images/linux/image.ub .
   ```

3. Create the root file system by extracting the `rootfs.tar.gz` file to the `root` partition.
   Assuming the `root` partition was mounted to `/media/user/root`, follow these instructions:
   ```
   $ cd /media/user/root/
   $ sudo cp /<petalinux-project>/images/linux/rootfs.tar.gz .
   $ sudo tar xvf rootfs.tar.gz -C .
   $ sync
   ```
   
   Once the `sync` command returns, you will be able to eject the SD card from the machine.

## Boot from SD card

1. Plug the SD card into your target board.
2. Ensure that the target board is configured to boot from SD card:
   * **ZCU102 / ZCU104 / ZCU106:** DIP switch SW6 must be set to 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF).
   * **PYNQ-ZU:** Switch labelled "JTAG SD" must be flipped to the right (towards "SD").
   * **UltraZed-EV:** DIP switch SW2 (on the SoM) is set to 1000 (1=ON, 2=OFF, 3=OFF, 4=OFF).
     The UltraZed-EV boots from SD1 (`/dev/mmcblk1p2`); SD0 is not used by this design.

   The boot mode switches are described in the user guide of each board.
3. Connect the [RPi Camera FMC] to the FMC connector of the target board (see the
   [target designs](build_instructions.md#target-designs) for the connector of each target). Connect
   one or more [Raspberry Pi camera module v2] to the camera ports that the target supports.
4. Connect a DisplayPort monitor that supports 1920x1080 at 60 Hz to the DisplayPort output of the board.
5. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.

   ```{note}
   The **ZCU102 / ZCU106** USB-UART bridge exposes several serial ports; the
   PetaLinux console comes out on PSU UART0 (typically the lowest-numbered
   port). Open them all if you're not sure which is which.
   ```
6. Connect and power your hardware.

## Log in

The console shows the login prompt of the image, whose hostname is
`<board>-rpi-cam-fmc-2025-2` (for example `zcu106-rpi-cam-fmc-2025-2 login:`).

Log in with the username `petalinux`. The first time you boot, you will be asked to set the
password for this user. On subsequent boots, you will be required to use the chosen password.

The kernel command line of the PetaLinux images contains `cma=1536M` (`cma=1000M` on the
UltraZed-EV), which reserves contiguous memory for the video frame buffers, and
`xlnx_mixer.connect_drm_bridge=1`, which the display pipeline needs (see
[Advanced](advanced.md#displayport-and-video-mixer-pipeline-fixes)). Check it with `cat /proc/cmdline`.

## Test the cameras

Continue with [Using and testing the design](testing): enumerate the cameras, configure the
pipelines with `init_cams.sh`, capture frames, and display all cameras on the monitor with
`sudo displaycams.sh`.

## Known issues and limitations

### PYNQ-ZU limits

The ZynqMP device on the PYNQ-ZU board is a relatively small device in terms of FPGA resources.
Fitting the necessary logic to handle four video streams simultaneously can be a challenge on this board. 
For this reason, in our Vivado design for this board we have included the video pipes for only two cameras:
CAM1 and CAM2.


[RPi Camera FMC]: https://docs.opsero.com/op068/datasheet/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.amd.com/r/en-US/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
