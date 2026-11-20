FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:hailo15-ne503 = " file://busybox-syslog.default"

do_install:append:hailo15-ne503() {
    install -d ${D}${sysconfdir}/default
    install -m 0644 ${WORKDIR}/busybox-syslog.default \
        ${D}${sysconfdir}/default/busybox-syslog
}
