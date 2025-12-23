````markdown
---
applyTo: '**/*.sh'
description: 'Create bash scripts for general use. Use Claude Haiku 4.5'
---

# Script Header Comment Block
- All scripts must include a documentation comment block immediately after the shebang line.
- The header block must contain the following fields in order:
  - `###############################################################################`
  - **Name:** Short identifier for the script (e.g., `# Script: findOracleDatabases.sh`).
  - **Description:** 1-2 sentence explanation of what the script does.
  - **Input Parameters:** List of all named parameters with types and descriptions (use `--parameter-name (type): Description`).
  - **Requirements:** List dependencies, required commands, OS requirements, or external files.
  - **Examples:** 2-3 usage examples showing common workflows.  
  - `###############################################################################`
  - **Copyright:** All code must include copyright notice as final line of header block: 
    Copyright © 2025 SolidWorks Consulting LLC. 
    This is a product of SolidWorks Consulting LLC. (www.rndev.com).
    Code is free to use with proper attribution to the source.
  - `###############################################################################`
- Separate each field with a blank comment line (`#`).
- Keep descriptions concise and focused on functionality.
- The copyright line must be the final line of the header block, positioned after all other fields.
- Example header block:
  ```bash
  #!/bin/bash
  # Script: findOracleDatabases.sh
  #
  # Description: Identifies all running Oracle databases on a RHEL server and displays their Oracle Home directories.
  #
  # Input Parameters:
  #   --output-format (string): Set output format to 'table' (default) or 'json'.
  #   --verbose (flag): Enable verbose output for debugging.
  #   --help (flag): Display help message.
  #
  # Requirements:
  #   - Must run on RHEL/Oracle Linux system.
  #   - Requires: ps, grep, awk commands.
  #   - Requires loggy.sh in same directory (optional).
  #
  # Examples:
  #   ./findOracleDatabases.sh
  #   ./findOracleDatabases.sh --output-format json
  #   ./findOracleDatabases.sh --verbose
  #
  ```

# Bash code guidelines

## Initialization & Error Handling
- Always use `#!/bin/bash` as the shebang.
- Enforce strict error handling by including `set -euo pipefail` at the start of every script.

## Syntax Best Practices
- Quote all variables to prevent word splitting and globbing (e.g., use "$VAR" instead of $VAR).
- Prefer `[[ ... ]]` over `[ ... ]` for conditional tests.
- Use `$(command)` instead of backticks for command substitution.
- Prefer long-form flags for readability (e.g., `--directory` instead of `-d`) when available.

## Functions & Scope
- Use local variables within functions (e.g., `local l_name="value"`).
- All helper functions will be subfunctions within a single parent function. Only export the parent function.

## Compatibility & Features
- Ensure scripts are POSIX-compliant unless specific Bash-only features are requested.
- Acceptable Bash-specific features (when POSIX-compliance not required): associative arrays, parameter expansion (${var:offset:length}), process substitution, extended globbing.

## User Interface
- Always include a usage function and basic help menu for scripts with arguments.

# Loggy
- Loggy calls of type beginend should include the function name in the message. Enclose the function name in [].
- All main functions will call loggy and log beginend as "Starting []".
- All subfunctions will call loggy and log function name, between [], as debug and "Calling []".
- For help and menu subfunctions: set --quiet when calling loggy debug for "Calling [_functionName]".
- When help/menu/error options return in parameter parsing, include completion loggy with --quiet flag: `loggy --type beginend --message "Completed [parentFunctionName]" --quiet`.
- Do not call loggy from within parameter parsing loop when processing named parameters.
- Example: `loggy --type beginend --message "Starting [myFunction]"` for main function start; `loggy --type debug --message "Calling [_helper]" --quiet` for subfunction calls.

# Input parameters
- All input values are named parameters and include a menu option.
- Input parameters can be passed at runtime via named flags or via global variables.
- Parameter precedence (highest to lowest): runtime named parameter → global variable → constants.sh value → explicit default.
- If a named parameter is not passed at runtime, the global variable will be used as default unless otherwise specified.
- If an explicit default value is provided in code, use it only if the parameter was not passed at runtime AND the global variable was not set.

# External source functions
- All sourced functions will be sourced if they have not been sourced previously.
- All scripts will source loggy regardless of it being used.
- All scripts will source constants file if it exists.

# Formatting
- Use 2 or 4 spaces (consistency is key); avoid hard tabs to ensure the script looks the same in all editors.

# Execution Context & Privilege Management

## Execution User
- Scripts should be designed to execute as a specific user context (e.g., `oracle` for database scripts).
- Assume the script will run under the designated user account (document this in Requirements section).
- Do NOT assume the script runs as root or with elevated privileges by default.

## Privilege Escalation
- Use `sudo` only when operations require permissions beyond the execution user's capabilities.
- Design operations to minimize privilege escalation:
  - Operations within the user's home directory or writable paths do not need `sudo`.
  - File modifications that the user can access directly do not need `sudo`.
  - Only escalate privileges for system-level operations (e.g., systemd management, system configuration).
- Create a helper function (e.g., `_executeSudo`) to encapsulate and standardize privilege escalation:
  ```bash
  _executeSudo() {
      local l_description="$1"
      shift
      
      if sudo -n "$@" 2>/dev/null; then
          return 0
      elif [[ -t 0 ]]; then
          echo "sudo is required for: $l_description"
          sudo "$@"
      else
          loggy --type error --message "Cannot execute with sudo (non-interactive): $l_description"
          return 1
      fi
  }
  ```
- In the Requirements section, document which operations require `sudo` and why.
- Example requirement: "Requires sudo for: systemd service/timer management, /etc file modifications"

## Documenting Execution Context
- In the **Requirements** section of the script header, specify:
  - The expected execution user (e.g., "Execute as: oracle user")
  - Which operations require elevated privileges (e.g., "Requires sudo for: systemd operations")
  - Any file permissions or ownership assumptions

# Naming convention
- Use camel case naming for functions.
- Local variable names: lowercase with `l_` prefix (e.g., `l_username`, `l_output`).
- Global variable names: UPPERCASE with `GV_` prefix (e.g., `GV_LOGFILE`, `GV_SSH_PORT`).
  - **Specificity requirement:** Global variable names must be specific enough to avoid unintended conflicts with variables in other scripts.
  - Include the script name or primary functionality in the variable name unless it's a universally shared constant.
  - Examples of good specificity: `GV_ORATAB_FILE` (for updateOratab.sh), `GV_ORATAB_LOCK_FILE` (specific operation), `GV_SSH_TIMEOUT` (clear purpose).
  - Examples of poor specificity: `GV_FILE` (too generic), `GV_TEMP` (could conflict), `GV_STATUS` (ambiguous context).
  - Exception: Variables explicitly intended to be shared across scripts should be documented in a shared constants file and noted in all scripts that use them.
- Function names: camelCase (e.g., `runSshCommand`, `validateKeyfile`).
- Constants: UPPERCASE (e.g., `RED_BRIGHT`, `RESET`).
- Prefix all helper and subfunction with _.

# Script Documentation & Registration

## Landing Page (HTML)
- Maintain a `bash_library/README.html` or `bash_library/index.html` landing page that lists all available scripts.
- Each script entry should include:
  - **Script name:** Link to the source script file (e.g., `findOracleDatabases.sh`)
  - **One-line description:** Brief functionality summary from script header
  - **Quick link:** Link to detailed documentation in instructions.md
  - **Status badge:** Indicates script readiness (Stable, Beta, Experimental)
  - **Last updated:** Date of last modification

## Script Reference Documentation (instructions.md)
- Maintain a `bash_library/SCRIPTS.html` or similar reference file with detailed documentation.
- Each script section must include:
  - **Script name and file location:** (e.g., `# findOracleDatabases.sh`)
  - **Full description:** 2-3 sentences explaining purpose and use cases
  - **Input parameters:** Copy of parameter list from script header with examples
  - **Output/Return values:** Description of what the script outputs or returns
  - **Global variables:** All GV_* variables used or set by the script
  - **Usage examples:** 3-5 realistic usage scenarios with expected output
  - **Error handling:** Common error conditions and exit codes
  - **Integration notes:** How the script interacts with other bash_library scripts
  - **Version & changelog:** Current version and notable changes

## Synchronization Requirements
- Keep HTML landing page synchronized with actual scripts in bash_library directory.
- Update SCRIPTS.md whenever script parameters or functionality changes.
- Include update date in both HTML header and SCRIPTS.md revision history.
- Script header comments (shebang block) are the source of truth; documentation files should reflect these.

## Documentation Tools
- Use markdown for SCRIPTS.md and convert to HTML using markdown tools (e.g., pandoc, Convert-Markdown.ps1).
- Generate landing page from template to ensure consistent formatting.
- Consider using automated tools to extract script information from headers and update documentation.

# Script Creation Instructions Log
- Create a comprehensive instructions log for each script documenting its development process, design decisions, and maintenance guidelines.
- ensure compliance with html.instruction.md
- Log file naming convention: Use the same script name with `.instructions.html` suffix (e.g., `findOracleDatabases.sh.instructions.html` for `findOracleDatabases.sh`).
- Store log files in the same directory as the script for easy co-location and discovery.
- Log file format: Use html headers and sections for readability and consistency.
- Log file content requirements (22 standard sections):
  - **Initial Request:** The original requirement or problem statement that prompted script creation
  - **Script Purpose:** Primary objective and use cases
  - **Core Requirements:** Essential functionality, constraints, and dependencies
  - **Development History/Phases:** Chronological record of development stages, refactoring, and major changes
  - **Global Variable Specifications:** Complete list of all GV_* variables with purpose, default values, and type information
  - **Execution Model:** How the script executes (background/foreground, user context, privilege escalation needs)
  - **Key Functions:** Detailed documentation of all functions including purpose, parameters, return values, and dependencies
  - **Command-Line Interface:** Parameter specifications, menu options, flag descriptions, and precedence rules
  - **Design Decisions & Rationale:** Major architectural choices and why they were made
  - **Compliance Checklist:** Verification points for coding standards, naming conventions, and documentation requirements
  - **Testing Checklist:** 25+ test scenarios covering normal operation, edge cases, error conditions, and integration points
  - **Deployment Notes:** Installation instructions, configuration guidance, and operational considerations
  - **Version History:** Complete changelog with dates, versions, and descriptions of changes
  - **Future Enhancements:** Proposed improvements, optimization opportunities, and potential new features (typically 5-10 items)
  - **Notes for Maintainers:** Tips, gotchas, common issues, and best practices for ongoing maintenance
  - **Related Scripts:** References to other scripts that integrate with or depend on this script
  - **Dependencies:** External commands, files, libraries, and tools required for operation
  - **Best Practices:** Code patterns, error handling approaches, and integration patterns to follow
  - Additional sections as needed for script-specific documentation (e.g., authentication methods, configuration files, output formats)
- Purpose of instruction logs:
  - Provide historical context for future maintainers
  - Document design decisions and trade-offs for long-term understanding
  - Serve as comprehensive testing and verification guidance
  - Record enhancement opportunities and technical debt for future work
  - Enable knowledge transfer across team members
- Update the log file whenever the script is significantly modified or enhanced to keep the development history current.
````
