# PetaLinux

PetaLinux can be built for these reference designs by using the Makefile in the `PetaLinux` directory
of the repository.

## Requirements

To build the PetaLinux projects, you will need a physical or virtual machine running one of the 
[supported Linux distributions] as well as the Vitis Core Development Kit installed.

```{attention} You cannot build the PetaLinux projects in the Windows operating system. Windows
users are advised to use a Linux virtual machine to build the PetaLinux projects.
```

## How to build

1. From a command terminal, clone the Git repository and `cd` into it.
   ```
   git clone https://github.com/fpgadeveloper/rpi-camera-fmc.git
   cd rpi-camera-fmc
   ```
2. Launch PetaLinux by sourcing the `settings.sh` bash script, eg:
   ```
   source <path-to-installed-petalinux>/settings.sh
   ```
3. Launch Vivado by sourcing the `settings64.sh` bash script, eg:
   ```
   source <vivado-install-dir>/settings64.sh
   ```
4. Build the Vivado and PetaLinux project for your specific target platform by running the following
   commands and replacing `<target>` with one of the following: `zcu104`, `zcu102_hpc0`, `zcu102_hpc1`,
   `zcu106_hpc0`, `pynqzu`, `uzev`
   ```
   cd PetaLinux
   make petalinux TARGET=<target>
   ```
   
The last command will launch the build process for the corresponding Vivado project if that project
has not already been built and it's hardware exported.

Note that there currently is no PetaLinux project for the Genesys-ZU board, because there is currently
no PetaLinux BSP available for that board.

## Prepare the SD card

Once the build process is complete, you must prepare the SD card for booting PetaLinux.

1. The SD card must first be prepared with two partitions: one for the boot files and another 
   for the root file system.

   * Plug the SD card into your computer and find it's device name using the `dmesg` command.
     The SD card should be found at the end of the log, and it's device name should be something
     like `/dev/sdX`, where `X` is a letter such as a,b,c,d, etc. Note that you should replace
     the `X` in the following instructions.
     
```{warning} Do not continue these steps until you are certain that you have found the correct
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
   * **ZCU10x:** DIP switch SW6 must be set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
   * **PYNQ-ZU:** Switch labelled "JTAG SD" must be flipped to the right (towards "SD")
   * **UltraZed-EV:** DIP switch SW2 (on the SoM) is set to 1000 (1=ON,2=OFF,3=OFF,4=OFF)
3. Connect the [RPi Camera FMC] to the FMC connector of the target board. Connect one or more
   [Raspberry Pi camera module v2] to the [RPi Camera FMC].
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.
5. Connect and power your hardware.

## Test the cameras

1. Log into PetaLinux using the username `petalinux`. The first time you boot, you will be forced to set the
   password for this user. On subsequent boots, you will be required to use the chosen password.
2. Check that the cameras have been enumerated correctly by running the `v4l2-ctl --list-devices` command.
   The output should be similar to the following:
   ```
   zcu104rpicamfmc20221:~$ v4l2-ctl --list-devices
   vcap_mipi_0_v_proc output 0 (platform:vcap_mipi_0_v_proc:0):
           /dev/video0
   
   vcap_mipi_1_v_proc output 0 (platform:vcap_mipi_1_v_proc:0):
           /dev/video1
   
   vcap_mipi_2_v_proc output 0 (platform:vcap_mipi_2_v_proc:0):
           /dev/video2
   
   vcap_mipi_3_v_proc output 0 (platform:vcap_mipi_3_v_proc:0):
           /dev/video3
   
   Xilinx Video Composite Device (platform:xilinx-video):
           /dev/media0
           /dev/media1
           /dev/media2
           /dev/media3
   ```
   Note that there will only be video and media devices for the cameras that you have physically
   connected, so if you have only connected 2 cameras for example, then you should only see 2 video devices
   and 2 media devices listed.

3. Use Gstreamer to display the video from a single camera on the DisplayPort monitor. First disable the 
   desktop environment so that GStreamer can take over the monitor, then run Gstreamer as follows:
   ```
   sudo systemctl isolate multi-user.target
   gst-launch-1.0 mediasrcbin media-device=/dev/media0 v4l2src0::io-mode=mmap ! "video/x-raw, width=1920, height=1080, format=NV12, framerate=30/1" ! kmssink plane-id=39 fullscreen-overlay=true -v
   ```
   To test a different camera, change the targeted media device from `/dev/media0` to another, such as
   `/dev/media1`. To stop streaming the video, press *Ctrl-C*.

4. If you wish to get the PetaLinux GUI desktop environment back, run the following command:
   ```
   sudo systemctl isolate graphical.target
   ```

[RPi Camera FMC]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment

