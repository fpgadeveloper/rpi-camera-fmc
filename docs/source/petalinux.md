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
   git clone --recursive https://github.com/fpgadeveloper/rpi-camera-fmc.git
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
   commands and replacing `<target>` with one of the following:
   {% for design in data.designs if design.petalinux and design.publish %} `{{ design.label }}`{{ ", " if not loop.last else "." }} {% endfor %}
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
   zcu104-rpi-cam-fmc-2022-1:~$ v4l2-ctl --list-devices
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

3. Run the init script with the command `init_cams.sh`.
   ```
   zcu104-rpi-cam-fmc-2022-1:~$ init_cams.sh
   -------------------------------------------------
    Capture pipeline init: RPi cam -> Scaler -> DDR
   -------------------------------------------------
   Configuring all video capture pipelines to:
    - RPi Camera output    : 1920 x 1080
    - Scaler (VPSS) output : 1920 x 1080 YUY2
   Video Mixer found here:
    - a0100000.v_mix
   Detected and configured the following cameras on RPi Camera FMC:
    - CAM0: /dev/media0 = /dev/video0
    - CAM1: /dev/media1 = /dev/video1
    - CAM2: /dev/media2 = /dev/video2
    - CAM3: /dev/media3 = /dev/video3
   ```
   The init script is located in `/usr/bin` and it serves as an example for setting the video pipe parameters
   using media-ctl. It configures all of the capture pipelines to a resolution, format and frame rate that
   is specified by a set of variables at the top of the script. It also lists the video mixer bus_id, as well as 
   all of the connected RPi cameras and the media and video devices to which they are associated. 
   The init script makes it easy to find all of the connected media and video devices, and to configure them
   so that they can be used with GStreamer or other applications.

4. Before we can use the display pipeline, we need to set it up with the following command:
   ```
   modetest -M xlnx -D a0000000.v_mix -s 60@46:1920x1080@NV16
   ```
   Note that the `-D` option must specify the correct `bus_id` of the video mixer. This can be found in the
   output of the `init_cams.sh` script (see above), or you can find it with the following command: 
   `find /sys/bus/platform/devices/ -name "*.v_mix"`.
   Here we are setting it up for 1080p resolution and NV16 pixel format, which is the expected format for
   this hardware.

5. Use Gstreamer to display the video from a single camera on the DisplayPort monitor:
   ```
   gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! \
   video/x-raw, width=1920, height=1080, format=YUY2, framerate=30/1 ! \
   kmssink bus-id=a0000000.v_mix plane-id=34 render-rectangle="<0,0,1920,1080>" \
   show-preroll-frame=false sync=false can-scale=false
   ```
   Note that in this command, as in the previous step, you must use the correct `bus_id` for the video mixer.
   To test a different camera, change the targeted video device from `/dev/video0` to another, such as
   `/dev/video1`. To stop streaming the video, press *Ctrl-C*.
   
6. Run the display cams script to display all cameras on the monitor at the same time.
   ```
   sudo displaycams.sh
   ```
   The display cams script is in the `/usr/bin` directory and it serves as an example for setting up the
   video pipelines and configuring the display pipeline to show all video streams. Here is the output of that
   script:
   ```
   zcu104-rpi-cam-fmc-2022-1:~$ sudo ./displaycams.sh
   -------------------------------------------------
    Capture pipeline init: RPi cam -> Scaler -> DDR
   -------------------------------------------------
   Configuring all video capture pipelines to:
    - RPi Camera output    : 1920 x 1080
    - Scaler (VPSS) output : 960 x 540 YUY2
    - Frame rate           : 30 fps
   Video Mixer found here:
    - a0100000.v_mix
   Detected and configured the following cameras on RPi Camera FMC:
    - CAM0: /dev/media0 = /dev/video0
    - CAM1: /dev/media1 = /dev/video1
    - CAM2: /dev/media2 = /dev/video2
    - CAM3: /dev/media3 = /dev/video3
   setting mode 1920x1080-60.00Hz on connectors 60, crtc 46
   GStreamer command:
   --------------------------
   gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0100000.v_mix plane-id=34 render-rectangle="<0,0,960,540>" show-preroll-frame=false sync=false can-scale=false v4l2src device=/dev/video1 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0100000.v_mix plane-id=35 render-rectangle="<960,0,960,540>" show-preroll-frame=false sync=false can-scale=false v4l2src device=/dev/video2 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0100000.v_mix plane-id=36 render-rectangle="<0,540,960,540>" show-preroll-frame=false sync=false can-scale=false v4l2src device=/dev/video3 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0100000.v_mix plane-id=37 render-rectangle="<960,540,960,540>" show-preroll-frame=false sync=false can-scale=false
   --------------------------
   Setting pipeline to PAUSED ...
   Pipeline is live and does not need PREROLL ...
   Pipeline is PREROLLED ...
   Setting pipeline to PLAYING ...
   New clock: GstSystemClock
   ^Chandling interrupt.
   Interrupt: Stopping pipeline ...
   Execution ended after 0:00:02.340043242
   Setting pipeline to NULL ...
   Freeing pipeline ...
   zcu104-rpi-cam-fmc-2022-1:~$
   ```

## Debugging tips

### Video pipe settings

The `media-ctl` command can be useful in debugging issues with your video pipe design. Below we show an
example of the `media-ctl -d /dev/media0 -p` output, which shows each of the elements in the video pipe as well
as how they are connected and configured.

```
zcu104-rpi-cam-fmc-2022-1:~$ media-ctl -d /dev/media0 -p
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
                <- "a0000000.v_proc_ss":1 [ENABLED]

- entity 5: 80000000.mipi_csi2_rx_subsystem (2 pads, 2 links)
            type V4L2 subdev subtype Unknown flags 0
            device node name /dev/v4l-subdev0
        pad0: Sink
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
                <- "imx219 1-0010":0 [ENABLED]
        pad1: Source
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
                -> "a0110000.ISPPipeline_accel":0 [ENABLED]

- entity 8: imx219 1-0010 (1 pad, 1 link)
            type V4L2 subdev subtype Sensor flags 0
            device node name /dev/v4l-subdev1
        pad0: Source
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb xfer:srgb ycbcr:601 quantization:full-range
                 crop.bounds:(8,8)/3280x2464
                 crop:(688,700)/1920x1080]
                -> "80000000.mipi_csi2_rx_subsystem":0 [ENABLED]

- entity 10: a0000000.v_proc_ss (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev2
        pad0: Sink
                [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]
                <- "a0110000.ISPPipeline_accel":1 [ENABLED]
        pad1: Source
                [fmt:UYVY8_1X16/960x540 field:none colorspace:srgb]
                -> "vcap_mipi_0_v_proc output 0":0 [ENABLED]

- entity 13: a0110000.ISPPipeline_accel (2 pads, 2 links)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev3
        pad0: Sink
                [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
                <- "80000000.mipi_csi2_rx_subsystem":1 [ENABLED]
        pad1: Source
                [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]
                -> "a0000000.v_proc_ss":0 [ENABLED]
```

Individual interfaces can be configured using `media-ctl -V` with commands similar to the following:

```
media-ctl -V '"80000000.mipi_csi2_rx_subsystem":0  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"80000000.mipi_csi2_rx_subsystem":1  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0110000.ISPPipeline_accel":0  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0110000.ISPPipeline_accel":1  [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0040000.v_proc_ss":0  [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0040000.v_proc_ss":1  [fmt:UYVY8_1X16/1920x1080 field:none colorspace:srgb]' -d /dev/media0
```

(video-and-media-devices)=
### Video and media devices

In PetaLinux, each connected RPi camera will be associated with a video device and a media device.
When using tools such as GStreamer, we need to specify the video or media device to use, so
it is important to know which cameras (which ports) are associated with which video devices and 
which media devices. Note that they are not necessarily aligned by index (ie. `/dev/video0` and 
`/dev/media0` are not necessarily associated with the same camera). So in the case that we have not 
connected a camera to every port that is supported by our hardware design, we need to determine the 
video and media device associations.

When you list the video devices using `v4l2-ctl --list-devices`, you will find a video device 
(eg. `/dev/video0`) for every video pipe in the hardware (Vivado) design. In other words, you will
find a video device for every camera that the hardware is *capable of connecting with*. However,
it is important to know that you will only find a media device (eg. `/dev/media0`) for every camera 
that *has actually been physically connected* to the hardware and successfully enumerated.

To make this clear, let's consider a typical example. Most of the designs in this project are built 
to handle 4 cameras, but let's say that we only connect 2x RPi cameras, one on port CAM1 and another 
on port CAM2. This would result in the following list of devices:

```
zcu104-rpi-cam-fmc-2022-1:~$ v4l2-ctl --list-devices
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
```

Notice that we have 4 video devices, but only 2 media devices. That is because the hardware can support
4 cameras, but only 2 have been connected and enumerated. From the above, we can determine these associations:

* CAM1 is associated with `/dev/video1` (since `platform:vcap_mipi_1_v_proc` is CAM1)
* CAM2 is associated with `/dev/video2` (since `platform:vcap_mipi_2_v_proc` is CAM2)

To determine the associations with the media devices, we need to use a different tool: `media-ctl`.
As shown in the previous section, we can use the command `media-ctl -p /dev/media0` to inspect
the video pipe elements of a particular media device. One of those elements, usually the first one,
is the video device. We can use `grep` to filter out the specific line indicating the associated
video device:

```
zcu104-rpi-cam-fmc-2022-1:~$ media-ctl -d /dev/media0 -p | grep "dev/video"
            device node name /dev/video1
zcu104-rpi-cam-fmc-2022-1:~$ media-ctl -d /dev/media1 -p | grep "dev/video"
            device node name /dev/video2
```

From the above, we determined these associations:

* `/dev/video1` (which we know is CAM1) is associated with `/dev/media0`
* `/dev/video2` (which we know is CAM2) is associated with `/dev/media1`

Below are a few examples of camera connections and the resulting video and media device
associations.

#### Only CAM1 and CAM2 connected

| Port  | Video device  | Media device  |
|-------|---------------|---------------|
| CAM0  | `/dev/video0` | N/C           |
| CAM1  | `/dev/video1` | `/dev/media0` |
| CAM2  | `/dev/video2` | `/dev/media1` |
| CAM3  | `/dev/video3` | N/C           |

#### Only CAM0 and CAM1 connected

| Port  | Video device  | Media device  |
|-------|---------------|---------------|
| CAM0  | `/dev/video0` | `/dev/media0` |
| CAM1  | `/dev/video1` | `/dev/media1` |
| CAM2  | `/dev/video2` | N/C           |
| CAM3  | `/dev/video3` | N/C           |

#### Only CAM2 and CAM3 connected

| Port  | Video device  | Media device  |
|-------|---------------|---------------|
| CAM0  | `/dev/video0` | N/C           |
| CAM1  | `/dev/video1` | N/C           |
| CAM2  | `/dev/video2` | `/dev/media0` |
| CAM3  | `/dev/video3` | `/dev/media1` |

(init-script)=
### Init script

To make it easier for the user to identify and configure the connected cameras, and their associated
video and media devices, a bash script is included in the root file system. When executed, the script 
lists the detected cameras, their physical ports, and their video and media devices. It also configures 
all of the video pipes according to the variables defined at the top of the script, or passed in as
command line arguments.

The script is located in `/usr/bin` and can be called from the command line by typing `init_cams.sh`.
An example output of the script is shown below:

```
zcu104-rpi-cam-fmc-2022-1:~$ init_cams.sh
-------------------------------------------------
 Capture pipeline init: RPi cam -> Scaler -> DDR
-------------------------------------------------
Configuring all video capture pipelines to:
 - RPi Camera output    : 1920 x 1080
 - Scaler (VPSS) output : 1920 x 1080 YUY2
Video Mixer found here:
 - a0000000.v_mix
Detected and configured the following cameras on RPi Camera FMC:
 - CAM1: /dev/media0 = /dev/video1
 - CAM2: /dev/media1 = /dev/video2
 - CAM3: /dev/media2 = /dev/video3
```

In the example above, only cameras CAM1, CAM2 and CAM3 are physically connected. Notice that the
video and media device indices don't align, which can occur when less than 4 cameras are connected.

#### Usage

There are two main ways to use the init script: edit/customize it according to your needs; or run it with
command line arguments to specify the desired configuration. If you edit the file, you will find five variables
at the top of the script that can be modified to your needs. In below example, the RPi cameras are 
configured for 1080p resolution and the Video Processing Subsystem is configured to output 720p. The
video format is set to YUY2:

```
# Resolution of RPi cameras (must be a resolution supported by the IMX219 Linux driver 640x480, 1640x1232, 1920x1080)
SRC_RES_W="${1:-1920}"
SRC_RES_H="${2:-1080}"
# Resolution of RPi camera pipelines (after Video Processing Subsystem IP)
OUT_RES_W="${3:-1280}"
OUT_RES_H="${4:-720}"
# Output format of the RPi camera pipelines (use a GStreamer pixel format from the dict above)
OUT_FORMAT="${5:-YUY2}"
```

The init script can take command line arguments to fill the configuration variables. The usage is shown
below. Note that if you specify the configuration values in the command line, you must specify ALL variables
and use the same order as shown below.

```
./init_cams.sh <SRC_RES_W> <SRC_RES_H> <OUT_RES_W> <OUT_RES_H> <OUT_FORMAT>
```

An example for configuring the RPi cameras to output 1080p which is then downscaled to 720p is shown below:

```
./init_cams.sh 1920 1080 1280 720 YUY2
```

The easy way to modify the script in PetaLinux is to copy the file from `/usr/bin/init_cams.sh` to the home 
directory and modify the copy from there.
If you want to modify the init script that gets integrated into your build, you can find it in the BSP files 
for your target board in this location of the repository: 
`PetaLinux/bsp/<target>/project-spec/meta-user/recipes-apps/init_cams/files/init_cams.sh`

### Yavta

An alternative way to get images from the cameras is to use the `yavta` tool, for example:

```
yavta -n 3 -c1 -f NV12 -s 1920x1080 --skip 9 -F /dev/video0
```

### Changing camera settings

It is possible to change certain camera settings to improve the quality of the images from the cameras, 
to change the colors or to flip the images. The settings that can be changed will depend on the camera
that is being used. To get a list of the settings, use the `v4l2-ctl -d /dev/video0 --list-ctrls` command.
In the case of the Raspberry Pi camera v2, this is the output from running that command:

```
uzevrpicamfmc20221:~$ v4l2-ctl -d /dev/video0 --list-ctrls

User Controls

                       exposure 0x00980911 (int)    : min=4 max=1759 step=1 default=1600 value=1600
                horizontal_flip 0x00980914 (bool)   : default=0 value=0 flags=modify-layout
                  vertical_flip 0x00980915 (bool)   : default=0 value=0 flags=modify-layout
  red_gamma_correction_1_0_1_10 0x0098c9c1 (int)    : min=1 max=40 step=1 default=10 value=10 flags=slider
 blue_gamma_correction_1_0_1_10 0x0098c9c2 (int)    : min=1 max=40 step=1 default=10 value=10 flags=slider
 green_gamma_correction_1_0_1_1 0x0098c9c3 (int)    : min=1 max=40 step=1 default=10 value=10 flags=slider
           low_latency_controls 0x0098ca21 (int)    : min=2 max=8 step=1 default=4 value=4

Image Source Controls

              vertical_blanking 0x009e0901 (int)    : min=4 max=64455 step=1 default=683 value=683
            horizontal_blanking 0x009e0902 (int)    : min=1528 max=1528 step=1 default=1528 value=1528 flags=read-only
                  analogue_gain 0x009e0903 (int)    : min=0 max=232 step=1 default=0 value=0
                red_pixel_value 0x009e0904 (int)    : min=0 max=1023 step=1 default=1023 value=1023
          green_red_pixel_value 0x009e0905 (int)    : min=0 max=1023 step=1 default=1023 value=1023
               blue_pixel_value 0x009e0906 (int)    : min=0 max=1023 step=1 default=1023 value=1023
         green_blue_pixel_value 0x009e0907 (int)    : min=0 max=1023 step=1 default=1023 value=1023

Image Processing Controls

                 link_frequency 0x009f0901 (intmenu): min=0 max=0 default=0 value=0 flags=read-only
                     pixel_rate 0x009f0902 (int64)  : min=182400000 max=182400000 step=1 default=182400000 value=182400000 flags=read-only
                   test_pattern 0x009f0903 (menu)   : min=0 max=4 default=0 value=0
                   digital_gain 0x009f0905 (int)    : min=256 max=4095 step=1 default=256 value=256
```

To change the exposure setting, we can run this command:

```
v4l2-ctl -d /dev/video0 --set-ctrl=exposure=1000
```

To change the analogue gain setting, we can run this command:

```
v4l2-ctl -d /dev/video0 --set-ctrl=analogue_gain=200
```

To change the digital gain setting, we can run this command:

```
v4l2-ctl -d /dev/video0 --set-ctrl=digital_gain=1000
```

```{tip}
If you find that you cannot change one of the settings above, or that some of them are missing, you might
be targetting the wrong video device. If you target a video device that has no camera physically connected
to it (thus also does not have an associated media device), you will find that not all of the settings are
listed and available to modify. Read section [Video and media devices](#video-and-media-devices) for more
information on determining the correct video device for the camera you intend to target.
```

If you wish to change certain settings on all of the connected cameras, one easy way to do that is to copy
the [init script](#init-script) located at `/usr/bin/init_cams.sh` and add the desired configuration commands
in the appropriate section of the script. Then you can run your modified version of the script from the 
command line and the configurations will be made to all of the connected cameras.

### Display pipeline

This section will provide an example of using the Video Mixer based display pipeline with GStreamer. We will first
configure the capture/video pipelines as follows:

* RPi cameras will output 1080p resolution
* Video Processing Subsystem will downscale to 960x540 (one quarter of the 1080p monitor)
* Video Processing Subsystem will output YUY2 format

We can make the above configuration on ALL video pipes by using the init cams script:
```
init_cams.sh 1920 1080 960 540 YUY2
```

The display pipeline uses the Video Mixer IP to combine up to four video streams and send them to the 
DisplayPort live interface of the ZynqMP. In order to use the display pipeline in GStreamer, you first
need to enable it with the following command:

```
modetest -M xlnx -D a0000000.v_mix -s 60@46:1920x1080@NV16
```

After running that command, the monitor should show a blue screen. At this point you are ready to use GStreamer
to drive the Video Mixer. Note the following important points:
* the `width` and `height` parameters are set to output resolution of the video pipes. 
* the `format` parameter is set to `YUY2` which is required by the Video Mixer as it is configured for that format
  in the Vivado design.
* the `render-rectangle` parameter is set to `<x,y,width,height>` where x and y indicate where to position the top 
  left corner of the video on the monitor. Width and height are set to the resolution of the video pipes.
* the `plane-id` is set to 34, 35, 36 or 37, which correspond to the layer inputs of the Video Mixer IP.

```
sudo gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=34 render-rectangle="<0,0,960,540>" show-preroll-frame=false sync=false can-scale=false \
v4l2src device=/dev/video1 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=36 render-rectangle="<960,0,960,540>" show-preroll-frame=false sync=false can-scale=false \
v4l2src device=/dev/video2 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=38 render-rectangle="<0,540,960,540>" show-preroll-frame=false sync=false can-scale=false \
v4l2src device=/dev/video3 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=40 render-rectangle="<960,540,960,540>" show-preroll-frame=false sync=false can-scale=false
```

## Known issues and limitations

### PYNQ-ZU limits

The ZynqMP device on the PYNQ-ZU board is a relatively small device in terms of FPGA resources.
Fitting the necessary logic to handle four video streams simultaneously can be a challenge on this board. 
For this reason, in our Vivado design for this board we have included the video pipes for only two cameras:
CAM1 and CAM2.


[RPi Camera FMC]: https://camerafmc.com/docs/rpi-camera-fmc/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[Video Processing Subsystem IP]: https://docs.xilinx.com/r/en-US/pg231-v-proc-ss


