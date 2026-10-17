# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT
#
# large-dtb-sp-bss.cfg: raise CONFIG_SYS_INIT_SP_BSS_OFFSET so the large system
# DTB (camera pipelines + display IP) fits u-boot's init-stack/BSS headroom check.
#
# vck190-vadj-1v2-bootcmd.cfg: set the FMC VADJ rail to 1.2 V from u-boot
# before every boot (the RPi Camera FMC MIPI lanes need the 1.2 V MIPI_DPHY
# I/O standard; with VADJ off the camera I2C buses are dead at probe).
#
# := captures the bbappend dir at parse time (${THISDIR} is unreliable at task
# time inside a bbappend).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://large-dtb-sp-bss.cfg file://vck190-vadj-1v2-bootcmd.cfg"
