SUMMARY = "NE503 system boot baseline"
DESCRIPTION = "Installs device access, module loading, clock recovery, time synchronization selection and persistent network configuration support."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
    file://ne503-modules.conf \
    file://80-ne503-device-access.rules \
    file://10-systemd-timesyncd.list \
    file://camthink-clock-state \
    file://camthink-clock-restore.service \
    file://camthink-clock-save.service \
    file://camthink-clock-save.timer \
    file://camthink-network-config \
    file://camthink-network-config.service \
    file://10-persistent-network.conf \
    file://camthink-system-ready.target \
"

S = "${WORKDIR}"

inherit systemd

do_install() {
    install -d \
        ${D}${sysconfdir}/modules-load.d \
        ${D}${sysconfdir}/udev/rules.d \
        ${D}${sysconfdir}/systemd/ntp-units.d \
        ${D}${sysconfdir}/systemd/system/systemd-networkd.service.d \
        ${D}${libexecdir} \
        ${D}${systemd_system_unitdir}

    install -m 0644 ${WORKDIR}/ne503-modules.conf \
        ${D}${sysconfdir}/modules-load.d/ne503.conf
    install -m 0644 ${WORKDIR}/80-ne503-device-access.rules \
        ${D}${sysconfdir}/udev/rules.d/
    install -m 0644 ${WORKDIR}/10-systemd-timesyncd.list \
        ${D}${sysconfdir}/systemd/ntp-units.d/

    install -m 0755 ${WORKDIR}/camthink-clock-state \
        ${D}${libexecdir}/camthink-clock-state
    install -m 0755 ${WORKDIR}/camthink-network-config \
        ${D}${libexecdir}/camthink-network-config

    install -m 0644 ${WORKDIR}/camthink-clock-restore.service \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-clock-save.service \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-clock-save.timer \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-network-config.service \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-system-ready.target \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/10-persistent-network.conf \
        ${D}${sysconfdir}/systemd/system/systemd-networkd.service.d/
}

SYSTEMD_SERVICE:${PN} = "camthink-clock-restore.service camthink-clock-save.timer camthink-system-ready.target"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += " \
    coreutils \
    camthink-data-layout \
    containerd-opencontainers \
    docker-ce \
"
RRECOMMENDS:${PN} += "kernel-module-hailo-integrated-nnc"

COMPATIBLE_MACHINE = "hailo15-ne503"

FILES:${PN} += " \
    ${sysconfdir}/modules-load.d/ne503.conf \
    ${sysconfdir}/udev/rules.d/80-ne503-device-access.rules \
    ${sysconfdir}/systemd/ntp-units.d/10-systemd-timesyncd.list \
    ${sysconfdir}/systemd/system/systemd-networkd.service.d/10-persistent-network.conf \
    ${libexecdir}/camthink-clock-state \
    ${libexecdir}/camthink-network-config \
    ${systemd_system_unitdir}/camthink-clock-restore.service \
    ${systemd_system_unitdir}/camthink-clock-save.service \
    ${systemd_system_unitdir}/camthink-clock-save.timer \
    ${systemd_system_unitdir}/camthink-network-config.service \
    ${systemd_system_unitdir}/camthink-system-ready.target \
"
