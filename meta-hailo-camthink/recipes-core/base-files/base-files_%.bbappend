FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://fstab-append"

do_install:append() {
    install -d ${D}/data

    # Ensure the data partition is mounted on boot.
    cat ${WORKDIR}/fstab-append >> ${D}${sysconfdir}/fstab
}

