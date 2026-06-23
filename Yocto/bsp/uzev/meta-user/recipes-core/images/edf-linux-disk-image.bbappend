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
