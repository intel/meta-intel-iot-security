# The Smack labels need to be loaded either from initramfs or
# automatically by systemd from rootfs. Select a configuration package
# that provides the labels and makes sure that they are loaded. The
# benefit from loading the files from initramfs is interoperability with
# IMA -- if you want to reference Smack labels from IMA policy files,
# the Smack labels need to be loaded before IMA policy files.
#
# So, you'll either need to select package initramfs-framework-smack and
# put that to your initramfs image, or install the label file to
# directory /etc/smack/accesses.d and let systemd load that
# automatically for you. You can control this by using
# SMACK_INSTALL_TO_INITRAMFS variable.

do_install_append_smack () {

    if [ -z "${SMACK_INSTALL_TO_INITRAMFS}" ] ; then
        # Smack is not installed to initramfs, so let systemd load the
        # labels from rootfs.
        install -d ${D}/${sysconfdir}/smack/accesses.d
        cat >${D}/${sysconfdir}/smack/accesses.d/default-access-domains <<EOF
System _ -----l
System System::Log rwxa--
System System::Run rwxat-
System System::Shared rwxat-
System ^ rwxa--
_ System::Run rwxat-
_ System -wx---
^ System::Log rwxa--
^ System::Run rwxat-
^ System rwxa--
EOF
        chmod 0644 ${D}/${sysconfdir}/smack/accesses.d/default-access-domains
    fi

    install -d ${D}/${libdir}/tmpfiles.d
    cat >${D}/${libdir}/tmpfiles.d/packet-forwarding.conf <<EOF
t /proc/sys/net/ipv4/conf/all/forwarding - - - - security.SMACK64=*
t /proc/sys/net/ipv6/conf/all/forwarding - - - - security.SMACK64=*
t /proc/sys/net/ipv4/conf/default/forwarding - - - - security.SMACK64=*
t /proc/sys/net/ipv6/conf/default/forwarding - - - - security.SMACK64=*
EOF
    chmod 0644 ${D}/${libdir}/tmpfiles.d/packet-forwarding.conf

    install -d ${D}/${base_libdir}/udev/rules.d
    cat >${D}/${base_libdir}/udev/rules.d/85-netdev-ipconf-smacklabel.rules <<EOF
SUBSYSTEM=="net", ENV{ID_NET_NAME}=="", RUN+="/bin/sh -c '/usr/bin/chsmack -a \* /proc/sys/net/ipv4/conf/%k/*'", RUN+="/bin/sh -c '/usr/bin/chsmack -a \* /proc/sys/net/ipv6/conf/%k/*'"

SUBSYSTEM=="net", ENV{ID_NET_NAME}!="", RUN+="/bin/sh -c '/usr/bin/chsmack -a \* /proc/sys/net/ipv4/conf/\$env{ID_NET_NAME}/*'", RUN+="/bin/sh -c '/usr/bin/chsmack -a \* /proc/sys/net/ipv6/conf/\$env{ID_NET_NAME}/*'"
EOF
    chmod 0644 ${D}/${base_libdir}/udev/rules.d/85-netdev-ipconf-smacklabel.rules
}

# Do not rely on an rpm with manifest support. Apparently that approach
# will no longer be used in Tizen 3.0. Instead set special Smack attributes
# via postinst. This is much easier to use with bitbake, too:
# - no need to maintain a patched rpm
# - works for directories which are not packaged by default when empty
RDEPENDS_${PN}_append_smack = " smack-userspace"
DEPENDS_append_smack = " smack-userspace-native"
pkg_postinst_${PN}_smack() {
    #!/bin/sh -e

    # https://review.tizen.org/gerrit/gitweb?p=platform/upstream/filesystem.git;a=blob;f=packaging/filesystem.manifest:
    # <filesystem path="/etc" label="System::Shared" type="transmutable" />
    install -d $D${sysconfdir}
    # This has no effect on files installed into /etc during image construction
    # because pseudo does not know the special semantic of SMACK::TRANSMUTE.
    # To avoid having different xattrs on files inside /etc when pre-installed
    # in an image vs. installed on a device, the xattr-images.bbclass has
    # a workaround for this deficiency in pseudo.
    chsmack -t $D${sysconfdir}
    chsmack -a 'System::Shared' $D${sysconfdir}

    # Same for /var. Any daemon running as "System" will get write access
    # to everything.
    install -d $D${localstatedir}
    chsmack -t $D${localstatedir}
    chsmack -a 'System::Shared' $D${localstatedir}

    # <filesystem path="/tmp" label="*" />
    mkdir -p $D/tmp
    chsmack -a '*' $D/tmp

    # <filesystem path="/var/log" label="System::Log" type="transmutable" />
    # <filesystem path="/var/tmp" label="*" />
    # These are in a file system mounted by systemd. We patch the systemd service
    # to set these attributes.
}
