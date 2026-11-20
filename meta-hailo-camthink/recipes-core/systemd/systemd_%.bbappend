# Product systemd policy. The lower BSP layer forces a volatile journal and
# error-only manager logging; this layer owns the final product defaults.
FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://zz-camthink-journal.conf \
                   file://zz-camthink-manager.conf \
                   file://serial-log-level.service \
"

do_install:append() {
    install -d ${D}${sysconfdir}/systemd/journald.conf.d \
        ${D}${sysconfdir}/systemd/system.conf.d
    install -m 0644 ${WORKDIR}/zz-camthink-journal.conf \
        ${D}${sysconfdir}/systemd/journald.conf.d/
    install -m 0644 ${WORKDIR}/zz-camthink-manager.conf \
        ${D}${sysconfdir}/systemd/system.conf.d/

    # Remove lower-layer policy files whose settings contradict the product
    # defaults above.
    rm -f ${D}${sysconfdir}/systemd/journald.conf.d/journald-err-level.conf

    # Keep the BSP unit name and enablement, but make it responsible only for
    # the kernel console threshold. Manager policy belongs in system.conf.d.
    install -m 0644 ${WORKDIR}/serial-log-level.service \
        ${D}${systemd_system_unitdir}/serial-log-level.service
}

FILES:${PN}:append = " \
    ${sysconfdir}/systemd/journald.conf.d/zz-camthink-journal.conf \
    ${sysconfdir}/systemd/system.conf.d/zz-camthink-manager.conf \
"
