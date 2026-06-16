# Normal rootfs keeps CamThink base-files fstab-append (PARTLABEL=data -> /data).
# Rescue image must not auto-mount data before SWUpdate postinstall resize/e2fsck.

ROOTFS_POSTPROCESS_COMMAND:append = "camthink_swupdate_skip_data_fstab;"

camthink_swupdate_skip_data_fstab() {
    if [ -f "${IMAGE_ROOTFS}${sysconfdir}/fstab" ]; then
        sed -i '/PARTLABEL=data/d' "${IMAGE_ROOTFS}${sysconfdir}/fstab"
    fi
}
