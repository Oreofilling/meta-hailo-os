#!/bin/sh
# Reject an OS rewrite unless the persistent AIPC release can reconstruct the
# new rootfs. This check lives inside the SWU so even an older application-side
# updater cannot bypass the migration prerequisite.

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

[ -x "$installer" ] || fail "missing executable current-root installer: $installer"
[ -x "$compat_check" ] || fail "missing executable compatibility checker: $compat_check"
[ -s "$manifest" ] || fail "missing app manifest: $manifest"
[ -d "$units" ] || fail "missing canonical systemd directory: $units"

found=0
for unit in "$units"/*.service "$units"/*.timer "$units"/*.target; do
    [ -f "$unit" ] || continue
    found=1
    break
done
[ "$found" -eq 1 ] || fail "canonical systemd directory is empty: $units"

echo "[aipc-os-preinstall] persistent current-root contract is ready"
exit 0
