#!/bin/bash
###############################################################################
# Script: jsonValue.sh
#
# Description: Extract values from JSON strings by key path with type detection and support for nested keys, array indexing, and complex JSON structures.
#
# Input Parameters:
#   --key (string): JSON key/path to extract (required). Supports nested keys with dot notation and array indexing (e.g., "ID", "user.name", "items[0]").
#   --json (string): JSON string to query (optional, default: GV_SQL_RESULT_JSON global variable).
#   --help (flag): Display help message.
#   --menu (flag): Show interactive menu.
#
# Requirements:
#   - Bash shell environment.
#   - Recommended: jq (JSON command-line processor) for robust parsing. Install: sudo apt install jq
#   - Requires loggy.sh in same directory.
#   - Fallback basic parsing available without jq (limited support).
#
# Examples:
#   sqlToJson --sql "SELECT id, name FROM users" --password pass123; jsonValue --key "[0].ID"
#   jsonValue --key "user.email" --json '{"user":{"email":"test@example.com"}}'
#   jsonValue --key "[0].NAME" --json '[{"ID":1,"NAME":"Alice"},{"ID":2,"NAME":"Bob"}]'
#   echo "$GV_SQL_RESULT_JSON" | (jsonValue --key "address"; echo "Address: $GV_JSON_VALUE")
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

# Global variable defaults (override before calling jsonValue)
# These can be set via:
#   1. Runtime named parameters
#   2. Global variables
#   3. Constants file
#   4. Explicit defaults below
GV_SQL_RESULT_JSON="${GV_SQL_RESULT_JSON:-}"
GV_JSON_VALUE="${GV_JSON_VALUE:-}"
GV_JSON_VALUE_TYPE="${GV_JSON_VALUE_TYPE:-}"

jsonValue() {
    
    loggy --type beginend --message "Starting [jsonValue]"
    
    ############################################################################
    # Subfunction: _showHelp
    # Display command usage and detailed help information
    ############################################################################
    _showHelp() {
        loggy --type debug --message "Calling [_showHelp]" --quiet
        cat << 'EOF'
jsonValue - Extract Value from JSON String by Key

Usage: jsonValue [OPTIONS]

REQUIRED NAMED PARAMETERS:
    --key KEY           JSON key/path to extract
                        Examples: "ID", "user.name", "items[0]"
                        Supports nested keys with dot notation

OPTIONAL NAMED PARAMETERS:
    --json JSON         JSON string to query (optional)
                        Default: GV_SQL_RESULT_JSON global variable
                        If both not provided, returns error

OTHER OPTIONS:
    --help              Display this help message
    
    --menu              Show interactive menu

RETURN VALUES (stored in global variables):
    GV_JSON_VALUE       The extracted value
    GV_JSON_VALUE_TYPE  Type of value: "string", "number", "array", "object", "boolean", "null"

PARAMETER PRECEDENCE (highest to lowest priority):
    1. Runtime named parameters (--json "...")
    2. Global variables (GV_SQL_RESULT_JSON)
    3. Defaults (none for JSON - must be provided)

VALUE TYPES:
    string    - Text enclosed in quotes (with escapes handled)
    number    - Integer or decimal value
    array     - JSON array structure [...]
    object    - JSON object structure {...}
    boolean   - true or false
    null      - JSON null value

EXAMPLES:
    # Extract from GV_SQL_RESULT_JSON global (from sqlToJson)
    sqlToJson --sql "SELECT id, name FROM users" --password pass123
    jsonValue --key "[0].ID"
    echo "Value: $GV_JSON_VALUE (Type: $GV_JSON_VALUE_TYPE)"
    
    # Extract from provided JSON string
    jsonValue --key "user.email" --json '{"user":{"email":"test@example.com"}}'
    echo "Email: $GV_JSON_VALUE"
    
    # Extract nested object (returns JSON)
    jsonValue --key "address" \
              --json '{"name":"John","address":{"city":"NYC","zip":"10001"}}'
    echo "Address object: $GV_JSON_VALUE (Type: $GV_JSON_VALUE_TYPE)"
    
    # Extract from array result
    jsonValue --key "[0].NAME" \
              --json '[{"ID":1,"NAME":"Alice"},{"ID":2,"NAME":"Bob"}]'
    echo "First name: $GV_JSON_VALUE"
    
    # Extract boolean value
    jsonValue --key "is_active" --json '{"user":"john","is_active":true}'
    echo "Active: $GV_JSON_VALUE (Type: $GV_JSON_VALUE_TYPE)"
    
    # Extract null value
    jsonValue --key "optional_field" --json '{"name":"test","optional_field":null}'
    echo "Value: $GV_JSON_VALUE (Type: $GV_JSON_VALUE_TYPE)"
    
    # Interactive menu
    jsonValue --menu

DEPENDENCIES:
    - jq: JSON command-line processor (recommended)
          Install: sudo apt install jq
    - loggy: Logging utility from bash_library
    - For best results, ensure jq is installed

JSON PATHS:
    Simple key:         "name"
    Nested path:        "user.profile.age"
    Array index:        "items[0]"
    Array element key:  "items[0].name"
    Deep nesting:       "a.b.c.d.e"

ERROR HANDLING:
    - Missing --key parameter returns exit code 1
    - Invalid JSON returns exit code 1
    - Key not found returns exit code 2
    - Type evaluation error returns exit code 3
EOF
    }
    
    ############################################################################
    # Subfunction: _showMenu
    # Display interactive menu for parameter entry
    ############################################################################
    _showMenu() {
        loggy --type debug --message "Calling [_showMenu]" --quiet
        local l_key=""
        local l_json="${GV_SQL_RESULT_JSON}"
        
        echo ""
        echo "========================================"
        echo "  JSON Value Extractor - Interactive"
        echo "========================================"
        echo ""
        
        # Get key
        read -p "Enter JSON key/path: " l_key
        
        # Get JSON source
        read -p "Enter JSON string (or press Enter to use GV_SQL_RESULT_JSON): " l_json
        [[ -z "$l_json" ]] && l_json="${GV_SQL_RESULT_JSON}"
        
        echo ""
        echo "========== Extraction Summary =========="
        echo "  Key:  $l_key"
        echo "  JSON: ${l_json:0:60}..."
        echo "========================================"
        echo ""
        
        # Execute extraction recursively
        if [[ -n "$l_json" ]]; then
            jsonValue --key "$l_key" --json "$l_json"
        else
            jsonValue --key "$l_key"
        fi
    }
    
    ############################################################################
    # Subfunction: _assertKeyProvided
    # Assert that --key parameter was provided
    # Returns: 0 if provided, 1 if missing
    ############################################################################
    _assertKeyProvided() {
        loggy --type debug --message "Calling [_assertKeyProvided]"
        if [[ -z "$1" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --key not provided"
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _assertJsonProvided
    # Assert that JSON is provided (runtime or global)
    # Returns: 0 if provided, 1 if missing
    ############################################################################
    _assertJsonProvided() {
        loggy --type debug --message "Calling [_assertJsonProvided]"
        if [[ -z "$1" ]]; then
            loggy --type error --message "Assertion failed - JSON string not provided (--json or GV_SQL_RESULT_JSON)"
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _validateJson
    # Validate that JSON string is valid
    # Returns: 0 if valid, 1 if invalid
    ############################################################################
    _validateJson() {
        loggy --type debug --message "Calling [_validateJson]"
        local l_json="$1"
        
        # Try to parse with jq if available
        if command -v jq &>/dev/null; then
            if ! echo "$l_json" | jq empty 2>/dev/null; then
                loggy --type error --message "Invalid JSON format"
                return 1
            fi
        else
            # Basic JSON validation without jq
            # Check if starts with { or [
            if [[ ! "$l_json" =~ ^[\{\[] ]]; then
                loggy --type error --message "Invalid JSON format (must start with { or [)"
                return 1
            fi
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _extractValue
    # Extract value from JSON using key and determine its type
    # Returns: 0 on success, 2 if key not found, 3 on error
    ############################################################################
    _extractValue() {
        loggy --type debug --message "Calling [_extractValue]"
        local l_key="$1"
        local l_json="$2"
        local l_rawValue=""
        local l_value=""
        local l_type=""
        
        loggy --type variable --message "Key: $l_key"
        loggy --type variable --message "JSON: ${l_json:0:80}..."
        
        # Use jq if available for robust extraction
        if command -v jq &>/dev/null; then
            # Try to extract the value
            l_rawValue=$(echo "$l_json" | jq -r ".${l_key}" 2>/dev/null) || {
                loggy --type fail --message "Failed to extract key '$l_key' from JSON"
                return 2
            }
            
            # Check if key was found
            if [[ "$l_rawValue" == "null" ]]; then
                # Verify key actually exists (null is valid value)
                if ! echo "$l_json" | jq "has(\"$l_key\") or (.[] | has(\"$l_key\"))" 2>/dev/null | grep -q "true"; then
                    loggy --type fail --message "Key '$l_key' not found in JSON"
                    return 2
                fi
                l_value="null"
                l_type="null"
            else
                l_value="$l_rawValue"
                # Determine type using jq
                l_type=$(echo "$l_json" | jq -r ".${l_key} | type" 2>/dev/null)
                
                # Validate type result
                if [[ -z "$l_type" || "$l_type" == "null" ]]; then
                    l_type="null"
                fi
            fi
        else
            # Fallback: manual parsing (basic implementation)
            loggy --type variable --message "jq not found, using basic JSON parsing"
            
            # This is a simplified approach for basic keys only
            # For complex nested keys, jq is recommended
            if echo "$l_json" | grep -q "\"$l_key\""; then
                # Extract value after key
                l_value=$(echo "$l_json" | sed -n "s/.*\"$l_key\":\([^,}]*\).*/\1/p" | head -1)
                
                if [[ -z "$l_value" ]]; then
                    loggy --type fail --message "Failed to extract value for key '$l_key'"
                    return 2
                fi
            else
                loggy --type fail --message "Key '$l_key' not found in JSON"
                return 2
            fi
            
            # Determine type from value format
            if [[ "$l_value" == "null" ]]; then
                l_type="null"
            elif [[ "$l_value" =~ ^\".*\"$ ]]; then
                l_type="string"
                l_value="${l_value%\"}"
                l_value="${l_value#\"}"
            elif [[ "$l_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                l_type="number"
            elif [[ "$l_value" == "true" || "$l_value" == "false" ]]; then
                l_type="boolean"
            elif [[ "$l_value" =~ ^\[ ]]; then
                l_type="array"
            elif [[ "$l_value" =~ ^\{ ]]; then
                l_type="object"
            else
                l_type="string"
            fi
        fi
        
        # Store results in globals
        GV_JSON_VALUE="$l_value"
        GV_JSON_VALUE_TYPE="$l_type"
        
        loggy --type success --message "Value extracted successfully"
        loggy --type variable --message "Value: $GV_JSON_VALUE"
        loggy --type variable --message "Type: $GV_JSON_VALUE_TYPE"
        
        return 0
    }
    
    ############################################################################
    # Main logic of jsonValue function
    ############################################################################
    
    local l_key=""
    local l_json=""
    
    # Parse named parameters
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --key)
                l_key="$2"
                shift 2
                ;;
            --json)
                l_json="$2"
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
                loggy --type beginend --message "Completed [jsonValue]" --quiet
                return 1
                ;;
        esac
    done
    
    # Set defaults for optional parameters from global variables
    l_json="${l_json:-$GV_SQL_RESULT_JSON}"
    
    # Assert required parameters
    if ! _assertKeyProvided "$l_key"; then
        loggy --type beginend --message "Completed [jsonValue]"
        return 1
    fi
    
    if ! _assertJsonProvided "$l_json"; then
        loggy --type beginend --message "Completed [jsonValue]"
        return 1
    fi
    
    # Validate JSON format
    if ! _validateJson "$l_json"; then
        loggy --type beginend --message "Completed [jsonValue]"
        return 1
    fi
    
    # Extract value and determine type
    if ! _extractValue "$l_key" "$l_json"; then
        local l_exitCode=$?
        loggy --type beginend --message "Completed [jsonValue]"
        return $l_exitCode
    fi
    
    loggy --type beginend --message "Completed [jsonValue]"
    return 0
}

################################################################################
# Function Export & Main Execution
################################################################################

# Export only the parent function
export -f jsonValue

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    jsonValue "$@"
fi
