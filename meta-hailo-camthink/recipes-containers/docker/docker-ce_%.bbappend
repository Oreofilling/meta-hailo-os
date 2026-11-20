FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:hailo15-ne503 = " \
    file://daemon.json \
    file://10-persistent-storage.conf \
"

do_install:append:hailo15-ne503() {
    install -d ${D}${sysconfdir}/docker \
        ${D}${sysconfdir}/systemd/system/docker.service.d
    install -m 0644 ${WORKDIR}/daemon.json \
        ${D}${sysconfdir}/docker/daemon.json
    install -m 0644 ${WORKDIR}/10-persistent-storage.conf \
        ${D}${sysconfdir}/systemd/system/docker.service.d/
}

FILES:${PN}:append:hailo15-ne503 = " \
    ${sysconfdir}/docker/daemon.json \
    ${sysconfdir}/systemd/system/docker.service.d/10-persistent-storage.conf \
"

CONFFILES:${PN}:append:hailo15-ne503 = " ${sysconfdir}/docker/daemon.json"
RDEPENDS:${PN} += "camthink-data-layout"
