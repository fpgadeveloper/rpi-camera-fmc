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

# Camera demo scripts (displaycams.sh / hailodemo.sh) need modetest and
# gst-launch-1.0 with v4l2src + kmssink; compositor/videoconvertscale/
# videotestsrc for custom display pipelines; debugutilsbad for fpsdisplaysink
# (frame-rate measurement in the documented test pipelines) (PetaLinux:
# libdrm-tests + packagegroup-xilinx-gstreamer).
# Every plugin the image needs is listed here explicitly: on VCU devices
# (ZU+ EV) gstreamer-vcu-examples above pulls in all of gst-plugins-bad as a
# side effect, but on non-VCU devices such as PYNQ-ZU (ZU5EG) nothing else
# installs them.
IMAGE_INSTALL:append = " \
    libdrm-tests \
    gstreamer1.0 \
    gstreamer1.0-plugins-good-video4linux2 \
    gstreamer1.0-plugins-bad-kms \
    gstreamer1.0-plugins-bad-debugutilsbad \
    gstreamer1.0-plugins-base-compositor \
    gstreamer1.0-plugins-base-videoconvertscale \
    gstreamer1.0-plugins-base-videotestsrc \
"

# PYNQ-ZU has no Ethernet: on-board WILC3000 Wi-Fi (firmware, supplicant, iw, regdb, wlan0 DHCP; credentials written on the board at runtime).
IMAGE_INSTALL:append = " \
    wilc3000-firmware \
    wifi-sta-config \
    wpa-supplicant \
    wpa-supplicant-cli \
    wpa-supplicant-passphrase \
    iw \
    wireless-regdb-static \
"
