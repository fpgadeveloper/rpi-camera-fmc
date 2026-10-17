# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# RPi Camera FMC reference-design rootfs packages (same set as the ZynqMP
# BSPs) plus the bench tools every Opsero image ships.
IMAGE_INSTALL:append = " \
    v4l-utils \
    libcamera \
    media-ctl \
    initcams \
    mtd-utils \
    nfs-utils \
    can-utils \
    ethtool \
    iperf3 \
    iproute2 \
    i2c-tools \
    phytool \
"

# Camera capture / custom pipelines: gst-launch-1.0 with v4l2src, plus
# modetest + kmssink for the display path (DVI over HDMI).
IMAGE_INSTALL:append = " \
    libdrm-tests \
    gstreamer1.0 \
    gstreamer1.0-plugins-good-video4linux2 \
    gstreamer1.0-plugins-bad-kms \
    gstreamer1.0-plugins-base-compositor \
    gstreamer1.0-plugins-base-videoconvertscale \
    gstreamer1.0-plugins-base-videotestsrc \
"
