SUMMARY = "Binary used to test smack tcp sockets"
DESCRIPTION = "Server and client binaries used to test smack attributes on TCP sockets"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://tcp_server.c \
           file://tcp_client.c \
" 

inherit copybin
TARGET_FILES += "${WORKDIR}/tcp_client ${WORKDIR}/tcp_server"

S = "${WORKDIR}"
do_compile() {
    ${CC} tcp_client.c -o tcp_client
    ${CC} tcp_server.c -o tcp_server
}

do_install() {
    install -d ${D}${bindir}
    install -m 0755 tcp_server ${D}${bindir}
    install -m 0755 tcp_client ${D}${bindir}
}
