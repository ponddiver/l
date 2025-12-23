#!/bin/bash
###############################################################################
# Script: sqlToJson.sh
#
# Description: Execute Oracle SQL queries and convert results to JSON format with optional file output and flexible database connection options.
#
# Input Parameters:
#   --sql (string): Oracle SQL query to execute (required). Automatically cleaned (all ; removed, single ; added).
#   --connection-string (string): Pre-built Oracle connection string (optional, overrides component-based connection).
#   --username (string): Oracle username (optional, default: GV_DB_USERNAME or 'sys').
#   --password (string): Oracle password (required unless using pre-built connection-string).
#   --hostname (string): Oracle host/server (optional, default: GV_DB_HOST or 'localhost').
#   --port (string): Oracle listener port (optional, default: GV_DB_PORT or '1521').
#   --sid (string): Oracle SID (optional, default: GV_DB_SID).
#   --service-name (string): Oracle Service Name (optional, preferred over SID).
#   --help (flag): Display help message.
#   --menu (flag): Show interactive menu.
#
# Requirements:
#   - Bash shell environment with Oracle client tools installed.
#   - Requires: sqlplus command (from Oracle client installation).
#   - Requires loggy.sh in same directory.
#   - Requires ORACLE_HOME environment variable configured or auto-detection.
#
# Examples:
#   sqlToJson --sql "SELECT * FROM v\$version" --password oracle_password
#   sqlToJson --sql "SELECT * FROM employees" --username scott --password tiger --sid ORCL
#   sqlToJson --sql "SELECT * FROM products" --hostname db.example.com --service-name prod_orcl.example.com --username admin --password secret
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

# Global variable defaults (override before calling sqlToJson)
# These can be set via:
#   1. Runtime named parameters
#   2. Global variables
#   3. Constants file
#   4. Explicit defaults below
GV_DB_USERNAME="${GV_DB_USERNAME:-sys}"
GV_DB_PASSWORD="${GV_DB_PASSWORD:-}"
GV_DB_HOST="${GV_DB_HOST:-localhost}"
GV_DB_PORT="${GV_DB_PORT:-1521}"
GV_DB_SID="${GV_DB_SID:-}"
GV_DB_SERVICE_NAME="${GV_DB_SERVICE_NAME:-}"
GV_DB_CONNECTION_STRING="${GV_DB_CONNECTION_STRING:-}"
GV_SQLPLUS_PATH="${GV_SQLPLUS_PATH:-}"
GV_SQL_RESULT_JSON="${GV_SQL_RESULT_JSON:-}"

sqlToJson() {
    loggy --type beginend --message "Starting [sqlToJson]"
    
    ############################################################################
    # Subfunction: _showHelp
    # Display command usage and detailed help information
    ############################################################################
    _showHelp() {
        loggy --type debug --message "Calling [_showHelp]" --quiet
        cat << 'EOF'
sqlToJson - Convert Oracle SQL Query Results to JSON

Usage: sqlToJson [OPTIONS]

REQUIRED NAMED PARAMETERS:
    --sql QUERY         Oracle SQL query to execute
                        Example: "SELECT id, name, email FROM users;"
                        Note: Query is automatically cleaned (all ; removed, single ; added)

ORACLE CONNECTION (choose one approach):
    Option 1 - Direct Connection String (simplest):
        --connection-string CS  Pre-built Oracle connection string
                                Example: "sys/password@localhost:1521/ORCL"
                                Example: "user/pass@host:1521/SERVICE_NAME"
    
    Option 2 - Build Connection String from Components (more flexible):
        Uses parameters below to construct the connection string automatically
    
    --username USER     Oracle username (e.g., system, scott)
                        Default: GV_DB_USERNAME (default: sys)
                        Special: If username is "sys", automatically set to "sys as sysdba"
                        Required if --connection-string not provided
    
    --password PASS     Oracle password (REQUIRED unless using pre-built connection-string)
                        Default: GV_DB_PASSWORD
                        Never exposed in logs
    
    --hostname HOST     Oracle host/server
                        Default: GV_DB_HOST (default: localhost)
                        Required if --connection-string not provided
    
    --port PORT         Oracle listener port
                        Default: GV_DB_PORT (default: 1521)
    
    --sid SID           Oracle SID (e.g., ORCL, XE)
                        Default: GV_DB_SID
                        Required if --service-name not provided AND using component approach
    
    --service-name NAME Oracle Service Name
                        Default: GV_DB_SERVICE_NAME
                        Preferred over SID if both provided

OTHER OPTIONS:
    --help              Display this help message
    
    --menu              Show interactive menu

PARAMETER PRECEDENCE (highest to lowest priority):
    1. Runtime named parameters (--hostname 192.168.1.100)
    2. Global variables (GV_DB_HOST="192.168.1.100")
    3. Constants file values (constants.sh)
    4. Explicit defaults (localhost, 1521)

RETURN VALUE:
    Returns JSON array in global variable GV_SQL_RESULT_JSON with column names as keys:
    [
      {"ID": 1, "NAME": "John", "EMAIL": "john@example.com"},
      {"ID": 2, "NAME": "Jane", "EMAIL": "jane@example.com"}
    ]
    
GLOBAL VARIABLES SET BY SCRIPT:
    GV_SQL_RESULT_JSON  Contains the JSON result array
    GV_SQLPLUS_PATH     Path to sqlplus executable (auto-detected if not set)

EXAMPLES:
    # Approach 1: Using pre-built connection string (simplest)
    sqlToJson --sql "SELECT * FROM v\$version" \
              --connection-string "sys/password@localhost:1521/ORCL" --password irrelevant
    
    # Approach 2: Component-based connection (more flexible, allows globals)
    
    # Basic query with sys/sysdba (default)
    sqlToJson --sql "SELECT * FROM v\$version" --password oracle_password
    
    # With specific credentials
    sqlToJson --sql "SELECT * FROM employees" \
              --username scott --password tiger --sid ORCL
    
    # Remote Oracle server with service name (preferred)
    sqlToJson --sql "SELECT * FROM products" \
              --hostname db.example.com --port 1521 \
              --service-name prod_orcl.example.com \
              --username admin --password secret
    
    # Using global variables
    GV_DB_USERNAME="scott"
    GV_DB_PASSWORD="tiger"
    GV_DB_SERVICE_NAME="ORCL"
    sqlToJson --sql "SELECT * FROM dept"
    echo "Result: $GV_SQL_RESULT_JSON"
    
    # Using pre-built connection string from global
    GV_DB_CONNECTION_STRING="system/oracle@prod_db:1521/PRODDB"
    sqlToJson --sql "SELECT COUNT(*) FROM users"
    echo "$GV_SQL_RESULT_JSON" | jq
    
    # Access returned JSON
    sqlToJson --sql "SELECT id, name FROM users" --password pass123
    echo "$GV_SQL_RESULT_JSON" | jq '.[] | select(.id > 10)'
    
    # Interactive menu
    sqlToJson --menu

ORACLE CONNECTION METHODS:
    1. Direct (Host/Port/SID):
       sqlToJson --sql "SELECT 1 FROM dual" --host localhost --port 1521 --sid ORCL --password pass
    
    2. Via Service Name:
       sqlToJson --sql "SELECT 1 FROM dual" --service-name ORCL.example.com --password pass
    
    3. Using ORACLE_HOME environment variable:
       export ORACLE_HOME=/u01/app/oracle/product/19c
       sqlToJson --sql "SELECT 1 FROM dual" --sid ORCL --password pass

JSON OUTPUT:
    - Array of objects (one per result row)
    - Column names become object keys (typically UPPERCASE in Oracle)
    - NULL values become JSON null
    - Numbers remain numeric (without quotes)
    - Strings are properly quoted and escaped
    - Dates are returned as strings in Oracle format
    - Empty result set returns empty array: []

SQLPLUS NOTES:
    - Query semicolons are automatically handled
    - Comments using -- or /* */ are supported
    - Requires sqlplus client installed and ORACLE_HOME configured
    - Set NLS_LANG environment variable for character set issues
    - Can use sqlplus formatting commands (SET commands)

ERROR HANDLING:
    - Missing --sql parameter returns exit code 1
    - Database connection errors return exit code 2
    - Query execution errors return exit code 3
    - All errors logged via loggy utility
EOF
    }
    
    ############################################################################
    # Subfunction: _showMenu
    # Display interactive menu for parameter entry
    ############################################################################
    _showMenu() {
        loggy --type debug --message "Calling [_showMenu]" --quiet
        local l_sql=""
        local l_username="${GV_DB_USERNAME}"
        local l_password="${GV_DB_PASSWORD}"
        local l_hostname="${GV_DB_HOST}"
        local l_port="${GV_DB_PORT}"
        local l_sid="${GV_DB_SID}"
        local l_service_name="${GV_DB_SERVICE_NAME}"
        
        echo ""
        echo "========================================"
        echo "  SQL to JSON Converter - Interactive"
        echo "========================================"
        echo ""
        
        # Get SQL query
        read -p "Enter SQL query: " l_sql
        
        # Get Oracle connection details
        read -p "Enter Oracle username (default: ${GV_DB_USERNAME}): " l_username
        [[ -z "$l_username" ]] && l_username="${GV_DB_USERNAME}"
        
        read -sp "Enter Oracle password: " l_password
        echo ""
        
        read -p "Enter hostname (default: ${GV_DB_HOST}): " l_hostname
        [[ -z "$l_hostname" ]] && l_hostname="${GV_DB_HOST}"
        
        read -p "Enter port (default: ${GV_DB_PORT}): " l_port
        [[ -z "$l_port" ]] && l_port="${GV_DB_PORT}"
        
        read -p "Enter Service Name (or leave empty): " l_service_name
        if [[ -z "$l_service_name" ]]; then
            read -p "Enter SID (required if service name empty): " l_sid
        fi
        
        echo ""
        echo "========== Query Summary =========="
        echo "  Hostname:    $l_hostname"
        echo "  Port:        $l_port"
        if [[ -n "$l_service_name" ]]; then
            echo "  Service:     $l_service_name"
        else
            echo "  SID:         $l_sid"
        fi
        echo "  Username:    $l_username"
        echo "  SQL:         ${l_sql:0:60}..."
        echo "===================================="
        echo ""
        
        # Execute query recursively
        if [[ -n "$l_service_name" ]]; then
            sqlToJson --sql "$l_sql" --hostname "$l_hostname" --port "$l_port" \
                      --service-name "$l_service_name" --username "$l_username" --password "$l_password"
        else
            sqlToJson --sql "$l_sql" --hostname "$l_hostname" --port "$l_port" \
                      --sid "$l_sid" --username "$l_username" --password "$l_password"
        fi
    }
    
    ############################################################################
    # Subfunction: _assertSqlProvided
    # Assert that SQL query parameter was provided
    # Returns: 0 if provided, 1 if missing
    ############################################################################
    _assertSqlProvided() {
        loggy --type debug --message "Calling [_assertSqlProvided]"
        if [[ -z "$1" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --sql not provided"
            return 1
        fi
        return 0
    }
    
    ############################################################################
    # Subfunction: _cleanupSqlQuery
    # Clean up SQL query: strip all semicolons and add single one at end
    # Returns: cleaned SQL query to stdout
    ############################################################################
    _cleanupSqlQuery() {
        loggy --type debug --message "Calling [_cleanupSqlQuery]"
        local l_sql="$1"
        # Remove all semicolons
        l_sql="${l_sql//;/}"
        # Trim leading/trailing whitespace
        l_sql=$(echo "$l_sql" | xargs)
        # Add single semicolon at the end
        l_sql="${l_sql};"
        echo "$l_sql"
    }
    
    ############################################################################
    # Subfunction: _escapeJsonString
    # Escape special characters for JSON string values
    # Returns: escaped string to stdout
    ############################################################################
    _escapeJsonString() {
        loggy --type debug --message "Calling [_escapeJsonString]"
        local l_input="$1"
        # Escape backslashes, quotes, newlines, etc.
        l_input="${l_input//\\/\\\\}"      # backslash
        l_input="${l_input//\"/\\\"}"      # double quote
        l_input="${l_input//$'\n'/\\n}"    # newline
        l_input="${l_input//$'\r'/\\r}"    # carriage return
        l_input="${l_input//$'\t'/\\t}"    # tab
        echo "$l_input"
    }
    
    ############################################################################
    # Subfunction: _findSqlplusPath
    # Find sqlplus executable and set GV_SQLPLUS_PATH if not already set
    # Returns: 0 on success, 2 if sqlplus not found
    ############################################################################
    _findSqlplusPath() {
        loggy --type debug --message "Calling [_findSqlplusPath]"
        if [[ -n "${GV_SQLPLUS_PATH:-}" ]]; then
            loggy --type variable --message "Using sqlplus from GV_SQLPLUS_PATH: $GV_SQLPLUS_PATH"
            return 0
        fi
        
        # Try to find sqlplus in PATH
        if command -v sqlplus &>/dev/null; then
            GV_SQLPLUS_PATH=$(command -v sqlplus)
            loggy --type variable --message "Found sqlplus at: $GV_SQLPLUS_PATH"
            return 0
        fi
        
        # Try ORACLE_HOME
        if [[ -n "${ORACLE_HOME:-}" && -f "${ORACLE_HOME}/bin/sqlplus" ]]; then
            GV_SQLPLUS_PATH="${ORACLE_HOME}/bin/sqlplus"
            loggy --type variable --message "Found sqlplus in ORACLE_HOME: $GV_SQLPLUS_PATH"
            return 0
        fi
        
        # Not found
        loggy --type error --message "sqlplus not found in PATH or ORACLE_HOME. Install Oracle client."
        return 2
    }
    
    ############################################################################
    # Subfunction: _buildConnectionString
    # Build Oracle connection string for sqlplus (never logs password)
    # Returns: connection string to stdout
    ############################################################################
    _buildConnectionString() {
        loggy --type debug --message "Calling [_buildConnectionString]"
        local l_username="$1"
        local l_password="$2"
        local l_hostname="$3"
        local l_port="$4"
        local l_sid="$5"
        local l_service_name="$6"
        local l_connStr=""
        local l_connSpec=""
        
        # Validate required parameters
        if [[ -z "$l_username" || -z "$l_password" ]]; then
            loggy --type error --message "Oracle username and password are required"
            return 1
        fi
        
        if [[ -z "$l_sid" && -z "$l_service_name" ]]; then
            loggy --type error --message "Either --sid or --service-name must be provided"
            return 1
        fi
        
        # Check if username is sys, convert to "sys as sysdba"
        if [[ "$l_username" == "sys" ]]; then
            l_username="sys as sysdba"
            loggy --type variable --message "SYS user detected, using: sys as sysdba"
        fi
        
        # Build connection string: username/password@host:port/service_or_sid
        l_connStr="$l_username/$l_password"
        
        # Determine connection specification (prefer service name over SID)
        if [[ -n "$l_service_name" ]]; then
            l_connSpec="$l_hostname:$l_port/$l_service_name"
            loggy --type variable --message "Using service name connection"
        elif [[ -n "$l_sid" ]]; then
            l_connSpec="$l_hostname:$l_port/$l_sid"
            loggy --type variable --message "Using SID connection"
        fi
        
        l_connStr="$l_connStr@$l_connSpec"
        echo "$l_connStr"
    }
    
    ############################################################################
    # Subfunction: _executeOracleQuery
    # Execute Oracle query using sqlplus and return results with column names
    # Returns: 0 on success, 3 on query error
    ############################################################################
    _executeOracleQuery() {
        loggy --type debug --message "Calling [_executeOracleQuery]"
        local l_sql="$1"
        local l_connStr="$2"
        local l_output=""
        
        loggy --type beginend --message "Starting Oracle SQL to JSON conversion"
        loggy --type command --message "Query: $l_sql"
        # Do NOT log connection string as it contains password
        loggy --type variable --message "Using Oracle connection (password hidden)"
        
        # Execute the actual query
        l_output=$("$GV_SQLPLUS_PATH" -s "$l_connStr" << EOSQL 2>&1
SET HEADING ON FEEDBACK OFF PAGESIZE 0 LINESIZE 32767 TRIMOUT ON TRIMSPOOL ON
SET COLSEP |
WHENEVER SQLERROR EXIT SQL.SQLCODE
$l_sql
EXIT;
EOSQL
) || {
            loggy --type fail --message "Oracle query execution failed"
            loggy --type output --message "Error output: $l_output"
            return 3
        }
        
        echo "$l_output"
        return 0
    }
    
    ############################################################################
    # Subfunction: _convertResultToJson
    # Convert Oracle query result to JSON using first row as column headers
    # Input: pipe-delimited rows, first row contains column names
    ############################################################################
    _convertResultToJson() {
        loggy --type debug --message "Calling [_convertResultToJson]"
        local l_result="$1"
        local l_json="["
        local l_first_row=true
        local l_headers=()
        local l_row_num=0
        
        while IFS='|' read -r -a l_values; do
            # Skip empty lines
            if [[ ${#l_values[@]} -eq 0 ]]; then
                continue
            fi
            
            # First row contains column headers
            if [[ $l_row_num -eq 0 ]]; then
                l_headers=("${l_values[@]}")
                # Trim whitespace from headers
                for i in "${!l_headers[@]}"; do
                    l_headers[$i]=$(echo "${l_headers[$i]}" | xargs)
                done
                ((l_row_num++))
                continue
            fi
            
            # Subsequent rows are data
            if [[ "$l_first_row" == true ]]; then
                l_first_row=false
            else
                l_json+=","
            fi
            
            l_json+="{"
            local l_first_col=true
            for ((i=0; i<${#l_values[@]}; i++)); do
                if [[ "$l_first_col" == true ]]; then
                    l_first_col=false
                else
                    l_json+=","
                fi
                
                local l_col_name="${l_headers[$i]:-col$((i+1))}"
                local l_value="${l_values[$i]:-}"
                # Trim whitespace
                l_value=$(echo "$l_value" | xargs)
                
                # Handle NULL and numeric values
                if [[ "$l_value" == "NULL" || -z "$l_value" ]]; then
                    l_json+="\"$l_col_name\":null"
                elif [[ "$l_value" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
                    # Numeric value
                    l_json+="\"$l_col_name\":$l_value"
                else
                    # String value - escape and quote
                    local l_escaped
                    l_escaped=$(escapeJsonString "$l_value")
                    l_json+="\"$l_col_name\":\"$l_escaped\""
                fi
            done
            l_json+="}"
            ((l_row_num++))
        done <<< "$l_result"
        
        l_json+="]"
        GV_SQL_RESULT_JSON="$l_json"
        return 0
    }
    
    ############################################################################
    # Main logic of sqlToJson function
    ############################################################################
    
    local l_sql=""
    local l_username=""
    local l_password=""
    local l_hostname=""
    local l_port=""
    local l_sid=""
    local l_service_name=""
    local l_connection_string=""
    
    # Parse named parameters
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --sql)
                l_sql="$2"
                shift 2
                ;;
            --connection-string)
                l_connection_string="$2"
                shift 2
                ;;
            --username)
                l_username="$2"
                shift 2
                ;;
            --password)
                l_password="$2"
                shift 2
                ;;
            --hostname)
                l_hostname="$2"
                shift 2
                ;;
            --port)
                l_port="$2"
                shift 2
                ;;
            --sid)
                l_sid="$2"
                shift 2
                ;;
            --service-name)
                l_service_name="$2"
                shift 2
                ;;
            --host)
                # Alias for backward compatibility
                l_hostname="$2"
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
                loggy --type beginend --message "Completed [sqlToJson]"
                return 1
                ;;
        esac
    done
    
    # Set defaults for optional parameters from global variables
    l_username="${l_username:-$GV_DB_USERNAME}"
    l_password="${l_password:-$GV_DB_PASSWORD}"
    l_hostname="${l_hostname:-$GV_DB_HOST}"
    l_port="${l_port:-$GV_DB_PORT}"
    l_sid="${l_sid:-$GV_DB_SID}"
    l_service_name="${l_service_name:-$GV_DB_SERVICE_NAME}"
    l_connection_string="${l_connection_string:-$GV_DB_CONNECTION_STRING}"
    
    # Assert required parameters
    if ! _assertSqlProvided "$l_sql"; then
        loggy --type beginend --message "Completed [sqlToJson]"
        return 1
    fi
    
    # Clean up SQL query: remove all semicolons and add single one at end
    l_sql=$(_cleanupSqlQuery "$l_sql")
    
    # Use provided connection string if available, otherwise build from components
    local l_connStr=""
    if [[ -n "$l_connection_string" ]]; then
        l_connStr="$l_connection_string"
        loggy --type variable --message "Using provided connection string"
    else
        # Build connection string from components
        if [[ -z "$l_password" ]]; then
            loggy --type error --message "Assertion failed - Required parameter --password not provided when using component approach"
            loggy --type beginend --message "Completed [sqlToJson]"
            return 1
        fi
        
        if ! l_connStr=$(_buildConnectionString "$l_username" "$l_password" "$l_hostname" "$l_port" "$l_sid" "$l_service_name"); then
            loggy --type beginend --message "Completed [sqlToJson]"
            return 1
        fi
    fi
    
    # Find sqlplus executable
    if ! _findSqlplusPath; then
        loggy --type beginend --message "Completed [sqlToJson]"
        return 2
    fi
    
    # Execute query and convert to JSON
    local l_result
    if ! l_result=$(_executeOracleQuery "$l_sql" "$l_connStr"); then
        loggy --type beginend --message "Completed [sqlToJson]"
        return $?
    fi
    
    # Convert result to JSON and set global variable
    _convertResultToJson "$l_result"
    
    loggy --type success --message "SQL to JSON conversion completed"
    loggy --type output --message "Result stored in GV_SQL_RESULT_JSON (length: ${#GV_SQL_RESULT_JSON})"
    loggy --type beginend --message "Completed [sqlToJson]"
    return 0
}

################################################################################
# Function Export & Main Execution
################################################################################

# Export only the parent function
export -f sqlToJson

# Execute if run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    sqlToJson "$@"
fi
