# Copyright (C) 2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# DVI output: 8T49N241 clock driver built in, panel-dpi bridge, AXI IIC, mixer + VTC.
# The mixer DRM-bridge fix (0001-drm-xlnx-mixer-fix-NULL-deref-in-connector_init)
# is carried by the target's own meta-user layer.
FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

SRC_URI:append = " file://dvi-out.cfg"
KERNEL_FEATURES:append = " dvi-out.cfg"

# panel-dpi offers only MEDIA_BUS_FMT_FIXED to the mixer CRTC; without this the
# modeset fails with "Bridge atomic check failed: -524" (VCK190 bench 2026-10-16).
# Independent of the target's 0001-0003 mixer/drv patches (applies before or after).
SRC_URI:append = " file://0101-drm-xlnx-mixer-accept-MEDIA_BUS_FMT_FIXED-from-the-bridge-chain.patch"
