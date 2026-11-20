FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append:hailo15-ne503 = " file://90-camthink-system.conf"

do_install:append:hailo15-ne503() {
    # The lower BSP layer points process dumps at the replaceable rootfs.
    # Remove that setting before 99-sysctl.conf links to this file.
    sed -i '/^[[:space:]]*kernel\.core_pattern[[:space:]]*=/d' \
        ${D}${sysconfdir}/sysctl.conf

    install -d ${D}${sysconfdir}/sysctl.d
    install -m 0644 ${WORKDIR}/90-camthink-system.conf \
        ${D}${sysconfdir}/sysctl.d/
}

FILES:${PN}:append:hailo15-ne503 = " ${sysconfdir}/sysctl.d/90-camthink-system.conf"
