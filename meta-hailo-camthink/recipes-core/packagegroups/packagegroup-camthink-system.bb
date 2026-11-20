SUMMARY = "CamThink product OS package group"
DESCRIPTION = "System packages required for hardware enablement, diagnostics, networking and container execution."

PACKAGE_ARCH = "${MACHINE_ARCH}"
BUILDHISTORY_FEATURES:remove = "image package"

inherit packagegroup

PACKAGEGROUP_DISABLE_COMPLEMENTARY = "1"

RDEPENDS:${PN} = " \
    containerd-opencontainers \
    runc-opencontainers \
    cni \
    docker \
    python3-docker-compose \
    factory-eeprom-tool \
    u-boot-fw-utils \
    quectel-cm \
    quectel-qlog \
    camthink-rootfs \
    camthink-data-layout \
    camthink-system-baseline \
    logrotate \
    procps \
    libavcodec \
    libavutil \
    libswresample \
    run-swupdate-script \
    swupdate \
    tzdata \
"
