FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

SRC_URI:append = " file://fstab-append"

# Keep /var/tmp on the writable root filesystem instead of linking it into
# /var/volatile. This also updates base-files' packaging permission metadata.
volatiles:remove = "tmp"
dirs1777:append = " ${localstatedir}/tmp"

do_install:append() {
    install -d ${D}/data

    # Ensure the data partition is mounted on boot.
    cat ${WORKDIR}/fstab-append >> ${D}${sysconfdir}/fstab

}
