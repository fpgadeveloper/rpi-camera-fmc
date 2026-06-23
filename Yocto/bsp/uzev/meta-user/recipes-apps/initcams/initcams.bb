#
# This file is the initcams recipe.
#

SUMMARY = "Scripts for RPi Camera FMC"
SECTION = "PETALINUX/apps"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://init_cams.sh \
	   file://displaycams.sh \
		  "

S = "${WORKDIR}"

RDEPENDS:${PN} += "bash"

do_install() {
        install -d ${D}${bindir}
        install -m 0755 ${WORKDIR}/init_cams.sh ${D}${bindir}/
        install -m 0755 ${WORKDIR}/displaycams.sh ${D}${bindir}/
}
