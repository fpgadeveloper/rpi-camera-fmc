# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT
#
# large-dtb-sp-bss.cfg: raise CONFIG_SYS_INIT_SP_BSS_OFFSET so the large system
# DTB (camera pipelines + display IP) fits u-boot's init-stack/BSS headroom check.
#
# := captures the bbappend dir at parse time (${THISDIR} is unreliable at task
# time inside a bbappend).
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://large-dtb-sp-bss.cfg"
