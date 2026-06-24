# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# RPi Camera FMC reference-design rootfs packages (ported from the PetaLinux
# bsp rootfs_config: design test/utility tools layered on the amd-edf base).
IMAGE_INSTALL:append = " \
    v4l-utils \
    libcamera \
    media-ctl \
    initcams \
    mtd-utils \
    nfs-utils \
    can-utils \
"

# gstreamer-vcu-examples has REQUIRED_MACHINE_FEATURES = "vcu" (hardened Video
# Codec Unit). This target's design does not expose a VCU, so gen-machineconf
# does not set the vcu feature -- requesting the package unconditionally fails
# the build with "Nothing RPROVIDES gstreamer-vcu-examples". Pull it in only
# when the generated machine actually has the feature.
IMAGE_INSTALL:append = " ${@bb.utils.contains('MACHINE_FEATURES', 'vcu', 'gstreamer-vcu-examples', '', d)}"
