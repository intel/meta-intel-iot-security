FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# Applying this patch is optional. Only some versions
# of e2fsprogs need it. So try to apply it, but if it fails,
# continue and hope the patch wasn't needed. If it is needed
# and got skipped, the oeqa Smack tests will catch the failure.
SRC_URI += "file://ext_attr.c-fix-adding-multiple-xattrs-during-image-c.patch;apply=no"

do_patch[postfuncs] += "patch_xattr_support"
patch_xattr_support () {
    cd ${S}
    cp ext2fs/ext_attr.c ext2fs/ext_attr.c.orig
    patch ext2fs/ext_attr.c <${WORKDIR}/ext_attr.c-fix-adding-multiple-xattrs-during-image-c.patch && rm ext2fs/ext_attr.c.orig || mv ext2fs/ext_attr.c.orig ext2fs/ext_attr.c
}
