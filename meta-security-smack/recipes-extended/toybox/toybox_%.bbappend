FILESEXTRAPATHS_prepend := "${THISDIR}/files:"
#add support to cflags as need it.
SRC_URI += "file://toybox_build-add-Missing-CFLAGS.patch"

#include CFLAGS to location of libraries.
CFLAGS_prepend = "-I ${STAGING_DIR_HOST}${includedir_native}"

do_configure() {
	oe_runmake defconfig
	# Disable killall5 as it isn't managed by update-alternatives
	sed -e 's/CONFIG_KILLALL5=y/# CONFIG_KILLALL5 is not set/' -i .config
	#Enable smack in toybox
	sed -e 's/# CONFIG_TOYBOX_SMACK is not set/CONFIG_TOYBOX_SMACK=y/' -i .config
}
