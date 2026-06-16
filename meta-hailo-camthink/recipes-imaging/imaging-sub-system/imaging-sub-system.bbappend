FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# Add systemd service files when systemd is enabled and source file doesn't exist
SRC_URI += "${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'file://isp_media_server.service', '', d)}"

# Override install_isp_media_server function
# Priority: use ${S}/hailo_cfg/isp_media_server.service if exists, otherwise use WORKDIR
install_isp_media_server() {
	install -m 0755 -D  ${B}/dist/${BUILD_TYPE}/bin/isp_media_server ${D}${bindir}
	# Install systemd files only if systemd is enabled
	if ${@bb.utils.contains('DISTRO_FEATURES', 'systemd', 'true', 'false', d)}; then
		install -d ${D}${systemd_unitdir}/system
		# Check if service file exists in source directory, use it if available
		if [ -f "${S}/hailo_cfg/isp_media_server.service" ]; then
			install -m 0644 ${S}/hailo_cfg/isp_media_server.service ${D}${systemd_unitdir}/system/
		else
			# Fallback to WORKDIR if source file doesn't exist
			install -m 0644 ${WORKDIR}/isp_media_server.service ${D}${systemd_unitdir}/system/
		fi
	else
		install -m 0755 -D  ${S}/hailo_cfg/isp_media_server ${D}/etc/init.d
		ln -s -r ${D}/etc/init.d/isp_media_server ${D}/etc/rc5.d/S20isp_media_server
	fi
}

