#!/bin/bash

###############################################################################
# Script: updateOratab.sh
#
# Description: Monitor Oracle databases (CDB and PDB instances) and automatically
# update the /etc/oratab file to reflect running instances, ensuring accurate
# database instance tracking across system restarts and state changes.
#
# Input Parameters:
#   --monitor (flag): Continuous monitoring mode with periodic checks.
#   --interval (integer): Seconds between checks (default: 60). Requires --monitor.
#   --update-once (flag): Single update pass and exit.
#   --install-timer (flag): Install systemd timer for scheduled updates.
#   --timer-interval (integer): Timer interval in seconds (default: 60). Requires --install-timer.
#   --remove-timer (flag): Remove systemd timer and service files.
#   --verbose (flag): Enable verbose debug output.
#   --dry-run (flag): Show what would be updated without making changes.
#   --help (flag): Display help message.
#
# Requirements:
#   - Execute as: oracle user
#   - Requires: ps, grep, awk, sed, tput commands.
#   - Requires loggy.sh in same directory (optional).
#   - /etc/oratab file must exist and be writable by oracle user.
#   - Oracle installation with pmon processes for running instances.
#   - Requires sudo for: systemd timer operations (--install-timer, --remove-timer).
#
# Examples:
#   ./updateOratab.sh --update-once
#   ./updateOratab.sh --monitor --interval 30 --verbose
#   sudo ./updateOratab.sh --install-timer --timer-interval 120
#
###############################################################################
# Copyright © 2025 SolidWorks Consulting LLC.
# This is a product of SolidWorks Consulting LLC. (www.rndev.com).
# Code is free to use with proper attribution to the source.
###############################################################################

set -euo pipefail

# Source loggy if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/loggy.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/loggy.sh"
else
    # Fallback logging function if loggy.sh not found
    loggy() {
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >&2
    }
fi

# Source constants if available
if [[ -f "$(dirname "${BASH_SOURCE[0]}")/constants.sh" ]]; then
    source "$(dirname "${BASH_SOURCE[0]}")/constants.sh"
fi

# Global variables
GV_ORATAB_MONITOR_MODE=false
GV_ORATAB_CHECK_INTERVAL=60
GV_ORATAB_VERBOSE=false
GV_ORATAB_DRY_RUN=false
GV_ORATAB_UPDATE_ONCE=false
GV_ORATAB_INSTALL_TIMER=false
GV_ORATAB_REMOVE_TIMER=false
GV_ORATAB_CLEANUP_NONRUNNING=false
GV_ORATAB_TIMER_INTERVAL=60
GV_ORATAB_BACKUP_RETENTION_DAYS=3
GV_ORATAB_FILE="/etc/oratab"
GV_ORATAB_LOCK_FILE="/tmp/updateOratab.lock"
GV_ORATAB_SYSTEMD_SERVICE="/etc/systemd/system/updateOratab.service"
GV_ORATAB_SYSTEMD_TIMER="/etc/systemd/system/updateOratab.timer"
GV_ORATAB_RUNNING_INSTANCES=()

###############################################################################
# Acquire exclusive lock to prevent concurrent executions
###############################################################################
_acquireLock() {
    loggy --type debug --message "Calling [_acquireLock]" --quiet
    
    local l_lock_pid
    
    # Check if lock file exists and contains valid PID
    if [[ -f "$GV_ORATAB_LOCK_FILE" ]]; then
        l_lock_pid=$(cat "$GV_ORATAB_LOCK_FILE" 2>/dev/null)
        
        # Check if process with that PID is still running
        if [[ -n "$l_lock_pid" ]] && kill -0 "$l_lock_pid" 2>/dev/null; then
            loggy --type error --message "Another instance of updateOratab.sh is already running (PID: $l_lock_pid)"
            exit 1
        else
            # Stale lock file, remove it
            if [[ "$GV_VERBOSE" == true ]]; then
                loggy --type debug --message "Removing stale lock file (PID $l_lock_pid no longer exists)"
            fi
            rm -f "$GV_ORATAB_LOCK_FILE"
        fi
    fi
    
    # Create new lock file with current PID
    echo "$$" > "$GV_ORATAB_LOCK_FILE" || {
        loggy --type error --message "Failed to create lock file: $GV_ORATAB_LOCK_FILE"
        exit 1
    }
    
    if [[ "$GV_VERBOSE" == true ]]; then
        loggy --type debug --message "Lock acquired (PID: $$)"
    fi
}

###############################################################################
# Release exclusive lock
###############################################################################
_releaseLock() {
    loggy --type debug --message "Calling [_releaseLock]" --quiet
    
    if [[ -f "$GV_ORATAB_LOCK_FILE" ]]; then
        rm -f "$GV_ORATAB_LOCK_FILE"
        if [[ "$GV_VERBOSE" == true ]]; then
            loggy --type debug --message "Lock released"
        fi
    fi
}

###############################################################################
# Generate systemd service file content
###############################################################################
_generateServiceFile() {
    loggy --type debug --message "Calling [_generateServiceFile]" --quiet
    
    local l_script_path
    l_script_path="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/$(basename "${BASH_SOURCE[0]}")"
    
    cat << EOF
[Unit]
Description=Update Oracle oratab with running database instances
After=network.target
Requires=updateOratab.timer

[Service]
Type=oneshot
ExecStart=$l_script_path --update-once
User=oracle
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF
}

###############################################################################
# Generate systemd timer file content
###############################################################################
_generateTimerFile() {
    loggy --type debug --message "Calling [_generateTimerFile]" --quiet
    
    cat << EOF
[Unit]
Description=Timer for Oracle oratab updates
Requires=updateOratab.service

[Timer]
OnBootSec=30sec
OnUnitActiveSec=${GV_ORATAB_TIMER_INTERVAL}sec
AccuracySec=1sec
Persistent=true

[Install]
WantedBy=timers.target
EOF
}

###############################################################################
# Install systemd timer for automatic updates
###############################################################################
_installTimer() {
    loggy --type debug --message "Calling [_installTimer]" --quiet
    loggy --type beginend --message "Starting [installTimer]"
    
    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        loggy --type error --message "Timer installation requires root privileges"
        exit 1
    fi
    
    loggy --type info --message "Installing systemd timer (interval: ${GV_ORATAB_TIMER_INTERVAL}s)"
    
    # Create service file
    if ! _generateServiceFile | sudo tee "$GV_ORATAB_SYSTEMD_SERVICE" > /dev/null; then
        loggy --type error --message "Failed to create service file: $GV_ORATAB_SYSTEMD_SERVICE"
        exit 1
    fi
    loggy --type debug --message "Service file created: $GV_ORATAB_SYSTEMD_SERVICE"
    
    # Create timer file
    if ! _generateTimerFile | sudo tee "$GV_ORATAB_SYSTEMD_TIMER" > /dev/null; then
        loggy --type error --message "Failed to create timer file: $GV_ORATAB_SYSTEMD_TIMER"
        exit 1
    fi
    loggy --type debug --message "Timer file created: $GV_ORATAB_SYSTEMD_TIMER"
    
    # Reload systemd daemon
    if ! sudo systemctl daemon-reload; then
        loggy --type error --message "Failed to reload systemd daemon"
        exit 1
    fi
    loggy --type debug --message "Systemd daemon reloaded"
    
    # Enable timer
    if ! sudo systemctl enable updateOratab.timer; then
        loggy --type error --message "Failed to enable updateOratab.timer"
        exit 1
    fi
    loggy --type info --message "Timer enabled: updateOratab.timer"
    
    # Start timer
    if ! sudo systemctl start updateOratab.timer; then
        loggy --type error --message "Failed to start updateOratab.timer"
        exit 1
    fi
    loggy --type info --message "Timer started: updateOratab.timer"
    
    # Show timer status
    loggy --type info --message "Timer installation complete. Use 'systemctl status updateOratab.timer' to check status."
    
    loggy --type beginend --message "Completed [installTimer]"
}

###############################################################################
# Remove systemd timer
###############################################################################
_removeTimer() {
    loggy --type debug --message "Calling [_removeTimer]" --quiet
    loggy --type beginend --message "Starting [removeTimer]"
    
    # Check if running as root
    if [[ "$EUID" -ne 0 ]]; then
        loggy --type error --message "Timer removal requires root privileges"
        exit 1
    fi
    
    loggy --type info --message "Removing systemd timer"
    
    # Stop timer if running
    if sudo systemctl is-active --quiet updateOratab.timer; then
        if ! sudo systemctl stop updateOratab.timer; then
            loggy --type error --message "Failed to stop updateOratab.timer"
            exit 1
        fi
        loggy --type debug --message "Timer stopped: updateOratab.timer"
    fi
    
    # Disable timer
    if sudo systemctl is-enabled --quiet updateOratab.timer 2>/dev/null; then
        if ! sudo systemctl disable updateOratab.timer; then
            loggy --type error --message "Failed to disable updateOratab.timer"
            exit 1
        fi
        loggy --type debug --message "Timer disabled: updateOratab.timer"
    fi
    
    # Remove files
    if [[ -f "$GV_ORATAB_SYSTEMD_SERVICE" ]]; then
        if ! sudo rm -f "$GV_ORATAB_SYSTEMD_SERVICE"; then
            loggy --type error --message "Failed to remove: $GV_ORATAB_SYSTEMD_SERVICE"
            exit 1
        fi
        loggy --type debug --message "Service file removed: $GV_ORATAB_SYSTEMD_SERVICE"
    fi
    
    if [[ -f "$GV_ORATAB_SYSTEMD_TIMER" ]]; then
        if ! sudo rm -f "$GV_ORATAB_SYSTEMD_TIMER"; then
            loggy --type error --message "Failed to remove: $GV_ORATAB_SYSTEMD_TIMER"
            exit 1
        fi
        loggy --type debug --message "Timer file removed: $GV_ORATAB_SYSTEMD_TIMER"
    fi
    
    # Reload systemd daemon
    if ! sudo systemctl daemon-reload; then
        loggy --type error --message "Failed to reload systemd daemon"
        exit 1
    fi
    loggy --type debug --message "Systemd daemon reloaded"
    
    loggy --type info --message "Timer removal complete"
    loggy --type beginend --message "Completed [removeTimer]"
}

###############################################################################
# Display usage information
###############################################################################
_showUsage() {
    cat << 'EOF'
Usage: updateOratab.sh [OPTIONS]

Monitor Oracle databases and update /etc/oratab file automatically.

OPTIONS:
  --monitor              Enable continuous monitoring mode with periodic checks.
  --interval SECONDS     Set check interval in seconds (default: 60, requires --monitor).
  --update-once          Perform single update pass and exit.
  --cleanup-nonrunning   Remove database entries marked as not running (Y->N status).
  --install-timer        Install systemd timer for scheduled updates (requires sudo).
  --timer-interval SECS  Set timer interval in seconds (default: 60, requires --install-timer).
  --remove-timer         Remove systemd timer and service files (requires sudo).
  --verbose              Enable verbose debug output.
  --dry-run              Show what would be changed without modifying /etc/oratab.
  --help                 Display this help message.

EXAMPLES:
  # Single update pass (as oracle user)
  ./updateOratab.sh --update-once

  # Continuous monitoring every 30 seconds with verbose output
  ./updateOratab.sh --monitor --interval 30 --verbose

  # Single update and remove non-running database entries
  ./updateOratab.sh --update-once --cleanup-nonrunning

  # Install systemd timer for automatic updates (requires sudo)
  sudo ./updateOratab.sh --install-timer --timer-interval 120

  # Remove systemd timer (requires sudo)
  sudo ./updateOratab.sh --remove-timer

NOTES:
  - Run as oracle user for instance detection and oratab updates.
  - Systemd timer operations (--install-timer, --remove-timer) require sudo.
  - /etc/oratab can be modified by oracle user without sudo.
  - Backup files older than GV_ORATAB_BACKUP_RETENTION_DAYS (default: 3 days) are automatically deleted.
EOF
}

###############################################################################
# Parse command-line parameters
###############################################################################
_parseParameters() {
    loggy --type debug --message "Calling [_parseParameters]" --quiet
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --monitor)
                GV_ORATAB_MONITOR_MODE=true
                shift
                ;;
            --interval)
                if [[ -z "${2:-}" ]]; then
                    loggy --type error --message "Missing value for --interval parameter"
                    _showUsage
                    exit 1
                fi
                if ! [[ "${2}" =~ ^[0-9]+$ ]]; then
                    loggy --type error --message "Invalid interval value: ${2} (must be a number)"
                    exit 1
                fi
                GV_ORATAB_CHECK_INTERVAL="${2}"
                shift 2
                ;;
            --update-once)
                GV_ORATAB_UPDATE_ONCE=true
                shift
                ;;
            --cleanup-nonrunning)
                GV_ORATAB_CLEANUP_NONRUNNING=true
                shift
                ;;
            --verbose)
                GV_ORATAB_VERBOSE=true
                shift
                ;;
            --dry-run)
                GV_ORATAB_DRY_RUN=true
                shift
                ;;
            --install-timer)
                GV_ORATAB_INSTALL_TIMER=true
                shift
                ;;
            --timer-interval)
                if [[ -z "${2:-}" ]]; then
                    loggy --type error --message "Missing value for --timer-interval parameter"
                    _showUsage
                    exit 1
                fi
                if ! [[ "${2}" =~ ^[0-9]+$ ]]; then
                    loggy --type error --message "Invalid timer interval value: ${2} (must be a number)"
                    exit 1
                fi
                GV_ORATAB_TIMER_INTERVAL="${2}"
                shift 2
                ;;
            --remove-timer)
                GV_ORATAB_REMOVE_TIMER=true
                shift
                ;;
            --help)
                _showUsage
                exit 0
                ;;
            *)
                loggy --type error --message "Unknown parameter: $1"
                _showUsage
                exit 1
                ;;
        esac
    done
}

###############################################################################
# Execute command with sudo if necessary (prompt user if not sudoers)
###############################################################################
_executeSudo() {
    loggy --type debug --message "Calling [_executeSudo]" --quiet
    
    local l_description="$1"
    shift
    
    # Check if already running as root
    if [[ "$EUID" -eq 0 ]]; then
        # Already running as root, execute directly
        "$@"
        return $?
    fi
    
    # Try to execute with sudo
    if sudo -v &> /dev/null; then
        # User is in sudoers, use cached sudo
        sudo "$@"
        return $?
    else
        # Not in sudoers, prompt for password
        loggy --type info --message "$l_description requires sudo privileges"
        sudo "$@"
        return $?
    fi
}

###############################################################################
# Verify script prerequisites
###############################################################################
_validateEnvironment() {
    loggy --type debug --message "Calling [_validateEnvironment]" --quiet
    
    # Check if running as oracle user
    if [[ \"$(whoami)\" != \"oracle\" ]]; then
        loggy --type warning --message \"Script is running as $(whoami), not oracle user. Instance detection may be limited.\"
    fi
    
    # Check if /etc/oratab is readable
    if [[ ! -r \"$GV_ORATAB_FILE\" ]]; then
        loggy --type error --message \"File is not readable: $GV_ORATAB_FILE\"
        exit 1
    fi
    
    # Verify required commands exist
    local l_required_commands=("ps" "grep" "awk" "sed")
    for l_cmd in "${l_required_commands[@]}"; do
        if ! command -v "$l_cmd" &> /dev/null; then
            loggy --type error --message "Required command not found: $l_cmd"
            exit 1
        fi
    done
}

###############################################################################
# Find all running Oracle instances by querying pmon processes
###############################################################################
_findRunningInstances() {
    loggy --type debug --message "Calling [_findRunningInstances]" --quiet
    
    GV_ORATAB_RUNNING_INSTANCES=()
    local l_instances
    local l_instance
    
    # Find all pmon processes and extract database names
    l_instances=$(ps aux | grep -E "ora_pmon_[A-Za-z0-9]+" | grep -v grep | awk '{print $NF}' | sed 's/ora_pmon_//')
    
    if [[ -n "$l_instances" ]]; then
        while IFS= read -r l_instance; do
            if [[ -n "$l_instance" ]]; then
                GV_ORATAB_RUNNING_INSTANCES+=("$l_instance")
                if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                    loggy --type debug --message "Found running instance: $l_instance"
                fi
            fi
        done <<< "$l_instances"
    fi
    
    if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
        loggy --type debug --message "Total running instances found: ${#GV_ORATAB_RUNNING_INSTANCES[@]}"
    fi
}

###############################################################################
# Get current entries from /etc/oratab
###############################################################################
_getOratabEntries() {
    loggy --type debug --message "Calling [_getOratabEntries]" --quiet
    
    local l_entries=()
    local l_line
    
    while IFS= read -r l_line; do
        # Skip comments and empty lines
        if [[ -z "$l_line" ]] || [[ "$l_line" =~ ^# ]]; then
            continue
        fi
        l_entries+=("$l_line")
    done < "$GV_ORATAB_FILE"
    
    printf '%s\n' "${l_entries[@]}"
}

###############################################################################
# Extract ORACLE_HOME for a given instance from oratab
###############################################################################
_getOracleHome() {
    local l_sid="$1"
    local l_oracle_home=""
    
    l_oracle_home=$(grep "^${l_sid}:" "$GV_ORATAB_FILE" 2>/dev/null | cut -d: -f2 | head -1)
    echo "$l_oracle_home"
}

###############################################################################
# Cleanup old backup files beyond retention period
###############################################################################
_cleanupOldBackups() {
    loggy --type debug --message "Calling [_cleanupOldBackups]" --quiet
    
    local l_backup_dir
    local l_current_time
    local l_file_age_days
    local l_backup_file
    
    l_backup_dir=$(dirname "$GV_ORATAB_FILE")
    l_current_time=$(date +%s)
    
    # Find all backup files matching the pattern and older than retention days
    while IFS= read -r l_backup_file; do
        if [[ -z "$l_backup_file" ]]; then
            continue
        fi
        
        # Extract timestamp from filename (format: oratab.bak.TIMESTAMP)
        local l_file_timestamp
        l_file_timestamp=$(echo "$l_backup_file" | sed 's/.*\.bak\.\([0-9]*\)/\1/')
        
        if ! [[ "$l_file_timestamp" =~ ^[0-9]+$ ]]; then
            continue
        fi
        
        # Calculate age in days
        l_file_age_days=$(( (l_current_time - l_file_timestamp) / 86400 ))
        
        # Remove if older than retention period
        if [[ $l_file_age_days -gt $GV_ORATAB_BACKUP_RETENTION_DAYS ]]; then
            if rm -f "$l_backup_file" 2>/dev/null; then
                if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                    loggy --type debug --message "Deleted old backup: $(basename "$l_backup_file") (${l_file_age_days} days old)"
                fi
            fi
        fi
    done < <(find "$l_backup_dir" -maxdepth 1 -name "oratab.bak.*" -type f 2>/dev/null)
}

###############################################################################
# Remove non-running database entries from /etc/oratab
###############################################################################
_cleanupNonRunningEntries() {
    loggy --type debug --message "Calling [_cleanupNonRunningEntries]" --quiet
    loggy --type beginend --message "Starting [cleanupNonRunningEntries]"
    
    local l_original_content
    local l_new_content=""
    local l_line
    local l_sid
    local l_status
    local l_removed_count=0
    
    # Read original oratab content
    l_original_content=$(<"$GV_ORATAB_FILE")
    
    # Process entries and skip those marked as not running
    while IFS= read -r l_line; do
        # Keep comments and empty lines as-is
        if [[ -z "$l_line" ]] || [[ "$l_line" =~ ^# ]]; then
            l_new_content+="$l_line"$'\n'
            continue
        fi
        
        # Extract SID and status
        l_sid=$(echo "$l_line" | cut -d: -f1)
        l_status=$(echo "$l_line" | cut -d: -f3)
        
        # Skip entries marked as not running (N status)
        if [[ "$l_status" == "N" ]]; then
            ((l_removed_count++))
            if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                loggy --type debug --message "Removing non-running entry: $l_sid"
            fi
            continue
        fi
        
        # Keep running entries
        l_new_content+="$l_line"$'\n'
    done <<< "$l_original_content"
    
    if [[ $l_removed_count -eq 0 ]]; then
        loggy --type info --message "No non-running entries found to remove"
        loggy --type beginend --message "Completed [cleanupNonRunningEntries]"
        return 0
    fi
    
    # Write cleaned content
    if [[ "$GV_ORATAB_DRY_RUN" == true ]]; then
        loggy --type info --message "DRY-RUN: Would remove $l_removed_count non-running entries"
        if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
            echo "--- Original ---"
            echo "$l_original_content"
            echo ""
            echo "--- Cleaned ---"
            echo "$l_new_content"
        fi
    else
        # Create backup before modifying
        local l_backup_file
        l_backup_file="${GV_ORATAB_FILE}.bak.$(date +%s)"
        
        if ! cp "$GV_ORATAB_FILE" "$l_backup_file"; then
            loggy --type error --message "Failed to create backup: $l_backup_file"
            loggy --type beginend --message "Completed [cleanupNonRunningEntries]"
            return 1
        fi
        loggy --type debug --message "Backup created: $l_backup_file"
        
        # Write cleaned content
        if ! echo -n "$l_new_content" | tee "$GV_ORATAB_FILE" > /dev/null; then
            loggy --type error --message "Failed to update /etc/oratab"
            loggy --type beginend --message "Completed [cleanupNonRunningEntries]"
            return 1
        fi
        
        loggy --type info --message "Removed $l_removed_count non-running database entries from /etc/oratab"
        
        # Cleanup old backups
        _cleanupOldBackups
    fi
    
    loggy --type beginend --message "Completed [cleanupNonRunningEntries]"
    return 0
}

###############################################################################
# Update /etc/oratab with current instance status
###############################################################################
_updateOratab() {
    loggy --type debug --message "Calling [_updateOratab]" --quiet
    loggy --type beginend --message "Starting [updateOratab]"
    
    local l_temp_file
    local l_updated=false
    local l_original_content
    local l_new_content=""
    local l_line
    local l_sid
    local l_oracle_home
    local l_status
    
    # Read original oratab content
    l_original_content=$(<"$GV_ORATAB_FILE")
    
    # Process existing entries
    while IFS= read -r l_line; do
        # Keep comments and empty lines as-is
        if [[ -z "$l_line" ]] || [[ "$l_line" =~ ^# ]]; then
            l_new_content+="$l_line"$'\n'
            continue
        fi
        
        # Extract SID and ORACLE_HOME
        l_sid=$(echo "$l_line" | cut -d: -f1)
        l_oracle_home=$(echo "$l_line" | cut -d: -f2)
        
        # Determine if instance is running
        if _instanceIsRunning "$l_sid"; then
            l_status="Y"
        else
            l_status="N"
        fi
        
        # Update status flag if different
        local l_current_status
        l_current_status=$(echo "$l_line" | cut -d: -f3)
        
        if [[ "$l_current_status" != "$l_status" ]]; then
            if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                loggy --type debug --message "Updating $l_sid: status changed from $l_current_status to $l_status"
            fi
            l_updated=true
        fi
        
        # Update the line with current status
        l_new_content+="${l_sid}:${l_oracle_home}:${l_status}"$'\n'
        
    done <<< "$l_original_content"
    
    # Add any running instances not already in oratab
    for l_instance in "${GV_ORATAB_RUNNING_INSTANCES[@]}"; do
        if ! grep -q "^${l_instance}:" "$GV_ORATAB_FILE"; then
            if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                loggy --type debug --message "Adding new instance: $l_instance"
            fi
            l_updated=true
            # Try to find ORACLE_HOME from environment or default location
            local l_home
            l_home=$(_guessOracleHome "$l_instance")
            l_new_content+="${l_instance}:${l_home}:Y"$'\n'
        fi
    done
    
    # Write changes if updated
    if [[ "$l_updated" == true ]]; then
        if [[ "$GV_ORATAB_DRY_RUN" == true ]]; then
            loggy --type info --message "DRY-RUN: Would update /etc/oratab"
            if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
                echo "--- Original ---"
                echo "$l_original_content"
                echo ""
                echo "--- Updated ---"
                echo "$l_new_content"
            fi
        else
            # Create backup before modifying
            local l_backup_file
            l_backup_file="${GV_ORATAB_FILE}.bak.$(date +%s)"
            
            if ! cp "$GV_ORATAB_FILE" "$l_backup_file"; then
                loggy --type error --message "Failed to create backup: $l_backup_file"
                exit 1
            fi
            loggy --type debug --message "Backup created: $l_backup_file"
            
            # Cleanup old backups beyond retention period
            _cleanupOldBackups
            
            # Write updated content directly (oracle user has write permissions)
            if ! echo -n "$l_new_content" | tee "$GV_ORATAB_FILE" > /dev/null; then
                loggy --type error --message "Failed to update /etc/oratab"
                exit 1
            fi
            
            loggy --type info --message "Updated /etc/oratab with current instance status"
        fi
    else
        if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
            loggy --type debug --message "No changes needed in /etc/oratab"
        fi
    fi
    
    loggy --type beginend --message "Completed [updateOratab]"
}

###############################################################################
# Check if a specific instance is currently running
###############################################################################
_instanceIsRunning() {
    local l_sid="$1"
    
    ps aux | grep -E "ora_pmon_${l_sid}" | grep -v grep > /dev/null 2>&1
}

###############################################################################
# Attempt to determine ORACLE_HOME for new instances
###############################################################################
_guessOracleHome() {
    local l_sid="$1"
    local l_oracle_home="/u01/app/oracle"
    
    # Try common Oracle Home locations
    if [[ -d "/opt/oracle/product" ]]; then
        l_oracle_home=$(find /opt/oracle/product -maxdepth 2 -name "bin" -type d 2>/dev/null | head -1 | xargs dirname)
    elif [[ -d "/u01/app/oracle/product" ]]; then
        l_oracle_home=$(find /u01/app/oracle/product -maxdepth 2 -name "bin" -type d 2>/dev/null | head -1 | xargs dirname)
    fi
    
    echo "$l_oracle_home"
}

###############################################################################
# Main monitoring loop for continuous mode
###############################################################################
_monitorLoop() {
    loggy --type info --message "Starting monitoring loop with ${GV_ORATAB_CHECK_INTERVAL}s interval"
    
    while true; do
        _findRunningInstances
        _updateOratab
        
        if [[ "$GV_ORATAB_VERBOSE" == true ]]; then
            loggy --type debug --message "Next check in ${GV_ORATAB_CHECK_INTERVAL} seconds"
        fi
        
        sleep "$GV_ORATAB_CHECK_INTERVAL"
    done
}

###############################################################################
# Main function
###############################################################################
main() {
    loggy --type beginend --message "Starting [main]"
    
    _parseParameters "$@"
    
    # Handle timer operations first (check sudo for privileged ops)
    if [[ "$GV_ORATAB_INSTALL_TIMER" == true ]] || [[ "$GV_ORATAB_REMOVE_TIMER" == true ]]; then
        # Validate environment but don't check lock
        _validateEnvironment
        
        # Check if user has sudo privileges for timer operations
        if ! sudo -v &> /dev/null; then
            loggy --type error --message "Systemd timer operations require sudo privileges"
            exit 1
        fi
    fi
    
    if [[ "$GV_ORATAB_INSTALL_TIMER" == true ]]; then
        _installTimer
        loggy --type beginend --message "Completed [main]"
        exit 0
    fi
    
    if [[ "$GV_ORATAB_REMOVE_TIMER" == true ]]; then
        _removeTimer
        loggy --type beginend --message "Completed [main]"
        exit 0
    fi
    
    _validateEnvironment
    
    # Acquire exclusive lock before proceeding
    _acquireLock
    
    # Set trap to ensure lock is released on exit
    trap _releaseLock EXIT INT TERM
    
    if [[ "$GV_ORATAB_MONITOR_MODE" == true ]]; then
        _monitorLoop
    elif [[ "$GV_ORATAB_UPDATE_ONCE" == true ]]; then
        _findRunningInstances
        _updateOratab
        
        # Cleanup non-running entries if requested
        if [[ "$GV_ORATAB_CLEANUP_NONRUNNING" == true ]]; then
            _cleanupNonRunningEntries
        fi
        
        loggy --type info --message "Update complete"
    else
        loggy --type error --message "Please specify either --monitor, --update-once, --install-timer, or --remove-timer"
        _showUsage
        exit 1
    fi
    
    loggy --type beginend --message "Completed [main]"
}

# Run main function with all arguments
main "$@"
