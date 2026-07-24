#!/bin/sh
# AIPC_SWUPDATE_INIT_WRAPPER_V1
#
# Keep Hailo's original recovery init intact. This wrapper only intercepts the
# AIPC local-SWU flow used by the Web OS upgrade; all TFTP / factory paths are
# delegated to the original Hailo SWUpdate init script.

set -eu
PATH=/sbin:/bin:/usr/sbin:/usr/bin

LOCAL_INIT="${AIPC_LOCAL_SWUPDATE_INIT:-/usr/libexec/aipc-swupdate-local}"
HAILO_INIT="${AIPC_HAILO_SWUPDATE_INIT:-/sbin/init.initscripts-hailo-swupdate}"
RECOVERY_CONSOLE="${RECOVERY_CONSOLE:-/dev/ttyS1}"

recovery_shell() {
    reason="$1"
    echo "[aipc-swupdate-wrapper] ERROR: ${reason}" >&2
    echo "Starting an emergency shell instead of exiting PID 1." >&2
    sync
    if [ -c "$RECOVERY_CONSOLE" ]; then
        exec /bin/sh <"$RECOVERY_CONSOLE" >"$RECOVERY_CONSOLE" 2>&1
    fi
    exec /bin/sh
}

case "${SWUPDATE_UPDATE_FILENAME:-}" in
    local:/*)
        [ -x "$LOCAL_INIT" ] ||
            recovery_shell "missing local SWUpdate handler: $LOCAL_INIT"
        exec "$LOCAL_INIT" "$@"
        ;;
    *)
        [ -x "$HAILO_INIT" ] ||
            recovery_shell "missing original Hailo SWUpdate init: $HAILO_INIT"
        exec "$HAILO_INIT" "$@"
        ;;
esac
