FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:hailo15-ne503 = " \
    file://config.toml \
    file://10-persistent-storage.conf \
"

do_install:append:hailo15-ne503() {
    install -d ${D}${sysconfdir}/containerd \
        ${D}${sysconfdir}/systemd/system/containerd.service.d
    install -m 0644 ${WORKDIR}/config.toml \
        ${D}${sysconfdir}/containerd/config.toml
    install -m 0644 ${WORKDIR}/10-persistent-storage.conf \
        ${D}${sysconfdir}/systemd/system/containerd.service.d/
}

FILES:${PN}:append:hailo15-ne503 = " \
    ${sysconfdir}/containerd/config.toml \
    ${sysconfdir}/systemd/system/containerd.service.d/10-persistent-storage.conf \
"

CONFFILES:${PN}:append:hailo15-ne503 = " ${sysconfdir}/containerd/config.toml"
RDEPENDS:${BPN} += "camthink-data-layout"
