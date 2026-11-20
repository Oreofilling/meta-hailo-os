SUMMARY = "Persistent data-partition directory layout"
DESCRIPTION = "Creates OS-owned directories on the persistent data partition before dependent mounts and services start."
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COREBASE}/meta/COPYING.MIT;md5=3da9cfbcb788c80a0384361b4de20420"

SRC_URI = " \
    file://camthink-data-layout \
    file://camthink-data-layout.service \
    file://camthink-core-prune \
    file://camthink-core-prune.service \
    file://camthink-core-prune.timer \
"

S = "${WORKDIR}"

inherit systemd

do_install() {
    install -d ${D}${libexecdir} ${D}${systemd_system_unitdir}

    install -m 0755 ${WORKDIR}/camthink-data-layout \
        ${D}${libexecdir}/camthink-data-layout
    install -m 0755 ${WORKDIR}/camthink-core-prune \
        ${D}${libexecdir}/camthink-core-prune

    install -m 0644 ${WORKDIR}/camthink-data-layout.service \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-core-prune.service \
        ${D}${systemd_system_unitdir}/
    install -m 0644 ${WORKDIR}/camthink-core-prune.timer \
        ${D}${systemd_system_unitdir}/
}

# camthink-data-layout.service is static and is pulled in by the /var/log bind
# mount and by services that store state on /data.
SYSTEMD_SERVICE:${PN} = "camthink-core-prune.timer"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

RDEPENDS:${PN} += "coreutils findutils util-linux-mountpoint"

FILES:${PN} += " \
    ${libexecdir}/camthink-data-layout \
    ${libexecdir}/camthink-core-prune \
    ${systemd_system_unitdir}/camthink-data-layout.service \
    ${systemd_system_unitdir}/camthink-core-prune.service \
    ${systemd_system_unitdir}/camthink-core-prune.timer \
"
