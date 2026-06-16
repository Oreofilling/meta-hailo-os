# Hailo15-NE503: same as hailo15-sbc (mmcblk1 for rootfs)
SWUPDATE_DEFAULT_FILESYSTEM_DEVICE:hailo15-ne503 = "mmcblk1"

# Override sw-description for hailo15-ne503 (single mode gets a data partition)
FILESEXTRAPATHS:prepend:hailo15-ne503 := "${THISDIR}/files:"
