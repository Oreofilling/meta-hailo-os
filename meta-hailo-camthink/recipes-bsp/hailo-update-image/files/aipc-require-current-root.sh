#!/bin/sh
# Gate OS rewrite against the persistent AIPC release.
#
# - Bare board / first flash: no AIPC artifacts under /data/aipc -> allow.
# - Device with an application package (any contract marker present): require
#   the full current-root contract so the new rootfs can be reconstructed.
# This check lives inside the SWU so even an older application-side updater
# cannot bypass the migration prerequisite on deployed devices.

set -eu

root="${AIPC_PERSISTENT_ROOT:-/data/aipc}"
installer="$root/scripts/aipc-install-current-root.sh"
manifest="$root/app-manifest.json"
units="$root/systemd"
compat_check="$root/libexec/aipc-compat-check"

fail() {
    echo "[aipc-os-preinstall] ERROR: $*" >&2
    echo "[aipc-os-preinstall] Deploy a current AIPC application package before upgrading the OS." >&2
    exit 1
}

cfg_value() {
    key="$1"
    [ -f /tmp/swupdate.cfg ] || return 1
    awk -F= -v key="$key" '
        $1 == key {
            print substr($0, index($0, "=") + 1)
            found = 1
            exit
        }
        END { exit !found }
    ' /tmp/swupdate.cfg
}

data_is_mounted() {
    awk '$2 == "/data" { found=1 } END { exit !found }' /proc/mounts
}

mount_persistent_data() {
    case "$root" in
        /data|/data/*) ;;
        *) return 0 ;;
    esac

    data_is_mounted && return 0

    filesystem_device="$(cfg_value FILESYSTEM_DEVICE || true)"
    filesystem_device="${filesystem_device:-${SWUPDATE_FILESYSTEM_DEVICE:-mmcblk1}}"

    data_partition=""
    for candidate in "/dev/${filesystem_device}p5" "/dev/${filesystem_device}p3"; do
        if [ -b "$candidate" ]; then
            data_partition="$candidate"
            break
        fi
    done

    if [ -z "$data_partition" ]; then
        echo "[aipc-os-preinstall] no persistent data partition found on /dev/${filesystem_device}; allowing bare-board contract probe"
        return 0
    fi

    mkdir -p /data
    mount "$data_partition" /data ||
        fail "failed to mount persistent data partition: $data_partition"
    echo "[aipc-os-preinstall] mounted persistent data partition: $data_partition"
}

mount_persistent_data

has_units=0
if [ -d "$units" ]; then
    for unit in "$units"/*.service "$units"/*.timer "$units"/*.target; do
        [ -f "$unit" ] || continue
        has_units=1
        break
    done
fi

# No application footprint at all -> factory / bare-board install.
if [ ! -e "$installer" ] &&
    [ ! -e "$compat_check" ] &&
    [ ! -s "$manifest" ] &&
    [ "$has_units" -eq 0 ]; then
    echo "[aipc-os-preinstall] no persistent AIPC application found; allowing bare-board OS install"
    exit 0
fi

[ -x "$installer" ] || fail "missing executable current-root installer: $installer"
[ -x "$compat_check" ] || fail "missing executable compatibility checker: $compat_check"
[ -s "$manifest" ] || fail "missing app manifest: $manifest"
[ -d "$units" ] || fail "missing canonical systemd directory: $units"
[ "$has_units" -eq 1 ] || fail "canonical systemd directory is empty: $units"

echo "[aipc-os-preinstall] persistent current-root contract is ready"
exit 0
