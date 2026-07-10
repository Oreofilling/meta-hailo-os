#!/bin/bash
# AIPC_LOCAL_RECOVERY_V1
#
# Hailo SWUpdate recovery init with support for a package stored on the legacy
# single-copy data partition. Keep PID 1 deliberately simple: do not use Bash
# process substitution because minimal recovery images may not provide
# /dev/fd -> /proc/self/fd.

set -u
PATH=/sbin:/bin:/usr/sbin:/usr/bin

RECOVERY_CONSOLE="${RECOVERY_CONSOLE:-/dev/ttyS1}"
JOB_DIR=""
LOG_FILE=""

console_log() {
    if [ -n "$LOG_FILE" ]; then
        printf '%s\n' "$*" | tee -a "$LOG_FILE"
    else
        printf '%s\n' "$*"
    fi
}

recovery_shell() {
    reason="$1"
    if [ -n "$JOB_DIR" ]; then
        printf '%s\n' "$reason" >"${JOB_DIR}/recovery.failed"
    fi
    console_log "Recovery stopped: ${reason}"
    console_log "Starting an emergency shell instead of exiting PID 1."
    sync
    if [ -c "$RECOVERY_CONSOLE" ]; then
        exec /bin/sh <"$RECOVERY_CONSOLE" >"$RECOVERY_CONSOLE" 2>&1
    fi
    exec /bin/sh
}

write_swupdate_config() {
    : >/tmp/swupdate.cfg
    for var in \
        SWUPDATE_FW_ENV_DEVICE \
        SWUPDATE_FIRMWARE_DEVICE \
        SWUPDATE_BOOTLOADER_DEVICE \
        SWUPDATE_FILESYSTEM_DEVICE \
        SWUPDATE_ROOTFS_DEVICE \
        SWUPDATE_FITIMAGE_DEVICE
    do
        eval "value=\${${var}:-}"
        if [ -n "$value" ]; then
            key="${var#SWUPDATE_}"
            echo "${key}=${value}" >>/tmp/swupdate.cfg
        fi
    done
}

post_swupdate_modify_scu_bl_cfg() {
    current_copy=$(/etc/get_sw_image.sh --next)
    if [ "$current_copy" = "a" ]; then
        /etc/set_sw_image.sh a
    fi
}

mount_persistent_data() {
    filesystem_device="${SWUPDATE_FILESYSTEM_DEVICE:-mmcblk1}"
    if awk '$2 == "/data" { found=1 } END { exit !found }' /proc/mounts; then
        return 0
    fi

    # Legacy single-copy layouts use p3; copy-a-only devices can retain the
    # complete p1..p5 table and place shared data on p5.
    data_partition="/dev/${filesystem_device}p3"
    if [ -b "/dev/${filesystem_device}p5" ]; then
        data_partition="/dev/${filesystem_device}p5"
    fi
    mkdir -p /data
    mount "$data_partition" /data || recovery_shell "data-mount-failed"
}

run_local_update() {
    relative_path="${SWUPDATE_UPDATE_FILENAME#local:}"
    case "$relative_path" in
        /data/*) package="$relative_path" ;;
        /*) package="/data${relative_path}" ;;
        *) package="/data/${relative_path}" ;;
    esac
    job_id="$(basename "$package" .swu)"
    JOB_DIR="/data/aipc-os-upgrade/jobs/${job_id}"

    mount_persistent_data
    mkdir -p "$JOB_DIR" ||
        recovery_shell "job-directory-failed"
    LOG_FILE="${JOB_DIR}/swupdate.log"

    console_log "AIPC single-copy recovery update"
    console_log "Package: ${package}"
    console_log "Target:  /dev/${filesystem_device}p1 + p2"

    if [ ! -f "$package" ]; then
        recovery_shell "package-not-found"
    fi

    set +e
    swupdate -i "$package" -v -m -M -e "stable,copy-a" 2>&1 |
        tee -a "$LOG_FILE"
    rc="${PIPESTATUS[0]}"
    set -e
    if [ "$rc" -ne 0 ]; then
        recovery_shell "swupdate-exit-${rc}"
    fi

    if ! /etc/set_sw_image.sh a; then
        recovery_shell "boot-copy-selection-failed"
    fi
    rm -f "${JOB_DIR}/recovery.failed"
    echo "ok" >"${JOB_DIR}/recovery.success"
    sync
    reboot -f
    recovery_shell "reboot-returned"
}

run_tftp_update() {
    if [[ -z "${SWUPDATE_SERVER_IP:-}" ||
          -z "${SWUPDATE_SERVER_UDP_LOGGING_PORT:-}" ||
          -z "${SWUPDATE_UPDATE_MODES:-}" ||
          -z "${SWUPDATE_UPDATE_FILENAME:-}" ]]; then
        recovery_shell "missing-swupdate-kernel-parameters"
    fi

    if [[ -n "${SWUPDATE_IPADDR:-}" && "${SWUPDATE_IPADDR}" != "10.0.0.1" ]]; then
        ip addr add "${SWUPDATE_IPADDR}/24" dev eth0
    fi
    /etc/init.d/networking start
    sleep 10
    # The SWU preinstall gate validates the persistent application contract.
    # Recovery TFTP mode therefore needs the same /data mount as local mode.
    mount_persistent_data

    set +e
    (
        cd /tmp || exit 1
        tftp -g -r "${SWUPDATE_UPDATE_FILENAME}" "${SWUPDATE_SERVER_IP}" ||
            exit 1
        for mode in ${SWUPDATE_UPDATE_MODES//,/ }; do
            swupdate -i "${SWUPDATE_UPDATE_FILENAME}" -v -m -M -e "stable,${mode}" ||
                exit $?
        done
        post_swupdate_modify_scu_bl_cfg
    ) 2>&1 | tee /proc/self/fd/2 |
        nc -u "${SWUPDATE_SERVER_IP}" "${SWUPDATE_SERVER_UDP_LOGGING_PORT}"
    rc="${PIPESTATUS[0]}"
    set -e
    if [ "$rc" -ne 0 ]; then
        recovery_shell "tftp-update-exit-${rc}"
    fi
    sync
    reboot -f
    recovery_shell "reboot-returned"
}

main() {
    umask 022
    mount -t proc proc /proc || recovery_shell "proc-mount-failed"
    mount -t sysfs sysfs /sys || recovery_shell "sysfs-mount-failed"
    mount -o size=4G -t tmpfs tmpfs /tmp || recovery_shell "tmp-mount-failed"
    mkdir -p /dev
    ln -snf /proc/self/fd /dev/fd
    ln -snf /proc/self/fd/0 /dev/stdin
    ln -snf /proc/self/fd/1 /dev/stdout
    ln -snf /proc/self/fd/2 /dev/stderr
    mkdir -p /var
    ln -snf /tmp /var/volatile
    write_swupdate_config

    case "${SWUPDATE_UPDATE_FILENAME:-}" in
        local:/*) run_local_update ;;
        *) run_tftp_update ;;
    esac
}

main
