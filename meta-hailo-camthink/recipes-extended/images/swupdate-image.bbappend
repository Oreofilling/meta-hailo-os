# Normal rootfs keeps CamThink base-files fstab-append (PARTLABEL=data -> /data).
# Rescue image must not auto-mount data before SWUpdate postinstall resize/e2fsck.

CAMTHINK_SWUPDATE_FILES_DIR := "${THISDIR}/files"

ROOTFS_POSTPROCESS_COMMAND:append = "camthink_swupdate_skip_data_fstab;"
ROOTFS_POSTPROCESS_COMMAND:append:hailo15-ne503 = "camthink_install_local_recovery_init;"

camthink_swupdate_skip_data_fstab() {
    if [ -f "${IMAGE_ROOTFS}${sysconfdir}/fstab" ]; then
        sed -i '/PARTLABEL=data/d' "${IMAGE_ROOTFS}${sysconfdir}/fstab"
    fi
}

camthink_install_local_recovery_init() {
    install -m 0755 "${CAMTHINK_SWUPDATE_FILES_DIR}/aipc-swupdate-init.sh" \
        "${IMAGE_ROOTFS}${base_sbindir}/init.initscripts-hailo-swupdate"
}

# swupdate-image is an image recipe and its do_unpack task is disabled, so the
# local recovery script is consumed directly from the layer. Track the file as
# an explicit do_rootfs input so changes invalidate the task signature.
do_rootfs[file-checksums] += "${CAMTHINK_SWUPDATE_FILES_DIR}/aipc-swupdate-init.sh:True"
