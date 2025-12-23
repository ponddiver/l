#!/bin/bash
###############################################################################
# Script: findOracleDatabases.sh
#
# Description: Identifies all running Oracle databases on a RHEL/Oracle Linux server and displays their Oracle Home directories, user ownership, and process IDs.
#
# Input Parameters:
#   --output-format (string): Set output format to 'table' (default) or 'json'.
#   --verbose (flag): Enable verbose output for debugging.
#   --help (flag): Display help message.
#   --menu (flag): Display interactive menu.
#
# Requirements:
#   - Must run on RHEL/Oracle Linux system (/etc/redhat-release required).
#   - Requires: ps, grep, awk commands.
#   - Requires loggy.sh in same directory (optional, has fallback).
#
# Examples:
#   ./findOracleDatabases.sh
#   ./findOracleDatabases.sh --output-format json
#   ./findOracleDatabases.sh --verbose --output-format table
#
# Copyright © 2025 SolidWorks Consulting LLC. All rights reserved.
###############################################################################

set -euo pipefail

# Source loggy if available
if [[ -f "${BASH_SOURCE%/*}/loggy.sh" ]]; then
    source "${BASH_SOURCE%/*}/loggy.sh"
else
    loggy() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] $*"; }
fi

# Global variables
GV_OUTPUT_FORMAT="${GV_OUTPUT_FORMAT:-table}"
GV_VERBOSE="${GV_VERBOSE:-false}"

findOracleDatabases() {
    loggy --type beginend --message "Starting [findOracleDatabases]"
    
    local l_exit_code=0
    
    case "${1:-}" in
        --help)
            _displayHelp
            return 0
            ;;
        --menu)
            _displayMenu
            return 0
            ;;
        --output-format)
            GV_OUTPUT_FORMAT="${2:-table}"
            ;;
        --verbose)
            GV_VERBOSE="true"
            ;;
    esac
    
    loggy --type debug --message "Calling [_validateEnvironment]" --quiet
    _validateEnvironment || { l_exit_code=$?; loggy --type error --message "Environment validation failed"; return "$l_exit_code"; }
    
    loggy --type debug --message "Calling [_findRunningDatabases]" --quiet
    _findRunningDatabases || { l_exit_code=$?; loggy --type error --message "Failed to find running databases"; return "$l_exit_code"; }
    
    loggy --type beginend --message "Completed [findOracleDatabases]"
    return 0
}

_displayHelp() {
    cat << 'EOF'
Usage: findOracleDatabases.sh [OPTIONS]

Identify all running Oracle databases on a RHEL server and display their Oracle Home directories.

OPTIONS:
  --help              Display this help message
  --menu              Display interactive menu
  --output-format     Set output format: table (default) or json
  --verbose           Enable verbose output for debugging

EXAMPLES:
  # Display running databases in table format
  ./findOracleDatabases.sh

  # Display in JSON format
  ./findOracleDatabases.sh --output-format json

  # Enable verbose output
  ./findOracleDatabases.sh --verbose

REQUIREMENTS:
  - Must run on RHEL/Oracle Linux server
  - Requires ps command to list processes
  - Works with Oracle 11g and later

EXIT CODES:
  0 - Success
  1 - Environment validation failed
  2 - No running databases found
EOF
}

_displayMenu() {
    echo ""
    echo "=== Oracle Database Discovery Menu ==="
    echo ""
    echo "1) List running databases (default)"
    echo "2) Display as JSON"
    echo "3) Enable verbose output"
    echo "4) Exit"
    echo ""
    echo "Note: This script runs with default options."
    echo "Use command-line flags for automation."
    echo ""
}

_validateEnvironment() {
    loggy --type debug --message "Calling [_validateEnvironment]"
    
    # Check if running on RHEL/Oracle Linux
    if [[ ! -f /etc/redhat-release ]]; then
        loggy --type error --message "This script requires a RHEL/Oracle Linux system"
        return 1
    fi
    
    # Check required commands
    for l_cmd in ps grep awk; do
        if ! command -v "$l_cmd" &> /dev/null; then
            loggy --type error --message "Required command not found: $l_cmd"
            return 1
        fi
    done
    
    return 0
}

_findRunningDatabases() {
    loggy --type debug --message "Calling [_findRunningDatabases]"
    
    local l_databases=()
    local l_pmon_processes
    
    # Find all pmon (Process Monitor) processes which indicate running Oracle instances
    l_pmon_processes=$(ps aux 2>/dev/null | grep -E "ora_pmon_|/sbin/init.ora" | grep -v grep || true)
    
    if [[ -z "$l_pmon_processes" ]]; then
        loggy --type error --message "No running Oracle databases found"
        return 2
    fi
    
    # Extract database names and find Oracle Home
    while IFS= read -r l_line; do
        local l_db_name
        local l_oracle_home
        local l_oracle_user
        local l_oracle_pid
        
        # Extract database name from pmon process
        if [[ "$l_line" =~ ora_pmon_([a-zA-Z0-9_]+) ]]; then
            l_db_name="${BASH_REMATCH[1]}"
            
            # Get process details
            l_oracle_pid=$(echo "$l_line" | awk '{print $2}')
            l_oracle_user=$(echo "$l_line" | awk '{print $1}')
            
            # Find Oracle Home from process environment or oratab
            l_oracle_home=$(_getOracleHome "$l_db_name" "$l_oracle_pid" "$l_oracle_user")
            
            # Store database info
            l_databases+=("${l_db_name}|${l_oracle_home}|${l_oracle_user}|${l_oracle_pid}")
            
            if [[ "$GV_VERBOSE" == "true" ]]; then
                loggy --type variable --message "Found database: $l_db_name at $l_oracle_home"
            fi
        fi
    done <<< "$l_pmon_processes"
    
    # Display results
    if [[ "$GV_OUTPUT_FORMAT" == "json" ]]; then
        _displayAsJson "${l_databases[@]}"
    else
        _displayAsTable "${l_databases[@]}"
    fi
    
    return 0
}

_getOracleHome() {
    local l_db_name="$1"
    local l_pid="$2"
    local l_user="$3"
    local l_oracle_home=""
    
    # Try to get ORACLE_HOME from /proc/[pid]/environ
    if [[ -f "/proc/${l_pid}/environ" ]]; then
        l_oracle_home=$(grep -ao "ORACLE_HOME=[^:]*" "/proc/${l_pid}/environ" 2>/dev/null | cut -d= -f2 || true)
    fi
    
    # Fallback: Check /etc/oratab
    if [[ -z "$l_oracle_home" && -f /etc/oratab ]]; then
        l_oracle_home=$(grep "^${l_db_name}:" /etc/oratab 2>/dev/null | cut -d: -f2 || true)
    fi
    
    # Fallback: Common Oracle Home locations
    if [[ -z "$l_oracle_home" ]]; then
        for l_path in /u01/app/oracle/product/* /opt/oracle/product/*; do
            if [[ -d "$l_path" && -x "$l_path/bin/sqlplus" ]]; then
                l_oracle_home="$l_path"
                break
            fi
        done
    fi
    
    echo "${l_oracle_home:-UNKNOWN}"
}

_displayAsTable() {
    echo ""
    echo "=========================================="
    echo "Oracle Databases Running on $(hostname)"
    echo "=========================================="
    printf "%-20s %-50s %-15s %-8s\n" "DATABASE" "ORACLE_HOME" "USER" "PID"
    echo "------------------------------------------"
    
    for l_entry in "$@"; do
        IFS='|' read -r l_db l_home l_user l_pid <<< "$l_entry"
        printf "%-20s %-50s %-15s %-8s\n" "$l_db" "$l_home" "$l_user" "$l_pid"
    done
    
    echo "=========================================="
    echo ""
}

_displayAsJson() {
    echo "["
    
    local l_first=true
    for l_entry in "$@"; do
        IFS='|' read -r l_db l_home l_user l_pid <<< "$l_entry"
        
        if [[ "$l_first" == false ]]; then
            echo ","
        fi
        
        cat << EOF
  {
    "database": "$l_db",
    "oracle_home": "$l_home",
    "oracle_user": "$l_user",
    "pid": $l_pid,
    "hostname": "$(hostname)",
    "timestamp": "$(date -u +'%Y-%m-%dT%H:%M:%SZ')"
  }
EOF
        l_first=false
    done
    
    echo ""
    echo "]"
}

# Run main function
findOracleDatabases "$@"
exit $?
