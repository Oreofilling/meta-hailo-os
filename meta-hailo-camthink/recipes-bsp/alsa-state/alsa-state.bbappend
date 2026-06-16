FILESEXTRAPATHS:prepend := "${THISDIR}/files:"

# NE503 + CF66: NAU88C10 via nau8810 driver — do not use hailo15_sbc (AIC3104) mixer state.
ASOUND_STATE_FILES:append:hailo15-ne503 = " hailo15_ne503_nau8810_asound.state"

# BSP appends hailo15_i2s_master_asound.conf (rate 48000). NE503 product default is 44.1 kHz.
do_install:append:hailo15-ne503() {
	if [ -f "${D}${sysconfdir}/asound.conf" ]; then
		sed -i '/pcm_slave\.hailo15_i2s_master/,/^}/s/rate 48000/rate 44100/' "${D}${sysconfdir}/asound.conf"
	fi
}
