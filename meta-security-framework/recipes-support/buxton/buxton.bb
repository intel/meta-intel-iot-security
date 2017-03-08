DESCRIPTION = "Buxton configuration management system"
HOMEPAGE = "https://github.com/sofar/buxton"
LICENSE = "LGPLv2.1 & MIT"

LIC_FILES_CHKSUM = "file://LICENSE.LGPL2.1;md5=4fbd65380cdd255951079008b364516c \
                    file://docs/LICENSE.MIT;md5=fbfb92e82dfd754722af5951af9f9e7c"

SRC_URI = "git://git@github.com/sofar/buxton.git;protocol=ssh"

PV = "6+git${SRCPV}"
SRCREV = "79bfdc55d6ef5703470ade9fbfb37dc8ede68d3d"

S = "${WORKDIR}/git"

DEPENDS = "gdbm systemd attr"

inherit pkgconfig autotools systemd useradd

#Files required for Buxton service
FILES_${PN} += "${systemd_unitdir}"

#Buxton daemon is run on buxton user.
USERADD_PACKAGES = "${PN}"
USERADD_PARAM_${PN} = "-r buxton"

#Buxton databases are owned by buxton user.
#Buxton daemon is a system service so the SMACK label of the databases has to be System.
do_install_append() {
  chmod 700 ${D}${localstatedir}/lib/buxton
  chown buxton -R ${D}${localstatedir}/lib/buxton
}

#Buxton supports SMACK labels but is not strictly dependant on SMACK.
RDEPENDS_${PN}_append_smack = " smack-userspace"
DEPENDS_append_smack = " smack-userspace-native"
CHSMACK_smack = "chsmack"
CHSMACK = "true"

pkg_postinst_${PN}() {
  ${CHSMACK} -a System $D${localstatedir}/lib/buxton
}
