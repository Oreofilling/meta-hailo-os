# The upstream target postinst runs update-ca-certificates while do_rootfs is
# assembling the image. On this image it can fail before the target OpenSSL
# runtime is usable. Keep the build-time postinst as a no-op and use
# pkg_postinst_ontarget for the first-boot regeneration. This Poky release
# explicitly rejects the old "exit 1 to defer" pattern.

pkg_postinst:${PN}:class-target () {
    :
}

pkg_postinst_ontarget:${PN} () {
    ${sbindir}/update-ca-certificates
}
