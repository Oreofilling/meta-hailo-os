# Hailo15-NE503 (AM20-01): TMP1075 temp on I2C1 @0x48, no INA231
FILESEXTRAPATHS:prepend:hailo15-ne503 := "${THISDIR}/files:"
SENSOR_CONF_FILES:append:hailo15-ne503 = " hailo15-ne503/tmp1075-i2c-1.conf"
