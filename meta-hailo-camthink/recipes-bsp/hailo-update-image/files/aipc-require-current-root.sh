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
