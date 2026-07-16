FILESEXTRAPATHS:prepend:hailo15-ne503 := "${THISDIR}/files:"

UBOOT_BOARD_DTS:hailo15-ne503 = "${MACHINE}.dts"

SRC_URI:append:hailo15-ne503 = " \
    file://0001-hailo15-ne503-board-support.patch \
    file://0002-hailo15-ne503-fixup-linux-memory-reg.patch \
    file://0003-hailo15-ne503-spiflash-gd25lq64c-support.patch \
"

# Inject DDR_DTSI from DDR_PROFILE into hailo15-ne503.dts.
python do_patch:append:hailo15-ne503() {
    import os
    import re

    dts = d.getVar('UBOOT_BOARD_DTS')
    dtsi = d.getVar('DDR_DTSI')
    if not dts or not dtsi:
        return

    srcdir = d.getVar('S')
    dtsidir = os.path.join(srcdir, 'arch', 'arm', 'dts')
    path = os.path.join(dtsidir, dts)
    if not os.path.isfile(path):
        bb.fatal('UBOOT_BOARD_DTS not found: %s' % path)

    bb.note('DDR profile %s: %s -> %s' % (d.getVar('DDR_PROFILE'), dtsi, dts))

    with open(path, 'r', encoding='utf-8') as f:
        content = f.read()

    content = re.sub(
        r'#include "hailo1x_ddr_[^"]*\.dtsi"',
        '#include "%s"' % dtsi,
        content,
    )

    with open(path, 'w', encoding='utf-8') as f:
        f.write(content)
}
