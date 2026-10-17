# Copyright (C) 2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# DVI output nodes (panel-dpi fixed mode, 8T49N241 reference clock, mixer/VTC
# enable, status register marker), Linux (APU) domain only - same scoping as
# the target's own system-user.dtsi.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

EXTRA_DT_INCLUDE_FILES:append = "${@' dvi-out.dtsi' if 'linux' in os.path.basename(d.getVar('CONFIG_DTFILE') or '') else ''}"
