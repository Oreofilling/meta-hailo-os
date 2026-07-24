#!/bin/bash
# AIPC_LOCAL_RECOVERY_V1
# AIPC_LOCAL_RECOVERY_ANY_MODE_V1
#
# Local SWUpdate recovery handler for Web-uploaded AIPC OS packages. Hailo's
# original recovery init handles every non-local path; this script only runs
# when SWUPDATE_UPDATE_FILENAME uses the local:/ prefix.
#
# Keep PID 1 deliberately simple: do not use Bash process substitution because
# minimal recovery images may not provide /dev/fd -> /proc/self/fd.

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

# Default grep pattern copied from Hailo's recovery init. It filters noisy TRACE
# lines while keeping errors, warnings, high-level progress, device mappings,
# write offsets and script execution results. Set SWUPDATE_LOG_FILTER="." to
# show everything.
SWUPDATE_LOG_FILTER_DEFAULT='^\[(INFO |WARN |ERROR)\]|_parse_images|install_single_image|__swupdate_copy.*offset|__run_cmd|\[extract_file_to_tmp\] :   filename |\[extract_files\] :.*filename [^ ]|lua_dump_table.*(device = /|offset = [^0]|filename = [^ ])|[fF][aA][iI][lL]|[eE][rR][rR][oO][rR]|No such file'

swupdate_log_filter() {
    local filter="${SWUPDATE_LOG_FILTER:-${SWUPDATE_LOG_FILTER_DEFAULT}}"
    if [ -z "${filter}" ]; then
        cat
    else
        grep -E "${filter}" || true
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

safe_forced_reboot() {
    sync
    if awk '$2 == "/data" { found=1 } END { exit !found }' /proc/mounts; then
        umount /data 2>/dev/null ||
            mount -o remount,ro /data 2>/dev/null ||
            true
    fi
    sync
    reboot -f
}

boot_copy_for_mode() {
    case "$1" in
        *-a) echo "a" ;;
        *-b) echo "b" ;;
        *) echo "" ;;
    esac
}

select_boot_after_update() {
    local mode="$1"
    local target_copy="$2"
    local current_copy=""

    if [ -n "$target_copy" ]; then
        if ! /etc/set_sw_image.sh "$target_copy"; then
            recovery_shell "boot-copy-selection-failed-${target_copy}"
        fi
        return 0
    fi

    # Match Hailo's recovery-init behavior for modes that do not name a target
    # copy explicitly. This keeps SCU boot_image_mode normalization with Hailo's
    # original logic while avoiding a forced A/B switch for maintenance modes.
    if [ -x /etc/get_sw_image.sh ]; then
        current_copy="$(/etc/get_sw_image.sh --next 2>/dev/null || true)"
    fi
    if [ "$current_copy" = "a" ]; then
        if ! /etc/set_sw_image.sh a; then
            recovery_shell "boot-copy-selection-failed-a"
        fi
    else
        console_log "No boot-copy switch for mode: ${mode}"
    fi
}

run_local_update() {
    local_update_mode="${SWUPDATE_UPDATE_MODES:-copy-a}"
    case "$local_update_mode" in
        ""|*[!A-Za-z0-9_.-]*)
            recovery_shell "invalid-local-update-mode-${local_update_mode//[^A-Za-z0-9_.-]/_}"
            ;;
        *)
            # The AIPC application validates that this mode was declared by the
            # uploaded SWU. Recovery only rejects syntactically unsafe values so
            # future images can add maintenance/factory update modes without an
            # AIPC app release.
            ;;
    esac

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
    target_copy="$(boot_copy_for_mode "$local_update_mode")"
    case "$target_copy" in
        a) target_summary="/dev/${filesystem_device}p1 + p2" ;;
        b) target_summary="/dev/${filesystem_device}p3 + p4" ;;
        *) target_summary="defined by SWUpdate mode" ;;
    esac

    console_log "AIPC local recovery update"
    console_log "Package: ${package}"
    console_log "Mode:    stable,${local_update_mode}"
    console_log "Target:  ${target_summary}"

    if [ ! -f "$package" ]; then
        recovery_shell "package-not-found"
    fi

    set +e
    swupdate -i "$package" -l "${SWUPDATE_LOGLEVEL:-4}" -m -M \
        -e "stable,${local_update_mode}" 2>&1 |
        swupdate_log_filter |
        tee -a "$LOG_FILE"
    rc="${PIPESTATUS[0]}"
    set -e
    if [ "$rc" -ne 0 ]; then
        recovery_shell "swupdate-exit-${rc}"
    fi

    select_boot_after_update "$local_update_mode" "$target_copy"
    rm -f "${JOB_DIR}/recovery.failed"
    echo "ok" >"${JOB_DIR}/recovery.success"
    safe_forced_reboot
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
        *) recovery_shell "unexpected-non-local-update" ;;
    esac
}

main
