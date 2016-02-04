COREDIR = "${COREBASE}/meta/recipes-devtools/e2fsprogs"

# This recipe is a copy of a e2fsprogs 1.42.99+1.43 from OE-core master and
# only meant to be used when the current OE-core does not have that version yet.
python () {
    import os
    upstream = os.path.join(d.getVar('COREDIR', True), 'e2fsprogs_1.42.9.bb')
    if not os.path.exists(upstream):
        raise bb.parse.SkipRecipe("This recipe replaces e2fsprogs 1.42.9 in OE-core. e2fsprogs from OE-core is something else and thus either recent enough to have xattr support or (less likely) something unexpected.")
}


require e2fsprogs.inc

SRC_URI += "file://acinclude.m4 \
            file://remove.ldconfig.call.patch \
            file://quiet-debugfs.patch \
            file://run-ptest \
            file://ptest.patch \
            file://mkdir.patch \
"

SRCREV = "0f26747167cc9d82df849b0aad387bf824f04544"
PV = "1.42.99+1.43+git${SRCPV}"
UPSTREAM_CHECK_GITTAGREGEX = "v(?P<pver>\d+\.\d+(\.\d+)*)$"

EXTRA_OECONF += "--libdir=${base_libdir} --sbindir=${base_sbindir} \
                --enable-elf-shlibs --disable-libuuid --disable-uuidd \
                --disable-libblkid --enable-verbose-makecmds"

EXTRA_OECONF_darwin = "--libdir=${base_libdir} --sbindir=${base_sbindir} --enable-bsd-shlibs"

PACKAGECONFIG ??= ""
PACKAGECONFIG[fuse] = '--enable-fuse2fs,--disable-fuse2fs,fuse'

do_configure_prepend () {
	cp ${WORKDIR}/acinclude.m4 ${S}/
}

do_install () {
	oe_runmake 'DESTDIR=${D}' install
	oe_runmake 'DESTDIR=${D}' install-libs
	# We use blkid from util-linux now so remove from here
	rm -f ${D}${base_libdir}/libblkid*
	rm -rf ${D}${includedir}/blkid
	rm -f ${D}${base_libdir}/pkgconfig/blkid.pc
	rm -f ${D}${base_sbindir}/blkid
	rm -f ${D}${base_sbindir}/fsck
	rm -f ${D}${base_sbindir}/findfs

	# e2initrd_helper and the pkgconfig files belong in libdir
	if [ ! ${D}${libdir} -ef ${D}${base_libdir} ]; then
		install -d ${D}${libdir}
		mv ${D}${base_libdir}/e2initrd_helper ${D}${libdir}
		mv ${D}${base_libdir}/pkgconfig ${D}${libdir}
	fi

	oe_multilib_header ext2fs/ext2_types.h
	install -d ${D}${base_bindir}
	mv ${D}${bindir}/chattr ${D}${base_bindir}/chattr.e2fsprogs

	install -v -m 755 ${S}/contrib/populate-extfs.sh ${D}${base_sbindir}/
}

do_install_append_class-target() {
	# Clean host path in compile_et, mk_cmds
	sed -i -e "s,ET_DIR=\"${S}/lib/et\",ET_DIR=\"${datadir}/et\",g" ${D}${bindir}/compile_et
	sed -i -e "s,SS_DIR=\"${S}/lib/ss\",SS_DIR=\"${datadir}/ss\",g" ${D}${bindir}/mk_cmds
}

RDEPENDS_e2fsprogs = "e2fsprogs-badblocks"
RRECOMMENDS_e2fsprogs = "e2fsprogs-mke2fs e2fsprogs-e2fsck"

PACKAGES =+ "e2fsprogs-e2fsck e2fsprogs-mke2fs e2fsprogs-tune2fs e2fsprogs-badblocks e2fsprogs-resize2fs"
PACKAGES =+ "libcomerr libss libe2p libext2fs"

FILES_e2fsprogs-resize2fs = "${base_sbindir}/resize2fs*"
FILES_e2fsprogs-e2fsck = "${base_sbindir}/e2fsck ${base_sbindir}/fsck.ext*"
FILES_e2fsprogs-mke2fs = "${base_sbindir}/mke2fs ${base_sbindir}/mkfs.ext* ${sysconfdir}/mke2fs.conf"
FILES_e2fsprogs-tune2fs = "${base_sbindir}/tune2fs ${base_sbindir}/e2label"
FILES_e2fsprogs-badblocks = "${base_sbindir}/badblocks"
FILES_libcomerr = "${base_libdir}/libcom_err.so.*"
FILES_libss = "${base_libdir}/libss.so.*"
FILES_libe2p = "${base_libdir}/libe2p.so.*"
FILES_libext2fs = "${libdir}/e2initrd_helper ${base_libdir}/libext2fs.so.*"
FILES_${PN}-dev += "${datadir}/*/*.awk ${datadir}/*/*.sed ${base_libdir}/*.so"

ALTERNATIVE_${PN} = "chattr"
ALTERNATIVE_PRIORITY = "100"
ALTERNATIVE_LINK_NAME[chattr] = "${base_bindir}/chattr"
ALTERNATIVE_TARGET[chattr] = "${base_bindir}/chattr.e2fsprogs"

ALTERNATIVE_${PN}-doc = "fsck.8"
ALTERNATIVE_LINK_NAME[fsck.8] = "${mandir}/man8/fsck.8"

RDEPENDS_${PN}-ptest += "${PN} ${PN}-tune2fs coreutils procps bash"

do_compile_ptest() {
	oe_runmake -C ${B}/tests
}

do_install_ptest() {
	cp -a ${B}/tests ${D}${PTEST_PATH}/test
	cp -a ${S}/tests/* ${D}${PTEST_PATH}/test
	sed -e 's!../e2fsck/e2fsck!e2fsck!g' -i ${D}${PTEST_PATH}/test/*/expect*
}
