# Copyright (C) 2025-2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT

# Extra kernel command-line arguments for the Versal EDF SD boot.
#
# On Versal the EDF image boots U-Boot -> systemd-boot (EFI) -> Image, and the
# kernel command line is ONLY the `options` line of the systemd-boot loader
# entry shipped by meta-amd-edf (systemd-bootconf-edf, versal/edf-linux.conf):
#     options console=ttyAMA0 earlycon=pl011,mmio32,0xFF000000,115200n8 root=PARTUUID=@@ROOTFS_UUID@@ ro rootwait uio_pdrv_genirq.of_id=generic-uio
# The entry is deployed as loader/edf-linux.conf and copied to the ESP as
# loader/entries/edf-linux.conf by the wic bootimg-efi-amd plugin (which fills
# in @@ROOTFS_UUID@@). The EFI stub replaces the device tree's /chosen/bootargs
# with these options, and APPEND in local.conf is never read by this flow.
#
# BSP_EXTRA_BOOTARGS is set per board in conf/local.conf.append; it is appended
# to the entry's `options` line right after unpack (before do_install and
# do_deploy both read it). The variable is part of do_unpack's signature, so
# changing it redeploys the entry.
BSP_EXTRA_BOOTARGS ??= ""

do_unpack[postfuncs] += "bsp_add_bootargs"
bsp_add_bootargs[dirs] = "${WORKDIR}"
bsp_add_bootargs() {
    [ -n "${BSP_EXTRA_BOOTARGS}" ] || return 0
    f=${WORKDIR}/edf-linux.conf
    [ -f "$f" ] || return 0
    sed -i -e '/^options /s|$| ${BSP_EXTRA_BOOTARGS}|' "$f"
    grep -qF -- " ${BSP_EXTRA_BOOTARGS}" "$f" || \
        bbfatal "BSP_EXTRA_BOOTARGS: no 'options' line patched in $f"
}
