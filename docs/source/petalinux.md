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

## Debugging tips

The `media-ctl` command can be useful in debugging issues with your video pipe design. Below we show an
example of the `media-ctl -p /dev/media0` output, which shows each of the elements in the video pipe as well
as how they are connected and configured.

```
zcu104rpicamfmc20221:~$ media-ctl -p /dev/media0
Media controller API version 5.15.19

Media device information
------------------------
driver          xilinx-video
model           Xilinx Video Composite Device
serial
bus info
hw revision     0x0
driver version  5.15.19

Device topology
- entity 1: vcap_mipi_0_v_proc output 0 (1 pad, 1 link)
            type Node subtype V4L flags 0
            device node name /dev/video0
        pad0: Sink
                <- "a0040000.v_proc_ss":1 [ENABLED]

- entity 5: a0000000.mipi_csi2_rx_subsystem (2 pads, 2 links)
            type V4L2 subdev subtype Unknown flags 0
            device node name /dev/v4l-subdev0
        pad0: Sink
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
                <- "imx219 1-0010":0 [ENABLED]
        pad1: Source
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
                -> "a0140000.v_demosaic":0 [ENABLED]

- entity 8: imx219 1-0010 (1 pad, 1 link)
            type V4L2 subdev subtype Sensor flags 0
            device node name /dev/v4l-subdev1
        pad0: Source
                [fmt:SRGGB10_1X10/3280x2464 field:none colorspace:srgb xfer:srgb ycbcr:601 quantization:full-range
                 crop.bounds:(8,8)/3280x2464
                 crop:(8,8)/3280x2464]
                -> "a0000000.mipi_csi2_rx_subsystem":0 [ENABLED]

- entity 10: a0140000.v_demosaic (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev2
        pad0: Sink
                [fmt:SRGGB8_1X8/1280x720 field:none colorspace:srgb]
                <- "a0000000.mipi_csi2_rx_subsystem":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1280x720 field:none colorspace:srgb]
                -> "a0170000.v_gamma_lut":0 [ENABLED]

- entity 13: a0170000.v_gamma_lut (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev3
        pad0: Sink
                [fmt:RBG888_1X24/1280x720 field:none colorspace:srgb]
                <- "a0140000.v_demosaic":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1280x720 field:none colorspace:srgb]
                -> "a0040000.v_proc_ss":0 [ENABLED]

- entity 16: a0040000.v_proc_ss (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev4
        pad0: Sink
                [fmt:VYYUYY8_1X24/1280x720 field:none colorspace:srgb]
                <- "a0170000.v_gamma_lut":1 [ENABLED]
        pad1: Source
                [fmt:VYYUYY8_1X24/1920x1080 field:none colorspace:srgb]
                -> "vcap_mipi_0_v_proc output 0":0 [ENABLED]
```

Individual interfaces can be configured using `media-ctl -V` as follows:

```
media-ctl -V '"a0140000.v_demosaic":0  [fmt:SRGGB10_1X8/1920x1080 field:none colorspace:srgb xfer:srgb ycbcr:601 quantization:full-range]' -d /dev/media0
media-ctl -V '"a0140000.v_demosaic":1  [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0040000.v_proc_ss":0  [fmt:VYYUYY8_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0040000.v_proc_ss":1  [fmt:VYYUYY8_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
```

An alternative way to get images from the cameras is to use the `yavta` tool, for example:

```
yavta -n 3 -c1 -f NV12 -s 1920x1080 --skip 9 -F /dev/video0
```

## Known issues and limitations

### PYNQ-ZU and Genesys-ZU limits

The ZynqMP devices on the PYNQ-ZU and Genesys-ZU boards are relatively small devices in terms of FPGA resources.
Fitting the necessary logic to handle four video streams simultaneously can be a challenge on these boards. 
For this reason, in our Vivado designs for these boards, the [Video Processing Subsystem IP] for cameras 2 and 3,
has been configured to use the simplest and lowest footprint scaling algorithm. This scaling algorithm is known as
"bilinear", and by using it in two of the video pipes we are able to get the entire design to fit within the 
resource constraints of these devices.

The consequences of using the "bilinear" scaling algorithm on the video pipes for cameras 2 and 3 are as follows:
* **Reduced quality of the scaled images:** As described in the documentation for the [Video Processing Subsystem IP],
  "Bilinear interpolation produces a greater number of interpolation artifacts (such as aliasing, blurring, and 
  edge halos) than more computationally demanding techniques such as bicubic interpolation."
* **No PetaLinux support:** The Linux driver for [Video Processing Subsystem IP] seems to only work when the 
  IP is configured to use the "polyphase" scaling algorithm. If you try to use camera 2 or 3 in PetaLinux, you will
  notice the following error message:
  ```
  [  123.456789] xilinx-csi2rxss a0002000.mipi_csi2_rx_subsystem: Stream Line Buffer Full!
  ```
  We have not yet found a workaround for this problem.


[RPi Camera FMC]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[Video Processing Subsystem IP]: https://docs.xilinx.com/r/en-US/pg231-v-proc-ss

