# Using and testing the design

This page shows how to use and test a Zynq UltraScale+ design once Linux has booted. It applies
to both the [PetaLinux](petalinux) and the [Yocto](yocto) images: they contain the same camera
and display drivers, the same kernel patches and the same `init_cams.sh` / `displaycams.sh`
scripts. The few differences are listed below.

|                       | PetaLinux image                     | Yocto (AMD EDF) image                       |
|-----------------------|-------------------------------------|---------------------------------------------|
| Login user            | `petalinux`                         | `amd-edf`                                   |
| First login           | you are asked to set a password     | you are asked to set a password             |
| Hostname              | `<board>-rpi-cam-fmc-2025-2`        | `<board>-rpi-2025-2` (`zcu102-hpc1-rpi-2025-2` for `zcu102_hpc1`) |
| Network               | board Ethernet port                 | board Ethernet port (DHCP, SSH server); PYNQ-ZU: Wi-Fi |
| Root filesystem       | SD card partition 2                 | SD card partition 3                         |

The examples below were captured on a ZCU106 (`zcu106_hpc0`) with four Raspberry Pi Camera
Module 2 (IMX219) on CAM0 to CAM3 and a 1080p60 capable monitor. Device numbers, DRM IDs and
the order of the entries can differ on your board; the text explains how to find the right
values. Run the camera and display commands with `sudo`: they need access to the media devices
and DRM master access to the display.

## Before you start

* Connect the cameras to the camera ports that your target supports: CAM0 to CAM3 on most targets,
  **CAM0 and CAM1** on `zcu102_hpc1`, **CAM1 and CAM2** on `pynqzu`. Cameras on other ports are
  not seen by the design.
* Connect a DisplayPort monitor (or a DisplayPort to HDMI adapter and an HDMI monitor) that
  supports 1920x1080 at 60 Hz. The display pipeline supports this mode only.
* Connect the USB-UART and open a terminal at 115200 baud (8N1). The board Ethernet port is
  optional; it gives you SSH access and an easy way to copy captured frames to your PC.

## Quick test

The table below is a complete functional test of a target. Each step is described in more
detail in the following sections.

| Step | Command | Expected result |
|------|---------|-----------------|
| 1. Cameras enumerated | `v4l2-ctl --list-devices` | a `vcap_mipi_<n>_v_proc` video device and a `Xilinx Video Composite Device` media device for each connected camera |
| 2. Sensors probed | `for m in /dev/media*; do sudo media-ctl -d $m -p \| grep -E "entity.*imx219"; done` | one `imx219` entity per connected camera |
| 3. Pipelines configured | `sudo init_cams.sh` | one `CAMn: /dev/mediaX = /dev/videoY` line per connected camera |
| 4. Capture | `sudo v4l2-ctl -d /dev/videoY --set-fmt-video=width=1920,height=1080,pixelformat=YUYV --stream-mmap=4 --stream-count=30 --stream-to=/tmp/cam.yuv` | a file of 124416000 bytes (30 frames of 1920x1080 YUYV) |
| 5. Monitor detected | `modetest -M xlnx -c \| grep -E "connected\|1920x1080"` | the DP connector is `connected` and lists a 1920x1080 mode |
| 6. Display | `sudo displaycams.sh` | every camera live in a 960x540 quadrant of the monitor; stop with *Ctrl-C* |
| 7. Kernel log | `dmesg \| grep -iE "error\|fail" \| grep -iE "video\|csi\|imx219\|v_proc\|mixer\|drm\|dpsub"` | nothing except the boot-time pair described in [Troubleshooting](troubleshooting.md#harmless-boot-messages) |

Run the capture step before `displaycams.sh`: `displaycams.sh` reconfigures every pipeline to
960x540, while the capture step above expects the 1920x1080 configuration that `init_cams.sh`
sets.

## Cameras and video devices

### List the cameras

`v4l2-ctl --list-devices` lists a media device (`Xilinx Video Composite Device`) and a video
device (`vcap_mipi_<n>_v_proc output 0`) for each capture pipeline whose camera was detected.
The number in `vcap_mipi_<n>_v_proc` is the camera port: `vcap_mipi_0_v_proc` is CAM0,
`vcap_mipi_1_v_proc` is CAM1, and so on. Example with four cameras:

```
$ v4l2-ctl --list-devices
Xilinx Video Composite Device (platform:amba_pl:vcap_mipi_0_v_):
	/dev/media0

Xilinx Video Composite Device (platform:amba_pl:vcap_mipi_1_v_):
	/dev/media1

Xilinx Video Composite Device (platform:amba_pl:vcap_mipi_2_v_):
	/dev/media2

Xilinx Video Composite Device (platform:amba_pl:vcap_mipi_3_v_):
	/dev/media3

vcap_mipi_0_v_proc output 0 (platform:vcap_mipi_0_v_proc:0):
	/dev/video0

vcap_mipi_1_v_proc output 0 (platform:vcap_mipi_1_v_proc:0):
	/dev/video1

vcap_mipi_2_v_proc output 0 (platform:vcap_mipi_2_v_proc:0):
	/dev/video2

vcap_mipi_3_v_proc output 0 (platform:vcap_mipi_3_v_proc:0):
	/dev/video3
```

The order of the entries depends on the build: some list all the media devices first (as above),
others alternate media and video devices.

### Video and media devices

Each connected camera is associated with one video device and one media device. When using tools
such as GStreamer, you must specify the video or media device to use, so it is important to know
which camera (which port) is associated with which device. **The device numbers are not stable**:
`/dev/video0` and `/dev/media0` are not necessarily the same camera, and the numbers shift when
fewer cameras are connected than the design supports.

A media device exists only for a camera that is physically connected and was successfully
enumerated. Some builds also create a video device for a capture pipeline whose camera is not
connected; such a device cannot be used.

The reliable way to find the devices of each camera is the output of the [init script](#init-script),
which prints one line per detected camera:

```
 - CAM1: /dev/media0 = /dev/video1
 - CAM2: /dev/media1 = /dev/video2
```

In this example only CAM1 and CAM2 are connected, and the media and video device numbers do not
align. To confirm an association by hand, run `media-ctl -d /dev/mediaN -p` and look for the
`device node name /dev/videoM` line: it names the video device that the media device feeds.

Below are a few examples of camera connections and the resulting device associations on a
four-camera target.

| Connected | CAM0 | CAM1 | CAM2 | CAM3 |
|-----------|------|------|------|------|
| CAM1 and CAM2 | — | `/dev/video1`, `/dev/media0` | `/dev/video2`, `/dev/media1` | — |
| CAM0 and CAM1 | `/dev/video0`, `/dev/media0` | `/dev/video1`, `/dev/media1` | — | — |
| CAM2 and CAM3 | — | — | `/dev/video2`, `/dev/media0` | `/dev/video3`, `/dev/media1` |

### Media graph

`media-ctl -d /dev/mediaN -p` shows the elements of one capture pipeline, how they are linked and
how each pad is configured. Below is the output for CAM0 (shortened):

```
$ sudo media-ctl -d /dev/media0 -p
Media device information
------------------------
driver          xilinx-video
model           Xilinx Video Composite Device
...
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

The `stream:0` prefixes and the `0 routes` counts come from the streams API of the Linux 6.12
media controller; they do not change the topology. The I2C bus number in the sensor name
(`imx219 2-0010`) depends on the probe order.

Individual pads can be configured with `media-ctl -V`. The entity names (which contain the base
addresses of the IP) depend on the capture pipeline; take them from the `media-ctl -p` output:

```
sudo media-ctl -d /dev/media0 -V '"imx219 2-0010":0 [fmt:SRGGB10_1X10/1920x1080]'
sudo media-ctl -d /dev/media0 -V '"80050000.mipi_csi2_rx_subsystem":0 [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]'
sudo media-ctl -d /dev/media0 -V '"80050000.mipi_csi2_rx_subsystem":1 [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]'
sudo media-ctl -d /dev/media0 -V '"a0010000.ISPPipeline_accel":0 [fmt:SRGGB10_1X10/1920x1080 field:none colorspace:srgb]'
sudo media-ctl -d /dev/media0 -V '"a0010000.ISPPipeline_accel":1 [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]'
sudo media-ctl -d /dev/media0 -V '"a0040000.v_proc_ss":0 [fmt:RBG888_1X24/1920x1080 field:none colorspace:srgb]'
sudo media-ctl -d /dev/media0 -V '"a0040000.v_proc_ss":1 [fmt:UYVY8_1X16/1920x1080 field:none colorspace:srgb]'
```

## Init script

The `init_cams.sh` script (in `/usr/bin`) finds all of the cameras connected to the RPi Camera
FMC, configures every capture pipeline with `media-ctl`, and prints the port, media device and
video device of each camera, plus the bus ID of the Video Mixer (used by the display commands).
Cameras on other buses (such as USB cameras) are ignored.

```
$ sudo init_cams.sh
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

By default the cameras output 1920x1080 and the scaler (VPSS) outputs 1920x1080 YUY2. You can pass
other values as arguments; if you do, specify all five, in this order:

```
sudo init_cams.sh <SRC_RES_W> <SRC_RES_H> <OUT_RES_W> <OUT_RES_H> <OUT_FORMAT>
```

* `SRC_RES_W` x `SRC_RES_H`: camera resolution, one supported by the IMX219 driver
  (640x480, 1640x1232, 1920x1080)
* `OUT_RES_W` x `OUT_RES_H`: scaler output resolution
* `OUT_FORMAT`: `YUY2` or `NV12`

For example, to scale the 1080p camera output down to 720p:

```
sudo init_cams.sh 1920 1080 1280 720 YUY2
```

To change the defaults, or to add your own `media-ctl` / `v4l2-ctl` commands for every camera, copy
`/usr/bin/init_cams.sh` to your home directory and edit the copy. The script that is built into the
image is in the BSP of each target: `PetaLinux/bsp/<board>/project-spec/meta-user/recipes-apps/initcams/files/init_cams.sh`
or `Yocto/bsp/<board>/meta-user/recipes-apps/initcams/files/init_cams.sh`.

## Capture frames

With the pipelines configured by `init_cams.sh` (1920x1080 YUY2), capture 30 frames from one camera
to a file. Use the video device that `init_cams.sh` printed for the camera:

```
$ sudo v4l2-ctl -d /dev/video0 --set-fmt-video=width=1920,height=1080,pixelformat=YUYV \
      --stream-mmap=4 --stream-count=30 --stream-to=/tmp/video0.yuv
<<<<<<<<<<<<<<< 13.55 fps
<<<<<<<<<<<< 12.58 fps
<<<
$ ls -l /tmp/video0.yuv
-rw-r--r-- 1 root root 124416000 Oct  1 00:26 /tmp/video0.yuv
```

The file holds 30 frames of 1920 x 1080 pixels at 2 bytes per pixel: 30 x 4147200 = 124416000
bytes. The format requested with `--set-fmt-video` must match the configuration of the pipeline.

```{note}
`v4l2-ctl` reports about 13 fps while it writes the frames to `/tmp`, which is held in RAM on these
images (delete the files when you are done). The cameras run at 30 fps: stream without writing a
file to see it, for example
`sudo v4l2-ctl -d /dev/video0 --stream-mmap=4 --stream-count=90`.
```

To capture from every connected camera in turn:

```
for v in $(v4l2-ctl --list-devices | grep -A1 vcap_mipi | grep -o '/dev/video[0-9]*'); do
  sudo v4l2-ctl -d $v --set-fmt-video=width=1920,height=1080,pixelformat=YUYV \
    --stream-mmap=4 --stream-count=30 --stream-to=/tmp/$(basename $v).yuv
  ls -l /tmp/$(basename $v).yuv
done
```

To look at a frame, copy the file to your PC (for example with `scp`; on the Yocto image use
`scp -O`, as the image has no SFTP server) and play it as raw video, for example with FFmpeg:

```
ffplay -f rawvideo -pixel_format yuyv422 -video_size 1920x1080 video0.yuv
```

An alternative way to grab frames on the PetaLinux image is the `yavta` tool, for example:

```
yavta -n 3 -c1 -f NV12 -s 1920x1080 --skip 9 -F /dev/video0
```

## Display

### Check the monitor

```
$ modetest -M xlnx -c | grep -E "connected|1920x1080"
49	0	connected	DP-1           	380x210		16	48
  #1 1920x1080 144.00 1920 2008 2052 2200 1080 1083 1088 1125 356400 flags: phsync, pvsync; type: driver
  #2 1920x1080 120.00 1920 2008 2052 2200 1080 1084 1089 1125 297000 flags: phsync, pvsync; type: driver
  #3 1920x1080 119.88 1920 2008 2052 2200 1080 1084 1089 1125 296703 flags: phsync, pvsync; type: driver
  #4 1920x1080 60.00 1920 2008 2052 2200 1080 1084 1089 1125 148500 flags: nhsync, nvsync; type: driver
  #5 1920x1080 60.00 1920 2008 2052 2200 1080 1084 1089 1125 148500 flags: phsync, pvsync; type: driver
  #6 1920x1080 59.94 1920 2008 2052 2200 1080 1084 1089 1125 148352 flags: phsync, pvsync; type: driver
```

The first column is the connector ID (`49` here). The list of modes comes from the monitor, so it
differs between monitors. The design can only display the 1920x1080 mode at 60 Hz (pixel clock
148.5 MHz).

### Display all cameras

The `displaycams.sh` script (in `/usr/bin`) shows every connected camera on the monitor at the
same time. It configures each capture pipeline to output 960x540 YUY2 at 30 fps, finds the DRM
connector, CRTC and overlay plane IDs of the Video Mixer, sets the 1920x1080 60 Hz mode, and runs
one GStreamer pipeline per camera, each drawing into a quadrant of the screen. It needs root
privileges (DRM master access for `kmssink`):

```
$ sudo displaycams.sh
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
```

What to expect on the monitor:

* The cameras are drawn in the order the script lists them, into the top-left, top-right,
  bottom-left and bottom-right quadrants (960x540 each).
* On the two-camera targets (`zcu102_hpc1`, `pynqzu`), the two cameras fill the top row and the
  bottom half of the screen shows the plain blue background of the Video Mixer. The same
  applies to any quadrant without a camera.
* The video keeps running until you press *Ctrl-C*. Afterwards the monitor shows the blue
  background until the display is switched off or another mode is set.

The script serves as an example: its settings (camera and output resolution, format, display mode
and frame rate) are variables at the top of the file. It pins the display mode to 1920x1080 at
60 Hz; do not change `DISP_RATE`.

### Set the mode and display one camera

To drive the display pipeline yourself, first set the mode with `modetest`. The command takes the
form `modetest -M xlnx -D <vmix-bus-id> -s <connector>@<crtc>:1920x1080-60@NV16`:

```
echo | sudo modetest -M xlnx -D a0000000.v_mix -s 49@47:1920x1080-60@NV16
```

* The `-D` option is the bus ID of the Video Mixer, printed by `init_cams.sh`, or found with
  `find /sys/bus/platform/devices/ -name "*.v_mix"`.
* The connector and CRTC IDs (`49@47` here) are not guaranteed to be the same on every board or
  kernel version. Run `modetest -M xlnx` to look them up: the connector is the one whose
  status is `connected`, the CRTC is the only one listed.
* **Always pin the refresh rate with the `-60` suffix.** Without it `modetest` picks the first
  mode of the monitor, which may be a higher refresh rate that the design cannot produce.
* After the mode set the monitor shows the blue background of the Video Mixer.

Then display a camera with GStreamer, here the camera on `/dev/video0` at full screen. Configure
the pipelines for 1920x1080 YUY2 first (`sudo init_cams.sh`):

```
sudo gst-launch-1.0 v4l2src device=/dev/video0 io-mode=mmap ! \
  video/x-raw, width=1920, height=1080, format=YUY2, framerate=30/1 ! \
  kmssink bus-id=a0000000.v_mix plane-id=35 render-rectangle="< 0, 0, 1920, 1080 >" \
  show-preroll-frame=false sync=false can-scale=true
```

* `width`, `height` and `format` must match the output of the capture pipeline (the scaler output
  set by `init_cams.sh`).
* `plane-id` must be one of the **YUYV overlay planes** of the Video Mixer, one per camera. On these
  designs they are `35`, `37`, `39` and `41`; confirm with `modetest -M xlnx` (each plane that lists
  `formats: YUYV`). Do not use the primary plane (`NV16`) or the alpha plane (`AR24`).
* `render-rectangle` must use the spaced `"< x, y, w, h >"` syntax, and `can-scale=true` must be
  set; otherwise `kmssink` ignores the rectangle and draws the video centred on the screen.

To display four cameras at 960x540 each, configure the pipelines with
`sudo init_cams.sh 1920 1080 960 540 YUY2`, set the mode, and run one `v4l2src ! ... ! kmssink`
branch per camera in a single `gst-launch-1.0` command, with a different `plane-id` and
`render-rectangle` for each (see the command printed by `displaycams.sh` above).

### Check the display path with a test pattern

To check the display path on its own (without the cameras), set the mode and send a GStreamer test
pattern to one of the overlay planes. The colour bars should appear on the monitor in their correct
colours (`videotestsrc` is included in the Yocto image):

```
echo | sudo modetest -M xlnx -D a0000000.v_mix -s 49@47:1920x1080-60@NV16
sudo gst-launch-1.0 videotestsrc pattern=smpte ! \
  video/x-raw,format=YUY2,width=1920,height=1080,framerate=30/1 ! \
  kmssink bus-id=a0000000.v_mix plane-id=35 sync=false
```

### Check the display clock

The display Clocking Wizard is reprogrammed by Linux for the pixel clock of each mode set. You can
read its rate in the clock summary (the debug file system must be mounted, as it is by default):

```
sudo grep clk_wiz /sys/kernel/debug/clk/clk_summary
```

The `80010000.clk_wiz_out0` clock (the address can differ between targets) should read about
**262.7 MHz** after boot, before any mode set, and **148.5 MHz** after a 1920x1080 60 Hz mode set.
See [Troubleshooting](troubleshooting.md#kernel-panic-at-the-display-mode-set) if it does not.

## ISP controls

The ISP Pipeline of each camera exposes its white balance and gamma settings as V4L2 controls. They
can be read and set on the camera's video device (or its ISP sub-device):

```
$ v4l2-ctl -d /dev/video0 --list-ctrls
...
                       red_gain 0x0098ca61 (int)    : min=0 max=65535 step=1 default=128 value=128 flags=slider
                      blue_gain 0x0098ca62 (int)    : min=0 max=65535 step=1 default=210 value=210 flags=slider
                         awb_en 0x0098ca63 (bool)   : default=1 value=1 flags=slider
                      threshold 0x0098ca64 (int)    : min=0 max=65535 step=1 default=350 value=350 flags=slider
                      red_gamma 0x0098ca65 (int)    : min=1 max=40 step=1 default=20 value=20 flags=slider
                    green_gamma 0x0098ca66 (int)    : min=1 max=40 step=1 default=20 value=20 flags=slider
                     blue_gamma 0x0098ca67 (int)    : min=1 max=40 step=1 default=20 value=20 flags=slider
...
```

| Control | Default | Description |
|---------|---------|-------------|
| `red_gain`, `blue_gain` | 128, 210 | gains applied to the red and blue Bayer samples before demosaicing |
| `awb_en` | 1 | automatic white balance on (1) or off (0) |
| `threshold` | 350 | threshold of the automatic white balance statistics |
| `red_gamma`, `green_gamma`, `blue_gamma` | 20 | gamma curve of each colour channel, in tenths (20 = gamma 2.0). A lower value brightens the mid-tones of that channel, a higher value darkens them |

The defaults of `red_gain`, `blue_gain` and `threshold` come from the device tree
(`xlnx,rgain`, `xlnx,bgain` and `xlnx,pawb` in the `system-user.dtsi` of the BSP); the three gamma
controls default to 2.0, which gives a colour-neutral picture.

Set a control with `--set-ctrl`, for example:

```
sudo v4l2-ctl -d /dev/video0 --set-ctrl=green_gamma=18
sudo v4l2-ctl -d /dev/video0 --set-ctrl=awb_en=0,red_gain=140,blue_gain=200
```

To apply the same settings to every camera:

```
for v in $(v4l2-ctl --list-devices | grep -A1 vcap_mipi | grep -o '/dev/video[0-9]*'); do
  sudo v4l2-ctl -d $v --set-ctrl=red_gamma=20,green_gamma=20,blue_gamma=20
done
```

```{note}
The automatic white balance assumes that the scene averages to grey. A scene that is dominated by
one colour (for example a green circuit board, or a dark scene lit by coloured LEDs) can give that
camera's picture a visible tint, while the other cameras look neutral. Point the camera at a more
varied scene, or turn the automatic white balance off (`awb_en=0`) and set `red_gain` and
`blue_gain` by hand.
```

## Camera sensor controls

The video device also exposes the controls of the IMX219 sensor, such as `exposure`,
`analogue_gain`, `digital_gain`, `horizontal_flip`, `vertical_flip` and `test_pattern`. List
them with `v4l2-ctl -d /dev/video0 --list-ctrls` and set them in the same way:

```
sudo v4l2-ctl -d /dev/video0 --set-ctrl=exposure=1000
sudo v4l2-ctl -d /dev/video0 --set-ctrl=analogue_gain=200
sudo v4l2-ctl -d /dev/video0 --set-ctrl=digital_gain=1000
sudo v4l2-ctl -d /dev/video0 --set-ctrl=vertical_flip=1,horizontal_flip=1
```

```{tip}
If a control is missing or cannot be changed, you are probably targeting the video device of a
capture pipeline that has no camera connected. See [Video and media devices](#video-and-media-devices)
to find the right device.
```

To apply settings to all cameras at every start, copy the [init script](#init-script) and add the
`v4l2-ctl` commands to it.
