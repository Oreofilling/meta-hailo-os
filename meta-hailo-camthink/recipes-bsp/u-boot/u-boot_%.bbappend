FILESEXTRAPATHS:prepend:hailo15-ne503 := "${THISDIR}/files:"

SRC_URI:append:hailo15-ne503 = " \
    file://0001-hailo15-ne503-board-support.patch \
    file://0003-hailo15-ne503-spiflash-gd25lq64c-support.patch \
"