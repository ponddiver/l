# Bash Library Scripts Reference

**Last Updated:** December 21, 2025  
**Library Location:** `bash_library/`  
**Source of Truth:** Script header comment blocks (shebang section)

---

## loggy.sh

**Status:** Stable  
**Version:** 1.0  
**Last Modified:** December 21, 2025

### Description

Flexible logging utility providing categorized message output with optional file persistence and log level filtering. Supports 8 message types with priority-based filtering, ANSI color codes for terminal output, and persistent file logging.

### Dependencies

- Bash shell environment
- Standard utilities: `date`, `mkdir`, `echo`, `read`
- POSIX-compliant

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--type` | string | ✓ | — | Message type: error, fail, success, output, beginend, variable, command, debug |
| `--message` | string | ✓ | — | Message text to log |
| `--file` | string | — | `$GV_LOGFILE` | File path to append log output |
| `--level` | string | — | `$GV_LOGLEVEL` | Log level filter (output, debug, etc.) |
| `--quiet` | flag | — | false | Suppress screen output (preserves file output) |
| `--help` | flag | — | — | Display help message |
| `--menu` | flag | — | — | Show interactive menu |

### Global Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GV_LOGFILE` | "" (empty) | Default log file path; if empty, logs to screen only |
| `GV_LOGLEVEL` | "output" | Default log level filter |

### Output/Return Values

Returns exit code 0 on success, 1 on parameter validation failure. Outputs formatted message to stdout with timestamp and type, optionally appends to specified file.

### Log Level Priority

| Level | Priority | Color | Use Case |
|-------|----------|-------|----------|
| error | 1 (critical) | Red | System/function call errors |
| fail | 2 | Red | Process failures |
| success | 3 | Green | Successful completion |
| output | 4 (default) | — | Normal process output |
| beginend | 5 | — | Function start/end markers |
| variable | 6 | — | Variable assignments |
| command | 7 | — | Command execution |
| debug | 8 (verbose) | — | Detailed debug information |

### Usage Examples

```bash
# Basic error logging
loggy --type error --message "Database connection failed"

# Logging with file output via global variable
GV_LOGFILE="/var/log/app.log"
loggy --type success --message "Backup completed successfully"

# Override global settings at runtime
loggy --type debug --message "Variable X=42" --file /tmp/debug.log --level debug

# Quiet mode (file only, no screen output)
loggy --type variable --message "Internal state" --file app.log --quiet

# Using with custom log level
GV_LOGLEVEL="debug"
loggy --type command --message "Executing: curl https://api.example.com"

# Interactive menu mode
loggy --menu
```

### Error Handling

| Exit Code | Condition |
|-----------|-----------|
| 0 | Success |
| 1 | Missing required parameter (--type or --message) |
| 1 | Invalid log type or log level |

### Integration Notes

- **Used by:** All bash_library scripts source loggy.sh
- **Integration pattern:** Source loggy.sh at script start, then call loggy throughout execution
- **Color output:** Automatically disabled in pipes/redirects (detects non-tty)
- **Thread-safe:** Appends to file are atomic operations

### Example Integration in Custom Script

```bash
#!/bin/bash
source "${BASH_SOURCE%/*}/loggy.sh"

GV_LOGFILE="/var/log/myscript.log"

myFunction() {
    loggy --type beginend --message "Starting [myFunction]"
    
    if ! command -v curl &>/dev/null; then
        loggy --type error --message "curl command not found"
        return 1
    fi
    
    loggy --type success --message "All dependencies available"
    return 0
}

myFunction
```

### Version & Changelog

- **1.0 (Dec 21, 2025):** Initial stable release with 8 log types, file persistence, color support

---

## findOracleDatabases.sh

**Status:** Stable  
**Version:** 1.0  
**Last Modified:** December 21, 2025

### Description

Identifies all running Oracle databases on a RHEL/Oracle Linux server and displays their Oracle Home directories, user ownership, and process IDs. Supports table and JSON output formats with verbose debugging.

### Dependencies

- RHEL/Oracle Linux system (`/etc/redhat-release` required)
- Required commands: `ps`, `grep`, `awk`
- Optional: `loggy.sh` in same directory (has fallback implementation)

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--output-format` | string | — | table | Output format: 'table' or 'json' |
| `--verbose` | flag | — | false | Enable verbose output for debugging |
| `--help` | flag | — | — | Display help message |
| `--menu` | flag | — | — | Display interactive menu |

### Global Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GV_OUTPUT_FORMAT` | "table" | Output format preference |
| `GV_VERBOSE` | "false" | Verbose logging enabled |

### Output/Return Values

Returns exit code 0 on success. Outputs table or JSON array of running Oracle databases with columns: DATABASE, ORACLE_HOME, USER, PID.

**Table Format Output:**
```
==========================================
Oracle Databases Running on myserver
==========================================
DATABASE             ORACLE_HOME                                    USER            PID     
------------------------------------------
ORCL                 /u01/app/oracle/product/19c                    oracle          12345   
XEPDB                /u01/app/oracle/product/21c                    oracle          12346   
==========================================
```

**JSON Format Output:**
```json
[
  {
    "database": "ORCL",
    "oracle_home": "/u01/app/oracle/product/19c",
    "oracle_user": "oracle",
    "pid": 12345,
    "hostname": "myserver",
    "timestamp": "2025-12-21T10:30:45Z"
  },
  {
    "database": "XEPDB",
    "oracle_home": "/u01/app/oracle/product/21c",
    "oracle_user": "oracle",
    "pid": 12346,
    "hostname": "myserver",
    "timestamp": "2025-12-21T10:30:45Z"
  }
]
```

### Usage Examples

```bash
# Display all running Oracle databases (default table format)
./findOracleDatabases.sh

# Output as JSON for programmatic processing
./findOracleDatabases.sh --output-format json

# Enable verbose output with debugging information
./findOracleDatabases.sh --verbose

# Combined: JSON format with verbose output
./findOracleDatabases.sh --output-format json --verbose

# Integration example: Parse JSON output
./findOracleDatabases.sh --output-format json | jq '.[] | select(.database == "ORCL")'
```

### Error Handling

| Exit Code | Condition |
|-----------|-----------|
| 0 | Success; database(s) found and displayed |
| 1 | Environment validation failed (not RHEL/OL, missing commands) |
| 2 | No running Oracle databases found |

### Integration Notes

- **Standalone:** Does not depend on other bash_library scripts
- **Oracle Home Detection:** Attempts multiple methods (process environment, /etc/oratab, filesystem search)
- **RHEL/OL Detection:** Requires `/etc/redhat-release` file

### Example Integration

```bash
#!/bin/bash
# Get all Oracle databases and connect to each
source "${BASH_SOURCE%/*}/ssh.sh"

while IFS='|' read -r database oracle_home user pid; do
    echo "Connecting to $database..."
    runSshCommand --username oracle --hostname dbserver \
                  --command "source $oracle_home/bin/oraenv; sqlplus -v" \
                  --keyfile ~/.ssh/oracle_key
done < <(bash findOracleDatabases.sh --output-format json | jq -r '.[] | "\(.database)|\(.oracle_home)|\(.oracle_user)|\(.pid)"')
```

### Version & Changelog

- **1.0 (Dec 21, 2025):** Initial stable release with table and JSON output support

---

## ssh.sh

**Status:** Stable  
**Version:** 1.0  
**Last Modified:** December 21, 2025

### Description

Remote SSH command execution utility with support for both password and key-based authentication, configurable timeout, and flexible parameter precedence (runtime → global variables → constants → defaults).

### Dependencies

- Bash shell environment
- Required: `ssh`, `ssh-keygen` commands
- Optional: `sshpass` for password-based authentication (install: `sudo apt install sshpass`)
- Requires `loggy.sh` in same directory

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--username` | string | ✓ | — | Remote server username |
| `--hostname` | string | ✓ | — | Remote server hostname or IP address |
| `--command` | string | ✓ | — | Command to execute on remote server |
| `--password` | string | — | `$GV_SSH_PASSWORD` | Password for authentication (requires sshpass) |
| `--keyfile` | string | — | `$GV_SSH_KEYFILE` | Path to SSH private key file |
| `--port` | string | — | `$GV_SSH_PORT` | SSH port (default: 22) |
| `--timeout` | string | — | `$GV_SSH_TIMEOUT` | Command timeout in seconds (default: 300) |
| `--help` | flag | — | — | Display help message |
| `--menu` | flag | — | — | Show interactive menu |

### Global Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GV_SSH_PORT` | "22" | Default SSH port |
| `GV_SSH_TIMEOUT` | "300" | Default command timeout in seconds |
| `GV_SSH_KEYFILE` | "" | Default SSH private key path |
| `GV_SSH_PASSWORD` | "" | Default password (plaintext, not recommended for production) |

### Output/Return Values

Returns exit code 0 on success. Outputs remote command result to stdout. Logs connection status and command execution via loggy.

**Exit Codes:**
- 0: Command executed successfully
- 1: Parameter validation failure
- 2: SSH connection or command execution error
- 3: Command timeout exceeded

### Usage Examples

```bash
# Using SSH key (most secure)
runSshCommand --username admin --hostname 192.168.1.10 \
              --command "uptime" --keyfile ~/.ssh/server_key

# Using password authentication
runSshCommand --username root --hostname example.com \
              --command "df -h" --password "secretpass123"

# Using global variables for common server
export GV_SSH_KEYFILE="/home/user/.ssh/prod_key"
export GV_SSH_PORT="2222"
runSshCommand --username deploy --hostname prod.server.com \
              --command "systemctl status nginx"

# Override globals at runtime
runSshCommand --username deploy --hostname prod.server.com \
              --command "whoami" --port 2222 --keyfile ~/.ssh/override_key

# With custom timeout
runSshCommand --username root --hostname backup.local \
              --command "tar -czf backup.tar.gz /data" \
              --timeout 1800 --keyfile ~/.ssh/backup_key

# Interactive menu
runSshCommand --menu
```

### Error Handling

| Exit Code | Condition |
|-----------|-----------|
| 0 | Success |
| 1 | Missing required parameter or validation failure |
| 2 | SSH connection failed or remote command error |
| 3 | Command execution timeout |

### Authentication Notes

- **Key-based:** More secure; uses SSH keys from `~/.ssh/id_rsa` or specified path
- **Password-based:** Less secure; requires sshpass; plaintext password in memory
- **Priority:** Runtime parameter > global variable > default
- **Fallback:** If neither provided, uses default SSH key (`~/.ssh/id_rsa`)

### Integration Notes

- **Chain with sqlToJson:** Execute remote SQL queries and parse results
- **Integration with findOracleDatabases:** Connect to servers hosting Oracle databases
- **Logging:** Uses loggy for all connection/execution events

### Example Integration

```bash
#!/bin/bash
source "${BASH_SOURCE%/*}/ssh.sh"
source "${BASH_SOURCE%/*}/sqlToJson.sh"

# Execute remote SQL and convert to JSON
export GV_SSH_KEYFILE="~/.ssh/prod_key"

runSshCommand --username oracle --hostname prod_db \
              --command "sqlplus -s sys/password@PROD @query.sql" \
              --timeout 600
```

### Version & Changelog

- **1.0 (Dec 21, 2025):** Initial stable release with password and key authentication

---

## sqlToJson.sh

**Status:** Stable  
**Version:** 1.0  
**Last Modified:** December 21, 2025

### Description

Execute Oracle SQL queries and convert results to JSON format with optional file output. Supports component-based connection strings or pre-built connection strings, automatic SQL cleanup, and flexible database connection options.

### Dependencies

- Bash shell environment
- Required: `sqlplus` command (Oracle client installation)
- Requires `loggy.sh` in same directory
- Requires `ORACLE_HOME` environment variable configured or auto-detection via PATH

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--sql` | string | ✓ | — | Oracle SQL query to execute (auto-cleaned) |
| `--connection-string` | string | — | — | Pre-built Oracle connection string (overrides components) |
| `--username` | string | — | `$GV_DB_USERNAME` | Oracle username (default: 'sys') |
| `--password` | string | — | `$GV_DB_PASSWORD` | Oracle password (required unless pre-built conn string) |
| `--hostname` | string | — | `$GV_DB_HOST` | Oracle host/server (default: 'localhost') |
| `--port` | string | — | `$GV_DB_PORT` | Oracle listener port (default: '1521') |
| `--sid` | string | — | `$GV_DB_SID` | Oracle SID (e.g., ORCL, XE) |
| `--service-name` | string | — | `$GV_DB_SERVICE_NAME` | Oracle Service Name (preferred over SID) |
| `--help` | flag | — | — | Display help message |
| `--menu` | flag | — | — | Show interactive menu |

### Global Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GV_DB_USERNAME` | "sys" | Default database username |
| `GV_DB_PASSWORD` | "" | Default database password |
| `GV_DB_HOST` | "localhost" | Default database host |
| `GV_DB_PORT` | "1521" | Default database listener port |
| `GV_DB_SID` | "" | Default Oracle SID |
| `GV_DB_SERVICE_NAME` | "" | Default Oracle Service Name |
| `GV_DB_CONNECTION_STRING` | "" | Pre-built connection string override |
| `GV_SQL_RESULT_JSON` | "" | Output variable containing JSON result |

### Output/Return Values

Returns JSON array in `GV_SQL_RESULT_JSON` global variable with column names as keys. Empty result returns empty array `[]`.

**Example Output:**
```json
[
  {"ID": 1, "NAME": "John", "EMAIL": "john@example.com", "HIRE_DATE": "2020-01-15"},
  {"ID": 2, "NAME": "Jane", "EMAIL": "jane@example.com", "HIRE_DATE": "2019-06-20"}
]
```

**Exit Codes:**
- 0: Success
- 1: Missing --sql parameter
- 2: Database connection failure
- 3: Query execution error

### Connection Methods

**Method 1: Component-Based (Most Flexible)**
```bash
sqlToJson --sql "SELECT * FROM employees" \
          --username scott --password tiger \
          --hostname db.example.com --port 1521 \
          --service-name ORCL.example.com
```

**Method 2: Pre-Built Connection String**
```bash
sqlToJson --sql "SELECT * FROM employees" \
          --connection-string "scott/tiger@db.example.com:1521/ORCL"
```

**Method 3: Using Global Variables**
```bash
export GV_DB_USERNAME="scott"
export GV_DB_PASSWORD="tiger"
export GV_DB_SERVICE_NAME="ORCL"
sqlToJson --sql "SELECT * FROM employees"
echo "$GV_SQL_RESULT_JSON" | jq
```

### Usage Examples

```bash
# Basic query with default sys/sysdba
sqlToJson --sql "SELECT * FROM v\$version" --password oracle_password

# Query specific user
sqlToJson --sql "SELECT * FROM employees" \
          --username scott --password tiger --sid ORCL

# Remote Oracle server with service name
sqlToJson --sql "SELECT * FROM products" \
          --hostname db.example.com --port 1521 \
          --service-name prod_orcl.example.com \
          --username admin --password secret

# Using global variables
export GV_DB_CONNECTION_STRING="system/oracle@prod_db:1521/PRODDB"
sqlToJson --sql "SELECT COUNT(*) as COUNT FROM users"
echo "$GV_SQL_RESULT_JSON" | jq '.[] | .COUNT'

# Parse and filter JSON result
sqlToJson --sql "SELECT id, name, salary FROM employees" --password pass123
echo "$GV_SQL_RESULT_JSON" | jq '.[] | select(.salary > 50000) | {name, salary}'

# Interactive menu
sqlToJson --menu
```

### SQL Query Handling

- **Semicolons:** Automatically cleaned (all removed, single one added at end)
- **Comments:** Supports `--` and `/* */` style comments
- **Formatting:** Automatically sets sqlplus options for JSON-compatible output
- **NLS_LANG:** Respects environment variable for character set handling

### Error Handling

| Exit Code | Condition |
|-----------|-----------|
| 0 | Success |
| 1 | Missing --sql parameter |
| 2 | Database connection failure (invalid credentials, unreachable host) |
| 3 | Query execution error (syntax error, table not found) |

### Integration Notes

- **Chained with jsonValue.sh:** Extract specific values from result JSON
- **Chained with ssh.sh:** Execute remote SQL on distant Oracle servers
- **Output variable:** Result stored in `GV_SQL_RESULT_JSON` for further processing

### Example Integration

```bash
#!/bin/bash
source "${BASH_SOURCE%/*}/sqlToJson.sh"
source "${BASH_SOURCE%/*}/jsonValue.sh"

# Query and extract first employee name
sqlToJson --sql "SELECT name FROM employees WHERE id = 1" --password pass123
jsonValue --key "[0].NAME"
echo "Employee: $GV_JSON_VALUE"
```

### Version & Changelog

- **1.0 (Dec 21, 2025):** Initial stable release with flexible connection options

---

## Script Dependencies Map

```
loggy.sh
  ├── Used by: findOracleDatabases.sh, ssh.sh, sqlToJson.sh
  └── Optional: Falls back to simple echo if not found

findOracleDatabases.sh
  ├── Depends on: loggy.sh (optional)
  └── Used by: System discovery, database inventory

ssh.sh
  ├── Depends on: loggy.sh (required)
  └── Used by: Remote command execution, chained with sqlToJson

sqlToJson.sh
  ├── Depends on: loggy.sh (required), Oracle client (sqlplus)
  └── Used by: Database query processing, chained with jsonValue

jsonValue.sh
  ├── Depends on: loggy.sh (required), jq (optional)
  └── Used by: JSON data extraction from sqlToJson results
```

---

## Integration Patterns

### Pattern 1: Discover and Query Databases

```bash
#!/bin/bash
source bash_library/findOracleDatabases.sh
source bash_library/ssh.sh
source bash_library/sqlToJson.sh

# Find all local databases
findOracleDatabases --output-format json | jq -r '.[] | .database' | while read db; do
    echo "Database: $db"
done
```

### Pattern 2: Remote Query with Local Parsing

```bash
#!/bin/bash
source bash_library/ssh.sh
source bash_library/sqlToJson.sh
source bash_library/jsonValue.sh

# Execute SQL on remote server and extract value
runSshCommand --username oracle --hostname prod_db \
              --command "sqlplus -s sys/pass@PROD @query.sql" \
              --keyfile ~/.ssh/prod_key

# Then parse locally if needed
sqlToJson --sql "SELECT * FROM local_table"
jsonValue --key "[0].column_name"
```

### Pattern 3: Bulk Operations with Logging

```bash
#!/bin/bash
source bash_library/loggy.sh
source bash_library/ssh.sh

GV_LOGFILE="/var/log/batch_ops.log"

for server in server1 server2 server3; do
    if runSshCommand --username admin --hostname "$server" \
                     --command "systemctl status nginx" \
                     --keyfile ~/.ssh/admin_key; then
        loggy --type success --message "Server $server is healthy"
    else
        loggy --type fail --message "Server $server health check failed"
    fi
done
```

---

## updateOratab.sh

**Status:** Stable  
**Version:** 1.0  
**Last Modified:** December 21, 2025

### Description

Monitor Oracle databases (CDB and PDB instances) and automatically update the `/etc/oratab` file to reflect running instances. Ensures accurate database instance tracking across system restarts and state changes. Includes exclusive locking to prevent concurrent executions.

### Dependencies

- Bash shell environment
- Root privileges or sudo access
- Standard utilities: `ps`, `grep`, `awk`, `sed`, `date`, `mkdir`
- loggy.sh (optional, fallback logging available)
- Oracle installation with pmon processes for running instances

### Input Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `--monitor` | flag | — | false | Enable continuous monitoring mode with periodic checks |
| `--interval` | integer | — | 60 | Seconds between instance checks (requires --monitor) |
| `--update-once` | flag | — | false | Perform single update pass and exit |
| `--verbose` | flag | — | false | Enable verbose debug output |
| `--dry-run` | flag | — | false | Show what would be updated without modifying /etc/oratab |
| `--help` | flag | — | — | Display help message |

### Global Variables

| Variable | Default | Purpose |
|----------|---------|---------|
| `GV_MONITOR_MODE` | false | Enable continuous monitoring |
| `GV_CHECK_INTERVAL` | 60 | Seconds between periodic checks |
| `GV_VERBOSE` | false | Verbose output flag |
| `GV_DRY_RUN` | false | Preview mode without modifications |
| `GV_ORATAB_FILE` | "/etc/oratab" | Target file for updates |
| `GV_ORATAB_LOCK_FILE` | "/var/run/updateOratab.lock" | Lock file for mutual exclusion |
| `GV_RUNNING_INSTANCES` | () | Array of detected running instances |

### Output/Return Values

Returns exit code 0 on successful update/monitoring, 1 on errors (lock conflict, missing prerequisites, invalid parameters). Outputs:
- Timestamped log messages via loggy utility
- Instance discovery summary when verbose enabled
- Backup files created as `/etc/oratab.bak.TIMESTAMP` before modifications

### Features

- **Mutual Exclusion:** Prevents concurrent script executions via PID-based lock file
- **Stale Lock Detection:** Removes and replaces stale lock files from crashed instances
- **Instance Detection:** Queries pmon processes to find all running Oracle databases
- **Status Tracking:** Updates Y/N flags in oratab based on running state
- **New Instance Addition:** Automatically adds newly discovered instances to oratab
- **ORACLE_HOME Discovery:** Attempts to locate ORACLE_HOME for new instances
- **Backup Creation:** Creates timestamped backups before file modifications
- **Dry-run Mode:** Preview changes without applying them

### Usage Examples

**Single Update Pass**
```bash
sudo ./updateOratab.sh --update-once
```

**Continuous Monitoring (30-second intervals)**
```bash
sudo ./updateOratab.sh --monitor --interval 30 --verbose
```

**Preview Changes Without Applying**
```bash
sudo ./updateOratab.sh --update-once --dry-run
```

**Background Monitoring with Logging**
```bash
GV_LOGFILE="/var/log/updateOratab.log" \
  sudo ./updateOratab.sh --monitor --interval 120 > /dev/null 2>&1 &
```

**Cron-Based Hourly Updates**
```bash
# Add to /etc/crontab:
0 * * * * root /opt/bash_library/updateOratab.sh --update-once
```

### Error Codes & Conditions

| Exit Code | Condition | Resolution |
|-----------|-----------|------------|
| 0 | Successful execution | — |
| 1 | Another instance already running | Wait for lock release or check PID |
| 1 | Not running as root | Use sudo or run as root user |
| 1 | /etc/oratab not found | Create /etc/oratab or verify Oracle installation |
| 1 | /etc/oratab not writable | Check file permissions (requires root) |
| 1 | Lock file creation failed | Check /var/run directory permissions |
| 1 | Invalid parameter value | Review parameter syntax with --help |

### Integration Notes

**With Monitoring Systems:**
Use with systemd service or cron for automatic database state tracking. Recommended update interval: 60-120 seconds to balance responsiveness with system load.

**With Other Scripts:**
- `loggy.sh`: Provides unified logging interface (fallback available if missing)
- `findOracleDatabases.sh`: Complements detection capability for system audits
- `ssh.sh`: Can be extended for remote oratab updates across infrastructure

**Parameter Precedence:**
1. Runtime command-line flags (highest priority)
2. Global variables (if defined in calling environment)
3. Script defaults (lowest priority)

### Known Limitations

- Requires root/sudo access to modify /etc/oratab
- Only detects instances with active pmon processes
- ORACLE_HOME discovery uses heuristics for new instances
- Lock file location requires /var/run to be writable
- Does not handle PDBs in separate directories (uses parent CDB path)

### Version History

**v1.0 (December 21, 2025)** - Initial release
- Continuous and single-pass monitoring modes
- Exclusive lock mechanism for concurrent protection
- Stale lock detection and cleanup
- Dry-run mode for testing
- Verbose debugging output
- Automatic backup file creation

---

## Contributing

When adding new scripts to bash_library:
1. Follow header comment block format per sh.instruction.md
2. Include --help and --menu options
3. Update this SCRIPTS.md file with complete documentation
4. Update bash_library/README.html with script entry
5. Test script execution and JSON output (if applicable)
6. Include meaningful error messages and exit codes

