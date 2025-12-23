#!/bin/bash
###############################################################################
# Script: loggy.sh
#
# Description: Flexible logging utility providing categorized message output with optional file persistence and log level filtering.
#
# Input Parameters:
#   --type (string): Message type - error, fail, success, output, beginend, variable, command, or debug (required).
#   --message (string): Message text to log (required).
#   --file (string): File path to append log output (optional, uses GV_LOGFILE if not specified).
#   --level (string): Log level filter - shows this level and higher priority levels (optional, default: 'output').
#   --quiet (flag): Suppress screen output while preserving file output (optional).
#   --help (flag): Display help message.
#   --menu (flag): Show interactive menu for parameter entry.
#
# Requirements:
#   - Bash shell environment.
#   - Standard utilities: date, mkdir, echo, read.
#   - POSIX-compliant for portability.
#
# Examples:
#   loggy --type error --message "Database connection failed"
#   GV_LOGFILE="/var/log/app.log"; loggy --type success --message "Backup completed"
#   loggy --type debug --message "Variable X=42" --file /tmp/debug.log --level debug
#
# Copyright © 2025 SolidWorks Consulting LLC. All rights reserved.
###############################################################################

set -euo pipefail

# ANSI color codes
readonly RED_BRIGHT='\033[1;31m'
readonly GREEN_BRIGHT='\033[1;32m'
readonly RESET='\033[0m'

# Global variable defaults (override before calling loggy)
GV_LOGFILE=""
GV_LOGLEVEL="output"

# Log level mapping (numeric value indicates priority)
declare -A LOG_LEVELS=(
    [error]=1
    [fail]=2
    [success]=3
    [output]=4
    [beginend]=5
    [variable]=6
    [command]=7
    [debug]=8
)

loggy() {
    ############################################################################
    # Subfunction: _showHelp
    # Display command usage and detailed help information
    ############################################################################
    _showHelp() {
        loggy --type debug --message "Calling [_showHelp]" --quiet 2>/dev/null || true
        cat << 'EOF'
loggy - Flexible Logging Utility with Named Parameters

Usage: loggy [OPTIONS]

NAMED PARAMETERS:
    --type TYPE         Message type (required):
                          error    - System/function call errors
                          fail     - Process failures
                          success  - Successful completion
                          output   - Process output data
                          beginend - Function start/end markers
                          variable - Variable assignments
                          command  - Command execution
                          debug    - Debug information
    
    --message MESSAGE   Message text to log (required)
    
    --file FILE         File path to append log output (optional)
                        Defaults to GV_LOGFILE global variable if not specified
                        If GV_LOGFILE is empty, logs to screen only
    
    --level LEVEL       Log level filter (optional)
                        Defaults to GV_LOGLEVEL global variable
                        Default value: "output"
                        Shows this level and all higher priority levels
    
    --quiet             Suppress screen output for this message (optional)
                        Message will still be written to file if --file specified
    
    --help              Display this help message
    
    --menu              Show interactive menu

GLOBAL VARIABLES:
    GV_LOGFILE          Set default log file path (can be empty)
    GV_LOGLEVEL         Set default log level (default: "output")

LOG LEVEL PRIORITY (1=critical, 8=verbose):
    1 - error      System/function errors (BRIGHT RED)
    2 - fail       Process failures (BRIGHT RED)
    3 - success    Successful completion (BRIGHT GREEN)
    4 - output     Process output ◄── DEFAULT FILTER
    5 - beginend   Function markers
    6 - variable   Variable values
    7 - command    Command execution
    8 - debug      Detailed debug info

EXAMPLES:
    # Basic usage
    loggy --type error --message "Database connection failed"
    
    # With file logging via global variable
    GV_LOGFILE="/var/log/app.log"
    loggy --type success --message "Backup completed"
    
    # Override global file setting
    loggy --type debug --message "Variable X=42" --file /tmp/debug.log
    
    # Custom log level
    loggy --type debug --message "Debug info" --level debug
    
    # Interactive menu
    loggy --menu
EOF
    }
    
    ############################################################################
    # Subfunction: _showMenu
    # Display interactive menu for parameter entry
    ############################################################################
    _showMenu() {
        loggy --type debug --message "Calling [_showMenu]" --quiet 2>/dev/null || true
        local l_type=""
        local l_message=""
        local l_file="${GV_LOGFILE}"
        local l_level="${GV_LOGLEVEL}"
        
        echo ""
        echo "========================================"
        echo "  Loggy - Interactive Logging Menu"
        echo "========================================"
        echo ""
        
        # Get message type
        echo "Available message types:"
        echo "  1) error    - System/function call errors"
        echo "  2) fail     - Process failures"
        echo "  3) success  - Successful completion"
        echo "  4) output   - Process output data"
        echo "  5) beginend - Function start/end"
        echo "  6) variable - Variable assignments"
        echo "  7) command  - Command execution"
        echo "  8) debug    - Debug information"
        echo ""
        
        read -p "Select message type (1-8 or name): " l_type
        case "$l_type" in
            1|error)     l_type="error" ;;
            2|fail)      l_type="fail" ;;
            3|success)   l_type="success" ;;
            4|output)    l_type="output" ;;
            5|beginend)  l_type="beginend" ;;
            6|variable)  l_type="variable" ;;
            7|command)   l_type="command" ;;
            8|debug)     l_type="debug" ;;
            *)           l_type="$l_type" ;;
        esac
        
        # Get message content
        read -p "Enter message text: " l_message
        
        # Get optional file path
        read -p "Enter file path (press Enter to use default or skip): " l_file
        [[ -z "$l_file" ]] && l_file="${GV_LOGFILE}"
        
        # Get optional log level
        read -p "Enter log level filter (press Enter to use default: ${GV_LOGLEVEL}): " l_level
        [[ -z "$l_level" ]] && l_level="${GV_LOGLEVEL}"
        
        echo ""
        echo "Logging with parameters:"
        echo "  Type:    $l_type"
        echo "  Message: $l_message"
        [[ -n "$l_file" ]] && echo "  File:    $l_file"
        echo "  Level:   $l_level"
        echo ""
        
        # Execute logging recursively
        if [[ -n "$l_file" ]]; then
            loggy --type "$l_type" --message "$l_message" --file "$l_file" --level "$l_level"
        else
            loggy --type "$l_type" --message "$l_message" --level "$l_level"
        fi
    }
    
    ############################################################################
    # Subfunction: _assertTypeProvided
    # Assert that --type parameter was provided and not empty
    # Returns: 0 if provided, 1 if missing
    ############################################################################
    _assertTypeProvided() {
        loggy --type debug --message "Calling [_assertTypeProvided]" 2>/dev/null || true
        if [[ -z "$1" ]]; then
            echo "ERROR: Assertion failed - Required parameter --type not provided" >&2
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _assertMessageProvided
    # Assert that --message parameter was provided and not empty
    # Returns: 0 if provided, 1 if missing
    ############################################################################
    _assertMessageProvided() {
        loggy --type debug --message "Calling [_assertMessageProvided]" 2>/dev/null || true
        if [[ -z "$1" ]]; then
            echo "ERROR: Assertion failed - Required parameter --message not provided" >&2
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _validateType
    # Check if log type is valid
    # Returns: 0 if valid, 1 if invalid
    ############################################################################
    _validateType() {
        loggy --type debug --message "Calling [_validateType]" 2>/dev/null || true
        local l_type="$1"
        if [[ ! -v LOG_LEVELS[$l_type] ]]; then
            echo "Error: Invalid log type '$l_type'" >&2
            echo "Valid types: error, fail, success, output, beginend, variable, command, debug" >&2
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _validateLogLevel
    # Check if log level is valid
    # Returns: 0 if valid, 1 if invalid
    ############################################################################
    _validateLogLevel() {
        loggy --type debug --message "Calling [_validateLogLevel]" 2>/dev/null || true
        local l_level="$1"
        if [[ ! -v LOG_LEVELS[$l_level] ]]; then
            echo "Error: Invalid log level '$l_level'" >&2
            echo "Valid levels: error, fail, success, output, beginend, variable, command, debug" >&2
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _getColorCode
    # Return ANSI color code based on message type
    # Returns: Color code string or empty string
    ############################################################################
    _getColorCode() {
        loggy --type debug --message "Calling [_getColorCode]" 2>/dev/null || true
        local l_type="$1"
        case "$l_type" in
            error|fail)
                echo "$RED_BRIGHT"
                ;;
            success)
                echo "$GREEN_BRIGHT"
                ;;
            *)
                echo ""
                ;;
        esac
    }
    
    ############################################################################
    # Main logic of loggy function
    ############################################################################
    
    local l_type=""
    local l_message=""
    local l_file=""
    local l_level=""
    local l_quiet="false"
    
    # Parse named parameters
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --type)
                l_type="$2"
                shift 2
                ;;
            --message)
                l_message="$2"
                shift 2
                ;;
            --file)
                l_file="$2"
                shift 2
                ;;
            --level)
                l_level="$2"
                shift 2
                ;;
            --quiet)
                l_quiet="true"
                shift 1
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
                echo "Error: Unknown parameter '$1'" >&2
                _showHelp >&2
                return 1
                ;;
        esac
    done
    
    # Set defaults for optional parameters from global variables
    l_file="${l_file:-$GV_LOGFILE}"
    l_level="${l_level:-$GV_LOGLEVEL}"
    
    # Assert required parameters
    if ! _assertTypeProvided "$l_type"; then
        return 1
    fi
    if ! _assertMessageProvided "$l_message"; then
        return 1
    fi
    
    # Validate all inputs
    if ! _validateType "$l_type"; then
        return 1
    fi
    if ! _validateLogLevel "$l_level"; then
        return 1
    fi
    
    # Get numeric severity levels for comparison
    local l_msgSeverity="${LOG_LEVELS[$l_type]}"
    local l_filterSeverity="${LOG_LEVELS[$l_level]}"
    
    # Process message only if its severity is <= filter threshold
    # (lower number = higher priority/severity)
    if [[ $l_msgSeverity -le $l_filterSeverity ]]; then
        
        # Generate timestamp in ISO 8601 format
        local l_timestamp
        l_timestamp=$(date '+%Y-%m-%d %H:%M:%S')
        
        # Create formatted message
        local l_formattedMessage="${l_timestamp} ${l_type} ${l_message}"
        
        # Output to screen with color if applicable (unless --quiet specified)
        if [[ "$l_quiet" == "false" ]]; then
            local l_colorCode
            l_colorCode=$(_getColorCode "$l_type")
            
            if [[ -n "$l_colorCode" ]]; then
                echo -e "${l_colorCode}${l_formattedMessage}${RESET}"
            else
                echo "${l_formattedMessage}"
            fi
        fi
        
        # Append to file if specified (without ANSI color codes)
        if [[ -n "$l_file" ]]; then
            # Ensure directory exists
            local l_dir
            l_dir=$(dirname "$l_file")
            if [[ "$l_dir" != "." && ! -d "$l_dir" ]]; then
                mkdir -p "$l_dir" 2>/dev/null || true
            fi
            echo "${l_formattedMessage}" >> "$l_file"
        fi
    fi
    
    return 0
}

################################################################################
# Function Export & Main Execution
################################################################################

# Export only the parent function
export -f loggy

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    loggy "$@"
fi
