#!/bin/bash
###############################################################################
# Script: ssh.sh
#
# Description: Remote SSH command execution utility with support for both password and key-based authentication, configurable timeout, and flexible parameter precedence.
#
# Input Parameters:
#   --username (string): Remote server username (required).
#   --hostname (string): Remote server hostname or IP address (required).
#   --command (string): Command to execute on remote server (required).
#   --password (string): Password for authentication (optional, requires sshpass).
#   --keyfile (string): Path to SSH private key file (optional, default: ~/.ssh/id_rsa).
#   --port (string): SSH port (optional, default: GV_SSH_PORT or 22).
#   --timeout (string): Command timeout in seconds (optional, default: GV_SSH_TIMEOUT or 300).
#   --help (flag): Display help message.
#   --menu (flag): Show interactive menu.
#
# Requirements:
#   - Bash shell environment.
#   - Requires: ssh, ssh-keygen commands.
#   - Optional: sshpass for password-based authentication.
#   - Requires loggy.sh in same directory.
#
# Examples:
#   runSshCommand --username admin --hostname 192.168.1.10 --command "uptime" --keyfile ~/.ssh/server_key
#   runSshCommand --username root --hostname example.com --command "df -h" --password "secret123"
#   GV_SSH_KEYFILE="/home/user/.ssh/prod_key"; runSshCommand --username deploy --hostname prod.server.com --command "systemctl status nginx"
#
# Copyright © 2025 SolidWorks Consulting LLC. All rights reserved.
###############################################################################

set -euo pipefail

# Source loggy if not already sourced
if ! type loggy &>/dev/null; then
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${SCRIPT_DIR}/loggy.sh" ]]; then
        source "${SCRIPT_DIR}/loggy.sh"
    else
        echo "ERROR: loggy.sh not found in $SCRIPT_DIR" >&2
        exit 1
    fi
fi

# Source constants file if it exists
if [[ -f "${SCRIPT_DIR}/constants.sh" ]]; then
    source "${SCRIPT_DIR}/constants.sh"
fi

# Global variable defaults (override before calling runSshCommand)
# These can be set via:
#   1. Runtime named parameters (--port, --timeout, --keyfile, --password)
#   2. Global variables (GV_SSH_PORT, GV_SSH_TIMEOUT, GV_SSH_KEYFILE, GV_SSH_PASSWORD)
#   3. Constants file (constants.sh)
#   4. Explicit defaults below (lowest priority)
GV_SSH_PORT="${GV_SSH_PORT:-22}"
GV_SSH_TIMEOUT="${GV_SSH_TIMEOUT:-300}"
GV_SSH_KEYFILE="${GV_SSH_KEYFILE:-}"
GV_SSH_PASSWORD="${GV_SSH_PASSWORD:-}"

runSshCommand() {
    
    loggy --type beginend --message "Starting [runSshCommand]"
    
    ############################################################################
    # Subfunction: _showHelp
    # Display command usage and detailed help information
    ############################################################################
    _showHelp() {
        loggy --type debug --message "Calling [_showHelp]" --quiet
        cat << 'EOF'
runSshCommand - Remote SSH Command Execution Utility

Usage: runSshCommand [OPTIONS]

REQUIRED NAMED PARAMETERS:
    --username USER     Remote server username
    --hostname HOST     Remote server hostname or IP address
    --command CMD       Command to execute on remote server

AUTHENTICATION (one required):
    --password PASS     Password for authentication
                        Note: sshpass must be installed
                        Defaults: GV_SSH_PASSWORD → (no default)
    
    --keyfile FILE      Path to SSH private key file
                        Defaults: GV_SSH_KEYFILE → ~/.ssh/id_rsa

OPTIONAL PARAMETERS:
    --port PORT         SSH port
                        Defaults: Runtime → GV_SSH_PORT → Constants → 22
    
    --timeout SECS      Command timeout in seconds
                        Defaults: Runtime → GV_SSH_TIMEOUT → Constants → 300
    
    --help              Display this help message
    
    --menu              Show interactive menu

PARAMETER PRECEDENCE (highest to lowest priority):
    1. Runtime named parameters (--port 2222)
    2. Global variables (GV_SSH_PORT="2222")
    3. Constants file values (constants.sh)
    4. Explicit defaults (22)

GLOBAL VARIABLES:
    GV_SSH_PORT         Default SSH port (default: 22)
    GV_SSH_TIMEOUT      Default command timeout (default: 300)
    GV_SSH_KEYFILE      Default key file path (default: empty)
    GV_SSH_PASSWORD     Default password (default: empty)

EXAMPLES:
    # Using SSH key at runtime (highest priority)
    runSshCommand --username admin --hostname 192.168.1.10 \
                  --command "uptime" --keyfile ~/.ssh/server_key
    
    # Using password
    runSshCommand --username root --hostname example.com \
                  --command "df -h" --password "secret123"
    
    # Using global variables (2nd priority)
    GV_SSH_KEYFILE="/home/user/.ssh/prod_key"
    GV_SSH_PORT="2222"
    runSshCommand --username deploy --hostname prod.server.com \
                  --command "systemctl status nginx"
    
    # Using constants file + global variables
    source ./constants.sh  # Sets SSH defaults
    runSshCommand --username deploy --hostname prod.server.com \
                  --command "systemctl status nginx"
    
    # Override any defaults at runtime
    runSshCommand --username deploy --hostname prod.server.com \
                  --command "whoami" --port 2222  # Overrides all defaults
    
    # Interactive menu
    runSshCommand --menu

AUTHENTICATION NOTES:
    - Password authentication requires sshpass: sudo apt install sshpass
    - Key-based authentication is more secure
    - If neither --password nor --keyfile provided, uses default SSH key
    - Command output is returned and logged

LOGGING:
    - Connection failures are logged as ERROR
    - Command failures are logged as FAIL
    - Successful execution is logged as SUCCESS
    - Use --level debug with loggy for detailed logging
EOF
    }
    
    ############################################################################
    # Subfunction: _showMenu
    # Display interactive menu for parameter entry
    ############################################################################
    _showMenu() {
        loggy --type debug --message "Calling [_showMenu]" --quiet
        local l_username=""
        local l_hostname=""
        local l_command=""
        local l_password=""
        local l_keyfile=""
        local l_port="${GV_SSH_PORT}"
        local l_timeout="${GV_SSH_TIMEOUT}"
        local l_authType=""
        
        echo ""
        echo "========================================"
        echo "  SSH Command Execution - Interactive"
        echo "========================================"
        echo ""
        
        # Get required parameters
        read -p "Enter username: " l_username
        read -p "Enter hostname/IP: " l_hostname
        read -p "Enter command to execute: " l_command
        
        # Get authentication method
        echo ""
        echo "Authentication method:"
        echo "  1) SSH Key (recommended)"
        echo "  2) Password"
        echo ""
        read -p "Select authentication (1 or 2): " l_authType
        
        if [[ "$l_authType" == "2" ]]; then
            read -sp "Enter password: " l_password
            echo ""
        else
            read -p "Enter key file path (default: ~/.ssh/id_rsa): " l_keyfile
            [[ -z "$l_keyfile" ]] && l_keyfile="~/.ssh/id_rsa"
        fi
        
        # Get optional parameters
        read -p "Enter SSH port (default: ${GV_SSH_PORT}): " l_port
        [[ -z "$l_port" ]] && l_port="${GV_SSH_PORT}"
        
        read -p "Enter timeout in seconds (default: ${GV_SSH_TIMEOUT}): " l_timeout
        [[ -z "$l_timeout" ]] && l_timeout="${GV_SSH_TIMEOUT}"
        
        echo ""
        echo "========== Connection Summary =========="
        echo "  Username: $l_username"
        echo "  Hostname: $l_hostname"
        echo "  Port:     $l_port"
        echo "  Command:  $l_command"
        echo "  Timeout:  ${l_timeout}s"
        if [[ -n "$l_keyfile" ]]; then
            echo "  Auth:     Key file ($l_keyfile)"
        else
            echo "  Auth:     Password"
        fi
        echo "========================================"
        echo ""
        
        # Execute SSH command recursively
        if [[ -n "$l_keyfile" ]]; then
            runSshCommand --username "$l_username" --hostname "$l_hostname" \
                          --command "$l_command" --keyfile "$l_keyfile" \
                          --port "$l_port" --timeout "$l_timeout"
        else
            runSshCommand --username "$l_username" --hostname "$l_hostname" \
                          --command "$l_command" --password "$l_password" \
                          --port "$l_port" --timeout "$l_timeout"
        fi
    }
    
    ############################################################################
    # Subfunction: _assertRequiredParameters
    # Assert that all required parameters are provided
    # Returns: 0 if valid, 1 if missing
    ############################################################################
    _assertRequiredParameters() {
        loggy --type debug --message "Calling [_assertRequiredParameters]"
        if [[ -z "$1" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --username not provided"
            return 1
        fi
        if [[ -z "$2" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --hostname not provided"
            return 1
        fi
        if [[ -z "$3" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --command not provided"
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _assertAuthenticationProvided
    # Assert that either password or keyfile is provided
    # Returns: 0 if valid, 1 if missing
    ############################################################################
    _assertAuthenticationProvided() {
        loggy --type debug --message "Calling [_assertAuthenticationProvided]"
        if [[ -z "$1" && -z "$2" ]]; then
            loggy --type error --message "Assertion failed - Either --password or --keyfile must be provided"
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _validateKeyfile
    # Validate that keyfile exists and is readable
    # Returns: 0 if valid, 1 if invalid
    ############################################################################
    _validateKeyfile() {
        loggy --type debug --message "Calling [_validateKeyfile]"
        local l_keyfile="$1"
        
        # Expand ~ to home directory
        l_keyfile="${l_keyfile/#\~/$HOME}"
        
        if [[ ! -f "$l_keyfile" ]]; then
            loggy --type fail --message "SSH key file not found: $l_keyfile"
            return 1
        fi
        
        if [[ ! -r "$l_keyfile" ]]; then
            loggy --type fail --message "SSH key file not readable: $l_keyfile"
            return 1
        fi
        
        return 0
    }
    
    ############################################################################
    # Subfunction: _executeSshCommand
    # Execute command on remote server and capture output
    # Returns: 0 on success, 2 on connection error, 3 on timeout
    ############################################################################
    _executeSshCommand() {
        loggy --type debug --message "Calling [_executeSshCommand]"
        local l_username="$1"
        local l_hostname="$2"
        local l_command="$3"
        local l_password="$4"
        local l_keyfile="$5"
        local l_port="$6"
        local l_timeout="$7"
        local l_output=""
        local l_exitCode=0
        
        loggy --type beginend --message "Starting [_executeSshCommand] $l_username@$l_hostname:$l_port"
        loggy --type command --message "Remote command: $l_command"
        
        # Expand tilde in keyfile path
        if [[ -n "$l_keyfile" ]]; then
            l_keyfile="${l_keyfile/#\~/$HOME}"
        fi
        
        # Execute SSH command based on authentication method
        if [[ -n "$l_password" ]]; then
            # Password-based authentication
            loggy --type variable --message "Authentication method: password"
            
            # Check if sshpass is available
            if ! command -v sshpass &>/dev/null; then
                loggy --type error --message "sshpass not found. Install with: sudo apt install sshpass"
                return 2
            fi
            
            l_output=$(sshpass -p "$l_password" timeout "$l_timeout" \
                       ssh -o StrictHostKeyChecking=no \
                           -o UserKnownHostsFile=/dev/null \
                           -p "$l_port" \
                           "${l_username}@${l_hostname}" \
                           "$l_command" 2>&1) || l_exitCode=$?
        else
            # Key-based authentication
            loggy --type variable --message "Authentication method: SSH key ($l_keyfile)"
            
            l_output=$(timeout "$l_timeout" \
                       ssh -i "$l_keyfile" \
                           -o StrictHostKeyChecking=no \
                           -o UserKnownHostsFile=/dev/null \
                           -p "$l_port" \
                           "${l_username}@${l_hostname}" \
                           "$l_command" 2>&1) || l_exitCode=$?
        fi
        
        # Handle timeout
        if [[ $l_exitCode -eq 124 ]]; then
            loggy --type error --message "Command execution timeout after ${l_timeout}s on $l_hostname"
            return 3
        fi
        
        # Handle SSH/command errors
        if [[ $l_exitCode -ne 0 ]]; then
            loggy --type fail --message "SSH command failed with exit code $l_exitCode on $l_hostname"
            loggy --type output --message "Error output: $l_output"
            return 2
        fi
        
        # Log success
        loggy --type success --message "SSH command executed successfully on $l_hostname"
        loggy --type output --message "Command output: $l_output"
        loggy --type beginend --message "SSH command execution completed"
        
        # Return output to stdout
        echo "$l_output"
        return 0
    }
    
    ############################################################################
    # Main logic of runSshCommand function
    ############################################################################
    
    local l_username=""
    local l_hostname=""
    local l_command=""
    local l_password=""
    local l_keyfile=""
    local l_port=""
    local l_timeout=""
    
    # Parse named parameters
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --username)
                l_username="$2"
                shift 2
                ;;
            --hostname)
                l_hostname="$2"
                shift 2
                ;;
            --command)
                l_command="$2"
                shift 2
                ;;
            --password)
                l_password="$2"
                shift 2
                ;;
            --keyfile)
                l_keyfile="$2"
                shift 2
                ;;
            --port)
                l_port="$2"
                shift 2
                ;;
            --timeout)
                l_timeout="$2"
                shift 2
                ;;
            --help)
                _showHelp
                return 0
                ;;
            --menu)
                _showMenu
                return 0
                ;;
            *)
                loggy --type error --message "Unknown parameter: $1"
                _showHelp >&2
                loggy --type beginend --message "Completed [runSshCommand]" --quiet
                return 1
                ;;
        esac
    done
    
    # Set defaults for optional parameters from global variables
    l_port="${l_port:-$GV_SSH_PORT}"
    l_timeout="${l_timeout:-$GV_SSH_TIMEOUT}"
    l_keyfile="${l_keyfile:-$GV_SSH_KEYFILE}"
    l_password="${l_password:-$GV_SSH_PASSWORD}"
    
    # Validate required parameters
    if ! _assertRequiredParameters "$l_username" "$l_hostname" "$l_command"; then
        loggy --type beginend --message "Completed [runSshCommand]"
        return 1
    fi
    
    # Validate authentication
    if ! _assertAuthenticationProvided "$l_password" "$l_keyfile"; then
        loggy --type beginend --message "Completed [runSshCommand]"
        return 1
    fi
    
    # Validate keyfile if provided
    if [[ -n "$l_keyfile" ]]; then
        if ! _validateKeyfile "$l_keyfile"; then
            loggy --type beginend --message "Completed [runSshCommand]"
            return 1
        fi
    fi
    
    # Execute the remote command
    if ! _executeSshCommand "$l_username" "$l_hostname" "$l_command" "$l_password" "$l_keyfile" "$l_port" "$l_timeout"; then
        local l_exitCode=$?
        loggy --type beginend --message "Completed [runSshCommand]"
        return $l_exitCode
    fi
    
    loggy --type beginend --message "Completed [runSshCommand]"
    return 0
}

################################################################################
# Function Export & Main Execution
################################################################################

# Export only the parent function
export -f runSshCommand

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    runSshCommand "$@"
fi
