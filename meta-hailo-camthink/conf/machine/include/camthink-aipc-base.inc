# CamThink AIPC Platform Base Configuration
# This file contains platform-specific configuration for CamThink AIPC

# Enable systemd as init manager (required for containerd service)
INIT_MANAGER = "systemd"

# Enable virtualization support for containerd
DISTRO_FEATURES:append = " virtualization"

