FILESEXTRAPATHS:prepend := "${THISDIR}/${PN}:"

do_install:append() {
	echo "PATH=\$PATH:/usr/bin/xlnx" >> ${D}${sysconfdir}/profile
}
