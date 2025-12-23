#!/bin/bash

###############################################################################
# Script: relocateRacOneNode.sh
#
# Description: Relocate an Oracle RAC One Node database from its current node
# to another available node within the RAC cluster pool. Includes pre-relocation
# checks, graceful shutdown, relocation, and post-relocation validation.
#
# Input Parameters:
#   --database (string): Oracle database name (SID). Required.
#   --target-node (string): Target cluster node name. Optional; if not provided, auto-selects from candidate servers.
#   --allow-downtime (flag): Allow service downtime during relocation.
#   --force (flag): Skip confirmation prompts and force relocation.
#   --verbose (flag): Enable verbose debug output.
#   --dry-run (flag): Show what would be done without making changes.
#   --help (flag): Display help message.
#
# Requirements:
#   - Execute as: oracle user
#   - Requires: crsctl, srvctl, sqlplus, grep, awk, sed commands.
#   - Requires loggy.sh in same directory (optional).
#   - Oracle Grid Infrastructure must be installed and running.
#   - Database must be a RAC One Node configuration.
#   - Oracle user must have proper environment variables (ORACLE_HOME, ORACLE_BASE).
#   - Requires sudo for: cluster resource verification (crsctl check cluster).
#
# Examples:
#   ./relocateRacOneNode.sh --database MYDB --target-node node2
#   ./relocateRacOneNode.sh --database MYDB (auto-select target node)
#   ./relocateRacOneNode.sh --database MYDB --allow-downtime --verbose
#   ./relocateRacOneNode.sh --database MYDB --dry-run
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
GV_RACONE_DATABASE=""
GV_RACONE_TARGET_NODE=""
GV_RACONE_ALLOW_DOWNTIME=false
GV_RACONE_FORCE=false
GV_RACONE_VERBOSE=false
GV_RACONE_DRY_RUN=false
GV_RACONE_CURRENT_NODE=""
GV_RACONE_AVAILABLE_NODES=()

###############################################################################
# Execute command with sudo if necessary
###############################################################################
_executeSudo() {
    loggy --type debug --message "Calling [_executeSudo]" --quiet
    
    local l_description="$1"
    shift
    
    # Check if already running as root
    if [[ "$EUID" -eq 0 ]]; then
        "$@"
        return $?
    fi
    
    # Try to execute with sudo
    if sudo -v &> /dev/null; then
        sudo "$@"
        return $?
    else
        loggy --type info --message "$l_description requires sudo privileges"
        sudo "$@"
        return $?
    fi
}

###############################################################################
# Display usage information
###############################################################################
_showUsage() {
    cat << 'EOF'
Usage: relocateRacOneNode.sh [OPTIONS]

Relocate an Oracle RAC One Node database to another cluster node.

OPTIONS:
  --database NAME        Name of the RAC One Node database to relocate. Required.
  --target-node NODE     Target cluster node name. Optional; if not provided, auto-selected.
  --allow-downtime       Allow service downtime during relocation.
  --force                Skip confirmation prompts and proceed with relocation.
  --verbose              Enable verbose debug output.
  --dry-run              Show what would be done without making changes.
  --help                 Display this help message.

EXAMPLES:
  # Relocate MYDB to explicit node2 with confirmation
  ./relocateRacOneNode.sh --database MYDB --target-node node2

  # Auto-select target node from candidate servers
  ./relocateRacOneNode.sh --database MYDB

  # Relocate with downtime allowed and skip confirmation
  ./relocateRacOneNode.sh --database MYDB --allow-downtime --force

  # Preview relocation without making changes
  ./relocateRacOneNode.sh --database MYDB --dry-run --verbose

NOTES:
  - Run as oracle user for database operations.
  - srvctl commands execute directly without sudo (oracle user has permissions).
  - Cluster verification (crsctl) may require sudo for privilege escalation.
  - Requires Grid Infrastructure and RAC One Node configuration.
  - Database should be tested on target node before relocation in production.
EOF
}

###############################################################################
# Parse command-line parameters
###############################################################################
_parseParameters() {
    loggy --type debug --message "Calling [_parseParameters]" --quiet
    
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --database)
                if [[ -z "${2:-}" ]]; then
                    loggy --type error --message "Missing value for --database parameter"
                    _showUsage
                    exit 1
                fi
                GV_RACONE_DATABASE="${2}"
                shift 2
                ;;
            --target-node)
                if [[ -z "${2:-}" ]]; then
                    loggy --type error --message "Missing value for --target-node parameter"
                    _showUsage
                    exit 1
                fi
                GV_RACONE_TARGET_NODE="${2}"
                shift 2
                ;;
            --allow-downtime)
                GV_RACONE_ALLOW_DOWNTIME=true
                shift
                ;;
            --force)
                GV_RACONE_FORCE=true
                shift
                ;;
            --verbose)
                GV_RACONE_VERBOSE=true
                shift
                ;;
            --dry-run)
                GV_RACONE_DRY_RUN=true
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
    
    # Validate required parameters
    if [[ -z "$GV_RACONE_DATABASE" ]]; then
        loggy --type error --message "Missing required parameter: --database"
        _showUsage
        exit 1
    fi
}

###############################################################################
# Verify script prerequisites
###############################################################################
_validateEnvironment() {
    loggy --type debug --message "Calling [_validateEnvironment]" --quiet
    
    # Check if running as oracle user
    if [[ "$(whoami)" != "oracle" ]]; then
        loggy --type warning --message "Script is running as $(whoami), not oracle user. Grid operations may be limited."
    fi
    
    # Verify required commands exist
    local l_required_commands=("crsctl" "srvctl" "sqlplus" "grep" "awk" "sed")
    for l_cmd in "${l_required_commands[@]}"; do
        if ! command -v "$l_cmd" &> /dev/null; then
            loggy --type error --message "Required command not found: $l_cmd"
            exit 1
        fi
    done
    
    # Check if Grid Infrastructure is running
    if ! _executeSudo "Checking Grid Infrastructure status" crsctl check cluster -verbose &> /dev/null; then
        loggy --type error --message "Grid Infrastructure is not running or not accessible"
        exit 1
    fi
    
    loggy --type info --message "Environment validation successful"
}

###############################################################################
# Validate database is RAC One Node type
###############################################################################
_validateDatabaseType() {
    loggy --type debug --message "Calling [_validateDatabaseType]" --quiet
    
    local l_config_output
    local l_database_type
    
    l_config_output=$(srvctl config database -d "$GV_RACONE_DATABASE" 2>&1)
    
    if [[ -z "$l_config_output" ]]; then
        loggy --type error --message "Could not retrieve database configuration for $GV_RACONE_DATABASE"
        return 1
    fi
    
    # Extract database type
    l_database_type=$(echo "$l_config_output" | grep -i "Database type:" | sed 's/.*Database type:\s*//I')
    
    if [[ -z "$l_database_type" ]]; then
        loggy --type error --message "Could not determine database type for $GV_RACONE_DATABASE"
        return 1
    fi
    
    if [[ "$l_database_type" != "RACONENODE" ]]; then
        loggy --type error --message "Database is not a RAC One Node database (type: $l_database_type)"
        loggy --type info --message "This script only supports RACONENODE database type"
        return 1
    fi
    
    loggy --type info --message "Database type validation successful (RACONENODE)"
    return 0
}

###############################################################################
_getCandidateServers() {
    loggy --type debug --message "Calling [_getCandidateServers]" --quiet
    
    local l_config_output
    local l_candidate_servers
    local l_server
    
    l_config_output=$(srvctl config database -d "$GV_RACONE_DATABASE" 2>&1)
    
    # Extract candidate servers or servers field
    l_candidate_servers=$(echo "$l_config_output" | grep -iE "(Candidate servers|Servers):" | sed 's/.*:\s*//' | tr ',' '\n' | xargs)
    
    if [[ -z "$l_candidate_servers" ]]; then
        loggy --type error --message "Could not determine candidate servers for database $GV_RACONE_DATABASE"
        return 1
    fi
    
    local l_server_array=()
    while IFS= read -r l_server; do
        if [[ -n "$l_server" ]]; then
            l_server_array+=("$l_server")
        fi
    done <<< "$(echo "$l_candidate_servers" | tr ' ' '\n')"
    
    if [[ "$GV_RACONE_VERBOSE" == true ]]; then
        loggy --type debug --message "Candidate servers: ${l_server_array[*]}"
    fi
    
    printf '%s\n' "${l_server_array[@]}"
    return 0
}

###############################################################################
# Auto-select target node from candidate servers (different from current)
###############################################################################
_autoSelectTargetNode() {
    loggy --type debug --message "Calling [_autoSelectTargetNode]" --quiet
  
    local l_candidates
    local l_candidate_array=()
    local l_candidate
    
    # Get candidate servers
    l_candidates=$(_getCandidateServers)
    
    if [[ -z "$l_candidates" ]]; then
        loggy --type error --message "No candidate servers found"
        loggy --type beginend --message "Completed [autoSelectTargetNode]"
        return 1
    fi
    
    # Parse candidates into array
    while IFS= read -r l_candidate; do
        if [[ -n "$l_candidate" ]] && [[ "$l_candidate" != "$GV_RACONE_CURRENT_NODE" ]]; then
            l_candidate_array+=("$l_candidate")
        fi
    done <<< "$l_candidates"
    
    if [[ "${#l_candidate_array[@]}" -eq 0 ]]; then
        loggy --type error --message "No alternate candidate servers available (all are current node or offline)"
        loggy --type beginend --message "Completed [autoSelectTargetNode]"
        return 1
    fi
    
    # Select first available alternate server
    GV_RACONE_TARGET_NODE="${l_candidate_array[0]}"
    loggy --type info --message "Auto-selected target node: $GV_RACONE_TARGET_NODE"
    
    loggy --type beginend --message "Completed [autoSelectTargetNode]"
    return 0
}

###############################################################################
# Get current node for a RAC One Node database
###############################################################################
_getCurrentNode() {
    loggy --type debug --message "Calling [_getCurrentNode]" --quiet
    
    local l_node
    
    l_node=$(srvctl status database -d "$GV_RACONE_DATABASE" 2>&1 | grep "is running on node" | awk '{print $NF}')
    
    if [[ -z "$l_node" ]]; then
        loggy --type error --message "Could not determine current node for database $GV_RACONE_DATABASE"
        return 1
    fi
    
    GV_RACONE_CURRENT_NODE="$l_node"
    loggy --type info --message "Database $GV_RACONE_DATABASE is currently running on node: $GV_RACONE_CURRENT_NODE"
    
    return 0
}

###############################################################################
# Validate target node is different from current node and in candidate servers
###############################################################################
_validateTargetNode() {
    loggy --type debug --message "Calling [_validateTargetNode]" --quiet
    
    local l_candidates
    local l_candidate_array=()
    local l_candidate
    local l_target_found=false
    
    if [[ "$GV_RACONE_TARGET_NODE" == "$GV_RACONE_CURRENT_NODE" ]]; then
        loggy --type error --message "Target node is the same as current node: $GV_RACONE_TARGET_NODE"
        return 1
    fi
    
    # Get candidate servers to validate target is available
    l_candidates=$(_getCandidateServers)
    
    if [[ -z "$l_candidates" ]]; then
        loggy --type error --message "Could not determine candidate servers for validation"
        return 1
    fi
    
    # Parse candidates into array
    while IFS= read -r l_candidate; do
        if [[ -n "$l_candidate" ]]; then
            l_candidate_array+=("$l_candidate")
            if [[ "$l_candidate" == "$GV_RACONE_TARGET_NODE" ]]; then
                l_target_found=true
            fi
        fi
    done <<< "$l_candidates"
    
    if [[ "$l_target_found" == false ]]; then
        loggy --type error --message "Target node '$GV_RACONE_TARGET_NODE' is not in candidate servers list"
        loggy --type info --message "Available candidate servers: ${l_candidate_array[*]}"
        return 1
    fi
    
    loggy --type info --message "Target node validation successful"
    return 0
}

###############################################################################
# Check database status
###############################################################################
_checkDatabaseStatus() {
    loggy --type debug --message "Calling [_checkDatabaseStatus]" --quiet
    
    local l_status
    
    l_status=$(srvctl status database -d "$GV_RACONE_DATABASE" 2>&1)
    
    if [[ "$l_status" == *"is not running"* ]]; then
        loggy --type error --message "Database is not running: $GV_RACONE_DATABASE"
        return 1
    fi
    
    if [[ "$GV_RACONE_VERBOSE" == true ]]; then
        loggy --type debug --message "Database status: $l_status"
    fi
    
    loggy --type info --message "Database status validation successful"
    return 0
}

###############################################################################
# Confirm relocation with user
###############################################################################
_confirmRelocation() {
    loggy --type debug --message "Calling [_confirmRelocation]" --quiet
    
    if [[ "$GV_RACONE_FORCE" == true ]]; then
        loggy --type info --message "Force flag set, skipping confirmation"
        return 0
    fi
    
    echo ""
    loggy --type info --message "=== Relocation Summary ==="
    loggy --type info --message "Database: $GV_RACONE_DATABASE"
    loggy --type info --message "Current Node: $GV_RACONE_CURRENT_NODE"
    loggy --type info --message "Target Node: $GV_RACONE_TARGET_NODE"
    loggy --type info --message "Allow Downtime: $GV_RACONE_ALLOW_DOWNTIME"
    echo ""
    
    read -p "Proceed with relocation? (yes/no): " l_response
    
    if [[ "$l_response" != "yes" ]]; then
        loggy --type info --message "Relocation cancelled by user"
        return 1
    fi
    
    return 0
}

###############################################################################
# Relocate database to target node
###############################################################################
_relocateDatabase() {
    loggy --type debug --message "Calling [_relocateDatabase]" --quiet
    loggy --type beginend --message "Starting [relocateDatabase]"
    
    local l_relocation_cmd
    
    if [[ "$GV_RACONE_DRY_RUN" == true ]]; then
        loggy --type info --message "DRY-RUN: Would execute relocation command"
        l_relocation_cmd="srvctl relocate database -d $GV_RACONE_DATABASE -n $GV_RACONE_TARGET_NODE"
        if [[ "$GV_RACONE_ALLOW_DOWNTIME" == true ]]; then
            l_relocation_cmd+=" -f"
        fi
        loggy --type info --message "Command: $l_relocation_cmd"
    else
        loggy --type info --message "Relocating database $GV_RACONE_DATABASE to node $GV_RACONE_TARGET_NODE..."
        
        if [[ "$GV_RACONE_ALLOW_DOWNTIME" == true ]]; then
            # Use force flag if downtime is allowed (graceful shutdown not required)
            if ! srvctl relocate database -d "$GV_RACONE_DATABASE" -n "$GV_RACONE_TARGET_NODE" -f; then
                loggy --type error --message "Database relocation failed"
                loggy --type beginend --message "Completed [relocateDatabase]"
                return 1
            fi
        else
            # Graceful relocation without force flag
            if ! srvctl relocate database -d "$GV_RACONE_DATABASE" -n "$GV_RACONE_TARGET_NODE"; then
                loggy --type error --message "Database relocation failed"
                loggy --type beginend --message "Completed [relocateDatabase]"
                return 1
            fi
        fi
        
        loggy --type info --message "Database relocation command executed successfully"
    fi
    
    loggy --type beginend --message "Completed [relocateDatabase]"
    return 0
}

###############################################################################
# Verify database is running on target node
###############################################################################
_verifyRelocation() {
    loggy --type debug --message "Calling [_verifyRelocation]" --quiet
    loggy --type beginend --message "Starting [verifyRelocation]"
    
    local l_retry_count=0
    local l_max_retries=30
    local l_retry_interval=10
    local l_current_node
    
    if [[ "$GV_RACONE_DRY_RUN" == true ]]; then
        loggy --type info --message "DRY-RUN: Would verify database on target node"
        loggy --type beginend --message "Completed [verifyRelocation]"
        return 0
    fi
    
    loggy --type info --message "Verifying database relocation (max ${l_max_retries} attempts, ${l_retry_interval}s interval)..."
    
    while [[ $l_retry_count -lt $l_max_retries ]]; do
        sleep "$l_retry_interval"
        
        l_current_node=$(srvctl status database -d "$GV_RACONE_DATABASE" 2>&1 | grep "is running on node" | awk '{print $NF}')
        
        if [[ "$l_current_node" == "$GV_RACONE_TARGET_NODE" ]]; then
            loggy --type info --message "Database successfully relocated to $GV_RACONE_TARGET_NODE"
            loggy --type beginend --message "Completed [verifyRelocation]"
            return 0
        fi
        
        ((l_retry_count++))
        if [[ "$GV_RACONE_VERBOSE" == true ]]; then
            loggy --type debug --message "Attempt $l_retry_count/$l_max_retries: Database still on $l_current_node, waiting..."
        fi
    done
    
    loggy --type error --message "Database relocation verification failed after $l_max_retries attempts"
    loggy --type info --message "Last known node: $l_current_node (expected: $GV_RACONE_TARGET_NODE)"
    loggy --type beginend --message "Completed [verifyRelocation]"
    return 1
}

###############################################################################
# Main function
###############################################################################
main() {
    loggy --type beginend --message "Starting [main]"
    
    _parseParameters "$@"
    _validateEnvironment
    
    loggy --type info --message "======================================="
    loggy --type info --message "RAC One Node Relocation Script"
    loggy --type info --message "========================================"
    
    # Get current database node
    if ! _getCurrentNode; then
        loggy --type error --message "Failed to determine current database node"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Validate database type is RACONENODE
    if ! _validateDatabaseType; then
        loggy --type error --message "Database type validation failed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Auto-select target node if not provided
    if [[ -z "$GV_RACONE_TARGET_NODE" ]]; then
        loggy --type info --message "Target node not specified, auto-selecting from candidate servers..."
        if ! _autoSelectTargetNode; then
            loggy --type error --message "Failed to auto-select target node"
            loggy --type beginend --message "Completed [main]"
            exit 1
        fi
    fi
    
    # Validate target node
    if ! _validateTargetNode; then
        loggy --type error --message "Target node validation failed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Check database status
    if ! _checkDatabaseStatus; then
        loggy --type error --message "Database status check failed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Confirm relocation
    if ! _confirmRelocation; then
        loggy --type error --message "Relocation not confirmed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Execute relocation
    if ! _relocateDatabase; then
        loggy --type error --message "Database relocation execution failed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    # Verify relocation
    if ! _verifyRelocation; then
        loggy --type error --message "Database relocation verification failed"
        loggy --type beginend --message "Completed [main]"
        exit 1
    fi
    
    loggy --type info --message "========================================"
    loggy --type info --message "RAC One Node Relocation Completed Successfully"
    loggy --type info --message "========================================"
    
    loggy --type beginend --message "Completed [main]"
}

# Run main function with all arguments
main "$@"
