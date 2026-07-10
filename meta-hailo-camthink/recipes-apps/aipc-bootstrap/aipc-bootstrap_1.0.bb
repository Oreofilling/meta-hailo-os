SUMMARY = "AIPC boot bootstrap (generic enabler) + recovery bundle"
DESCRIPTION = "Generic, service-agnostic AIPC boot enabler that promotes AIPC \
units from the shared /data at boot, plus the single-recovery upgrade recovery \
bundle. Owns no AIPC service names, so adding an AIPC service never forces an \
OS image rebuild. Compatibility capability values remain an explicit OS \
interface contract."
LICENSE = "CLOSED"

SRC_URI = " \
    file://aipc-app-bootstrap \
    file://aipc-app-bootstrap.service \
    file://aipc-bootstrap-owner \
    file://aipc-os-release \
"

S = "${WORKDIR}"

inherit systemd

# Only the generic enabler is enabled by the OS image. The real AIPC boot units
# (aipc-restore/firstboot/autostart/os-verify) and their helpers are staged in
# /data/aipc/systemd by the AIPC package and promoted into this slot at boot by
# aipc-app-bootstrap. Keeping the list to one generic unit is what makes the OS
# image independent of the AIPC service set.
SYSTEMD_SERVICE:${PN} = "aipc-app-bootstrap.service"
SYSTEMD_AUTO_ENABLE:${PN} = "enable"

# fw_printenv/fw_setenv are required by the persistent AIPC OS-upgrade runner
# to classify copy-a-only devices and stage recovery boot atomically.
RDEPENDS:${PN} = "bash coreutils gzip tar kmod u-boot-fw-utils"

# Recovery bundle files come from the kernel (fitImage) and swupdate-image
# recipes. These are only available on incremental rebuilds — clean builds
# without prior deploy outputs will skip recovery bundle inclusion silently.
# Task-level dependency is used instead of DEPENDS because swupdate-image is an
# image recipe and adding it to DEPENDS would create a circular dependency.

# Ensure the kernel deploy and swupdate-image rootfs tasks finish before we try
# to copy their output files from DEPLOY_DIR_IMAGE.
do_install[depends] += " \
    virtual/kernel:do_deploy \
    swupdate-image:do_image_complete \
"

RECOVERY_DIR = "/data/aipc/recovery"

do_install() {
    install -d ${D}${libexecdir}
    install -m 0755 ${WORKDIR}/aipc-app-bootstrap ${D}${libexecdir}/aipc-app-bootstrap

    install -d ${D}${sysconfdir}
    # Compatibility capabilities are an OS-owned interface contract. They
    # change only when the OS/App ABI or supported schema changes, not when an
    # application service is added or renamed.
    install -m 0644 ${WORKDIR}/aipc-os-release ${D}${sysconfdir}/aipc-os-release
    install -m 0644 ${WORKDIR}/aipc-bootstrap-owner ${D}${sysconfdir}/aipc-bootstrap-owner

    install -d ${D}${systemd_system_unitdir}
    install -m 0644 ${WORKDIR}/aipc-app-bootstrap.service ${D}${systemd_system_unitdir}/

    # --- Bundled recovery for single-recovery OS upgrades ---
    # The kernel (do_deploy) and swupdate-image (do_image_complete) tasks are
    # declared in do_install[depends] above, so both artifacts MUST exist by
    # this point. Fail the build loudly if they don't: a silently-empty or
    # missing recovery bundle bricks devices on the next single-recovery
    # upgrade (swupdate cannot boot the recovery initramfs). Do NOT silent-skip.
    RECOVERY_FIT="${DEPLOY_DIR_IMAGE}/fitImage"
    RECOVERY_ROOTFS="${DEPLOY_DIR_IMAGE}/swupdate-image-${MACHINE}.ext4.gz"

    if [ ! -f "$RECOVERY_FIT" ]; then
        bbfatal "Recovery fitImage missing at $RECOVERY_FIT; kernel do_deploy did not stage it - cannot build recovery bundle (a missing bundle bricks devices on single-recovery upgrade)"
    fi
    if [ ! -f "$RECOVERY_ROOTFS" ]; then
        bbfatal "Recovery rootfs missing at $RECOVERY_ROOTFS; swupdate-image do_image_complete did not stage it - cannot build recovery bundle (a missing bundle bricks devices on single-recovery upgrade)"
    fi

    install -d ${D}${RECOVERY_DIR}
    install -m 0644 "$RECOVERY_FIT" ${D}${RECOVERY_DIR}/fitImage
    install -m 0644 "$RECOVERY_ROOTFS" \
        ${D}${RECOVERY_DIR}/swupdate-image-${MACHINE}.ext4.gz

    # Source version info from the release stub (OS-owned OS_VERSION).
    . ${WORKDIR}/aipc-os-release

    fit_sha=$(sha256sum ${D}${RECOVERY_DIR}/fitImage | awk '{print $1}')
    fit_size=$(stat -c %s ${D}${RECOVERY_DIR}/fitImage)
    root_sha=$(sha256sum ${D}${RECOVERY_DIR}/swupdate-image-${MACHINE}.ext4.gz | awk '{print $1}')
    root_size=$(stat -c %s ${D}${RECOVERY_DIR}/swupdate-image-${MACHINE}.ext4.gz)

    printf '{\n' > ${D}${RECOVERY_DIR}/manifest.json
    printf '  "format": 1,\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "machine": "%s",\n' "${MACHINE}" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "bsp_version": "%s",\n' "${OS_VERSION}" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "recovery_version": "%s",\n' "${OS_VERSION}" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "local_update_protocol": "AIPC_LOCAL_RECOVERY_V1",\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "secure_boot_key_id": "",\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "fit_image": {\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "file": "fitImage",\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "sha256": "%s",\n' "$fit_sha" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "size": %s\n' "$fit_size" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  },\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  "rootfs": {\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "file": "swupdate-image-%s.ext4.gz",\n' "${MACHINE}" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "sha256": "%s",\n' "$root_sha" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '    "size": %s\n' "$root_size" >> ${D}${RECOVERY_DIR}/manifest.json
    printf '  }\n' >> ${D}${RECOVERY_DIR}/manifest.json
    printf '}\n' >> ${D}${RECOVERY_DIR}/manifest.json
}

FILES:${PN} += " \
    ${libexecdir}/aipc-app-bootstrap \
    ${sysconfdir}/aipc-os-release \
    ${sysconfdir}/aipc-bootstrap-owner \
    ${systemd_system_unitdir}/aipc-app-bootstrap.service \
    ${RECOVERY_DIR} \
"
