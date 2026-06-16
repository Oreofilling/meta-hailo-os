SUMMARY = "Factory EEPROM tool (CTFB v1 A/B)"
LICENSE = "MIT"
LIC_FILES_CHKSUM = "file://${COMMON_LICENSE_DIR}/MIT;md5=0835ade698e0bcf8506ecda2f7b4f302"

SRC_URI = "file://factory-eeprom.sh"

S = "${WORKDIR}"

do_install() {
    # Factory default location requested by manufacturing
    install -d ${D}${sysconfdir}
    install -m 0755 ${WORKDIR}/factory-eeprom.sh ${D}${sysconfdir}/factory-eeprom.sh
}

FILES:${PN} += " \
    ${sysconfdir}/factory-eeprom.sh \
"

