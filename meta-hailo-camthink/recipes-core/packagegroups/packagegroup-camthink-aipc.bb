SUMMARY = "Compatibility package group for the dynamic application payload"
DESCRIPTION = "Retains the previous package-group name while depending on the product OS baseline and application bootstrap."

PACKAGE_ARCH = "${MACHINE_ARCH}"
BUILDHISTORY_FEATURES:remove = "image package"

inherit packagegroup

PACKAGEGROUP_DISABLE_COMPLEMENTARY = "1"
PACKAGES = "${PN} ${PN}-system ${PN}-app"

# Compatibility system set. New images include packagegroup-camthink-system
# directly so OS dependencies do not depend on an application package name.
RDEPENDS:${PN}-system = " \
    packagegroup-camthink-system \
    aipc-bootstrap \
"

# Optional dynamic application payload. It remains empty because the payload
# is installed independently of the replaceable root filesystem.
RDEPENDS:${PN}-app = ""

# Preserve the dependency shape expected by older image configurations.
RDEPENDS:${PN} = " \
    ${PN}-system \
    ${PN}-app \
"
