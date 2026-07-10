# The upstream target postinst runs update-ca-certificates while do_rootfs is
# assembling the image. On this image it can fail before the target OpenSSL
# runtime is usable. Merely adding pkg_postinst_ontarget does not replace the
# upstream postinst, so explicitly disable the build-time hook and regenerate
# the certificate store on first boot.

pkg_postinst:${PN}:class-target () {
    :
}

pkg_postinst_ontarget:${PN} () {
    ${sbindir}/update-ca-certificates
}
