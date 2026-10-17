# Copyright (C) 2026, Opsero Electronic Design Inc.  All rights reserved.
#
# SPDX-License-Identifier: MIT
#
# DVI (HDMI-compatible) output bring-up for the Versal targets of the RPi
# Camera FMC design (VCK190 / VEK280 on-board HDMI TX, free-IP DVI encoder).
#
#  dvi-init    : configures the board's HDMI retimer/redriver over the HDMI
#                control I2C bus (SN65DP159 on VCK190, TMDS1204 on VEK280),
#                waits for the transceiver link and prints the link status.
#                Run once at boot by dvi-init.service. The 148.5 MHz reference
#                clock (8T49N241) is programmed earlier by the kernel's
#                idt8t49n24x clock driver from the device tree.
#  dvi-status  : prints / changes the DVI output status & control register
#                (link, transceiver resets, test pattern, lane polarity).
#  dvi-reg     : tiny /dev/mem register peek/poke used by dvi-status.

SUMMARY = "DVI output init and debug scripts (RPi Camera FMC, Versal)"
SECTION = "apps"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = " \
    file://dvi-init.sh \
    file://dvi-status.sh \
    file://dvi-init.service \
    file://dvi-reg.c \
"

S = "${WORKDIR}"

inherit systemd

SYSTEMD_SERVICE:${PN} = "dvi-init.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "bash i2c-tools"

do_compile() {
    ${CC} ${CFLAGS} ${LDFLAGS} -o dvi-reg ${WORKDIR}/dvi-reg.c
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 ${WORKDIR}/dvi-init.sh ${D}${bindir}/dvi-init
    install -m 0755 ${WORKDIR}/dvi-status.sh ${D}${bindir}/dvi-status
    install -m 0755 ${B}/dvi-reg ${D}${bindir}/dvi-reg
    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/dvi-init.service ${D}${systemd_system_unitdir}/
}

FILES:${PN} += "${systemd_system_unitdir}/dvi-init.service"
