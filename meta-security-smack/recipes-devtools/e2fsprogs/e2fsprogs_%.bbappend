FILESEXTRAPATHS_prepend := "${THISDIR}/files:"

# Applying this patch is optional. Only some versions
# of e2fsprogs need it. So try to apply it, but if it fails,
# continue and hope the patch wasn't needed. If it is needed
# and got skipped, the oeqa Smack tests will catch the failure.
SRC_URI += "file://create_inode.c-work-around-xattr-handling.patch;apply=no"

do_patch[postfuncs] += "patch_xattr_support"
patch_xattr_support () {
    cd ${S}
    cp misc/create_inode.c misc/create_inode.c.orig
    patch misc/create_inode.c <${WORKDIR}/create_inode.c-work-around-xattr-handling.patch && rm misc/create_inode.c.orig || mv misc/create_inode.c.orig misc/create_inode.c
}
