require security-manager.inc

PV = "1.0.2+git${SRCPV}"
SRCREV = "860305a595d681d650024ad07b3b0977e1fcb0a6"
SRC_URI += "git://github.com/Samsung/security-manager.git"
S = "${WORKDIR}/git"

SRC_URI += " \
file://systemd-stop-using-compat-libs.patch \
file://security-manager-policy-reload-do-not-depend-on-GNU-.patch \
"

##########################################
# This are patches for backward compatibility to the version dizzy of poky.
# The dizzy version of libcap isn't providing a packconfig file.
# This is solved by the patch libcap-without-pkgconfig.patch.
# But after solving that issue, it appears that linux/xattr.h should
# also be include add definitions of XATTR_NAME_SMACK... values.
# Unfortunately, there is no explanation why linux/xattr.h should
# also be included (patch include-linux-xattr.patch)
##########################################
do_patch[depends] = "libcap:do_populate_sysroot"
APPLY = "${@str('no' if os.path.exists('${STAGING_LIBDIR}/pkgconfig/libcap.pc') else 'yes')}"
SRC_URI += "\
  file://libcap-without-pkgconfig.patch;apply=${APPLY} \
  file://include-linux-xattr.patch;apply=${APPLY} \
"

