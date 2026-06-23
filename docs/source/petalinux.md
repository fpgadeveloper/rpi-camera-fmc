# PetaLinux

PetaLinux can be built for these reference designs with the cross-platform `build.py`
runner at the root of the repository.

## Requirements

To build the PetaLinux projects, you will need a physical or virtual machine running one of the 
[supported Linux distributions] as well as the Vitis Core Development Kit installed.

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

This will also launch the build process for the corresponding Vivado project if that project
has not already been built and its hardware exported.

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
3. Connect the [RPi Camera FMC] to the FMC connector of the target board. Connect one or more
   [Raspberry Pi camera module v2] to the [RPi Camera FMC].
4. Connect the USB-UART to your PC and then open a UART terminal set to 115200 baud and the 
   comport that corresponds to your target board.

   ```{note}
   The **ZCU102 / ZCU106** USB-UART bridge exposes *two* serial ports; the
   PetaLinux console comes out on PSU UART0 (typically the lower-numbered
   port). Open both if you're not sure which is which.
   ```
5. Connect and power your hardware.

## Test the cameras

1. Log into PetaLinux using the username `petalinux`. The first time you boot, you will be forced to set the
   password for this user. On subsequent boots, you will be required to use the chosen password.
2. Check that the cameras have been enumerated correctly by running the `v4l2-ctl --list-devices` command.
   The output should be similar to the following:
   ```
   zcu106-rpi-cam-fmc-2025-2:~$ v4l2-ctl --list-devices
   Xilinx Video Composite Device (platform:vcap_mipi_0_v_proc):
   	/dev/media0

   vcap_mipi_0_v_proc output 0 (platform:vcap_mipi_0_v_proc:0):
   	/dev/video0

   Xilinx Video Composite Device (platform:vcap_mipi_1_v_proc):
   	/dev/media1

   vcap_mipi_1_v_proc output 0 (platform:vcap_mipi_1_v_proc:0):
   	/dev/video1

   Xilinx Video Composite Device (platform:vcap_mipi_2_v_proc):
   	/dev/media2

   vcap_mipi_2_v_proc output 0 (platform:vcap_mipi_2_v_proc:0):
   	/dev/video2

   Xilinx Video Composite Device (platform:vcap_mipi_3_v_proc):
   	/dev/media3

   vcap_mipi_3_v_proc output 0 (platform:vcap_mipi_3_v_proc:0):
   	/dev/video3
   ```
   Note that there will only be a `Xilinx Video Composite Device` (media device) entry for each camera that
   is physically connected. The `vcap_mipi_N_v_proc` (video device) entries are always present for each
   capture pipeline in the hardware design, even if no camera is connected to that port.

3. Run the init script with the command `init_cams.sh`.
   ```
   zcu106-rpi-cam-fmc-2025-2:~$ init_cams.sh
   -------------------------------------------------
    Capture pipeline init: RPi cam -> Scaler -> DDR
   -------------------------------------------------
   Configuring all video capture pipelines to:
    - RPi Camera output    : 1920 x 1080
    - Scaler (VPSS) output : 1920 x 1080 YUY2
   Video Mixer found here:
    - a0000000.v_mix
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

4. The simplest way to display all of the connected cameras on a DisplayPort monitor is to run the
   `displaycams.sh` script (see step 6 below). If you want to display a single camera manually,
   or are testing the display pipeline, you first need to set the CRTC's mode with `modetest`. The
   command takes the form `modetest -M xlnx -D <vmix-bus-id> -s <connector>@<crtc>:1920x1080-60@NV16`.

   ```{important}
   * The pixel-clock wizard in the FPGA fabric is configured for **1080p60 only**. If you let
     modetest pick a different mode (for example the monitor's preferred 144 Hz or 4K mode), the
     dpsub will silently fail to drive valid pixels and the monitor will stay dark. Always pin the
     refresh rate with the `-60` suffix.
   * The connector and CRTC IDs are not stable across boards or kernel versions, so the example
     `49@47` shown below may differ on your system. Look them up at run-time using
     `modetest -M xlnx` (the connector ID is the one whose `status` shows `connected`; the CRTC
     ID is the only one listed). On a 2025.2 ZCU106 they will typically be `49@47`; on other
     boards they will differ.
   ```

   ```
   modetest -M xlnx -D a0000000.v_mix -s 49@47:1920x1080-60@NV16
   ```
   Note that the `-D` option must specify the correct `bus_id` of the video mixer. This can be found in the
   output of the `init_cams.sh` script (see above), or you can find it with the following command: 
   `find /sys/bus/platform/devices/ -name "*.v_mix"`. After running the command above, the monitor
   should display the modetest test pattern (a coloured fill that occupies the whole screen).

5. Use GStreamer to display the video from a single camera on the DisplayPort monitor:
   ```
   gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! \
   video/x-raw, width=1920, height=1080, format=YUY2, framerate=30/1 ! \
   kmssink bus-id=a0000000.v_mix plane-id=35 render-rectangle="< 0, 0, 1920, 1080 >" \
   show-preroll-frame=false sync=false can-scale=true
   ```
   Note the following important details:
   * You must use the correct `bus_id` for the video mixer (see step 4).
   * The `plane-id` must be one of the **YUYV overlay planes** of the Video Mixer IP. On a 2025.2
     ZCU106 these are typically `35`, `37`, `39` and `41` (the odd-numbered overlay planes). Plane IDs
     are not stable across boards or kernel versions, so look them up with `modetest -M xlnx`: each
     plane that lists `formats: YUYV` is an overlay you can target with a camera stream. Do not use
     the primary plane (which is `NV16` format) or the alpha/logo plane (which is `AR24`).
   * `render-rectangle` must use the spaced `"< x, y, w, h >"` syntax (kmssink documents the format
     this way and the parser in the 2025.2 GStreamer build is strict about the spaces).
   * `can-scale` must be set to `true`. In the 2025.2 kmssink build, setting `can-scale=false`
     causes the `render-rectangle` to be silently ignored and the video to be drawn centred on the
     screen instead.
   * To test a different camera, change the targeted video device from `/dev/video0` to another, such
     as `/dev/video1`. To stop streaming the video, press *Ctrl-C*.
   
6. Run the display cams script to display all cameras on the monitor at the same time. The script
   requires root privileges (DRM master access for kmssink), so it must be run with `sudo`:
   ```
   sudo displaycams.sh
   ```
   The display cams script is in the `/usr/bin` directory and it serves as an example for setting up the
   video pipelines and configuring the display pipeline to show all video streams. It auto-discovers the
   DRM connector, CRTC and overlay plane IDs at run-time, so it works on any board without editing.
   Here is the output of that script on a ZCU106:
   ```
   zcu106-rpi-cam-fmc-2025-2:~$ sudo displaycams.sh
   -------------------------------------------------
    Capture pipeline init: RPi cam -> Scaler -> DDR
   -------------------------------------------------
   Configuring all video capture pipelines to:
    - RPi Camera output    : 1920 x 1080
    - Scaler (VPSS) output : 960 x 540 YUY2
    - Frame rate           : 30 fps
   Video Mixer found here:
    - a0000000.v_mix
   Detected and configured the following cameras on RPi Camera FMC:
    - CAM0: /dev/media0 = /dev/video0
    - CAM1: /dev/media1 = /dev/video1
    - CAM2: /dev/media2 = /dev/video2
    - CAM3: /dev/media3 = /dev/video3
   setting mode 1920x1080-60.00Hz on connectors 49, crtc 47
   GStreamer command:
   --------------------------
   gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0000000.v_mix plane-id=35 render-rectangle="< 0, 0, 960, 540 >" show-preroll-frame=false sync=false can-scale=true v4l2src device=/dev/video1 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0000000.v_mix plane-id=37 render-rectangle="< 960, 0, 960, 540 >" show-preroll-frame=false sync=false can-scale=true v4l2src device=/dev/video2 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0000000.v_mix plane-id=39 render-rectangle="< 0, 540, 960, 540 >" show-preroll-frame=false sync=false can-scale=true v4l2src device=/dev/video3 io-mode=mmap ! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 ! kmssink bus-id=a0000000.v_mix plane-id=41 render-rectangle="< 960, 540, 960, 540 >" show-preroll-frame=false sync=false can-scale=true
   --------------------------
   Setting pipeline to PAUSED ...
   Pipeline is live and does not need PREROLL ...
   Pipeline is PREROLLED ...
   Setting pipeline to PLAYING ...
   New clock: GstSystemClock
   Redistribute latency...
   ^Chandling interrupt.
   Interrupt: Stopping pipeline ...
   Execution ended after 0:00:04.344644134
   Setting pipeline to NULL ...
   Freeing pipeline ...
   ```

## Debugging tips

### Video pipe settings

The `media-ctl` command can be useful in debugging issues with your video pipe design. Below we show an
example of the `media-ctl -d /dev/media0 -p` output, which shows each of the elements in the video pipe as well
as how they are connected and configured.

```
zcu106-rpi-cam-fmc-2025-2:~$ media-ctl -d /dev/media0 -p
Media controller API version 6.12.40

Media device information
------------------------
driver          xilinx-video
model           Xilinx Video Composite Device
serial          
bus info        platform:vcap_mipi_0_v_proc
hw revision     0x0
driver version  6.12.40

Device topology
- entity 1: vcap_mipi_0_v_proc output 0 (1 pad, 1 link)
            type Node subtype V4L flags 0
            device node name /dev/video0
	pad0: Sink
		<- "a0040000.v_proc_ss":1 [ENABLED]

- entity 5: 80050000.mipi_csi2_rx_subsystem (2 pads, 2 links, 0 routes)
            type V4L2 subdev subtype Unknown flags 0
            device node name /dev/v4l-subdev0
	pad0: Sink
		[stream:0 fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
		<- "imx219 2-0010":0 [ENABLED]
	pad1: Source
		[stream:0 fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
		-> "a0010000.ISPPipeline_accel":0 [ENABLED]

- entity 8: imx219 2-0010 (1 pad, 1 link, 0 routes)
            type V4L2 subdev subtype Sensor flags 0
            device node name /dev/v4l-subdev1
	pad0: Source
		[stream:0 fmt:SRGGB10_1X10/1920x1080 field:none colorspace:raw xfer:none ycbcr:601 quantization:full-range
		 crop.bounds:(8,8)/3280x2464
		 crop:(688,160)/1920x2160]
		-> "80050000.mipi_csi2_rx_subsystem":0 [ENABLED]

- entity 10: a0010000.ISPPipeline_accel (2 pads, 2 links, 0 routes)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev2
	pad0: Sink
		[stream:0 fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]
		<- "80050000.mipi_csi2_rx_subsystem":1 [ENABLED]
	pad1: Source
		[stream:0 fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]
		-> "a0040000.v_proc_ss":0 [ENABLED]

- entity 13: a0040000.v_proc_ss (2 pads, 2 links, 0 routes)
             type V4L2 subdev subtype Unknown flags 0
             device node name /dev/v4l-subdev3
	pad0: Sink
		[stream:0 fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]
		<- "a0010000.ISPPipeline_accel":1 [ENABLED]
	pad1: Source
		[stream:0 fmt:UYVY8_1X16/1920x1080 field:none colorspace:srgb]
		-> "vcap_mipi_0_v_proc output 0":0 [ENABLED]
```

Note that the format lines now include a `stream:0` prefix and entity headers list `0 routes` — these
are new in the 2025.2 / Linux 6.12 media controller API and reflect support for the streams API. The
overall topology and format propagation rules are unchanged.

Individual interfaces can be configured using `media-ctl -V` with commands similar to the following.
The exact base addresses (`80050000`, `a0010000`, `a0040000`) will depend on which capture pipeline
you are targeting; use `media-ctl -d /dev/mediaN -p` to find the right ones.

```
media-ctl -V '"80050000.mipi_csi2_rx_subsystem":0  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"80050000.mipi_csi2_rx_subsystem":1  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0010000.ISPPipeline_accel":0  [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]' -d /dev/media0
media-ctl -V '"a0010000.ISPPipeline_accel":1  [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]' -d /dev/media0
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
zcu106-rpi-cam-fmc-2025-2:~$ v4l2-ctl --list-devices
vcap_mipi_0_v_proc output 0 (platform:vcap_mipi_0_v_proc:0):
	/dev/video0

Xilinx Video Composite Device (platform:vcap_mipi_1_v_proc):
	/dev/media0

vcap_mipi_1_v_proc output 0 (platform:vcap_mipi_1_v_proc:0):
	/dev/video1

Xilinx Video Composite Device (platform:vcap_mipi_2_v_proc):
	/dev/media1

vcap_mipi_2_v_proc output 0 (platform:vcap_mipi_2_v_proc:0):
	/dev/video2

vcap_mipi_3_v_proc output 0 (platform:vcap_mipi_3_v_proc:0):
	/dev/video3
```

Notice that we have 4 video devices, but only 2 media devices. That is because the hardware can support
4 cameras, but only 2 have been connected and enumerated. The `Xilinx Video Composite Device` entries
identify which capture pipeline each media device is associated with (`vcap_mipi_1_v_proc` is CAM1,
`vcap_mipi_2_v_proc` is CAM2), and the `vcap_mipi_N_v_proc output 0` entries identify the video device
for each capture pipeline. From the above, we can determine these associations:

* CAM1 is associated with `/dev/video1` (since `platform:vcap_mipi_1_v_proc` is CAM1) and `/dev/media0`
  (because the `Xilinx Video Composite Device` for `vcap_mipi_1_v_proc` lists `/dev/media0`)
* CAM2 is associated with `/dev/video2` and `/dev/media1`

```{tip}
In the 2025.2 PetaLinux build, `v4l2-ctl --list-devices` groups each connected camera's media device
with its corresponding video pipeline (alternating `Xilinx Video Composite Device` ... media + 
`vcap_mipi_N_v_proc output 0` ... video). This is a change from earlier releases (such as 2022.1)
where all video devices were listed first followed by a single combined block of all media devices.
If you also want to confirm an association using `media-ctl`, use the `media-ctl -d /dev/mediaN -p`
command and look for the `device node name /dev/videoM` line, which gives the video device that
particular media device feeds into.
```

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
zcu106-rpi-cam-fmc-2025-2:~$ init_cams.sh
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
`PetaLinux/bsp/<target>/project-spec/meta-user/recipes-apps/initcams/files/init_cams.sh`

### Yavta

An alternative way to get images from the cameras is to use the `yavta` tool, for example:

```
yavta -n 3 -c1 -f NV12 -s 1920x1080 --skip 9 -F /dev/video0
```

### Changing camera settings

It is possible to change certain camera settings to improve the quality of the images from the cameras, 
to change the colors or to flip the images. The settings that can be changed will depend on the camera
that is being used. To get a list of the settings, use the `v4l2-ctl -d /dev/video0 --list-ctrls` command.
In the case of the Raspberry Pi camera v2 in the 2025.2 build, this is the output from running that command:

```
zcu106-rpi-cam-fmc-2025-2:~$ v4l2-ctl -d /dev/video0 --list-ctrls

User Controls

                       exposure 0x00980911 (int)    : min=4 max=1759 step=1 default=1600 value=1600
                horizontal_flip 0x00980914 (bool)   : default=0 value=0 flags=modify-layout
                  vertical_flip 0x00980915 (bool)   : default=0 value=0 flags=modify-layout
           low_latency_controls 0x0098ca21 (int)    : min=2 max=8 step=1 default=4 value=4
                       red_gain 0x0098ca61 (int)    : min=0 max=65535 step=1 default=100 value=100 flags=slider
                      blue_gain 0x0098ca62 (int)    : min=0 max=65535 step=1 default=350 value=350 flags=slider
                         awb_en 0x0098ca63 (bool)   : default=1 value=1 flags=slider
                      threshold 0x0098ca64 (int)    : min=0 max=65535 step=1 default=512 value=512 flags=slider
                      red_gamma 0x0098ca65 (int)    : min=1 max=40 step=1 default=20 value=20 flags=slider
                    green_gamma 0x0098ca66 (int)    : min=1 max=40 step=1 default=15 value=15 flags=slider
                     blue_gamma 0x0098ca67 (int)    : min=1 max=40 step=1 default=20 value=20 flags=slider

Image Source Controls

              vertical_blanking 0x009e0901 (int)    : min=32 max=64455 step=1 default=683 value=683
            horizontal_blanking 0x009e0902 (int)    : min=1528 max=1528 step=1 default=1528 value=1528 flags=read-only
                  analogue_gain 0x009e0903 (int)    : min=0 max=232 step=1 default=0 value=0
                red_pixel_value 0x009e0904 (int)    : min=0 max=1023 step=1 default=1023 value=1023
          green_red_pixel_value 0x009e0905 (int)    : min=0 max=1023 step=1 default=1023 value=1023
               blue_pixel_value 0x009e0906 (int)    : min=0 max=1023 step=1 default=1023 value=1023
         green_blue_pixel_value 0x009e0907 (int)    : min=0 max=1023 step=1 default=1023 value=1023

Image Processing Controls

                 link_frequency 0x009f0901 (intmenu): min=0 max=0 default=0 value=0 (456000000 0x1b2e0200) flags=read-only
                     pixel_rate 0x009f0902 (int64)  : min=182400000 max=182400000 step=1 default=182400000 value=182400000 flags=read-only
                   test_pattern 0x009f0903 (menu)   : min=0 max=4 default=0 value=0 (Disabled)
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

The 2025.2 build also adds ISP-pipeline white-balance and gamma controls (`red_gain`, `blue_gain`,
`awb_en`, `threshold`, `red_gamma`, `green_gamma`, `blue_gamma`). For example, to disable automatic
white balance and apply manual gains:

```
v4l2-ctl -d /dev/video0 --set-ctrl=awb_en=0
v4l2-ctl -d /dev/video0 --set-ctrl=red_gain=120
v4l2-ctl -d /dev/video0 --set-ctrl=blue_gain=300
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
need to enable it with the following command (substitute the correct connector and CRTC IDs and the
correct video mixer bus_id for your board — see step 4 of the [Test the cameras](#test-the-cameras)
section above):

```
modetest -M xlnx -D a0000000.v_mix -s 49@47:1920x1080-60@NV16
```

After running that command, the monitor should show the modetest test pattern. At this point you are
ready to use GStreamer to drive the Video Mixer. Note the following important points:
* the `width` and `height` parameters are set to the output resolution of the video pipes (960×540 in
  this example).
* the `format` parameter is set to `YUY2`, which is the format that the Video Processing Subsystem is
  outputting (see the `init_cams.sh` output).
* the `render-rectangle` parameter is set to `"< x, y, width, height >"` where x and y indicate where
  to position the top left corner of the video on the monitor. Note the **spaces** around the values
  inside the angle brackets — these are required by the GstValueArray parser in the 2025.2 GStreamer
  build; without them, kmssink silently ignores the render-rectangle and the video is drawn centered
  on the screen.
* the `plane-id` is set to one of the YUYV overlay planes of the Video Mixer IP. On a 2025.2 ZCU106
  these are typically `35`, `37`, `39` and `41` (the four odd-numbered overlay planes); use
  `modetest -M xlnx` to confirm the IDs on your board (look for `formats: YUYV` under each plane).
* `can-scale=true` must be set; the previous default of `false` causes the render-rectangle to be
  silently dropped in the 2025.2 kmssink build.
* The whole GStreamer command must be run with `sudo` because each kmssink instance needs DRM
  master access to the video mixer.

```
sudo gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=35 render-rectangle="< 0, 0, 960, 540 >" show-preroll-frame=false sync=false can-scale=true \
v4l2src device=/dev/video1 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=37 render-rectangle="< 960, 0, 960, 540 >" show-preroll-frame=false sync=false can-scale=true \
v4l2src device=/dev/video2 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=39 render-rectangle="< 0, 540, 960, 540 >" show-preroll-frame=false sync=false can-scale=true \
v4l2src device=/dev/video3 io-mode=mmap \
! video/x-raw, width=960, height=540, format=YUY2, framerate=30/1 \
! kmssink bus-id=a0000000.v_mix plane-id=41 render-rectangle="< 960, 540, 960, 540 >" show-preroll-frame=false sync=false can-scale=true
```

The `displaycams.sh` script in `/usr/bin` is a wrapper that performs the steps above (mode-set,
multi-camera gst-launch) using DRM/plane IDs that it discovers at run-time, so you do not have to
edit the script when switching boards or rebuilding the kernel.

## Known issues and limitations

### PYNQ-ZU limits

The ZynqMP device on the PYNQ-ZU board is a relatively small device in terms of FPGA resources.
Fitting the necessary logic to handle four video streams simultaneously can be a challenge on this board. 
For this reason, in our Vivado design for this board we have included the video pipes for only two cameras:
CAM1 and CAM2.


[RPi Camera FMC]: https://docs.opsero.com/op068/datasheet/overview/
[Raspberry Pi camera module v2]: https://www.raspberrypi.com/products/camera-module-v2/
[supported Linux distributions]: https://docs.xilinx.com/r/2022.1-English/ug1144-petalinux-tools-reference-guide/Setting-Up-Your-Environment
[Video Processing Subsystem IP]: https://docs.xilinx.com/r/en-US/pg231-v-proc-ss


