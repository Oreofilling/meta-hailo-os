FILESEXTRAPATHS:prepend := "${THISDIR}:"

FILESEXTRAPATHS:prepend:hailo15-ne503 := "${THISDIR}/files:"
SRC_URI:append:hailo15-ne503 = " \
    file://0001-hailo15-ne503-kernel-support.patch \
    file://0002-hailo15-ne503-kernel-drivers-base.patch \   
"

# cfg
SRC_URI:append:hailo15-ne503 = " \
    file://cfg/containerd.cfg \
    file://cfg/codec.cfg \
"