# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# RPi Camera FMC reference-design rootfs packages (ported from the PetaLinux
# bsp rootfs_config: design test/utility tools layered on the amd-edf base).
IMAGE_INSTALL:append = " \
    v4l-utils \
    libcamera \
    media-ctl \
    gstreamer-vcu-examples \
    initcams \
    mtd-utils \
    nfs-utils \
    can-utils \
"

# Camera demo scripts (displaycams.sh / hailodemo.sh) need modetest and
# gst-launch-1.0 with v4l2src + kmssink; compositor/videoconvertscale/
# videotestsrc for custom display pipelines (PetaLinux: libdrm-tests +
# packagegroup-xilinx-gstreamer).
IMAGE_INSTALL:append = " \
    libdrm-tests \
    gstreamer1.0 \
    gstreamer1.0-plugins-good-video4linux2 \
    gstreamer1.0-plugins-bad-kms \
    gstreamer1.0-plugins-base-compositor \
    gstreamer1.0-plugins-base-videoconvertscale \
    gstreamer1.0-plugins-base-videotestsrc \
"
