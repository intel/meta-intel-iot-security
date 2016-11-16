# This recipe creates a module for the initramfs-framework in OE-core
# which initializes Smack by loading a policy before transferring
# control to the init process in the rootfs. This is done in initramfs
# because in order to use Smack labels in IMA policy, the Smack policy
# needs be loaded before IMA policy. Since IMA policy loading happens
# typically in initramfs, Smack policy should be loaded there too. The
# actual labeling of files etc. can happen later.
#
# Note that this package doesn't actually write the Smack policy
# anywhere. Typically systemd does that automatically. In systems which
# don't use systemd, you need to add writing the Smack policy into the
# init system you use.

SUMMARY = "Smack module for the modular initramfs system"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"
RDEPENDS_${PN} += "initramfs-framework-base"

# This policy file will get installed as
# /etc/smack/accesses.d/default-access-domains.
# It is located via the normal file search path, so a .bbappend
# to this recipe can just point towards one of its own files.
#
# The default Smack rules are copied from a running Tizen IVI 3.0.  They
# correspond to manifest file from default-access-domains in Tizen:
# https://review.tizen.org/git?p=platform/core/security/default-ac-domains.git;a=blob;f=packaging/default-ac-domains.manifest

SMACK_POLICY ?= "default-access-domains"

SRC_URI = " \
    file://${SMACK_POLICY} \
    file://smack \
"

do_install () {
    install -d ${D}/${sysconfdir}/smack/accesses.d
    install -m 0644 ${WORKDIR}/${SMACK_POLICY} ${D}/${sysconfdir}/smack/accesses.d/
    install -d ${D}/init.d
    install ${WORKDIR}/smack  ${D}/init.d/19-smack
}

FILES_${PN} = "${sysconfdir} init.d/19-smack"
