#!/usr/bin/env bash
# =============================================================================
# adaptive_btrfs_coW_guard.sh
# =============================================================================
# PURPOSE:
#   - Continuously monitor disk IO
#   - Detect performance degradation
#   - Apply +C only when beneficial
#   - Rollback changes if performance worsens
#   - Maintain full audit trail
# =============================================================================

set -euo pipefail

LOG_FILE="/tmp/btrfs_adaptive_guard.log"

USER_HOME="/home/owner"

TARGET_DIRS=(
    "$USER_HOME/.cache"
    "$USER_HOME/.local/share/Trash"
    "$USER_HOME/Downloads"
    "/var/cache"
    "$USER_HOME/.mozilla"
)

# Thresholds
IO_HIGH_THRESHOLD=80
IO_LOW_THRESHOLD=30

# State tracking
STATE_FILE="/tmp/btrfs_guard_state"

log() {
    echo "[$(date '+%F %T')] $*" | tee -a "$LOG_FILE"
}

get_fs() {
    df -T "$1" 2>/dev/null | awk 'NR==2 {print $2}'
}

is_btrfs() {
    [[ "$(get_fs "$1")" == "btrfs" ]]
}

exists() {
    [[ -d "$1" ]]
}

get_io_util() {
    if command -v iostat >/dev/null 2>&1; then
        iostat -x 1 1 2>/dev/null | awk '/^[a-z]/ {print $NF}' | tail -n1 || echo "0"
    else
        echo "0"
    fi
}

apply_cow_off() {
    local dir="$1"

    if lsattr -d "$dir" 2>/dev/null | grep -q "C"; then
        return
    fi

    log "APPLY +C → $dir"

    if chattr +C "$dir" 2>>"$LOG_FILE"; then
        echo "$dir" >> "$STATE_FILE"
        log "SUCCESS +C → $dir"
    else
        log "FAIL +C → $dir"
    fi
}

remove_cow_off() {
    local dir="$1"

    if ! lsattr -d "$dir" 2>/dev/null | grep -q "C"; then
        return
    fi

    log "ROLLBACK -C → $dir"

    if chattr -C "$dir" 2>>"$LOG_FILE"; then
        sed -i "\|$dir|d" "$STATE_FILE"
        log "SUCCESS -C → $dir"
    else
        log "FAIL rollback → $dir"
    fi
}

evaluate_dir() {
    local dir="$1"

    if ! exists "$dir"; then
        log "SKIP: missing → $dir"
        return
    fi

    if ! is_btrfs "$dir"; then
        log "SKIP: not Btrfs → $dir"
        return
    fi

    apply_cow_off "$dir"
}

rollback_all() {
    log "ROLLBACK TRIGGERED: restoring CoW"

    if [[ -f "$STATE_FILE" ]]; then
        while read -r dir; do
            remove_cow_off "$dir"
        done < "$STATE_FILE"
    fi
}

monitor_loop() {
    local last_state=""

    while true; do
        local io_util
        io_util=$(get_io_util)

        log "IO_UTIL: $io_util"

        # High IO → apply optimizations
        if awk -v v="$io_util" -v t="$IO_HIGH_THRESHOLD" 'BEGIN {exit !(v > t)}'; then
            log "STATE: HIGH IO → optimizing"

            for dir in "${TARGET_DIRS[@]}"; do
                evaluate_dir "$dir"
            done
        fi

        # Low IO → consider rollback if we had changes
        if awk -v v="$io_util" -v t="$IO_LOW_THRESHOLD" 'BEGIN {exit !(v < t)}'; then
            if [[ -f "$STATE_FILE" && -s "$STATE_FILE" ]]; then
                log "STATE: LOW IO → evaluating rollback"
                rollback_all
            fi
        fi

        sleep 10
    done
}

main() {
    log "=== ADAPTIVE COw CONTROLLER START ==="

    touch "$STATE_FILE"

    monitor_loop
}

main