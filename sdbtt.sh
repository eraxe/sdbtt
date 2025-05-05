#!/bin/bash
# SDBTT: Simple Database Transfer Tool
# Enhanced MySQL Database Import Script with Retrowave Theme
# Version: 1.3.0

# Default configuration
CONFIG_DIR="$HOME/.sdbtt"
CONFIG_FILE="$CONFIG_DIR/config.conf"
TEMP_DIR="/tmp/sdbtt_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sdbtt_$(date +%Y%m%d_%H%M%S).log"
DISPLAY_LOG_FILE="/tmp/sdbtt_display_log_$(date +%Y%m%d_%H%M%S)"
PASS_STORE="$CONFIG_DIR/.passstore"
VERSION="1.3.0"
REPO_URL="https://github.com/eraxe/sdbtt"

# Determine if we can use terminal colors
if [ -t 1 ]; then
    USE_COLORS=1
else
    USE_COLORS=0
fi

# Default behavior - can be changed by command line arguments
DEBUG=0
USE_DIALOG=1

# Function to output debug messages
debug_log() {
    if [ "$DEBUG" -eq 1 ]; then
        echo "[DEBUG] $1" >&2
    fi
}

# We need to ensure these variables are set for the dialog interface
export TERM=xterm-256color 2>/dev/null

# Ensure COLUMNS is defined for terminal operations
get_terminal_size() {
    debug_log "Getting terminal size"

    # Try different methods to get terminal size
    if [ -z "$COLUMNS" ]; then
        if command -v tput > /dev/null 2>&1; then
            COLUMNS=$(tput cols 2>/dev/null || echo 80)
        else
            COLUMNS=80
        fi
    fi

    if [ -z "$LINES" ]; then
        if command -v tput > /dev/null 2>&1; then
            LINES=$(tput lines 2>/dev/null || echo 24)
        else
            LINES=24
        fi
    fi

    export COLUMNS LINES
    debug_log "Terminal size: ${COLUMNS}x${LINES}"
}

# Enhanced theme settings with retrowave colors
setup_dialog_theme() {
    debug_log "Setting up dialog theme"

    # First verify dialog is available
    if ! command -v dialog > /dev/null 2>&1; then
        echo "ERROR: dialog command not found. Please install dialog package." >&2
        USE_DIALOG=0
        return 1
    fi

    # Try to determine if we can use colors
    if [ "$USE_COLORS" -eq 0 ]; then
        debug_log "Terminal doesn't support colors, skipping dialog theme"
        return 0
    fi

    # Create a unique temporary file for this process
    local dialogrc_file="/tmp/dialogrc_sdbtt_$"

    # Create the dialog configuration file with retrowave colors
    # Using more compatible dialog theme settings
    cat > "$dialogrc_file" << 'EOF'
# Dialog configuration with Retrowave theme
# Set aspect-ratio and screen edge
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = OFF
use_shadow = ON
use_colors = ON

# Retrowave color scheme for better compatibility
screen_color = (BLACK,BLACK,OFF)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (MAGENTA,BLACK,OFF)
title_color = (MAGENTA,BLACK,ON)
border_color = (MAGENTA,BLACK,ON)
button_active_color = (BLACK,MAGENTA,ON)
button_inactive_color = (CYAN,BLACK,OFF)
button_key_active_color = (BLACK,MAGENTA,ON)
button_key_inactive_color = (CYAN,BLACK,OFF)
button_label_active_color = (BLACK,MAGENTA,ON)
button_label_inactive_color = (CYAN,BLACK,OFF)
inputbox_color = (CYAN,BLACK,OFF)
inputbox_border_color = (MAGENTA,BLACK,ON)
searchbox_color = (CYAN,BLACK,OFF)
searchbox_title_color = (MAGENTA,BLACK,ON)
searchbox_border_color = (MAGENTA,BLACK,ON)
position_indicator_color = (YELLOW,BLACK,ON)
menubox_color = (CYAN,BLACK,OFF)
menubox_border_color = (MAGENTA,BLACK,ON)
item_color = (CYAN,BLACK,OFF)
item_selected_color = (BLACK,MAGENTA,ON)
tag_color = (MAGENTA,BLACK,ON)
tag_selected_color = (BLACK,MAGENTA,ON)
tag_key_color = (MAGENTA,BLACK,ON)
tag_key_selected_color = (BLACK,MAGENTA,ON)
check_color = (CYAN,BLACK,OFF)
check_selected_color = (BLACK,MAGENTA,ON)
uarrow_color = (MAGENTA,BLACK,ON)
darrow_color = (MAGENTA,BLACK,ON)
itemhelp_color = (CYAN,BLACK,OFF)
form_active_text_color = (BLACK,MAGENTA,ON)
form_text_color = (CYAN,BLACK,ON)
form_item_readonly_color = (CYAN,BLACK,ON)
gauge_color = (MAGENTA,BLACK,ON)
EOF

    # Set permissions
    chmod 644 "$dialogrc_file"

    # Export the environment variable
    export DIALOGRC="$dialogrc_file"

    # Verify the file exists and is readable
    if [ ! -f "$DIALOGRC" ] || [ ! -r "$DIALOGRC" ]; then
        echo "ERROR: Failed to create or access dialog configuration at $DIALOGRC" >&2
        unset DIALOGRC
        return 1
    fi

    debug_log "Dialog theme configured at $DIALOGRC"
    return 0
}

# Retrowave ANSI color codes for better compatibility
if [ "$USE_COLORS" -eq 1 ]; then
    RESET="\033[0m"
    BOLD="\033[1m"
    BLACK="\033[30m"
    RED="\033[31m"
    GREEN="\033[32m"
    YELLOW="\033[33m"
    BLUE="\033[34m"
    MAGENTA="\033[35m"
    CYAN="\033[36m"
    WHITE="\033[37m"
    # Bright colors for retrowave theme
    BRIGHTBLACK="\033[90m"
    BRIGHTRED="\033[91m"
    BRIGHTGREEN="\033[92m"
    BRIGHTYELLOW="\033[93m"
    BRIGHTBLUE="\033[94m"
    BRIGHTMAGENTA="\033[95m"
    BRIGHTCYAN="\033[96m"
    BRIGHTWHITE="\033[97m"
    # Background colors
    BGBLACK="\033[40m"
    BGRED="\033[41m"
    BGGREEN="\033[42m"
    BGYELLOW="\033[43m"
    BGBLUE="\033[44m"
    BGMAGENTA="\033[45m"
    BGCYAN="\033[46m"
    BGWHITE="\033[47m"
    BGBRIGHTBLACK="\033[100m"
    BGBRIGHTMAGENTA="\033[105m"
else
    # No colors in non-interactive mode or terminals without color support
    RESET=""
    BOLD=""
    BLACK=""
    RED=""
    GREEN=""
    YELLOW=""
    BLUE=""
    MAGENTA=""
    CYAN=""
    WHITE=""
    BRIGHTBLACK=""
    BRIGHTRED=""
    BRIGHTGREEN=""
    BRIGHTYELLOW=""
    BRIGHTBLUE=""
    BRIGHTMAGENTA=""
    BRIGHTCYAN=""
    BRIGHTWHITE=""
    BGBLACK=""
    BGRED=""
    BGGREEN=""
    BGYELLOW=""
    BGBLUE=""
    BGMAGENTA=""
    BGCYAN=""
    BGWHITE=""
    BGBRIGHTBLACK=""
    BGBRIGHTRED=""
    BGBRIGHTGREEN=""
    BGBRIGHTYELLOW=""
    BGBRIGHTBLUE=""
    BGBRIGHTMAGENTA=""
    BGBRIGHTCYAN=""
    BGBRIGHTWHITE=""
fi

# Retrowave color presets matching the theme
RW_PRIMARY="${BRIGHTMAGENTA}"
RW_SECONDARY="${BRIGHTBLUE}"
RW_ACCENT="${BRIGHTYELLOW}"
RW_ALERT="${BRIGHTRED}"
RW_SUCCESS="${BRIGHTGREEN}"
RW_WARNING="${YELLOW}"
RW_BG="${BGBLACK}"
RW_HEADER="${BRIGHTMAGENTA}${BOLD}"
RW_TEXT="${BRIGHTBLUE}"

# Verify dialog works properly - simplified with better error handling
check_dialog() {
    debug_log "Checking if dialog works properly"

    # Only do this check if we're using dialog
    if [ "$USE_DIALOG" -eq 0 ]; then
        debug_log "Dialog disabled, skipping check"
        return 1
    fi

    # Check for dialog command
    if ! command -v dialog >/dev/null 2>&1; then
        echo "ERROR: Dialog command not found" >&2
        USE_DIALOG=0
        return 1
    fi

    # Test dialog functionality quietly without creating any windows
    if ! dialog --print-version >/dev/null 2>&1; then
        echo "ERROR: Dialog not working properly" >&2
        USE_DIALOG=0
        return 1
    fi

    # Skip interactive checks to avoid issues
    debug_log "Dialog basic check passed"
    return 0
}

# Function to set terminal title and background - simplified for better compatibility
set_term_appearance() {
    debug_log "Setting terminal appearance"

    # Get terminal size
    get_terminal_size

    # Only perform these operations if we're in a terminal that supports colors
    if [ "$USE_COLORS" -eq 1 ]; then
        # Set terminal title
        echo -ne "\033]0;SDBTT - Retrowave\007"

        # Simple clear with basic retrowave effect
        clear
        # Top border
        echo -e "${BGBLACK}${BRIGHTMAGENTA}$(printf '%*s' ${COLUMNS} | tr ' ' '═')${RESET}"

        # Empty space with black background
        for i in {1..3}; do
            echo -e "${BGBLACK}$(printf '%*s' ${COLUMNS})${RESET}"
        done

        # Return cursor to top
        tput cup 0 0 2>/dev/null || true
    else
        # Simple fallback for terminals without color support
        clear
    fi

    debug_log "Terminal appearance set"
}

# Ensure required tools are installed
check_dependencies() {
    debug_log "Checking dependencies"

    local missing_deps=()

    for cmd in dialog mysql mysqldump sed awk git openssl curl iconv; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done

    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RW_ALERT}Error: Missing required dependencies: ${missing_deps[*]}${RESET}"
        echo "Please install them before running this script."
        exit 1
    fi

    debug_log "All dependencies found"
}

# Display fancy ASCII art header with retrowave colors
show_header() {
    debug_log "Showing header"

    # Return cursor to top (if possible)
    if command -v tput > /dev/null 2>&1; then
        tput cup 0 0 2>/dev/null || true
    fi

    # Using retrowave colors
    if [ "$USE_COLORS" -eq 1 ]; then
        echo -e "${RW_HEADER}"
        cat << "EOF"
 ██████╗██████╗ ██████╗ ████████╗████████╗
██╔════╝██╔══██╗██╔══██╗╚══██╔══╝╚══██╔══╝
╚█████╗ ██║  ██║██████╔╝   ██║      ██║
 ╚═══██╗██║  ██║██╔══██╗   ██║      ██║
██████╔╝██████╔╝██████╔╝   ██║      ██║
╚═════╝ ╚═════╝ ╚═════╝    ╚═╝      ╚═╝
EOF
        echo -e "${BRIGHTCYAN}░▒▓${BRIGHTMAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTMAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTMAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTMAGENTA}█${BRIGHTCYAN}▓▒░"
        echo -e "${RW_HEADER}Simple Database Transfer Tool v$VERSION${RESET}"
        echo -e "${BRIGHTCYAN}░▒▓${BRIGHTBLUE}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTBLUE}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTBLUE}█${BRIGHTCYAN}▓▒░${BRIGHTCYAN}░▒▓${BRIGHTBLUE}█${BRIGHTCYAN}▓▒░${RESET}"
    else
        # Plain text version for terminals without color support
        cat << EOF
==================================================
           SDBTT: Simple Database Transfer Tool
                     Version $VERSION
==================================================
EOF
    fi

    debug_log "Header displayed"
}

# Create required directories
initialize_directories() {
    debug_log "Initializing directories"

    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$TEMP_DIR"
    # Secure the configuration directory
    chmod 700 "$CONFIG_DIR"

    debug_log "Directories initialized"
}

# Enhanced log message function with timestamp and log levels
enhanced_log_message() {
    local level="$1"
    local message="$2"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")

    # Format based on level
    case "$level" in
        "INFO")
            prefix="[INFO]"
            ;;
        "WARNING")
            prefix="[WARNING]"
            ;;
        "ERROR")
            prefix="[ERROR]"
            ;;
        "SUCCESS")
            prefix="[SUCCESS]"
            ;;
        *)
            prefix="[INFO]"
            ;;
    esac

    # Write to main log file
    echo "[$timestamp] $prefix $message" >> "$LOG_FILE"

    # If we have an active display log file, write to it too
    if [ -f "$DISPLAY_LOG_FILE" ]; then
        echo "[$timestamp] $prefix $message" >> "$DISPLAY_LOG_FILE"
    fi
}

# Function to log messages - enhanced to also display to active log screen
log_message() {
    local message="$1"
    enhanced_log_message "INFO" "$message"
}

# Enhanced error handling with dialog support
enhanced_error_exit() {
    enhanced_log_message "ERROR" "$1"
    if command -v dialog &>/dev/null && [ -f "$DIALOGRC" ]; then
        dialog --title "Error" --colors --msgbox "\Z1ERROR: $1\Z0" 8 60
    else
        echo -e "${RW_ALERT}ERROR: $1${RESET}" >&2
    fi
    exit 1
}

# Function to handle errors with themed error messages
error_exit() {
    enhanced_log_message "ERROR" "$1"
    if command -v dialog &>/dev/null && [ -f "$DIALOGRC" ]; then
        dialog --title "Error" --colors --msgbox "\Z1ERROR: $1\Z0" 8 60
    else
        echo -e "${RW_ALERT}ERROR: $1${RESET}" >&2
    fi
    exit 1
}

# Function to check and test MySQL connection
check_mysql_connection() {
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
        return 1
    fi

    if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT 1" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Verify database exists
verify_database_exists() {
    local db_name="$1"

    local db_exists
    db_exists=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = '$db_name';" 2>/dev/null | grep -v "SCHEMA_NAME")

    if [ -n "$db_exists" ]; then
        return 0
    else
        return 1
    fi
}

# Securely store MySQL password
store_password() {
    local username="$1"
    local password="$2"

    # Generate a secure key for this user
    local key_file="$CONFIG_DIR/.key_$username"
    if [ ! -f "$key_file" ]; then
        openssl rand -base64 32 > "$key_file"
        chmod 600 "$key_file"
    fi

    # Encrypt the password using the key
    mkdir -p "$(dirname "$PASS_STORE")"
    echo "$password" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass file:"$key_file" -out "$PASS_STORE.$username" 2>/dev/null
    chmod 600 "$PASS_STORE.$username"

    log_message "Password securely stored for user $username"
}

# Retrieve securely stored MySQL password
get_password() {
    local username="$1"
    local password=""

    local key_file="$CONFIG_DIR/.key_$username"
    local pass_file="$PASS_STORE.$username"

    if [ -f "$key_file" ] && [ -f "$pass_file" ]; then
        password=$(openssl enc -aes-256-cbc -d -salt -pbkdf2 -pass file:"$key_file" -in "$pass_file" 2>/dev/null)
    fi

    echo "$password"
}

# Load saved configuration
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        # shellcheck source=/dev/null
        source "$CONFIG_FILE"
        return 0
    fi
    return 1
}

# Save current configuration
save_config() {
    mkdir -p "$CONFIG_DIR"
    cat > "$CONFIG_FILE" << EOF
# SDBTT Configuration
# Last updated: $(date)
SQL_DIR="$SQL_DIR"
DB_PREFIX="$DB_PREFIX"
MYSQL_USER="$MYSQL_USER"
DB_OWNER="$DB_OWNER"
SQL_PATTERN="$SQL_PATTERN"
LAST_DIRECTORIES="$LAST_DIRECTORIES"
EOF
    chmod 600 "$CONFIG_FILE"  # Secure permissions for config file
    dialog --colors --title "Configuration Saved" --msgbox "\Z6Settings have been saved to $CONFIG_FILE" 8 60
}

# Install the script to the system
install_script() {
    local install_dir="/usr/local/bin"
    local conf_dir="/etc/sdbtt"
    local script_name="sdbtt"
    local current_script="$0"
    local fullpath=$(readlink -f "$current_script")

    # Check if running with sudo/root
    if [ "$(id -u)" -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Installation requires root privileges. Please run with sudo." 8 60
        return 1
    fi

    # Create directories
    mkdir -p "$install_dir" "$conf_dir"

    # Copy script to install location
    cp "$fullpath" "$install_dir/$script_name"
    chmod 755 "$install_dir/$script_name"

    # Create global config
    if [ ! -f "$conf_dir/config.conf" ]; then
        cat > "$conf_dir/config.conf" << EOF
# SDBTT Global Configuration
VERSION="$VERSION"
EOF
    fi

    dialog --colors --title "Installation Complete" --msgbox "\Z6SDBTT has been installed to $install_dir/$script_name\n\nYou can now run it by typing 'sdbtt' in your terminal." 10 70
    return 0
}


# Enhanced update function with better UI feedback
update_script() {
    local temp_dir="/tmp/sdbtt_update_$(date +%s)"
    local current_dir=$(pwd)
    local update_log="$temp_dir/update.log"

    # Ensure we start with a clean directory
    if [ -d "$temp_dir" ]; then
        rm -rf "$temp_dir"
    fi

    # Create fresh temporary directory
    mkdir -p "$temp_dir"
    local update_log="$temp_dir/update.log"
    echo "[$(date)] Starting update process..." > "$update_log"

    # Create a tailbox for live update progress
    dialog --colors --title "Update Process" --begin 3 10 --tailbox "$update_log" 15 70 &
    local dialog_pid=$!

    # Clone the repository in background and log process
    {
        echo "[$(date)] Checking for updates from $REPO_URL..." >> "$update_log"

        cd "$temp_dir" || {
            echo "[$(date)] ERROR: Failed to create temporary directory" >> "$update_log"
            sleep 2
            kill $dialog_pid 2>/dev/null
            return 1
        }

        echo "[$(date)] Cloning repository..." >> "$update_log"

        # Clone the repository
        if ! git clone "$REPO_URL" repo 2>>$update_log; then
            echo "[$(date)] ERROR: Failed to clone repository. Check your internet connection and try again." >> "$update_log"
            sleep 3
            kill $dialog_pid 2>/dev/null
            cd "$current_dir" || true
            dialog --colors --title "Update Failed" --msgbox "\Z1Failed to clone repository. Check your internet connection and try again." 8 60
            rm -rf "$temp_dir"
            return 1
        fi

        # Change into the cloned repository directory
        cd repo || {
            echo "[$(date)] ERROR: Failed to access repository directory" >> "$update_log"
            sleep 2
            kill $dialog_pid 2>/dev/null
            cd "$current_dir" || true
            dialog --colors --title "Update Failed" --msgbox "\Z1Failed to access cloned repository." 8 60
            rm -rf "$temp_dir"
            return 1
        }

        # Kill tailbox before asking for confirmation
        sleep 1
        kill $dialog_pid 2>/dev/null

        # Confirm update - simplified message
        dialog --colors --title "Update Confirmation" --yesno "\Z6Do you want to update SDBTT to the latest version?\n\nThis will replace your current version with the latest from GitHub." 10 60

        if [ $? -eq 0 ]; then
            # User confirmed update
            echo "[$(date)] User confirmed update. Proceeding with installation..." > "$update_log"
            echo "Installing update, please wait..."

            # Find the main script file
            local script_file=""
            if [ -f "sdbtt" ]; then
                script_file="sdbtt"
            elif [ -f "sdbtt.sh" ]; then
                script_file="sdbtt.sh"
            else
                # Look for any shell script
                for file in *.sh; do
                    if [ -f "$file" ]; then
                        script_file="$file"
                        break
                    fi
                done
            fi

            if [ -z "$script_file" ]; then
                echo "[$(date)] ERROR: Could not find main script file in repository" >> "$update_log"
                dialog --colors --title "Update Failed" --msgbox "\Z1Could not find main script file in repository." 8 60
                cd "$current_dir" || true
                rm -rf "$temp_dir"
                return 1
            fi

            # Update the script
            echo "[$(date)] Found script file: $script_file" >> "$update_log"

            if [ -f "/usr/local/bin/sdbtt" ]; then
                echo "[$(date)] Detected system installation." >> "$update_log"
                if [ "$(id -u)" -ne 0 ]; then
                    echo "[$(date)] ERROR: Update requires root privileges for system installation." >> "$update_log"
                    cd "$current_dir" || true
                    dialog --title "Error" --msgbox "Update requires root privileges. Please run with sudo." 8 60
                    rm -rf "$temp_dir"
                    return 1
                fi

                echo "[$(date)] Updating system installation..." >> "$update_log"
                cp "$script_file" "/usr/local/bin/sdbtt" >> "$update_log" 2>&1
                chmod 755 "/usr/local/bin/sdbtt" >> "$update_log" 2>&1
                echo "[$(date)] System installation updated successfully." >> "$update_log"
            else
                echo "[$(date)] Updating current script..." >> "$update_log"
                cp "$script_file" "$0" >> "$update_log" 2>&1
                chmod 755 "$0" >> "$update_log" 2>&1
                echo "[$(date)] Script updated successfully." >> "$update_log"
            fi

            dialog --colors --title "Update Successful" --msgbox "\Z6SDBTT has been updated to the latest version.\n\nPlease restart the script for changes to take effect." 10 60

            # Cleanup and exit
            rm -rf "$temp_dir"
            cd "$current_dir" || true
            exit 0
        else
            dialog --colors --title "Update Cancelled" --msgbox "\Z6Update cancelled." 8 60
            rm -rf "$temp_dir"
            cd "$current_dir" || true
            return 0
        fi
    } &

    # Wait for background process to complete
    wait

    # Make sure dialog is killed
    kill $dialog_pid 2>/dev/null || true

    # Return to original directory
    cd "$current_dir" || true
    return 0
}

# Simplified check for updates function
check_for_updates() {
    dialog --colors --title "Check for Updates" --yesno "\Z6Would you like to check for and download the latest version of SDBTT from GitHub?\n\nThis will replace your current version with the latest available." 10 70

    if [ $? -eq 0 ]; then
        update_script
        return $?
    fi

    return 0
}
# Display the about information with enhanced colors
show_about() {
    dialog --colors --title "About SDBTT" --msgbox "\
\Z5Simple Database Transfer Tool (SDBTT) v$VERSION\Z0
\n
A tool for importing and managing MySQL databases with ease.
\n
\Z6Features:\Z0
- Interactive TUI with enhanced Retrowave theme
- Directory navigation and selection
- Secure password management
- Multiple import methods for compatibility
- MySQL database administration
- Auto-update from GitHub
- Transfer and replace databases
- MySQL user management
\n
\Z6GitHub:\Z0 $REPO_URL
\n
\Z5Created by:\Z0 eraxe
" 20 70
}

# Securely store database backup and restore function
backup_database() {
    local db_name="$1"
    local backup_dir="$CONFIG_DIR/backups"
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${db_name}_backup_${timestamp}.sql.gz"

    # Ensure backup directory exists
    mkdir -p "$backup_dir"

    # Check if database exists
    if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "USE \`$db_name\`" 2>/dev/null; then
        log_message "Database $db_name does not exist. No backup needed."
        return 0
    fi

    log_message "Creating backup of database $db_name to $backup_file"

    # Perform the backup with compression to save space
    if mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" --skip-extended-insert \
       --default-character-set=utf8mb4 \
       --add-drop-table --add-drop-database --routines --triggers \
       "$db_name" | gzip > "$backup_file"; then

        log_message "Backup of $db_name completed successfully."
        echo "$backup_file"
        return 0
    else
        log_message "ERROR: Backup of $db_name failed."
        return 1
    fi
}

# Restore database from backup
restore_database() {
    local db_name="$1"
    local backup_file="$2"

    if [ ! -f "$backup_file" ]; then
        log_message "ERROR: Backup file $backup_file does not exist."
        return 1
    fi

    log_message "Restoring database $db_name from backup $backup_file"

    # Drop existing database if it exists
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS \`$db_name\`;" 2>> "$LOG_FILE"

    # Create fresh database
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"

    # Restore from backup
    if [ "${backup_file##*.}" = "gz" ]; then
        # For gzipped backup
        zcat "$backup_file" | mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" 2>> "$LOG_FILE"
    else
        # For uncompressed backup
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" < "$backup_file" 2>> "$LOG_FILE"
    fi

    if [ $? -eq 0 ]; then
        log_message "Database $db_name restored successfully from backup."
        return 0
    else
        log_message "ERROR: Failed to restore database $db_name from backup."
        return 1
    fi
}

# Improved charset handling function with safety checks
# This fixes the issue with duplicate replacements like utf8mb4mb4
improved_charset_handling() {
    local input_file="$1"
    local output_file="$2"
    local log_file="$3"

    log_message "Applying charset fixes with improved pattern matching..."

    # Create a temporary file for incremental processing
    local temp_file="${output_file}.tmp"

    # First, copy the input file to temporary file
    cp "$input_file" "$temp_file"

    # Apply each replacement carefully to avoid duplication
    # Check if pattern already exists before replacing

    # Process for utf8mb3 first (special case)
    sed -i 's/utf8mb3/utf8mb4/g' "$temp_file"

    # Process main charset replacements with safeguards against duplications
    # The key improvement is using word boundaries and more specific matches
    sed -i \
        -e 's/\bSET NAMES utf8;\b/SET NAMES utf8mb4;/g' \
        -e 's/\bSET character_set_client = utf8;\b/SET character_set_client = utf8mb4;/g' \
        -e 's/\bDEFAULT CHARSET=utf8\b/DEFAULT CHARSET=utf8mb4/g' \
        -e 's/\bCHARSET=utf8\b/CHARSET=utf8mb4/g' \
        -e 's/\bCHARACTER SET utf8\b/CHARACTER SET utf8mb4/g' \
        -e 's/\bCOLLATE=utf8_general_ci\b/COLLATE=utf8mb4_unicode_ci/g' \
        -e 's/\bCOLLATE utf8_general_ci\b/COLLATE utf8mb4_unicode_ci/g' \
        "$temp_file"

    # Safer replacement for utf8 -> utf8mb4 (only where it's still just utf8)
    # This is the most risky replacement and caused the utf8mb4mb4 issues
    # So we'll use a more careful approach
    sed -i \
        -e 's/\butf8\b/utf8mb4/g' \
        -e 's/\bCOLLATE=utf8_/COLLATE=utf8mb4_/g' \
        "$temp_file"

    # Fix other syntax issues unrelated to charset
    sed -i \
        -e 's/^\s*\\-/-- -/g' \
        -e 's/SET @saved_cs_client     = @@character_set_client/SET @saved_cs_client = @@character_set_client/g' \
        "$temp_file"

    # Verify there are no invalid charset specifications
    if grep -q 'utf8mb4mb4\|utf8mb4mb4mb4\|utf8mb4mb4mb4mb4' "$temp_file"; then
        log_message "ERROR: Invalid charset detected after processing. Attempting to fix..."

        # Fix the double/triple/quad replacement errors
        sed -i \
            -e 's/utf8mb4mb4mb4mb4/utf8mb4/g' \
            -e 's/utf8mb4mb4mb4/utf8mb4/g' \
            -e 's/utf8mb4mb4/utf8mb4/g' \
            "$temp_file"

        # Verify again
        if grep -q 'utf8mb4mb4\|utf8mb4mb4mb4\|utf8mb4mb4mb4mb4' "$temp_file"; then
            log_message "ERROR: Critical charset error persists. The SQL file may be corrupted."
            log_message "Rolling back to original file."
            cp "$input_file" "$output_file"
            return 1
        fi
    fi

    # Move temporary file to output if all is well
    mv "$temp_file" "$output_file"

    log_message "Charset conversion completed successfully."
    return 0
}

# Create and initialize the database
create_database() {
    local db_name="$1"
    log_message "Creating database: $db_name with utf8mb4 charset"

    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS \`$db_name\`;" 2>> "$LOG_FILE" || {
        log_message "Warning: Could not drop database $db_name. Continuing..."
    }

    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE" || {
        error_exit "Failed to create database $db_name"
    }

    # Set encoding parameters - Make sure to use strict utf8mb4
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" -e "
        SET NAMES utf8mb4;
        SET character_set_client = utf8mb4;
        SET character_set_connection = utf8mb4;
        SET character_set_results = utf8mb4;
        SET collation_connection = utf8mb4_unicode_ci;" 2>> "$LOG_FILE"
}

# New function to attempt split import for complex SQL files
attempt_split_import() {
    local db_name="$1"
    local sql_file="$2"
    local split_dir="$TEMP_DIR/split_${db_name}"

    mkdir -p "$split_dir"
    log_message "Splitting SQL file for incremental import..."

    # Split file by SQL statements
    awk 'BEGIN{RS=";\n"; i=0} {i++; if(NF>0) print $0 ";" > "'$split_dir'/chunk_" sprintf("%05d", i) ".sql"}' "$sql_file"

    # Count chunks
    local chunk_count=$(ls -1 "$split_dir"/chunk_*.sql 2>/dev/null | wc -l)
    log_message "Split SQL file into $chunk_count chunks"

    if [ "$chunk_count" -eq 0 ]; then
        log_message "ERROR: Failed to split SQL file"
        return 1
    fi

    # Import chunks in order
    local success_count=0
    local error_count=0

    # Initialize database again
    create_database "$db_name"

    # Process chunks with progress updates
    local i=0
    for chunk in $(ls -1 "$split_dir"/chunk_*.sql | sort); do
        ((i++))
        local progress=$((i * 100 / chunk_count))

        log_message "Importing chunk $i of $chunk_count ($progress%)"

        # Try to import the chunk
        if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" < "$chunk" 2>> "$LOG_FILE"; then
            log_message "Warning: Chunk $i failed to import. Continuing with next chunk."
            ((error_count++))
        else
            ((success_count++))
        fi
    done

    log_message "Chunk import completed: $success_count succeeded, $error_count failed"

    # Check if we have tables
    local table_count
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)

    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        log_message "Split import created $table_count tables in $db_name"
        return 0
    else
        log_message "Split import failed to create any tables in $db_name"
        return 1
    fi
}

# Improved function to fix database charset with better error handling
fix_database_charset() {
    local db_name="$1"
    log_message "Fixing character sets and collations for tables and columns in $db_name"

    # Get list of all tables
    local tables
    tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)

    if [ -z "$tables" ]; then
        log_message "No tables found in database $db_name"
        return 1
    fi

    # Fix database charset first
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER DATABASE \`$db_name\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"

    local table_count=$(echo "$tables" | wc -w)
    local i=0

    for table in $tables; do
        ((i++))
        local progress=$((i * 100 / table_count))
        log_message "Fixing charset for table $i of $table_count: $table ($progress%)"

        # Convert table to utf8mb4
        if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER TABLE \`$db_name\`.\`$table\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"; then
            log_message "Warning: Failed to convert table $table to utf8mb4. Trying individual columns."

            # Get columns for this table
            local columns
            columns=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW COLUMNS FROM \`$db_name\`.\`$table\`;" 2>/dev/null | awk '{print $1}')

            # For each column of type CHAR, VARCHAR, TEXT, etc., convert to utf8mb4
            for column in $columns; do
                # Check if column is of string type
                local column_type
                column_type=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT DATA_TYPE FROM information_schema.COLUMNS WHERE TABLE_SCHEMA='$db_name' AND TABLE_NAME='$table' AND COLUMN_NAME='$column';" 2>/dev/null)

                # If column is a string type, modify it to utf8mb4
                if [[ "$column_type" == "char" || "$column_type" == "varchar" || "$column_type" == "text" ||
                      "$column_type" == "tinytext" || "$column_type" == "mediumtext" || "$column_type" == "longtext" ||
                      "$column_type" == "enum" || "$column_type" == "set" ]]; then
                    # Get the column definition
                    local column_def
                    column_def=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW FULL COLUMNS FROM \`$db_name\`.\`$table\` WHERE Field='$column';" 2>/dev/null | awk '{print $2}')

                    # Modify column to use utf8mb4
                    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER TABLE \`$db_name\`.\`$table\` MODIFY COLUMN \`$column\` $column_def CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"
                fi
            done
        fi
    done

    log_message "Character set and collation fixes completed for all tables in $db_name"
    return 0
}

# Improved import_sql_file function with better error handling and backup/restore
improved_import_sql_file() {
    local db_name="$1"
    local sql_file="$2"
    local processed_file="$3"

    log_message "Preparing to import $sql_file into database $db_name"

    # First, analyze the file encoding
    local file_encoding
    if command -v file >/dev/null 2>&1; then
        file_encoding=$(file -bi "$sql_file" | sed -e 's/.*charset=//')
        log_message "Detected file encoding: $file_encoding"
    else
        file_encoding="unknown"
        log_message "Could not detect file encoding (file command not available)"
    fi

    # Create a backup of the database if it exists
    local backup_file=""
    if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "USE \`$db_name\`" 2>/dev/null; then
        log_message "Database $db_name already exists. Creating backup before import."
        backup_file=$(backup_database "$db_name")
        if [ $? -ne 0 ]; then
            log_message "WARNING: Failed to create backup of existing database $db_name. Proceeding with caution."
        else
            log_message "Backup created at: $backup_file"
        fi
    fi

    # Process the SQL file with encoding fixes - convert to UTF-8 if needed
    log_message "Converting file to UTF-8 with encoding fixes..."

    # Create a temporary directory for intermediary processed files
    local tmp_process_dir="$TEMP_DIR/process_$db_name"
    mkdir -p "$tmp_process_dir"

    # First step: Convert encoding to UTF-8 if needed
    local utf8_file="$tmp_process_dir/utf8_converted.sql"

    if [ "$file_encoding" = "unknown" ] || [ "$file_encoding" = "utf-8" ] || [ "$file_encoding" = "us-ascii" ]; then
        # File is already UTF-8 or ASCII (subset of UTF-8), just copy
        cp "$sql_file" "$utf8_file"
    else
        # Try to convert to UTF-8
        if command -v iconv >/dev/null 2>&1; then
            log_message "Converting from $file_encoding to UTF-8 with iconv..."
            if ! iconv -f "$file_encoding" -t UTF-8//TRANSLIT "$sql_file" > "$utf8_file" 2>> "$LOG_FILE"; then
                log_message "Warning: iconv conversion failed, trying direct copy..."
                cp "$sql_file" "$utf8_file"
            fi
        else
            # No iconv available, just copy and hope for the best
            log_message "Warning: iconv not available, using original file..."
            cp "$sql_file" "$utf8_file"
        fi
    fi

    # Second step: Fix charset declarations and other issues using improved charset handling
    log_message "Applying charset fixes and other corrections..."
    if ! improved_charset_handling "$utf8_file" "$processed_file" "$LOG_FILE"; then
        log_message "ERROR: Failed to process charset in SQL file."
        if [ -n "$backup_file" ]; then
            log_message "Attempting to restore database from backup..."
            restore_database "$db_name" "$backup_file"
        fi
        return 1
    fi

    log_message "File processed for encoding issues. Attempting import..."

    # Create or reset the database
    create_database "$db_name"

    # Create a table counter file to monitor progress
    local table_counter_file="$TEMP_DIR/${db_name}_table_count.txt"
    echo "0" > "$table_counter_file"

    # Try direct import with charset parameters
    log_message "Attempting direct import with charset parameters for $db_name..."
    if mysql --default-character-set=utf8mb4 -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" < "$processed_file" 2> "$TEMP_DIR/${db_name}_import_errors.log"; then
        # Count tables to verify success
        local table_count
        table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)

        if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
            log_message "Import successful - $table_count tables created in $db_name"
            fix_database_charset "$db_name"
            return 0
        fi
    fi

    # Check the error log for specific issues
    log_message "Direct import encountered issues. Analyzing errors..."
    cat "$TEMP_DIR/${db_name}_import_errors.log" >> "$LOG_FILE"

    # Count specific error types to better understand issues
    local charset_errors=$(grep "Unknown character set" "$TEMP_DIR/${db_name}_import_errors.log" | wc -l)
    local table_errors=$(grep "Table.*doesn't exist" "$TEMP_DIR/${db_name}_import_errors.log" | wc -l)
    local syntax_errors=$(grep "syntax error" "$TEMP_DIR/${db_name}_import_errors.log" | wc -l)

    log_message "Error analysis: Charset errors: $charset_errors, Table missing errors: $table_errors, Syntax errors: $syntax_errors"

    # Try alternative method: Use SOURCE command
    log_message "Attempting import with SOURCE command..."
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" -e "SOURCE $processed_file;" 2> "$TEMP_DIR/${db_name}_source_errors.log"

    # Check if import was successful
    local table_count
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)

    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        log_message "Import via SOURCE command successful - $table_count tables created in $db_name"
        fix_database_charset "$db_name"
        return 0
    fi

    # If we're here, both methods failed
    cat "$TEMP_DIR/${db_name}_source_errors.log" >> "$LOG_FILE"
    log_message "Both import methods failed. As a last resort, trying split SQL import..."

    # Try import by splitting file
    if attempt_split_import "$db_name" "$processed_file"; then
        log_message "Split SQL import successful for $db_name"
        fix_database_charset "$db_name"
        return 0
    fi

    # All import methods failed, restore from backup
    log_message "All import methods failed for $db_name"

    if [ -n "$backup_file" ]; then
        log_message "Restoring database from backup..."
        restore_database "$db_name" "$backup_file"
        log_message "Database restored to previous state."
    fi

    log_message "Import failed. Manual inspection required:"
    log_message "mysql -u root -p --default-character-set=utf8mb4"
    log_message "CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
    log_message "USE $db_name;"
    log_message "SOURCE $sql_file;"
    return 1
}

# Improved grant privileges with user checking
improved_grant_privileges() {
    local db_name="$1"
    local db_owner="$2"

    log_message "Verifying user '$db_owner' exists before granting privileges..."

    # Check if the user exists
    local user_exists
    user_exists=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(*) FROM mysql.user WHERE User='$db_owner';" 2>/dev/null)

    if [ -z "$user_exists" ] || [ "$user_exists" -eq 0 ]; then
        log_message "User '$db_owner' doesn't exist. Creating user..."

        # Generate a secure random password
        local password
        password=$(openssl rand -base64 12)

        # Create the user
        if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE USER '$db_owner'@'localhost' IDENTIFIED BY '$password';" 2>> "$LOG_FILE"; then
            log_message "User '$db_owner' created successfully with password: $password"
            log_message "IMPORTANT: Save this password securely!"
        else
            log_message "Failed to create user '$db_owner'"
            return 1
        fi
    fi

    log_message "Granting privileges on $db_name to user '$db_owner'..."
    if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_owner'@'localhost';" 2>> "$LOG_FILE"; then
        log_message "Privileges granted successfully to $db_owner on database $db_name"

        # Flush privileges to ensure changes take effect
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>> "$LOG_FILE"
        return 0
    else
        log_message "Failed to grant privileges on $db_name to $db_owner"
        return 1
    fi
}

# Grant privileges to database owner
grant_privileges() {
    improved_grant_privileges "$1" "$2"
}

# Enhanced database information display with more details
show_database_details() {
    local db_name="$1"

    # Verify database exists
    if ! verify_database_exists "$db_name"; then
        dialog --colors --title "Error" --msgbox "\Z1Database '$db_name' does not exist." 8 60
        return 1
    fi

    # Get database statistics
    local result=""

    # General database info
    local charset=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT DEFAULT_CHARACTER_SET_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$db_name';" 2>/dev/null)
    local collation=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT DEFAULT_COLLATION_NAME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$db_name';" 2>/dev/null)
    local creation_time=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT CREATE_TIME FROM information_schema.SCHEMATA WHERE SCHEMA_NAME = '$db_name';" 2>/dev/null)

    # Table statistics
    local tables_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(*) FROM information_schema.TABLES WHERE TABLE_SCHEMA = '$db_name';" 2>/dev/null)
    local views_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(*) FROM information_schema.VIEWS WHERE TABLE_SCHEMA = '$db_name';" 2>/dev/null)
    local triggers_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(*) FROM information_schema.TRIGGERS WHERE TRIGGER_SCHEMA = '$db_name';" 2>/dev/null)
    local routines_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(*) FROM information_schema.ROUTINES WHERE ROUTINE_SCHEMA = '$db_name';" 2>/dev/null)

    # Size calculations
    local size_info=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
    SELECT
        ROUND(SUM(data_length) / 1024 / 1024, 2) as data_size,
        ROUND(SUM(index_length) / 1024 / 1024, 2) as index_size,
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) as total_size
    FROM information_schema.TABLES
    WHERE table_schema = '$db_name';" 2>/dev/null)

    local data_size=$(echo "$size_info" | awk '{print $1}')
    local index_size=$(echo "$size_info" | awk '{print $2}')
    local total_size=$(echo "$size_info" | awk '{print $3}')

    # Format the output with detailed information
    result="\Z5Database Details: $db_name\Z0\n\n"
    result+="Character Set: \Z6$charset\Z0\n"
    result+="Collation: \Z6$collation\Z0\n"
    result+="Creation Time: \Z6$creation_time\Z0\n\n"

    result+="\Z5Structure:\Z0\n"
    result+="Tables: \Z6$tables_count\Z0\n"
    result+="Views: \Z6$views_count\Z0\n"
    result+="Triggers: \Z6$triggers_count\Z0\n"
    result+="Stored Procedures/Functions: \Z6$routines_count\Z0\n\n"

    result+="\Z5Size Information:\Z0\n"
    result+="Data Size: \Z6${data_size} MB\Z0\n"
    result+="Index Size: \Z6${index_size} MB\Z0\n"
    result+="Total Size: \Z6${total_size} MB\Z0\n\n"

    # Get table list with row counts and sizes
    local tables_info=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT
        t.TABLE_NAME AS 'Table Name',
        t.TABLE_ROWS AS 'Approx. Rows',
        t.ENGINE AS 'Engine',
        ROUND((t.DATA_LENGTH + t.INDEX_LENGTH) / 1024 / 1024, 2) AS 'Size (MB)'
    FROM information_schema.TABLES t
    WHERE t.TABLE_SCHEMA = '$db_name'
    ORDER BY (t.DATA_LENGTH + t.INDEX_LENGTH) DESC;" 2>/dev/null)

    if [ -n "$tables_info" ]; then
        result+="\Z5Table Information:\Z0\n$tables_info\n\n"
    fi

    # Get users with privileges on this database
    local users_info=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT
        User,
        Host,
        SUBSTRING_INDEX(GROUP_CONCAT(PRIVILEGE_TYPE), ',', 3) AS 'Sample Privileges'
    FROM information_schema.USER_PRIVILEGES
    WHERE GRANTEE LIKE '%@%'
    GROUP BY User, Host
    ORDER BY User;" 2>/dev/null)

    if [ -n "$users_info" ]; then
        result+="\Z5User Access:\Z0\n$users_info\n"
    fi

    # Display the formatted output
    dialog --colors --title "Database Information: $db_name" --msgbox "$result" 30 80
}

# Backup database with progress indicator
backup_database_with_progress() {
    local db_name="$1"

    # Verify database exists
    if ! verify_database_exists "$db_name"; then
        dialog --colors --title "Error" --msgbox "\Z1Database '$db_name' does not exist." 8 60
        return 1
    fi

    # Ask for backup options
    local choice
    choice=$(dialog --colors --clear --backtitle "\Z6SDBTT MySQL Backup\Z0" \
        --title "Backup Options" --menu "Choose backup format:" 15 60 4 \
        "1" "\Z6Compressed SQL backup (gzip)\Z0" \
        "2" "\Z6Plain SQL backup\Z0" \
        "3" "\Z6Custom backup with selected tables\Z0" \
        "4" "\Z1Cancel\Z0" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            backup_type="compressed"
            backup_ext=".sql.gz"
            ;;
        2)
            backup_type="plain"
            backup_ext=".sql"
            ;;
        3)
            backup_type="custom"
            backup_ext=".sql.gz"
            select_tables_for_backup "$db_name"
            return $?
            ;;
        4|"")
            return 0
            ;;
    esac

    # Set backup directory and filename
    local backup_dir="$CONFIG_DIR/backups"
    mkdir -p "$backup_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${db_name}_backup_${timestamp}${backup_ext}"

    # Create a temporary log file for backup progress
    local backup_log="/tmp/sdbtt_backup_$$.log"
    echo "Starting backup of database '$db_name'" > "$backup_log"

    # Calculate an estimate of the database size for progress
    local db_size=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
        SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
        FROM information_schema.tables
        WHERE table_schema = '$db_name';" 2>/dev/null)

    echo "Estimated database size: ${db_size} MB" >> "$backup_log"

    # Display progress dialog
    dialog --title "Backup Progress" --tailbox "$backup_log" 15 70 &
    local dialog_pid=$!

    # Run the backup process in background
    {
        echo "Beginning backup process... this may take a while" >> "$backup_log"

        # Get the table count for better progress reporting
        local table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = '$db_name';" 2>/dev/null)

        echo "Total tables to backup: $table_count" >> "$backup_log"

        # Create a temporary status file that mysqldump will update
        local status_file="/tmp/sdbtt_dump_status_$$.txt"

        if [ "$backup_type" = "compressed" ]; then
            echo "Creating compressed backup..." >> "$backup_log"

            # Use mysqldump with progress reporting
            if mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" \
               --verbose --debug-info \
               --default-character-set=utf8mb4 \
               --add-drop-database --add-drop-table \
               --routines --triggers --events \
               --single-transaction \
               "$db_name" 2> "$status_file" | gzip > "$backup_file"; then
                echo "Backup completed successfully" >> "$backup_log"
                backup_status="success"
            else
                echo "Backup failed" >> "$backup_log"
                cat "$status_file" >> "$backup_log"
                backup_status="failure"
            fi
        else
            echo "Creating plain SQL backup..." >> "$backup_log"

            # Use mysqldump with progress reporting
            if mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" \
               --verbose --debug-info \
               --default-character-set=utf8mb4 \
               --add-drop-database --add-drop-table \
               --routines --triggers --events \
               --single-transaction \
               "$db_name" 2> "$status_file" > "$backup_file"; then
                echo "Backup completed successfully" >> "$backup_log"
                backup_status="success"
            else
                echo "Backup failed" >> "$backup_log"
                cat "$status_file" >> "$backup_log"
                backup_status="failure"
            fi
        fi

        # Calculate final backup size
        if [ -f "$backup_file" ]; then
            local final_size=$(du -h "$backup_file" | cut -f1)
            echo "Backup file size: $final_size" >> "$backup_log"
        fi

        # Clean up status file
        rm -f "$status_file"

        # Kill the dialog process
        kill $dialog_pid 2>/dev/null || true

        # Display completion message
        if [ "$backup_status" = "success" ]; then
            dialog --colors --title "Backup Complete" --msgbox "\Z6Backup of database '$db_name' completed successfully.\n\nBackup saved to:\Z0\n$backup_file" 10 70
        else
            dialog --colors --title "Backup Failed" --msgbox "\Z1Backup of database '$db_name' failed.\n\nSee log file for details.\Z0" 8 70

            # Show the backup log
            dialog --colors --title "Backup Log" --textbox "$backup_log" 20 76
        fi

        # Clean up temporary log
        rm -f "$backup_log"

    } &

    # Wait for the background process to complete
    wait
}

# Check database integrity with enhanced UI
check_database_integrity() {
    local db_name
    db_name=$(dialog --colors --title "Check Database Integrity" --inputbox "Enter database name:" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$db_name" ]; then
        return
    fi

    # Check if database exists
    local db_exists
    db_exists=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES LIKE '$db_name';" 2>/dev/null)

    if [ -z "$db_exists" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Database '$db_name' does not exist." 8 60
        return
    fi

    # Get all tables in the database
    local tables
    tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null | tail -n +2)

    if [ -z "$tables" ]; then
        dialog --colors --title "No Tables" --msgbox "\Z1Database '$db_name' has no tables to check." 8 60
        return
    fi

    # Create a temporary log file for check progress
    local check_log_file="/tmp/sdbtt_check_$.log"
    echo "Starting integrity check for database '$db_name'" > "$check_log_file"

    # Calculate total tables for progress
    local total=$(echo "$tables" | wc -l)

    # Use a split display - progress gauge on top, log tail at bottom
    dialog --colors --title "Checking Database Integrity" \
           --mixedgauge "Preparing to check tables in $db_name..." 0 70 0 \
           "Progress" "0%" "Remaining" "100%" 2>/dev/null &
    local dialog_pid=$!

    # Open a tail dialog for the log
    dialog --colors --title "Check Log" --begin 10 5 --tailbox "$check_log_file" 15 70 &
    local tail_pid=$!

    {
        local i=0
        for table in $tables; do
            i=$((i + 1))
            progress=$((i * 100 / total))
            remaining=$((100 - progress))

            # Update the log file
            echo "[$i/$total] Checking table: $table" >> "$check_log_file"

            # Update the progress gauge
            dialog --colors --title "Checking Database Integrity" \
                   --mixedgauge "Checking tables in $db_name..." 0 70 $progress \
                   "Progress" "$progress%" "Remaining" "$remaining%" 2>/dev/null

            # Perform the check
            result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CHECK TABLE \`$db_name\`.\`$table\`;" 2>&1)
            echo "Result: " >> "$check_log_file"
            echo "$result" >> "$check_log_file"
            echo "----------------------------------------" >> "$check_log_file"

            # Small delay for visibility
            sleep 0.1
        done

        # Mark as complete
        echo "Integrity check complete for all $total tables in $db_name" >> "$check_log_file"

        # Final progress update - 100%
        dialog --colors --title "Checking Database Integrity" \
               --mixedgauge "Checking tables in $db_name..." 0 70 100 \
               "Progress" "100%" "Remaining" "0%" 2>/dev/null

        # Give time to see the final state
        sleep 2

        # Kill the dialog processes
        kill $dialog_pid 2>/dev/null || true
        kill $tail_pid 2>/dev/null || true

        # Show completion dialog
        dialog --colors --title "Integrity Check Complete" --msgbox "\Z6All tables in database '$db_name' have been checked.\n\nSee full details in the check log." 8 70

        # Display the log in a scrollable viewer
        dialog --colors --title "Integrity Check Results" --textbox "$check_log_file" 20 76

        # Clean up
        rm -f "$check_log_file"

    } &

    # Wait for the background process to complete
    wait
}

# Show MySQL server status with enhanced formatting
show_mysql_status() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW STATUS;" 2>/dev/null)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve MySQL status." 8 60
        return
    fi

    # Format important status variables with enhanced coloring
    local formatted_result
    formatted_result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SHOW GLOBAL STATUS WHERE
    Variable_name = 'Uptime' OR
    Variable_name = 'Threads_connected' OR
    Variable_name = 'Queries' OR
    Variable_name = 'Connections' OR
    Variable_name = 'Aborted_connects' OR
    Variable_name = 'Created_tmp_tables' OR
    Variable_name = 'Innodb_buffer_pool_reads' OR
    Variable_name = 'Innodb_buffer_pool_read_requests' OR
    Variable_name = 'Bytes_received' OR
    Variable_name = 'Bytes_sent';" 2>/dev/null)

    # Format MySQL version with enhanced coloring
    local version
    version=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT VERSION();" 2>/dev/null)

    # Format the output with enhanced theming
    formatted_result=$(echo -e "\Z5MySQL Version:\Z0\n$version\n\n\Z5Status Variables:\Z0\n$formatted_result" |
                      sed 's/Variable_name/\\Z6Variable_name\\Z0/g' |
                      sed 's/Value/\\Z6Value\\Z0/g')

    dialog --colors --title "MySQL Server Status" --msgbox "$formatted_result" 20 70
}

# Create MySQL user with enhanced UI
create_mysql_user() {
    # Get system/DirectAdmin users if available
    local system_users=()

    if command -v getent >/dev/null 2>&1; then
        # Get real system users with UID >= 1000
        while IFS=: read -r user _ uid _; do
            if [ "$uid" -ge 1000 ] && [ "$uid" -ne 65534 ]; then
                system_users+=("$user")
            fi
        done < <(getent passwd)
    fi

    # If DirectAdmin environment
    if [ -d "/usr/local/directadmin" ]; then
        if [ -f "/usr/local/directadmin/data/users/users.list" ]; then
            while IFS= read -r user; do
                # Add only if not already in the list
                if ! [[ " ${system_users[@]} " =~ " ${user} " ]]; then
                    system_users+=("$user")
                fi
            done < <(cat "/usr/local/directadmin/data/users/users.list")
        fi
    fi

    # If no system users found, allow manual entry
    local system_user
    if [ ${#system_users[@]} -eq 0 ]; then
        system_user=$(dialog --colors --title "System User" --inputbox "Enter system/DirectAdmin username this MySQL user belongs to:" 8 60 3>&1 1>&2 2>&3)
        if [ -z "$system_user" ]; then
            return
        fi
    else
        # Create a menu to select from available system users
        local options=()
        for user in "${system_users[@]}"; do
            options+=("$user" "System user: $user")
        done
        options+=("manual" "Enter a different username")

        system_user=$(dialog --colors --title "Select System User" --menu "Select the system user this MySQL user belongs to:" 15 60 8 "${options[@]}" 3>&1 1>&2 2>&3)

        if [ -z "$system_user" ]; then
            return
        fi

        if [ "$system_user" = "manual" ]; then
            system_user=$(dialog --colors --title "System User" --inputbox "Enter system/DirectAdmin username this MySQL user belongs to:" 8 60 3>&1 1>&2 2>&3)
            if [ -z "$system_user" ]; then
                return
            fi
        fi
    fi

    # Get MySQL username
    local mysql_user
    mysql_user=$(dialog --colors --title "MySQL Username" --inputbox "Enter new MySQL username (or press Enter to use default format ${system_user}_user):" 8 70 3>&1 1>&2 2>&3)

    if [ -z "$mysql_user" ]; then
        mysql_user="${system_user}_user"
    fi

    # Check if user already exists
    local user_exists
    user_exists=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User='$mysql_user';" 2>/dev/null | grep -c "$mysql_user")

    if [ "$user_exists" -gt 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1MySQL user '$mysql_user' already exists." 8 60
        return
    fi

    # Get password
    local password
    password=$(dialog --colors --title "MySQL Password" --passwordbox "Enter password for '$mysql_user':" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$password" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Password cannot be empty." 8 60
        return
    fi

    # Confirm password
    local confirm_password
    confirm_password=$(dialog --colors --title "Confirm Password" --passwordbox "Confirm password for '$mysql_user':" 8 60 3>&1 1>&2 2>&3)

    if [ "$password" != "$confirm_password" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Passwords do not match." 8 60
        return
    fi

    # Create the user
    local create_result
    create_result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE USER '$mysql_user'@'localhost' IDENTIFIED BY '$password';" 2>&1)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to create MySQL user '$mysql_user'.\n\nError: $create_result" 10 60
        return
    fi

    # Ask if user wants to grant privileges to any database
    dialog --colors --title "Grant Privileges" --yesno "Do you want to grant privileges to '$mysql_user' on any database?" 8 60

    if [ $? -eq 0 ]; then
        # Get list of databases
        local databases
        databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

        if [ -z "$databases" ]; then
            dialog --colors --title "No Databases" --msgbox "\Z1No user databases found." 8 60
            return
        fi

        # Create options for database selection
        local db_options=()
        for db in $databases; do
            db_options+=("$db" "Database: $db")
        done

        # Allow selecting multiple databases
        local selected_dbs
        selected_dbs=$(dialog --colors --title "Select Databases" --checklist "Select databases to grant privileges to '$mysql_user':" 15 60 8 "${db_options[@]}" 3>&1 1>&2 2>&3)

        if [ -n "$selected_dbs" ]; then
            # Remove quotes from the output
            selected_dbs=$(echo "$selected_dbs" | tr -d '"')

            for db in $selected_dbs; do
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$mysql_user'@'localhost';" 2>/dev/null

                if [ $? -ne 0 ]; then
                    dialog --colors --title "Warning" --msgbox "\Z3Warning: Failed to grant privileges on database '$db' to user '$mysql_user'." 8 70
                fi
            done

            # Flush privileges
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

            dialog --colors --title "Success" --msgbox "\Z6MySQL user '$mysql_user' created successfully and granted privileges on selected databases." 8 70
        else
            dialog --colors --title "Success" --msgbox "\Z6MySQL user '$mysql_user' created successfully without any database privileges." 8 70
        fi
    else
        dialog --colors --title "Success" --msgbox "\Z6MySQL user '$mysql_user' created successfully." 8 70
    fi
}

# Change MySQL user password
change_mysql_password() {
    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No Users" --msgbox "\Z1No MySQL users found." 8 60
        return
    fi

    # Create options for user selection
    local user_options=()
    for user in $users; do
        user_options+=("$user" "MySQL user: $user")
    done

    # Select user
    local selected_user
    selected_user=$(dialog --colors --title "Select User" --menu "Select MySQL user to change password:" 15 60 8 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_user" ]; then
        return
    fi

    # Get new password
    local password
    password=$(dialog --colors --title "New Password" --passwordbox "Enter new password for '$selected_user':" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$password" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Password cannot be empty." 8 60
        return
    fi

    # Confirm password
    local confirm_password
    confirm_password=$(dialog --colors --title "Confirm Password" --passwordbox "Confirm new password for '$selected_user':" 8 60 3>&1 1>&2 2>&3)

    if [ "$password" != "$confirm_password" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Passwords do not match." 8 60
        return
    fi

    # Change password
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER USER '$selected_user'@'localhost' IDENTIFIED BY '$password';" 2>&1)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to change password for '$selected_user'.\n\nError: $result" 10 60
        return
    fi

    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

    dialog --colors --title "Success" --msgbox "\Z6Password for MySQL user '$selected_user' changed successfully." 8 70
}

# Delete MySQL user
delete_mysql_user() {
    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No Users" --msgbox "\Z1No MySQL users found." 8 60
        return
    fi

    # Create options for user selection
    local user_options=()
    for user in $users; do
        user_options+=("$user" "MySQL user: $user")
    done

    # Select user
    local selected_user
    selected_user=$(dialog --colors --title "Select User" --menu "Select MySQL user to delete:" 15 60 8 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_user" ]; then
        return
    fi

    # Confirm deletion
    dialog --colors --title "Confirm Deletion" --yesno "\Z1Are you sure you want to delete MySQL user '$selected_user'?\n\nThis action cannot be undone." 8 70

    if [ $? -ne 0 ]; then
        return
    fi

    # Delete user
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP USER '$selected_user'@'localhost';" 2>&1)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to delete MySQL user '$selected_user'.\n\nError: $result" 10 60
        return
    fi

    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

    dialog --colors --title "Success" --msgbox "\Z6MySQL user '$selected_user' deleted successfully." 8 70
}

# Start the script
main "$@"
}

# Select tables for custom backup
select_tables_for_backup() {
    local db_name="$1"

    # Get list of tables
    local tables
    tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)

    if [ -z "$tables" ]; then
        dialog --colors --title "No Tables" --msgbox "\Z1Database '$db_name' has no tables." 8 60
        return 1
    fi

    # Create options for table selection
    local table_options=()
    for table in $tables; do
        # Get row count and size for each table
        local table_info=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
        SELECT
            TABLE_ROWS,
            ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 2)
        FROM information_schema.TABLES
        WHERE TABLE_SCHEMA = '$db_name' AND TABLE_NAME = '$table';" 2>/dev/null)

        local rows=$(echo "$table_info" | awk '{print $1}')
        local size=$(echo "$table_info" | awk '{print $2}')

        table_options+=("$table" "Table: $table (Rows: $rows, Size: ${size}MB)" "on")
    done

    # Allow selecting multiple tables
    local selected_tables
    selected_tables=$(dialog --colors --title "Select Tables" --checklist "Select tables to include in backup:" 20 76 15 "${table_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_tables" ]; then
        return 1
    fi

    # Remove quotes from the output
    selected_tables=$(echo "$selected_tables" | tr -d '"')

    # Set backup directory and filename
    local backup_dir="$CONFIG_DIR/backups"
    mkdir -p "$backup_dir"

    local timestamp=$(date +%Y%m%d_%H%M%S)
    local backup_file="$backup_dir/${db_name}_custom_backup_${timestamp}.sql.gz"

    # Create a temporary log file for backup progress
    local backup_log="/tmp/sdbtt_backup_$$.log"
    echo "Starting custom backup of selected tables from database '$db_name'" > "$backup_log"
    echo "Selected tables: $selected_tables" >> "$backup_log"

    # Display progress dialog
    dialog --title "Backup Progress" --tailbox "$backup_log" 15 70 &
    local dialog_pid=$!

    # Run the backup process in background
    {
        echo "Beginning backup process..." >> "$backup_log"

        # Create a temporary status file
        local status_file="/tmp/sdbtt_dump_status_$$.txt"

        # Use mysqldump with progress reporting and selected tables
        if mysqldump -u "$MYSQL_USER" -p"$MYSQL_PASS" \
           --verbose --debug-info \
           --default-character-set=utf8mb4 \
           --add-drop-table \
           --routines --triggers \
           --single-transaction \
           "$db_name" $selected_tables 2> "$status_file" | gzip > "$backup_file"; then
            echo "Backup completed successfully" >> "$backup_log"
            backup_status="success"
        else
            echo "Backup failed" >> "$backup_log"
            cat "$status_file" >> "$backup_log"
            backup_status="failure"
        fi

        # Calculate final backup size
        if [ -f "$backup_file" ]; then
            local final_size=$(du -h "$backup_file" | cut -f1)
            echo "Backup file size: $final_size" >> "$backup_log"
        fi

        # Clean up status file
        rm -f "$status_file"

        # Kill the dialog process
        kill $dialog_pid 2>/dev/null || true

        # Display completion message
        if [ "$backup_status" = "success" ]; then
            dialog --colors --title "Backup Complete" --msgbox "\Z6Custom backup of selected tables from database '$db_name' completed successfully.\n\nBackup saved to:\Z0\n$backup_file" 10 70
        else
            dialog --colors --title "Backup Failed" --msgbox "\Z1Custom backup of database '$db_name' failed.\n\nSee log file for details.\Z0" 8 70

            # Show the backup log
            dialog --colors --title "Backup Log" --textbox "$backup_log" 20 76
        fi

        # Clean up temporary log
        rm -f "$backup_log"

    } &

    # Wait for the background process to complete
    wait
}

# Restore database from backup with progress indicator
restore_database_with_progress() {
    # First, check for available backups
    local backup_dir="$CONFIG_DIR/backups"

    if [ ! -d "$backup_dir" ]; then
        dialog --colors --title "No Backups" --msgbox "\Z1No backup directory found at $backup_dir" 8 60
        return 1
    fi

    # Find all SQL and gzipped SQL backups
    local backups=()
    local i=1

    # List backup files
    while IFS= read -r backup; do
        if [ -f "$backup" ]; then
            local backup_date=$(basename "$backup" | grep -oE '[0-9]{8}_[0-9]{6}')
            local formatted_date=$(date -d "${backup_date:0:8} ${backup_date:9:2}:${backup_date:11:2}:${backup_date:13:2}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null || echo "$backup_date")
            local size=$(du -h "$backup" | cut -f1)
            backups+=("$backup" "[$i] \Z6$(basename "$backup")\Z0 (Date: $formatted_date, Size: $size)")
            ((i++))
        fi
    done < <(find "$backup_dir" -type f \( -name "*.sql" -o -name "*.sql.gz" \) | sort -r)

    if [ ${#backups[@]} -eq 0 ]; then
        dialog --colors --title "No Backups" --msgbox "\Z1No backup files found in $backup_dir" 8 60
        return 1
    fi

    # Add option to cancel
    backups+=("CANCEL" "\Z1Cancel operation\Z0")

    # Select backup file
    local selected_backup
    selected_backup=$(dialog --colors --clear --backtitle "\Z6SDBTT Restore Backup\Z0" \
        --title "Select Backup File" \
        --menu "Choose a backup file to restore:" 20 76 15 \
        "${backups[@]}" 3>&1 1>&2 2>&3)

    if [ "$selected_backup" = "CANCEL" ] || [ -z "$selected_backup" ]; then
        return 0
    fi

    # Determine database name from backup file
    local db_name=$(basename "$selected_backup" | sed -E 's/(.+)_backup_[0-9]{8}_[0-9]{6}(\.sql(\.gz)?)/\1/')

    # Ask for target database name (default to extracted name)
    local target_db
    target_db=$(dialog --colors --title "Target Database" --inputbox "Enter target database name for restore:" 8 60 "$db_name" 3>&1 1>&2 2>&3)

    if [ -z "$target_db" ]; then
        return 0
    fi

    # Check if target database exists
    if verify_database_exists "$target_db"; then
        dialog --colors --title "Warning" --defaultno --yesno "\Z1Database '$target_db' already exists.\n\nThis will DELETE all existing data in this database.\n\nAre you sure you want to continue?\Z0" 10 70

        if [ $? -ne 0 ]; then
            return 0
        fi

        # Create a backup of the existing database before overwriting
        dialog --colors --title "Backup Existing" --yesno "\Z3Would you like to create a backup of the existing database before restoring?\Z0" 8 70

        if [ $? -eq 0 ]; then
            dialog --infobox "Creating backup of existing database '$target_db'..." 5 60
            backup_database "$target_db" > /dev/null
        fi
    fi

    # Create a temporary log file for restore progress
    local restore_log="/tmp/sdbtt_restore_$$.log"
    echo "Starting restoration of database '$target_db' from backup $(basename "$selected_backup")" > "$restore_log"

    # Display progress dialog
    dialog --title "Restore Progress" --tailbox "$restore_log" 15 70 &
    local dialog_pid=$!

    # Run the restore process in background
    {
        echo "Beginning restore process..." >> "$restore_log"

        # Drop existing database if it exists
        echo "Dropping existing database if it exists..." >> "$restore_log"
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE IF EXISTS \`$target_db\`;" 2>> "$restore_log"

        # Create fresh database
        echo "Creating new database '$target_db'..." >> "$restore_log"
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE \`$target_db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$restore_log"

        # Restore based on file type
        if [[ "$selected_backup" == *.gz ]]; then
            echo "Decompressing and restoring from gzipped backup..." >> "$restore_log"
            if zcat "$selected_backup" | mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$target_db" 2>> "$restore_log"; then
                echo "Restoration from gzipped backup completed successfully" >> "$restore_log"
                restore_status="success"
            else
                echo "Restoration from gzipped backup failed" >> "$restore_log"
                restore_status="failure"
            fi
        else
            echo "Restoring from SQL backup..." >> "$restore_log"
            if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$target_db" < "$selected_backup" 2>> "$restore_log"; then
                echo "Restoration from SQL backup completed successfully" >> "$restore_log"
                restore_status="success"
            else
                echo "Restoration from SQL backup failed" >> "$restore_log"
                restore_status="failure"
            fi
        fi

        # Fix character sets
        if [ "$restore_status" = "success" ]; then
            echo "Fixing character sets and collations..." >> "$restore_log"
            fix_database_charset "$target_db" >> "$restore_log" 2>&1
        fi

        # Kill the dialog process
        kill $dialog_pid 2>/dev/null || true

        # Display completion message
        if [ "$restore_status" = "success" ]; then
            dialog --colors --title "Restore Complete" --msgbox "\Z6Restoration of database '$target_db' completed successfully." 8 70
        else
            dialog --colors --title "Restore Failed" --msgbox "\Z1Restoration of database '$target_db' failed.\n\nSee log file for details.\Z0" 8 70

            # Show the restore log
            dialog --colors --title "Restore Log" --textbox "$restore_log" 20 76
        fi

        # Clean up temporary log
        rm -f "$restore_log"

    } &

    # Wait for the background process to complete
    wait
}

# Rename database with safety checks
rename_database() {
    # Get list of databases
    local databases
    databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        dialog --colors --title "No Databases" --msgbox "\Z1No user databases found." 8 60
        return 1
    fi

    # Create options for database selection
    local db_options=()
    for db in $databases; do
        db_options+=("$db" "Database: $db")
    done

    # Select source database
    local source_db
    source_db=$(dialog --colors --title "Select Database" --menu "Select database to rename:" 15 60 10 "${db_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$source_db" ]; then
        return 0
    fi

    # Ask for new name
    local target_db
    target_db=$(dialog --colors --title "New Database Name" --inputbox "Enter new name for database '$source_db':" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$target_db" ]; then
        return 0
    fi

    # Check if target name already exists
    if verify_database_exists "$target_db"; then
        dialog --colors --title "Error" --msgbox "\Z1A database with the name '$target_db' already exists.\n\nPlease choose a different name." 8 70
        return 1
    fi

    # Confirm operation
    dialog --colors --title "Confirm Rename" --yesno "\Z3Are you sure you want to rename database '$source_db' to '$target_db'?\Z0" 8 70

    if [ $? -ne 0 ]; then
        return 0
    fi

    # Create a temporary log file for rename progress
    local rename_log="/tmp/sdbtt_rename_$$.log"
    echo "Starting rename of database '$source_db' to '$target_db'" > "$rename_log"

    # Display progress dialog
    dialog --title "Rename Progress" --tailbox "$rename_log" 15 70 &
    local dialog_pid=$!

    # Run the rename process in background
    {
        echo "Beginning rename process..." >> "$rename_log"

        # MySQL doesn't have a direct RENAME DATABASE command, so we need to:
        # 1. Create a new database
        # 2. Copy all tables and objects
        # 3. Drop the old database

        # Create new database
        echo "Creating new database '$target_db'..." >> "$rename_log"
        if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE DATABASE \`$target_db\` CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$rename_log"; then
            echo "Failed to create target database '$target_db'" >> "$rename_log"
            rename_status="failure"
            kill $dialog_pid 2>/dev/null || true
            dialog --colors --title "Rename Failed" --msgbox "\Z1Failed to create target database '$target_db'.\Z0" 8 70
            return 1
        fi

        # Get list of tables
        local tables
        tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$source_db\`;" 2>/dev/null)

        local total_tables=$(echo "$tables" | wc -w)
        echo "Total tables to move: $total_tables" >> "$rename_log"

        if [ -z "$tables" ]; then
            echo "No tables found in source database" >> "$rename_log"
        else
            local i=0
            for table in $tables; do
                ((i++))
                local progress=$((i * 100 / total_tables))

                echo "[$i/$total_tables] Moving table: $table ($progress%)" >> "$rename_log"

                # Move each table to the new database
                if ! mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "RENAME TABLE \`$source_db\`.\`$table\` TO \`$target_db\`.\`$table\`;" 2>> "$rename_log"; then
                    echo "Warning: Failed to move table $table. Will try alternative approach." >> "$rename_log"

                    # Alternative approach - create table with same structure and copy data
                    if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CREATE TABLE \`$target_db\`.\`$table\` LIKE \`$source_db\`.\`$table\`;" 2>> "$rename_log"; then
                        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "INSERT INTO \`$target_db\`.\`$table\` SELECT * FROM \`$source_db\`.\`$table\`;" 2>> "$rename_log"
                    else
                        echo "Error: Failed to move table $table using alternative approach" >> "$rename_log"
                    fi
                fi
            done
        fi

        # Copy routines (stored procedures and functions)
        echo "Copying stored procedures and functions..." >> "$rename_log"
        local routines
        routines=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT ROUTINE_NAME, ROUTINE_TYPE
            FROM information_schema.ROUTINES
            WHERE ROUTINE_SCHEMA = '$source_db';" 2>/dev/null)

        if [ -n "$routines" ]; then
            while read -r name type; do
                echo "Copying $type: $name" >> "$rename_log"

                # Get routine definition
                local definition
                definition=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
                    SHOW CREATE $type \`$source_db\`.\`$name\`;" 2>/dev/null | sed -e '1d')

                # Create in new database
                if [ -n "$definition" ]; then
                    # Replace the database name in the definition
                    definition=$(echo "$definition" | sed "s/\`$source_db\`/\`$target_db\`/g")

                    # Create the routine in the new database
                    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$target_db" -e "
                        DELIMITER //
                        $definition
                        DELIMITER ;" 2>> "$rename_log"
                fi
            done <<< "$routines"
        fi

        # Copy triggers
        echo "Copying triggers..." >> "$rename_log"
        local triggers
        triggers=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SHOW TRIGGERS FROM \`$source_db\`;" 2>/dev/null)

        if [ -n "$triggers" ]; then
            local trigger_names=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
                SELECT TRIGGER_NAME
                FROM information_schema.TRIGGERS
                WHERE EVENT_OBJECT_SCHEMA = '$source_db';" 2>/dev/null)

            for trigger in $trigger_names; do
                echo "Copying trigger: $trigger" >> "$rename_log"

                # Get trigger definition
                local trigger_def
                trigger_def=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
                    SHOW CREATE TRIGGER \`$source_db\`.\`$trigger\`;" 2>/dev/null | sed -e '1d')

                # Create in new database
                if [ -n "$trigger_def" ]; then
                    # Replace the database name in the definition
                    trigger_def=$(echo "$trigger_def" | sed "s/\`$source_db\`/\`$target_db\`/g")

                    # Create the trigger in the new database
                    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$target_db" -e "
                        DELIMITER //
                        $trigger_def
                        DELIMITER ;" 2>> "$rename_log"
                fi
            done
        fi

        # Copy views
        echo "Copying views..." >> "$rename_log"
        local views
        views=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT TABLE_NAME
            FROM information_schema.VIEWS
            WHERE TABLE_SCHEMA = '$source_db';" 2>/dev/null)

        if [ -n "$views" ]; then
            for view in $views; do
                echo "Copying view: $view" >> "$rename_log"

                # Get view definition
                local view_def
                view_def=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
                    SHOW CREATE VIEW \`$source_db\`.\`$view\`;" 2>/dev/null |
                    awk 'NR==1 {for (i=1; i<=NF; i++) if ($i == "View") col=i+2} NR==1 {print $col}')

                # Create in new database
                if [ -n "$view_def" ]; then
                    # Replace the database name in the definition
                    view_def=$(echo "$view_def" | sed "s/\`$source_db\`/\`$target_db\`/g")

                    # Create the view in the new database
                    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$target_db" -e "
                        CREATE VIEW \`$view\` AS $view_def;" 2>> "$rename_log"
                fi
            done
        fi

        # Copy grants from old database to new database
        echo "Copying user permissions..." >> "$rename_log"
        local grants
        grants=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT CONCAT('GRANT ', privilege_type, ' ON ', table_schema, '.', table_name, ' TO ''', grantee, ''';')
            FROM information_schema.table_privileges
            WHERE table_schema = '$source_db';" 2>/dev/null)

        if [ -n "$grants" ]; then
            while read -r grant; do
                # Replace old database name with new database name
                local new_grant=$(echo "$grant" | sed "s/ON $source_db\./ON $target_db\./g")
                echo "Applying grant: $new_grant" >> "$rename_log"

                # Apply the grant
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "$new_grant" 2>> "$rename_log"
            done <<< "$grants"
        fi

        # Verify new database has all tables
        local new_tables_count
        new_tables_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT COUNT(*) FROM information_schema.tables
            WHERE table_schema = '$target_db';" 2>/dev/null)

        echo "Tables in new database: $new_tables_count" >> "$rename_log"

        # Ask before dropping old database
        kill $dialog_pid 2>/dev/null || true

        dialog --colors --title "Drop Old Database" --yesno "\Z3Rename operation completed.\n\nDo you want to drop the original database '$source_db'?\Z0" 8 70

        if [ $? -eq 0 ]; then
            dialog --colors --title "Confirm Drop" --defaultno --yesno "\Z1WARNING: This will permanently delete the original database '$source_db'.\n\nAre you absolutely sure?\Z0" 10 70

            if [ $? -eq 0 ]; then
                dialog --infobox "Dropping database '$source_db'..." 5 60
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE \`$source_db\`;" 2>/dev/null
                dialog --colors --title "Rename Complete" --msgbox "\Z6Database renamed from '$source_db' to '$target_db' and original database dropped." 8 70
            else
                dialog --colors --title "Rename Complete" --msgbox "\Z6Database renamed from '$source_db' to '$target_db'.\n\nOriginal database was kept for safety." 8 70
            fi
        else
            dialog --colors --title "Rename Complete" --msgbox "\Z6Database renamed from '$source_db' to '$target_db'.\n\nOriginal database was kept for safety." 8 70
        fi

        # Clean up temporary log
        rm -f "$rename_log"

    } &

    # Wait for the background process to complete
    wait
}

# Remove database with safety checks
remove_database() {
    # Get list of databases
    local databases
    databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        dialog --colors --title "No Databases" --msgbox "\Z1No user databases found." 8 60
        return 1
    fi

    # Create options for database selection
    local db_options=()
    for db in $databases; do
        # Get database size
        local size=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2)
            FROM information_schema.tables
            WHERE table_schema = '$db';" 2>/dev/null)

        # Get table count
        local tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "
            SELECT COUNT(*)
            FROM information_schema.tables
            WHERE table_schema = '$db';" 2>/dev/null)

        db_options+=("$db" "Database: $db (Size: ${size}MB, Tables: $tables)")
    done

    # Select database to remove
    local selected_db
    selected_db=$(dialog --colors --title "Select Database" --menu "Select database to remove:" 15 70 10 "${db_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_db" ]; then
        return 0
    fi

    # First confirmation with warning
    dialog --colors --title "Warning" --defaultno --yesno "\Z1WARNING: You are about to permanently delete the database '$selected_db'.\n\nThis action CANNOT be undone.\n\nAre you sure you want to continue?\Z0" 10 70

    if [ $? -ne 0 ]; then
        return 0
    fi

    # Ask if user wants to backup before deletion
    dialog --colors --title "Backup Before Deletion" --yesno "\Z3Would you like to create a backup of the database before deleting it?\Z0" 8 70

    if [ $? -eq 0 ]; then
        # Create backup
        dialog --infobox "Creating backup of database '$selected_db' before deletion..." 5 60
        local backup_file=$(backup_database "$selected_db")

        if [ -n "$backup_file" ] && [ -f "$backup_file" ]; then
            dialog --colors --title "Backup Created" --msgbox "\Z6Backup of database '$selected_db' created successfully at:\n\n$backup_file\Z0" 8 70
        else
            dialog --colors --title "Backup Failed" --yesno "\Z1Failed to create backup of database '$selected_db'.\n\nDo you still want to proceed with deletion?\Z0" 8 70

            if [ $? -ne 0 ]; then
                return 0
            fi
        fi
    fi

    # Second confirmation with database name verification
    local verification
    verification=$(dialog --colors --title "Verification Required" --inputbox "\Z1DANGER: To confirm deletion, please type the database name '$selected_db' exactly:\Z0" 8 70 3>&1 1>&2 2>&3)

    if [ "$verification" != "$selected_db" ]; then
        dialog --colors --title "Deletion Cancelled" --msgbox "\Z6Database name verification failed. Deletion cancelled." 8 60
        return 0
    fi

    # Perform the deletion
    dialog --infobox "Deleting database '$selected_db'..." 5 60

    if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "DROP DATABASE \`$selected_db\`;" 2>/dev/null; then
        dialog --colors --title "Deletion Complete" --msgbox "\Z6Database '$selected_db' has been permanently deleted." 8 60
        return 0
    else
        dialog --colors --title "Deletion Failed" --msgbox "\Z1Failed to delete database '$selected_db'.\n\nCheck MySQL permissions and try again." 8 70
        return 1
    fi
}

# Manage database permissions
manage_database_permissions() {
    # Get list of databases
    local databases
    databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        dialog --colors --title "No Databases" --msgbox "\Z1No user databases found." 8 60
        return 1
    fi

    # Create options for database selection
    local db_options=()
    for db in $databases; do
        db_options+=("$db" "Database: $db")
    done

    # Select database
    local selected_db
    selected_db=$(dialog --colors --title "Select Database" --menu "Select database to manage permissions:" 15 60 10 "${db_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_db" ]; then
        return 0
    fi

    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No MySQL Users" --msgbox "\Z1No MySQL users found. Create users first." 8 60
        return 1
    fi

    # Show current permissions for this database
    local current_permissions
    current_permissions=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT
        User,
        Host,
        GROUP_CONCAT(DISTINCT PRIVILEGE_TYPE SEPARATOR ', ') AS 'Privileges'
    FROM information_schema.SCHEMA_PRIVILEGES
    WHERE TABLE_SCHEMA = '$selected_db'
    GROUP BY User, Host
    ORDER BY User;" 2>/dev/null)

    dialog --colors --title "Current Permissions" --msgbox "\Z5Current permissions for database '$selected_db':\Z0\n\n$current_permissions" 15 70

    # Permissions management menu
    local choice
    choice=$(dialog --colors --clear --backtitle "\Z6SDBTT Permission Management\Z0" \
        --title "Permissions for $selected_db" --menu "Choose an option:" 15 60 5 \
        "1" "\Z6Grant permissions to a user\Z0" \
        "2" "\Z6Revoke permissions from a user\Z0" \
        "3" "\Z6View detailed user permissions\Z0" \
        "4" "\Z6Transfer ownership\Z0" \
        "5" "\Z1Back\Z0" \
        3>&1 1>&2 2>&3)

    case $choice in
        1)
            grant_permissions_to_user "$selected_db"
            ;;
        2)
            revoke_permissions_from_user "$selected_db"
            ;;
        3)
            view_detailed_permissions "$selected_db"
            ;;
        4)
            transfer_database_ownership "$selected_db"
            ;;
        5|"")
            return 0
            ;;
    esac
}

# Grant permissions to a user for a specific database
grant_permissions_to_user() {
    local db_name="$1"

    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No MySQL Users" --yesno "\Z1No MySQL users found. Would you like to create a new user?\Z0" 8 60

        if [ $? -eq 0 ]; then
            create_mysql_user
            # Refresh user list
            users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

            if [ -z "$users" ]; then
                return 1
            fi
        else
            return 1
        fi
    fi

    # Create options for user selection
    local user_options=()
    for user in $users; do
        user_options+=("$user" "MySQL user: $user")
    done

    # Add root as an option
    user_options+=("root" "MySQL user: root (system administrator)")

    # Select user
    local selected_user
    selected_user=$(dialog --colors --title "Select MySQL User" --menu "Select user to grant permissions:" 15 60 10 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_user" ]; then
        return 0
    fi

    # Choose privilege type
    local privilege_type
    privilege_type=$(dialog --colors --title "Privilege Type" --menu "Select type of privileges to grant:" 15 70 5 \
        "ALL" "All privileges (SELECT, INSERT, UPDATE, DELETE, etc.)" \
        "READONLY" "Read-only privileges (SELECT)" \
        "READWRITE" "Read-write privileges (SELECT, INSERT, UPDATE, DELETE)" \
        "CUSTOM" "Select custom privileges" \
        "CANCEL" "Cancel operation" \
        3>&1 1>&2 2>&3)

    if [ "$privilege_type" = "CANCEL" ] || [ -z "$privilege_type" ]; then
        return 0
    fi

    # For custom privileges, show a checklist
    local privileges=""

    if [ "$privilege_type" = "CUSTOM" ]; then
        local privilege_options=(
            "SELECT" "Read data from tables" "on"
            "INSERT" "Add new data to tables" "off"
            "UPDATE" "Modify existing data" "off"
            "DELETE" "Remove data from tables" "off"
            "CREATE" "Create new tables" "off"
            "DROP" "Delete tables" "off"
            "REFERENCES" "Create foreign keys" "off"
            "INDEX" "Create or drop indexes" "off"
            "ALTER" "Modify table structures" "off"
            "CREATE_TMP_TABLE" "Create temporary tables" "off"
            "LOCK_TABLES" "Lock tables" "off"
            "EXECUTE" "Execute stored procedures" "off"
            "CREATE_VIEW" "Create views" "off"
            "SHOW_VIEW" "View definitions" "off"
            "CREATE_ROUTINE" "Create stored procedures" "off"
            "ALTER_ROUTINE" "Modify stored procedures" "off"
            "TRIGGER" "Create triggers" "off"
            "EVENT" "Create events" "off"
        )

        local selected_privileges
        selected_privileges=$(dialog --colors --title "Select Privileges" --checklist "Select privileges to grant:" 20 70 15 "${privilege_options[@]}" 3>&1 1>&2 2>&3)

        if [ -z "$selected_privileges" ]; then
            return 0
        fi

        # Remove quotes from the output
        privileges=$(echo "$selected_privileges" | tr -d '"')
        privileges=$(echo "$privileges" | tr ' ' ',')
    else
        case $privilege_type in
            "ALL")
                privileges="ALL PRIVILEGES"
                ;;
            "READONLY")
                privileges="SELECT"
                ;;
            "READWRITE")
                privileges="SELECT,INSERT,UPDATE,DELETE"
                ;;
        esac
    fi

    # Specify grant scope
    local grant_scope
    grant_scope=$(dialog --colors --title "Grant Scope" --menu "Select the scope of the grant:" 15 70 3 \
        "DATABASE" "Grant on the entire database" \
        "TABLES" "Grant on specific tables" \
        "CANCEL" "Cancel operation" \
        3>&1 1>&2 2>&3)

    if [ "$grant_scope" = "CANCEL" ] || [ -z "$grant_scope" ]; then
        return 0
    fi

    # For specific tables, show a table selection dialog
    local tables_clause="*"

    if [ "$grant_scope" = "TABLES" ]; then
        # Get list of tables
        local tables
        tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)

        if [ -z "$tables" ]; then
            dialog --colors --title "No Tables" --msgbox "\Z1No tables found in database '$db_name'." 8 60
            return 1
        fi

        # Create options for table selection
        local table_options=()
        for table in $tables; do
            table_options+=("$table" "Table: $table" "off")
        done

        # Allow selecting multiple tables
        local selected_tables
        selected_tables=$(dialog --colors --title "Select Tables" --checklist "Select tables to grant privileges on:" 20 70 15 "${table_options[@]}" 3>&1 1>&2 2>&3)

        if [ -z "$selected_tables" ]; then
            return 0
        fi

        # Remove quotes from the output
        selected_tables=$(echo "$selected_tables" | tr -d '"')

        # For each selected table, create a grant statement
        for table in $selected_tables; do
            # Grant privileges to the specified user on the specified table
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT $privileges ON \`$db_name\`.\`$table\` TO '$selected_user'@'localhost';" 2>/dev/null
        done

        # Flush privileges
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

        dialog --colors --title "Privileges Granted" --msgbox "\Z6Privileges ($privileges) granted to user '$selected_user' on selected tables in database '$db_name'." 8 70
    else
        # Grant privileges to the entire database
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT $privileges ON \`$db_name\`.* TO '$selected_user'@'localhost';" 2>/dev/null

        # Flush privileges
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

        dialog --colors --title "Privileges Granted" --msgbox "\Z6Privileges ($privileges) granted to user '$selected_user' on database '$db_name'." 8 70
    fi
}

# Revoke permissions from a user for a specific database
revoke_permissions_from_user() {
    local db_name="$1"

    # Get users with permissions on this database
    local users_with_permissions
    users_with_permissions=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT DISTINCT User
    FROM information_schema.SCHEMA_PRIVILEGES
    WHERE TABLE_SCHEMA = '$db_name'
    ORDER BY User;" 2>/dev/null | grep -v "User")

    if [ -z "$users_with_permissions" ]; then
        dialog --colors --title "No Permissions" --msgbox "\Z1No users with specific permissions found for database '$db_name'." 8 70
        return 1
    fi

    # Create options for user selection
    local user_options=()
    for user in $users_with_permissions; do
        # Get privileges for this user
        local user_privileges
        user_privileges=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
        SELECT GROUP_CONCAT(DISTINCT PRIVILEGE_TYPE SEPARATOR ', ')
        FROM information_schema.SCHEMA_PRIVILEGES
        WHERE TABLE_SCHEMA = '$db_name' AND GRANTEE LIKE '%''$user''%';" 2>/dev/null | grep -v "GROUP_CONCAT")

        user_options+=("$user" "MySQL user: $user (Privileges: $user_privileges)")
    done

    # Select user
    local selected_user
    selected_user=$(dialog --colors --title "Select MySQL User" --menu "Select user to revoke permissions from:" 15 70 10 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_user" ]; then
        return 0
    fi

    # Confirm revocation
    dialog --colors --title "Confirm Revocation" --yesno "\Z3Are you sure you want to revoke ALL privileges for user '$selected_user' on database '$db_name'?\Z0" 8 70

    if [ $? -ne 0 ]; then
        return 0
    fi

    # Revoke privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "REVOKE ALL PRIVILEGES ON \`$db_name\`.* FROM '$selected_user'@'localhost';" 2>/dev/null

    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

    dialog --colors --title "Privileges Revoked" --msgbox "\Z6All privileges revoked from user '$selected_user' on database '$db_name'." 8 70
}

# View detailed permissions for a database
view_detailed_permissions() {
    local db_name="$1"

    # Get detailed privileges
    local detailed_permissions
    detailed_permissions=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT
        GRANTEE AS 'User',
        PRIVILEGE_TYPE AS 'Privilege',
        IS_GRANTABLE AS 'Can Grant',
        TABLE_NAME AS 'Table'
    FROM information_schema.TABLE_PRIVILEGES
    WHERE TABLE_SCHEMA = '$db_name'
    ORDER BY GRANTEE, TABLE_NAME, PRIVILEGE_TYPE;" 2>/dev/null)

    if [ -z "$detailed_permissions" ] || [ "$(echo "$detailed_permissions" | wc -l)" -le 1 ]; then
        # Try schema privileges if no table privileges
        detailed_permissions=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
        SELECT
            GRANTEE AS 'User',
            PRIVILEGE_TYPE AS 'Privilege',
            IS_GRANTABLE AS 'Can Grant',
            'ALL TABLES' AS 'Table'
        FROM information_schema.SCHEMA_PRIVILEGES
        WHERE TABLE_SCHEMA = '$db_name'
        ORDER BY GRANTEE, PRIVILEGE_TYPE;" 2>/dev/null)

        if [ -z "$detailed_permissions" ] || [ "$(echo "$detailed_permissions" | wc -l)" -le 1 ]; then
            dialog --colors --title "No Permissions" --msgbox "\Z1No detailed permissions found for database '$db_name'." 8 70
            return 1
        fi
    fi

    # Format the output
    local formatted_permissions
    formatted_permissions=$(echo "$detailed_permissions" | sed 's/User/\\Z5User\\Z0/g' | sed 's/Privilege/\\Z5Privilege\\Z0/g' | sed 's/Can Grant/\\Z5Can Grant\\Z0/g' | sed 's/Table/\\Z5Table\\Z0/g')

    dialog --colors --title "Detailed Permissions for $db_name" --msgbox "$formatted_permissions" 25 80
}

# Transfer database ownership
transfer_database_ownership() {
    local db_name="$1"

    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No MySQL Users" --yesno "\Z1No MySQL users found. Would you like to create a new user?\Z0" 8 60

        if [ $? -eq 0 ]; then
            create_mysql_user
            # Refresh user list
            users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

            if [ -z "$users" ]; then
                return 1
            fi
        else
            return 1
        fi
    fi

    # Create options for user selection
    local user_options=()
    for user in $users; do
        user_options+=("$user" "MySQL user: $user")
    done

    # Add root as an option
    user_options+=("root" "MySQL user: root (system administrator)")

    # Select new owner
    local new_owner
    new_owner=$(dialog --colors --title "Select New Owner" --menu "Select new owner for database '$db_name':" 15 60 10 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$new_owner" ]; then
        return 0
    fi

    # Confirm transfer
    dialog --colors --title "Confirm Transfer" --yesno "\Z3Are you sure you want to transfer ownership of database '$db_name' to user '$new_owner'?\n\nThis will revoke privileges from other users and grant ALL privileges to the new owner.\Z0" 10 70

    if [ $? -ne 0 ]; then
        return 0
    fi

    # Transfer ownership by granting all privileges to the new owner
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$new_owner'@'localhost';" 2>/dev/null

    # Update database owner in configuration
    DB_OWNER="$new_owner"

    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

    dialog --colors --title "Ownership Transferred" --msgbox "\Z6Ownership of database '$db_name' transferred to user '$new_owner'." 8 70
}

# Assign multiple databases to a user
database_user_assignment() {
    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No MySQL Users" --yesno "\Z1No MySQL users found. Would you like to create a new user?\Z0" 8 60

        if [ $? -eq 0 ]; then
            create_mysql_user
            # Refresh user list
            users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

            if [ -z "$users" ]; then
                return 1
            fi
        else
            return 1
        fi
    fi

    # Create options for user selection
    local user_options=()
    for user in $users; do
        user_options+=("$user" "MySQL user: $user")
    done

    # Select user
    local selected_user
    selected_user=$(dialog --colors --title "Select MySQL User" --menu "Select user to assign databases to:" 15 60 10 "${user_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_user" ]; then
        return 0
    fi

    # Get list of databases
    local databases
    databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -z "$databases" ]; then
        dialog --colors --title "No Databases" --msgbox "\Z1No user databases found." 8 60
        return 1
    fi

    # Get databases this user already has access to
    local user_dbs
    user_dbs=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT DISTINCT TABLE_SCHEMA
    FROM information_schema.SCHEMA_PRIVILEGES
    WHERE GRANTEE LIKE '%''$selected_user''%'
    ORDER BY TABLE_SCHEMA;" 2>/dev/null | grep -v "TABLE_SCHEMA")

    # Create options for database selection
    local db_options=()
    for db in $databases; do
        local is_assigned="off"
        # Check if this database is already assigned to the user
        if echo "$user_dbs" | grep -q "^$db$"; then
            is_assigned="on"
        fi

        db_options+=("$db" "Database: $db" "$is_assigned")
    done

    # Select databases
    local selected_dbs
    selected_dbs=$(dialog --colors --title "Select Databases" --checklist "Select databases to assign to user '$selected_user':" 20 70 15 "${db_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_dbs" ]; then
        return 0
    fi

    # Remove quotes from the output
    selected_dbs=$(echo "$selected_dbs" | tr -d '"')

    # Choose privilege type
    local privilege_type
    privilege_type=$(dialog --colors --title "Privilege Type" --menu "Select type of privileges to grant:" 15 70 5 \
        "ALL" "All privileges (SELECT, INSERT, UPDATE, DELETE, etc.)" \
        "READONLY" "Read-only privileges (SELECT)" \
        "READWRITE" "Read-write privileges (SELECT, INSERT, UPDATE, DELETE)" \
        "CUSTOM" "Select custom privileges" \
        "CANCEL" "Cancel operation" \
        3>&1 1>&2 2>&3)

    if [ "$privilege_type" = "CANCEL" ] || [ -z "$privilege_type" ]; then
        return 0
    fi

    # For custom privileges, show a checklist
    local privileges=""

    if [ "$privilege_type" = "CUSTOM" ]; then
        local privilege_options=(
            "SELECT" "Read data from tables" "on"
            "INSERT" "Add new data to tables" "off"
            "UPDATE" "Modify existing data" "off"
            "DELETE" "Remove data from tables" "off"
            "CREATE" "Create new tables" "off"
            "DROP" "Delete tables" "off"
            "REFERENCES" "Create foreign keys" "off"
            "INDEX" "Create or drop indexes" "off"
            "ALTER" "Modify table structures" "off"
            "CREATE_TMP_TABLE" "Create temporary tables" "off"
            "LOCK_TABLES" "Lock tables" "off"
            "EXECUTE" "Execute stored procedures" "off"
            "CREATE_VIEW" "Create views" "off"
            "SHOW_VIEW" "View definitions" "off"
            "CREATE_ROUTINE" "Create stored procedures" "off"
            "ALTER_ROUTINE" "Modify stored procedures" "off"
            "TRIGGER" "Create triggers" "off"
            "EVENT" "Create events" "off"
        )

        local selected_privileges
        selected_privileges=$(dialog --colors --title "Select Privileges" --checklist "Select privileges to grant:" 20 70 15 "${privilege_options[@]}" 3>&1 1>&2 2>&3)

        if [ -z "$selected_privileges" ]; then
            return 0
        fi

        # Remove quotes from the output
        privileges=$(echo "$selected_privileges" | tr -d '"')
        privileges=$(echo "$privileges" | tr ' ' ',')
    else
        case $privilege_type in
            "ALL")
                privileges="ALL PRIVILEGES"
                ;;
            "READONLY")
                privileges="SELECT"
                ;;
            "READWRITE")
                privileges="SELECT,INSERT,UPDATE,DELETE"
                ;;
        esac
    fi

    # Create a temporary log file for grant progress
    local grant_log="/tmp/sdbtt_grant_$.log"
    echo "Starting grant of privileges for user '$selected_user'" > "$grant_log"

    # Display progress dialog
    dialog --title "Grant Progress" --tailbox "$grant_log" 15 70 &
    local dialog_pid=$!

    # Run the grant process in background
    {
        # First, revoke existing privileges to set a clean slate for selected DBs
        for db in $selected_dbs; do
            echo "Revoking existing privileges on $db..." >> "$grant_log"
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "REVOKE ALL PRIVILEGES ON \`$db\`.* FROM '$selected_user'@'localhost';" 2>/dev/null
        done

        # Now grant the new privileges to each database
        for db in $selected_dbs; do
            echo "Granting $privileges on $db..." >> "$grant_log"
            if mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT $privileges ON \`$db\`.* TO '$selected_user'@'localhost';" 2>/dev/null; then
                echo "Successfully granted privileges on $db" >> "$grant_log"
            else
                echo "Failed to grant privileges on $db" >> "$grant_log"
            fi
        done

        # Flush privileges to ensure changes take effect
        echo "Flushing privileges..." >> "$grant_log"
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null

        echo "Grant operation completed" >> "$grant_log"

        # Kill the dialog process
        kill $dialog_pid 2>/dev/null || true

        # Display completion message
        dialog --colors --title "Privileges Granted" --msgbox "\Z6Privileges ($privileges) granted to user '$selected_user' on selected databases." 8 70

        # Clean up temporary log
        rm -f "$grant_log"

    } &

    # Wait for the background process to complete
    wait
}

# Display main menu with enhanced theming
show_main_menu() {
    local choice

    debug_log "Displaying main menu"

    while true; do
        # Try to use a simpler menu format with retrowave colors
        choice=$(dialog --colors --clear --backtitle "\Z6SDBTT - Simple Database Transfer Tool v$VERSION\Z0" \
            --title "Main Menu" --menu "Choose an option:" 18 60 12 \
            "1" "\Z6Import Databases\Z0" \
            "2" "\Z6Transfer and Replace Database\Z0" \
            "3" "\Z6Configure Settings\Z0" \
            "4" "\Z6Browse & Select Directories\Z0" \
            "5" "\Z6MySQL Administration\Z0" \
            "6" "\Z6View Logs\Z0" \
            "7" "\Z6Save Current Settings\Z0" \
            "8" "\Z6Load Saved Settings\Z0" \
            "9" "\Z6Check for Updates\Z0" \
            "10" "\Z6About SDBTT\Z0" \
            "11" "\Z6Help\Z0" \
            "0" "\Z1Exit\Z0" \
            3>&1 1>&2 2>&3)

        local menu_exit=$?
        debug_log "Menu returned: '$choice' with exit code $menu_exit"

        if [ $menu_exit -ne 0 ]; then
            # Exit code is not 0, check if it's a normal cancel
            if [ $menu_exit -ne 1 ]; then
                debug_log "Dialog menu failed with code $menu_exit"
                echo "ERROR: Dialog menu failed, trying to continue..." >&2
            fi
            choice=""
        fi

        case $choice in
            1) import_databases_menu ;;
            2) transfer_replace_database ;;
            3) configure_settings ;;
            4) browse_directories ;;
            5) enhanced_mysql_admin_menu ;;
            6) view_logs ;;
            7) save_config ;;
            8)
                if load_config; then
                    dialog --colors --title "Configuration Loaded" --msgbox "\Z6Settings have been loaded from $CONFIG_FILE" 8 60
                else
                    dialog --colors --title "Error" --msgbox "\Z1No saved configuration found at $CONFIG_FILE" 8 60
                fi
                ;;
            9) check_for_updates ;;
            10) show_about ;;
            11) show_help ;;
            0)
                # Clean up and reset terminal without showing goodbye message
                rm -f "$DIALOGRC" 2>/dev/null
                clear
                exit 0
                ;;
            *)
                # User pressed Cancel or ESC
                if [ -z "$choice" ]; then
                    dialog --colors --title "Exit Confirmation" --yesno "Are you sure you want to exit?" 8 60
                    if [ $? -eq 0 ]; then
                        # Clean up and reset terminal without showing goodbye message
                        rm -f "$DIALOGRC" 2>/dev/null
                        clear
                        exit 0
                    fi
                fi
                ;;
        esac
    done
}

# Configure settings menu with enhanced theming
configure_settings() {
    local settings_menu

    while true; do
        settings_menu=$(dialog --colors --clear --backtitle "\Z6SDBTT - Configuration\Z0" \
            --title "Configure Settings" --menu "Choose a setting to configure:" 15 60 6 \
            "1" "\Z5MySQL Username\Z0 (Current: ${MYSQL_USER:-not set})" \
            "2" "\Z5Database Owner\Z0 (Current: ${DB_OWNER:-not set})" \
            "3" "\Z5Database Prefix\Z0 (Current: ${DB_PREFIX:-not set})" \
            "4" "\Z5SQL File Pattern\Z0 (Current: ${SQL_PATTERN:-*.sql})" \
            "5" "\Z5MySQL Password\Z0" \
            "6" "\Z1Back to Main Menu\Z0" \
            3>&1 1>&2 2>&3)

        case $settings_menu in
            1)
                MYSQL_USER=$(dialog --colors --title "MySQL Username" --inputbox "Enter MySQL username:" 8 60 "${MYSQL_USER:-root}" 3>&1 1>&2 2>&3)
                ;;
            2)
                DB_OWNER=$(dialog --colors --title "Database Owner" --inputbox "Enter database owner username:" 8 60 "${DB_OWNER}" 3>&1 1>&2 2>&3)
                ;;
            3)
                DB_PREFIX=$(dialog --colors --title "Database Prefix" --inputbox "Enter database prefix:" 8 60 "${DB_PREFIX}" 3>&1 1>&2 2>&3)
                ;;
            4)
                SQL_PATTERN=$(dialog --colors --title "SQL File Pattern" --inputbox "Enter SQL file pattern:" 8 60 "${SQL_PATTERN:-*.sql}" 3>&1 1>&2 2>&3)
                ;;
            5)
                local password
                password=$(dialog --colors --title "MySQL Password" --passwordbox "Enter MySQL password for user '${MYSQL_USER:-root}':" 8 60 3>&1 1>&2 2>&3)

                if [ -n "$password" ]; then
                    # Store the password securely
                    MYSQL_PASS="$password"
                    store_password "${MYSQL_USER:-root}" "$password"

                    # Verify MySQL connection works
                    if ! mysql -u "${MYSQL_USER:-root}" -p"$password" -e "SELECT 1" >/dev/null 2>&1; then
                        dialog --colors --title "Connection Error" --msgbox "\Z1Failed to connect to MySQL server. Please check credentials." 8 60
                    else
                        dialog --colors --title "Connection Success" --msgbox "\Z6Successfully connected to MySQL server and securely stored password." 8 60
                    fi
                fi
                ;;
            6|"")
                break
                ;;
        esac
    done
}

# Browse and select directories with enhanced theming
browse_directories() {
    local current_dir="${SQL_DIR:-$HOME}"
    local selection

    while true; do
        # Get directories in current path
        local dirs=()
        local files=()

        # Add parent directory option
        dirs+=("../" "↑ Parent Directory")

        # List directories and SQL files
        while IFS= read -r dir; do
            if [ -d "$dir" ]; then
                # Format for display with better colors
                local display_name="${dir##*/}/"
                dirs+=("$dir/" "\Z6📁 $display_name\Z0")
            fi
        done < <(find "$current_dir" -maxdepth 1 -type d -not -path "$current_dir" | sort)

        # List SQL files if pattern is defined
        if [ -n "$SQL_PATTERN" ]; then
            while IFS= read -r file; do
                if [ -f "$file" ]; then
                    local display_name="${file##*/}"
                    files+=("$file" "\Z6📄 $display_name\Z0")
                fi
            done < <(find "$current_dir" -maxdepth 1 -type f -name "$SQL_PATTERN" | sort)
        fi

        # Combine directories and files
        local options=("${dirs[@]}" "${files[@]}")

        # Add options to select current directory and to go back
        options+=("SELECT_DIR" "\Z2✅ [ Select Current Directory ]\Z0")
        options+=("BACK" "\Z1⬅️ [ Back to Main Menu ]\Z0")

        selection=$(dialog --colors --clear --backtitle "\Z6SDBTT - Directory Browser\Z0" \
            --title "Directory Browser" \
            --menu "Current: \Z5$current_dir\Z0\n\nNavigate to directory containing SQL files:" 20 76 12 \
            "${options[@]}" 3>&1 1>&2 2>&3)

        case $selection in
            "SELECT_DIR")
                SQL_DIR="$current_dir"
                dialog --colors --title "Directory Selected" --msgbox "\Z6Selected directory: $SQL_DIR" 8 60

                # Add to last directories list (max 5)
                if [ -z "$LAST_DIRECTORIES" ]; then
                    LAST_DIRECTORIES="$SQL_DIR"
                else
                    # Add to beginning of list and keep unique entries
                    LAST_DIRECTORIES="$SQL_DIR:$(echo "$LAST_DIRECTORIES" | sed "s|$SQL_DIR||g" | sed "s|::*|:|g" | sed "s|^:|:|g" | sed "s|:$||g")"

                    # Keep only the 5 most recent directories
                    LAST_DIRECTORIES=$(echo "$LAST_DIRECTORIES" | cut -d: -f1-5)
                fi

                break
                ;;
            "../")
                current_dir="$(dirname "$current_dir")"
                ;;
            "BACK"|"")
                break
                ;;
            *)
                if [ -d "$selection" ]; then
                    current_dir="$selection"
                elif [ -f "$selection" ]; then
                    dialog --colors --title "File Selected" --msgbox "\Z6Selected file: $selection\n\nThis is a file, not a directory. Please select a directory." 10 60
                fi
                ;;
        esac
    done
}

# Import databases menu with enhanced theming
import_databases_menu() {
    if [ -z "$SQL_DIR" ] || [ ! -d "$SQL_DIR" ]; then
        dialog --colors --title "No Directory Selected" \
            --menu "No valid directory selected. Choose an option:" 10 60 3 \
            "1" "\Z6Browse for Directory\Z0" \
            "2" "\Z6Select from Recent Directories\Z0" \
            "3" "\Z1Back to Main Menu\Z0" \
            2>/tmp/menu_choice

        local choice
        choice=$(<"/tmp/menu_choice")

        case $choice in
            1) browse_directories ;;
            2) select_from_recent_dirs ;;
            *) return ;;
        esac

        # If still no directory, return to main menu
        if [ -z "$SQL_DIR" ] || [ ! -d "$SQL_DIR" ]; then
            return
        fi
    fi

    # Check for missing required settings
    local missing=()
    [ -z "$MYSQL_USER" ] && missing+=("MySQL Username")
    [ -z "$DB_OWNER" ] && missing+=("Database Owner")
    [ -z "$DB_PREFIX" ] && missing+=("Database Prefix")

    # Retrieve password if we have a username but no password
    if [ -n "$MYSQL_USER" ] && [ -z "$MYSQL_PASS" ]; then
        MYSQL_PASS=$(get_password "$MYSQL_USER")

        # If still no password, add to missing list
        [ -z "$MYSQL_PASS" ] && missing+=("MySQL Password")
    fi

    if [ ${#missing[@]} -ne 0 ]; then
        dialog --colors --title "Missing Settings" --msgbox "\Z1The following required settings are missing:\n\n${missing[*]}\n\nPlease configure them before proceeding." 12 60
        configure_settings
        return
    fi

    # List SQL files in the directory
    local sql_files=()
    local i=1

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename="${file##*/}"
            local base_filename="${filename%.sql}"

            # Extract existing prefix if any
            # This assumes prefixes are followed by an underscore
            local existing_prefix=""
            if [[ "$base_filename" == *"_"* ]]; then
                existing_prefix=$(echo "$base_filename" | sed -E 's/^([^_]+)_.*/\1/')
                base_db_name=$(echo "$base_filename" | sed -E 's/^[^_]+_(.*)$/\1/')
            else
                base_db_name="$base_filename"
            fi

            # Apply the new prefix
            local db_name="${DB_PREFIX}${base_db_name}"

            # Show original name → new name with enhanced colors
            if [ -n "$existing_prefix" ]; then
                sql_files+=("$file" "[$i] \Z6$filename\Z0 → \Z5$db_name\Z0 (replacing prefix '\Z3$existing_prefix\Z0')")
            else
                sql_files+=("$file" "[$i] \Z6$filename\Z0 → \Z5$db_name\Z0")
            fi

            ((i++))
        fi
    done < <(find "$SQL_DIR" -maxdepth 1 -type f -name "$SQL_PATTERN" | sort)

    if [ ${#sql_files[@]} -eq 0 ]; then
        dialog --colors --title "No SQL Files Found" --msgbox "\Z1No SQL files matching pattern '$SQL_PATTERN' found in $SQL_DIR." 8 60
        return
    fi

    # Options for how to process the files
    local process_choice
    process_choice=$(dialog --colors --clear --backtitle "\Z6SDBTT - Import\Z0" \
        --title "Process SQL Files" \
        --menu "Found \Z5${#sql_files[@]}\Z0 SQL files. Choose an option:" 15 76 4 \
        "1" "\Z6List and select individual files to import\Z0" \
        "2" "\Z6Import all files\Z0" \
        "3" "\Z6Verify settings and show import plan\Z0" \
        "4" "\Z1Back to Main Menu\Z0" \
        3>&1 1>&2 2>&3)

    case $process_choice in
        1)
            # Multi-select dialog for individual files
            local selected_files
            selected_files=$(dialog --colors --clear --backtitle "\Z6SDBTT - Import\Z0" \
                --title "Select SQL Files to Import" \
                --checklist "Select files to import:" 20 76 12 \
                "${sql_files[@]}" 3>&1 1>&2 2>&3)

            if [ -n "$selected_files" ]; then
                # Remove quotes from the output
                selected_files=$(echo "$selected_files" | tr -d '"')
                start_import_process "$selected_files"
            fi
            ;;
        2)
            # Extract just the filenames from sql_files array
            local all_files=""
            for ((i=0; i<${#sql_files[@]}; i+=2)); do
                all_files="$all_files ${sql_files[i]}"
            done
            start_import_process "$all_files"
            ;;
        3)
            show_import_plan
            ;;
        4|"")
            return
            ;;
    esac
}

# Show import plan with enhanced formatting
show_import_plan() {
    local plan="\Z5Import Plan Summary:\Z0\n\n"
    plan+="MySQL User: \Z6$MYSQL_USER\Z0\n"
    plan+="Database Owner: \Z6$DB_OWNER\Z0\n"
    plan+="Source Directory: \Z6$SQL_DIR\Z0\n"
    plan+="SQL Pattern: \Z6$SQL_PATTERN\Z0\n"
    plan+="Database Prefix: \Z6$DB_PREFIX\Z0\n\n"
    plan+="\Z5Files to be imported:\Z0\n"

    local count=0
    local file_list=""

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename="${file##*/}"
            local base_filename="${filename%.sql}"

            # Extract existing prefix if any
            local existing_prefix=""
            if [[ "$base_filename" == *"_"* ]]; then
                existing_prefix=$(echo "$base_filename" | sed -E 's/^([^_]+)_.*/\1/')
                base_db_name=$(echo "$base_filename" | sed -E 's/^[^_]+_(.*)$/\1/')
            else
                base_db_name="$base_filename"
            fi

            # Apply the new prefix
            local db_name="${DB_PREFIX}${base_db_name}"

            # Show original name → new name with enhanced colors
            if [ -n "$existing_prefix" ]; then
                file_list+="\Z6$filename\Z0 → \Z5$db_name\Z0 (replacing prefix '\Z3$existing_prefix\Z0')\n"
            else
                file_list+="\Z6$filename\Z0 → \Z5$db_name\Z0\n"
            fi

            ((count++))
        fi
    done < <(find "$SQL_DIR" -maxdepth 1 -type f -name "$SQL_PATTERN" | sort)

    plan+="$file_list\n"
    plan+="Total: \Z5$count files\Z0\n\n"
    plan+="\Z6The import process will:\Z0\n"
    plan+="1. Drop existing databases with the same name\n"
    plan+="2. Create new databases with utf8mb4 charset\n"
    plan+="3. Import data from SQL files\n"
    plan+="4. Grant privileges to \Z5$DB_OWNER\Z0 user\n\n"
    plan+="Logs will be saved to \Z6$LOG_FILE\Z0"

    dialog --colors --title "Import Plan" --yesno "$plan\n\nProceed with import?" 25 76

    if [ $? -eq 0 ]; then
        # Get all files
        local all_files=""
        while IFS= read -r file; do
            if [ -f "$file" ]; then
                all_files="$all_files $file"
            fi
        done < <(find "$SQL_DIR" -maxdepth 1 -type f -name "$SQL_PATTERN" | sort)

        start_import_process "$all_files"
    fi
}

# Enhanced import process with better progress display and log viewing
start_import_process() {
    local file_list="$1"
    local db_count=0
    local success_count=0
    local failure_count=0

    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR"

    # Initialize log files
    echo "Starting database import process at $(date)" > "$LOG_FILE"
    echo "MySQL user: $MYSQL_USER" >> "$LOG_FILE"
    echo "Database owner: $DB_OWNER" >> "$LOG_FILE"
    echo "Database prefix: $DB_PREFIX" >> "$LOG_FILE"
    echo "SQL file pattern: $SQL_PATTERN" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"

    # Create a display log file for the UI
    echo "Starting database import process at $(date)" > "$DISPLAY_LOG_FILE"
    echo "----------------------------------------" >> "$DISPLAY_LOG_FILE"

    # Check MySQL server's default charset
    local default_charset=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW VARIABLES LIKE 'character_set_server';" | awk '{print $2}')
    local default_collation=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW VARIABLES LIKE 'collation_server';" | awk '{print $2}')
    log_message "MySQL server default charset: $default_charset, collation: $default_collation"

    # Calculate total files
    local total_files=$(echo "$file_list" | wc -w)

    # Create a temporary file for progress calculation
    local progress_file=$(mktemp)
    echo "0" > "$progress_file"

    # Create initial log display and progress display - simpler setup
    touch "$DISPLAY_LOG_FILE" # Ensure the file exists
    log_message "Starting import process..."
    log_message "Found $total_files files to import"

    # Use a simpler progress display to avoid dialog issues
    dialog --title "Import Progress" --gauge "Preparing to import databases..." 10 70 0 &
    local gauge_pid=$!

    # Wait briefly to ensure dialog is running
    sleep 1

    # Background process for the actual import
    {
        # Process each file
        for sql_file in $file_list; do
            # Extract database name from filename
            local filename=$(basename "$sql_file")
            local base_filename="${filename%.sql}"

            # Extract existing prefix if any
            if [[ "$base_filename" == *"_"* ]]; then
                local existing_prefix=$(echo "$base_filename" | sed -E 's/^([^_]+)_.*/\1/')
                local base_db_name=$(echo "$base_filename" | sed -E 's/^[^_]+_(.*)$/\1/')
            else
                local base_db_name="$base_filename"
            fi

            # Apply the new prefix
            local db_name="${DB_PREFIX}${base_db_name}"

            ((db_count++))
            log_message "Processing database: $db_name from file $filename"

            # Update progress display
            local progress=$((db_count * 100 / total_files))

            # Update the progress gauge - simpler version without colors
            echo $progress | dialog --title "Import Progress" \
                   --gauge "Importing database $db_count of $total_files: $db_name" 10 70 $progress \
                   2>/dev/null

            # Create a processed version with standardized charset
            local processed_file="$TEMP_DIR/processed_$filename"

            # Create the database
            create_database "$db_name"

            # Import the SQL file using improved version
            if improved_import_sql_file "$db_name" "$sql_file" "$processed_file"; then
                # Grant privileges if import was successful
                improved_grant_privileges "$db_name" "$DB_OWNER"
                ((success_count++))
            else
                ((failure_count++))
            fi

            log_message "Done with $db_name"
            log_message "------------------------"

            # Small delay for readability
            sleep 0.2
        done

        # Apply privileges
        log_message "Flushing privileges..."
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>> "$LOG_FILE"

        # Clean up temporary files
        log_message "Cleaning up temporary files..."
        rm -rf "$TEMP_DIR"

        log_message "All databases have been processed"
        log_message "------------------------"
        log_message "Summary:"
        log_message "Total databases processed: $db_count"
        log_message "Successful imports: $success_count"
        log_message "Failed imports: $failure_count"

        # Final progress update - 100%
        echo 100 | dialog --title "Import Progress" \
               --gauge "Import completed!" 10 70 100 \
               2>/dev/null

        # Give time to see the final state
        sleep 2

        # Kill the dialog process
        kill $gauge_pid 2>/dev/null || true

        # Show the result summary
        dialog --colors --title "Import Complete" --msgbox "\Z6Import process complete.\n\nTotal databases processed: \Z5$db_count\Z0\nSuccessful imports: \Z5$success_count\Z0\nFailed imports: \Z1$failure_count\Z0\n\nLog file saved to: \Z5$LOG_FILE\Z0" 12 70

        # Show the complete log if there were failures
        if [ $failure_count -gt 0 ]; then
            dialog --colors --title "Import Log" --yesno "\Z1Some imports failed. Would you like to view the complete log?\Z0" 8 60
            if [ $? -eq 0 ]; then
                dialog --colors --title "Complete Import Log" --textbox "$LOG_FILE" 25 78
            fi
        fi

        # Clean up
        rm -f "$progress_file"
        rm -f "$DISPLAY_LOG_FILE"

    } &

    # Wait for the background process to complete
    wait
}

# Transfer and replace a single database
transfer_replace_database() {
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
        dialog --colors --title "Missing Credentials" --msgbox "\Z1MySQL credentials not configured.\n\nPlease set your MySQL username and password first." 8 60
        configure_settings
        return
    fi

    # Step 1: Select the source SQL file
    if [ -z "$SQL_DIR" ] || [ ! -d "$SQL_DIR" ]; then
        dialog --colors --title "No Directory Selected" --msgbox "\Z1No SQL directory selected. Please select a directory first." 8 60
        browse_directories

        if [ -z "$SQL_DIR" ] || [ ! -d "$SQL_DIR" ]; then
            return
        fi
    fi

    # Get list of SQL files in the directory
    local sql_files=()
    local i=1

    while IFS= read -r file; do
        if [ -f "$file" ]; then
            local filename="${file##*/}"
            sql_files+=("$file" "[$i] \Z6$filename\Z0")
            ((i++))
        fi
    done < <(find "$SQL_DIR" -maxdepth 1 -type f -name "$SQL_PATTERN" | sort)

    if [ ${#sql_files[@]} -eq 0 ]; then
        dialog --colors --title "No SQL Files Found" --msgbox "\Z1No SQL files matching pattern '$SQL_PATTERN' found in $SQL_DIR." 8 60
        return
fi

    # Select a single SQL file
    local selected_file
    selected_file=$(dialog --colors --clear --backtitle "\Z6SDBTT - Transfer Database\Z0" \
        --title "Select Source SQL File" \
        --menu "Select the SQL file to import:" 20 76 12 \
        "${sql_files[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$selected_file" ]; then
        return
    fi

    # Extract original database name from filename
    local filename=$(basename "$selected_file")
    local base_filename="${filename%.sql}"

    # Step 2: Select MySQL user to own the database
    # Get list of MySQL users
    local users
    users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

    if [ -z "$users" ]; then
        dialog --colors --title "No MySQL Users" --msgbox "\Z1No MySQL users found. Would you like to create a MySQL user first?" 8 60
        local create_user_choice
        create_user_choice=$(dialog --colors --title "Create MySQL User" --yesno "Would you like to create a new MySQL user first?" 8 60)

        if [ $? -eq 0 ]; then
            create_mysql_user
            # Try again to get users
            users=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User FROM mysql.user WHERE User NOT IN ('root', 'debian-sys-maint', 'mysql.sys', 'mysql.session', 'mysql.infoschema');" 2>/dev/null | grep -v "User")

            if [ -z "$users" ]; then
                dialog --colors --title "Error" --msgbox "\Z1Still no MySQL users found. Using root as owner." 8 60
                DB_OWNER="root"
            fi
        else
            dialog --colors --title "Using Root" --msgbox "\Z1Using root as the database owner." 8 60
            DB_OWNER="root"
        fi
fi

    if [ -n "$users" ]; then
        # Create options for user selection
        local user_options=()
        for user in $users; do
            user_options+=("$user" "MySQL user: $user")
        done

        # Add root as an option
        user_options+=("root" "MySQL user: root (system administrator)")

        # Select user
        local selected_user
        selected_user=$(dialog --colors --title "Select MySQL User" --menu "Select MySQL user to own the database:" 15 60 8 "${user_options[@]}" 3>&1 1>&2 2>&3)

        if [ -z "$selected_user" ]; then
            return
fi

        DB_OWNER="$selected_user"
fi

    # Step 3: Choose whether to create a new database or replace existing one
    local db_options=()

    # Add option for new database with generated name
    local suggested_name="${DB_PREFIX}${base_filename}"
    db_options+=("new" "Create new database: \Z5$suggested_name\Z0")

    # Get list of existing databases
    local databases
    databases=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")

    if [ -n "$databases" ]; then
        # Add option to select existing database to replace
        db_options+=("replace" "Replace an existing database")
fi

    # Add option for custom name
    db_options+=("custom" "Use a custom database name")

    # Select database option
    local db_option
    db_option=$(dialog --colors --title "Database Operation" --menu "Choose database operation:" 15 60 8 "${db_options[@]}" 3>&1 1>&2 2>&3)

    if [ -z "$db_option" ]; then
        return
    fi

    local target_db_name=""

    case $db_option in
        "new")
            target_db_name="$suggested_name"
            ;;
        "replace")
            # Create options for database selection
            local existing_db_options=()
            for db in $databases; do
                existing_db_options+=("$db" "Database: $db")
            done

            # Select database
            local selected_db
            selected_db=$(dialog --colors --title "Select Database to Replace" --menu "Select database to replace:" 15 60 8 "${existing_db_options[@]}" 3>&1 1>&2 2>&3)

            if [ -z "$selected_db" ]; then
                return
fi

            # Confirm replacement
            dialog --colors --title "Confirm Database Replacement" --yesno "\Z1Are you sure you want to replace the database '$selected_db'?\n\nThis will DELETE all data in this database and replace it with the content from $filename.\n\nThis action cannot be undone!" 12 70

            if [ $? -ne 0 ]; then
                return
fi

            target_db_name="$selected_db"
            ;;
        "custom")
            # Get custom database name
            target_db_name=$(dialog --colors --title "Custom Database Name" --inputbox "Enter custom database name:" 8 60 "$suggested_name" 3>&1 1>&2 2>&3)

            if [ -z "$target_db_name" ]; then
                return
fi
            ;;
    esac

    # Show transfer plan
    local plan="\Z5Transfer Plan Summary:\Z0\n\n"
    plan+="Source SQL file: \Z6$filename\Z0\n"
    plan+="Target database: \Z6$target_db_name\Z0\n"
    plan+="Database owner: \Z6$DB_OWNER\Z0\n\n"

    if [ "$db_option" = "replace" ]; then
        plan+="\Z1WARNING: The existing database '$target_db_name' will be dropped and replaced!\Z0\n\n"
    fi

    plan+="\Z6The transfer process will:\Z0\n"
    plan+="1. Drop the target database if it exists\n"
    plan+="2. Create a new database with utf8mb4 charset\n"
    plan+="3. Import data from the SQL file\n"
    plan+="4. Fix character encoding issues\n"
    plan+="5. Grant privileges to \Z5$DB_OWNER\Z0 user\n\n"
    plan+="Logs will be saved to \Z6$LOG_FILE\Z0"

    dialog --colors --title "Transfer Plan" --yesno "$plan\n\nProceed with transfer?" 20 76

    if [ $? -ne 0 ]; then
        return
fi

    # Initialize log files
    echo "Starting database transfer process at $(date)" > "$LOG_FILE"
    echo "MySQL user: $MYSQL_USER" >> "$LOG_FILE"
    echo "Database owner: $DB_OWNER" >> "$LOG_FILE"
    echo "Source SQL file: $filename" >> "$LOG_FILE"
    echo "Target database: $target_db_name" >> "$LOG_FILE"
    echo "----------------------------------------" >> "$LOG_FILE"

    # Create a display log file for the UI
    echo "Starting database transfer process at $(date)" > "$DISPLAY_LOG_FILE"
    echo "----------------------------------------" >> "$DISPLAY_LOG_FILE"

    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR"

    # Show progress
    dialog --title "Transfer Progress" --gauge "Preparing to transfer database..." 10 70 0 &
    local gauge_pid=$!

    # Background process for the actual transfer
    {
        # Update progress - 10%
        echo 10 | dialog --title "Transfer Progress" \
               --gauge "Creating target database..." 10 70 10 \
               2>/dev/null

        # Create the database
        log_message "Creating target database: $target_db_name with utf8mb4 charset"
        create_database "$target_db_name"

        # Update progress - 30%
        echo 30 | dialog --title "Transfer Progress" \
               --gauge "Importing database content..." 10 70 30 \
               2>/dev/null

        # Create a processed version with standardized charset
        local processed_file="$TEMP_DIR/processed_$filename"

        # Import the SQL file using improved version
        if improved_import_sql_file "$target_db_name" "$selected_file" "$processed_file"; then
            # Update progress - 70%
            echo 70 | dialog --title "Transfer Progress" \
                   --gauge "Granting privileges to $DB_OWNER..." 10 70 70 \
                   2>/dev/null

            # Grant privileges
            improved_grant_privileges "$target_db_name" "$DB_OWNER"

            # Update progress - 90%
            echo 90 | dialog --title "Transfer Progress" \
                   --gauge "Finalizing transfer..." 10 70 90 \
                   2>/dev/null

            # Flush privileges
            log_message "Flushing privileges..."
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>> "$LOG_FILE"

            # Clean up temporary files
            log_message "Cleaning up temporary files..."
            rm -rf "$TEMP_DIR"

            log_message "Database transfer completed successfully"
            log_message "------------------------"

            # Final progress update - 100%
            echo 100 | dialog --title "Transfer Progress" \
                   --gauge "Transfer completed!" 10 70 100 \
                   2>/dev/null

            # Give time to see the final state
            sleep 2

            # Kill the dialog process
            kill $gauge_pid 2>/dev/null || true

            # Show the result summary
            dialog --colors --title "Transfer Complete" --msgbox "\Z6Database transfer completed successfully.\n\nSource SQL file: \Z5$filename\Z0\nTarget database: \Z5$target_db_name\Z0\nDatabase owner: \Z5$DB_OWNER\Z0\n\nLog file saved to: \Z5$LOG_FILE\Z0" 12 70
        else
            # Update progress - error state
            echo 100 | dialog --title "Transfer Progress" \
                   --gauge "Transfer failed!" 10 70 100 \
                   2>/dev/null

            # Clean up temporary files
            log_message "Cleaning up temporary files..."
            rm -rf "$TEMP_DIR"

            log_message "Database transfer failed"
            log_message "------------------------"

            # Give time to see the final state
            sleep 2

            # Kill the dialog process
            kill $gauge_pid 2>/dev/null || true

            # Show error message
            dialog --colors --title "Transfer Failed" --msgbox "\Z1Database transfer failed.\n\nPlease check the log file for more details: \Z5$LOG_FILE\Z0" 8 70

            # Show the log
            dialog --colors --title "Transfer Log" --textbox "$LOG_FILE" 20 76
        fi

        # Clean up
        rm -f "$DISPLAY_LOG_FILE"

    } &

    # Wait for the background process to complete
    wait
}

# Select from previously used directories with enhanced theming
select_from_recent_dirs() {
    if [ -z "$LAST_DIRECTORIES" ]; then
        dialog --colors --title "No Recent Directories" --msgbox "\Z1No recently used directories found." 8 60
        return 1
    fi

    local dirs=()
    local i=1

    # Convert colon-separated list to array
    IFS=':' read -ra dir_array <<< "$LAST_DIRECTORIES"

    for dir in "${dir_array[@]}"; do
        if [ -n "$dir" ] && [ -d "$dir" ]; then
            dirs+=("$dir" "Directory $i: \Z6$dir\Z0")
            ((i++))
        fi
    done

    if [ ${#dirs[@]} -eq 0 ]; then
        dialog --colors --title "No Valid Directories" --msgbox "\Z1No valid directories in recent history." 8 60
        return 1
    fi

    dirs+=("BACK" "\Z1⬅️ [ Back to Main Menu ]\Z0")

    local selection
    selection=$(dialog --colors --clear --backtitle "\Z6SDBTT - Recent Directories\Z0" \
        --title "Recent Directories" \
        --menu "Select a recently used directory:" 15 76 8 \
        "${dirs[@]}" 3>&1 1>&2 2>&3)

    case $selection in
        "BACK"|"")
            return 1
            ;;
        *)
            SQL_DIR="$selection"
            dialog --colors --title "Directory Selected" --msgbox "\Z6Selected directory: $SQL_DIR" 8 60
            return 0
            ;;
    esac
}

# View logs menu with enhanced theming
view_logs() {
    local logs=()
    local i=1

    # List log files
    while IFS= read -r log; do
        if [ -f "$log" ]; then
            local log_date=$(basename "$log" | sed 's/sdbtt_\(.*\)\.log/\1/')
            logs+=("$log" "[$i] \Z6Log from $log_date\Z0")
            ((i++))
        fi
    done < <(find "$LOG_DIR" -maxdepth 1 -type f -name "sdbtt_*.log" | sort -r)

    if [ ${#logs[@]} -eq 0 ]; then
        dialog --colors --title "No Logs Found" --msgbox "\Z1No log files found in $LOG_DIR." 8 60
        return
    fi

    logs+=("BACK" "\Z1⬅️ [ Back to Main Menu ]\Z0")

    local selection
    selection=$(dialog --colors --clear --backtitle "\Z6SDBTT - Logs\Z0" \
        --title "View Logs" \
        --menu "Select a log file to view:" 15 76 8 \
        "${logs[@]}" 3>&1 1>&2 2>&3)

    case $selection in
        "BACK"|"")
            return
            ;;
        *)
            # Check file size
            local file_size=$(du -k "$selection" | cut -f1)

            if [ "$file_size" -gt 500 ]; then
                dialog --colors --title "Large File" --yesno "\Z1The log file is quite large (${file_size}KB). Viewing large files may be slow. Continue?" 8 60
                if [ $? -ne 0 ]; then
                    return
                fi
            fi

            # View log file with enhanced formatting
            # Process the log file to add color to key events
            local temp_log="/tmp/sdbtt_colored_log_$"
            cat "$selection" |
                sed 's/\[ERROR\]/\\Z1[ERROR]\\Z0/g' |
                sed 's/\[WARNING\]/\\Z3[WARNING]\\Z0/g' |
                sed 's/Creating database:/\\Z5Creating database:\\Z0/g' |
                sed 's/Import successful/\\Z2Import successful\\Z0/g' |
                sed 's/Failed to/\\Z1Failed to\\Z0/g' |
                sed 's/All import methods failed/\\Z1All import methods failed\\Z0/g' |
                sed 's/Flushing privileges/\\Z5Flushing privileges\\Z0/g' |
                sed 's/All databases have been processed/\\Z5All databases have been processed\\Z0/g' > "$temp_log"

            dialog --colors --title "Log File: $(basename "$selection")" --textbox "$temp_log" 25 78

            # Clean up
            rm -f "$temp_log"
            ;;
    esac
}

# Main MySQL management menu with enhanced options
enhanced_mysql_admin_menu() {
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
        dialog --colors --title "MySQL Admin" --msgbox "\Z1MySQL credentials not configured.\n\nPlease set your MySQL username and password first." 8 60
        return
    fi

    while true; do
        local choice
        choice=$(dialog --colors --clear --backtitle "\Z6SDBTT MySQL Administration\Z0" \
            --title "MySQL Administration" --menu "Choose an option:" 20 70 18 \
            "1" "\Z6List All Databases\Z0" \
            "2" "\Z6View Database Details\Z0" \
            "3" "\Z6Backup Database\Z0" \
            "4" "\Z6Restore Database from Backup\Z0" \
            "5" "\Z6Rename Database\Z0" \
            "6" "\Z6Remove Database\Z0" \
            "7" "\Z6Manage Database Permissions\Z0" \
            "8" "\Z6Show Database Size\Z0" \
            "9" "\Z6Optimize Tables\Z0" \
            "10" "\Z6Check Database Integrity\Z0" \
            "11" "\Z6MySQL Status\Z0" \
            "12" "\Z6List All Users\Z0" \
            "13" "\Z6Show User Privileges\Z0" \
            "14" "\Z6Create MySQL User\Z0" \
            "15" "\Z6Change User Password\Z0" \
            "16" "\Z6Delete MySQL User\Z0" \
            "17" "\Z6Database-to-User Assignment\Z0" \
            "18" "\Z1Back to Main Menu\Z0" \
            3>&1 1>&2 2>&3)

        case $choice in
            1) list_databases ;;
            2)
                # First get a list of databases to select from
                local db_list=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")
                local db_options=()
                for db in $db_list; do
                    db_options+=("$db" "Database: $db")
                done

                if [ ${#db_options[@]} -eq 0 ]; then
                    dialog --colors --title "No Databases" --msgbox "\Z1No databases found." 8 60
                else
                    local selected_db=$(dialog --colors --title "Select Database" --menu "Select a database to view:" 15 60 10 "${db_options[@]}" 3>&1 1>&2 2>&3)
                    if [ -n "$selected_db" ]; then
                        show_database_details "$selected_db"
                    fi
                fi
                ;;
            3)
                # First get a list of databases to select from
                local db_list=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")
                local db_options=()
                for db in $db_list; do
                    db_options+=("$db" "Database: $db")
                done

                if [ ${#db_options[@]} -eq 0 ]; then
                    dialog --colors --title "No Databases" --msgbox "\Z1No databases found." 8 60
                else
                    local selected_db=$(dialog --colors --title "Select Database" --menu "Select a database to backup:" 15 60 10 "${db_options[@]}" 3>&1 1>&2 2>&3)
                    if [ -n "$selected_db" ]; then
                        backup_database_with_progress "$selected_db"
                    fi
                fi
                ;;
            4) restore_database_with_progress ;;
            5) rename_database ;;
            6) remove_database ;;
            7)
                # First get a list of databases to select from
                local db_list=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null | grep -v -E "^(Database|information_schema|performance_schema|mysql|sys)$")
                local db_options=()
                for db in $db_list; do
                    db_options+=("$db" "Database: $db")
                done

                if [ ${#db_options[@]} -eq 0 ]; then
                    dialog --colors --title "No Databases" --msgbox "\Z1No databases found." 8 60
                else
                    local selected_db=$(dialog --colors --title "Select Database" --menu "Select a database to manage permissions:" 15 60 10 "${db_options[@]}" 3>&1 1>&2 2>&3)
                    if [ -n "$selected_db" ]; then
                        manage_database_permissions "$selected_db"
                    fi
                fi
                ;;
            8) show_database_size ;;
            9) optimize_tables ;;
            10) check_database_integrity ;;
            11) show_mysql_status ;;
            12) list_users ;;
            13) show_user_privileges ;;
            14) create_mysql_user ;;
            15) change_mysql_password ;;
            16) delete_mysql_user ;;
            17) database_user_assignment ;;
            18|"") break ;;
        esac
    done
}

# Help screen with enhanced theming
show_help() {
    dialog --colors --title "SDBTT Help" --msgbox "\
\Z5Simple Database Transfer Tool (SDBTT) Help\Z0
------------------------------------

This tool helps you import MySQL databases from SQL files with the following features:

\Z6* Interactive TUI with enhanced Retrowave theme
* Directory navigation and selection
* Configuration management with secure password storage
* Automatic charset conversion and fixing Persian/Arabic text
* Multiple import methods for compatibility
* Prefix replacement
* MySQL administration tools
* MySQL user management
* Database transfer and replacement
* Privilege management\Z0

\Z5How to use this tool:\Z0
1. Configure your MySQL credentials
2. Set the database owner who will receive privileges
3. Browse to the directory containing your SQL files
4. Select which files to import
5. Review and confirm the import plan

\Z5Command-line options:\Z0
--install    Install SDBTT to system
--update     Update SDBTT from GitHub
--remove     Remove SDBTT from system
--help       Show this help message
--debug      Enable debug logging
--no-dialog  Disable dialog UI
--no-color   Disable colored output

\Z5Security features:\Z0
* Passwords are encrypted and stored securely
* Restricted file permissions for sensitive files
* No plaintext passwords in config files

The tool saves your settings for future use and keeps logs of all operations.

\Z5Character Encoding Support:\Z0
* Properly handles UTF-8 and UTF-8MB4 encoding
* Automatically detects and fixes encoding issues
* Ensures proper display of Persian, Arabic, and other non-Latin scripts
" 25 78
}

# Process command line arguments
process_arguments() {
    for arg in "$@"; do
        case "$arg" in
            --install)
                install_script
                exit $?
                ;;
            --update)
                update_script
                exit $?
                ;;
            --remove)
                remove_script
                exit $?
                ;;
            --help)
                show_header
                cat << EOF
SDBTT: Simple Database Transfer Tool
Usage: $(basename "$0") [OPTION]

Options:
  --install       Install SDBTT to system
  --update        Update SDBTT from GitHub
  --remove        Remove SDBTT from system
  --help          Show this help message
  --debug         Enable debug logging
  --no-dialog     Disable dialog UI (use console mode)
  --no-color      Disable colored output

When run without options, launches the interactive TUI.
EOF
                exit 0
                ;;
            --debug)
                DEBUG=1
                debug_log "Debug mode enabled"
                ;;
            --no-dialog)
                USE_DIALOG=0
                debug_log "Dialog UI disabled"
                ;;
            --no-color)
                USE_COLORS=0
                debug_log "Colors disabled"
                ;;
        esac
    done
}

# Main function
main() {
    # Set DEBUG temporarily to diagnose issues if needed
    DEBUG=${DEBUG:-0}
    debug_log "Starting SDBTT v$VERSION"

    # Process command line arguments if any
    if [ $# -gt 0 ]; then
        process_arguments "$@"
    fi

    # Check dependencies before proceeding
    debug_log "Checking dependencies"
    check_dependencies

    # Get terminal size information
    debug_log "Getting terminal size"
    get_terminal_size

    # Simple clearing first
    clear
    debug_log "Terminal cleared"

    # Set up basic terminal appearance
    debug_log "Setting up terminal appearance"
    set_term_appearance

    # Show the header
    debug_log "Showing header"
    show_header

    # Create required directories
    debug_log "Initializing directories"
    initialize_directories

    # Set default values if not loaded from config
    MYSQL_USER=${MYSQL_USER:-"root"}
    SQL_PATTERN=${SQL_PATTERN:-"*.sql"}

    # Try to load config
    debug_log "Loading configuration"
    load_config

    # Try to retrieve password if we have a username
    if [ -n "$MYSQL_USER" ] && [ -z "$MYSQL_PASS" ]; then
        MYSQL_PASS=$(get_password "$MYSQL_USER")
    fi

    # Setup dialog only after other initialization is complete
    debug_log "Dialog setup starting"
    if [ "$USE_DIALOG" -eq 1 ]; then
        # Setup dialog theme
        if ! setup_dialog_theme; then
            debug_log "Dialog theme setup failed, falling back to console mode"
            USE_DIALOG=0
        fi

        # Check if dialog works
        if ! check_dialog; then
            debug_log "Dialog check failed, falling back to console mode"
            USE_DIALOG=0
        fi
    fi

    debug_log "Ready to show main menu"

    # Show main menu without unnecessary dialogs
    if [ "$USE_DIALOG" -eq 1 ]; then
        show_main_menu
    else
        echo "Console mode not implemented in this version." >&2
        echo "Please install dialog or fix terminal settings to use SDBTT." >&2
        exit 1
    fi

    # Clean up on exit
    if [ -n "$DIALOGRC" ] && [ -f "$DIALOGRC" ]; then
        rm -f "$DIALOGRC"
    fi

    debug_log "SDBTT exiting normally"
}

# List all databases with enhanced formatting
list_databases() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve databases. Check your MySQL credentials." 8 60
        return
    fi

    # Format the output for display with consistent coloring
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/Database/\\Z5Database\\Z0/g')

    dialog --colors --title "MySQL Databases" --msgbox "$formatted_result" 20 60
}

# List all MySQL users with enhanced formatting
list_users() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User, Host FROM mysql.user;" 2>/dev/null)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve users. Check your MySQL credentials." 8 60
        return
    fi

    # Format the output for display with enhanced coloring
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/User/\\Z5User\\Z0/g' | sed 's/Host/\\Z5Host\\Z0/g')

    dialog --colors --title "MySQL Users" --msgbox "$formatted_result" 20 60
}

# Show privileges for a specific user with enhanced formatting
show_user_privileges() {
    local username
    username=$(dialog --colors --title "User Privileges" --inputbox "Enter MySQL username:" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$username" ]; then
        return
    fi

    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW GRANTS FOR '$username'@'localhost';" 2>/dev/null)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve privileges for user $username.\nThe user may not exist." 8 60
        return
    fi

    # Format with consistent coloring
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/Grants for/\\Z5Grants for\\Z0/g')

    dialog --colors --title "Privileges for $username" --msgbox "$formatted_result" 20 70
}

# Show database sizes with enhanced formatting
show_database_size() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "
    SELECT
        table_schema AS 'Database',
        ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) AS 'Size (MB)'
    FROM information_schema.tables
    GROUP BY table_schema
    ORDER BY SUM(data_length + index_length) DESC;" 2>/dev/null)

    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve database sizes." 8 60
        return
    fi

    # Format the output with enhanced coloring
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/Database/\\Z5Database\\Z0/g' | sed 's/Size (MB)/\\Z5Size (MB)\\Z0/g')

    dialog --colors --title "Database Sizes" --msgbox "$formatted_result" 20 70
}

# Optimize tables in a database with progress bar and log display
optimize_tables() {
    local db_name
    db_name=$(dialog --colors --title "Optimize Tables" --inputbox "Enter database name:" 8 60 3>&1 1>&2 2>&3)

    if [ -z "$db_name" ]; then
        return
    fi

    # Check if database exists
    local db_exists
    db_exists=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES LIKE '$db_name';" 2>/dev/null)

    if [ -z "$db_exists" ]; then
        dialog --colors --title "Error" --msgbox "\Z1Database '$db_name' does not exist." 8 60
        return
    fi

    # Get all tables in the database
    local tables
    tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null | tail -n +2)

    if [ -z "$tables" ]; then
        dialog --colors --title "No Tables" --msgbox "\Z6Database '$db_name' has no tables to optimize." 8 60
        return
    fi

    # Create a temporary log file for optimization progress
    local opt_log_file="/tmp/sdbtt_optimize_$.log"
    echo "Starting optimization for database '$db_name'" > "$opt_log_file"

    # Calculate total tables for progress
    local total=$(echo "$tables" | wc -l)

    # Use a split display - progress gauge on top, log tail at bottom
    dialog --colors --title "Optimizing Database" \
           --mixedgauge "Preparing to optimize tables in $db_name..." 0 70 0 \
           "Progress" "0%" "Remaining" "100%" 2>/dev/null &
    local dialog_pid=$!

    # Open a tail dialog for the log
    dialog --colors --title "Optimization Log" --begin 10 5 --tailbox "$opt_log_file" 15 70 &
    local tail_pid=$!

    {
        local i=0
        for table in $tables; do
            i=$((i + 1))
            progress=$((i * 100 / total))
            remaining=$((100 - progress))

            # Update the log file
            echo "[$i/$total] Optimizing table: $table" >> "$opt_log_file"

            # Update the progress gauge
            dialog --colors --title "Optimizing Database" \
                   --mixedgauge "Optimizing tables in $db_name..." 0 70 $progress \
                   "Progress" "$progress%" "Remaining" "$remaining%" 2>/dev/null

            # Perform the optimization
            result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "OPTIMIZE TABLE \`$db_name\`.\`$table\`;" 2>&1)
            echo "Result: $result" >> "$opt_log_file"
            echo "----------------------------------------" >> "$opt_log_file"

            # Small delay for visibility
            sleep 0.1
        done

        # Mark as complete
        echo "Optimization complete for all $total tables in $db_name" >> "$opt_log_file"

        # Final progress update - 100%
        dialog --colors --title "Optimizing Database" \
               --mixedgauge "Optimizing tables in $db_name..." 0 70 100 \
               "Progress" "100%" "Remaining" "0%" 2>/dev/null

        # Give time to see the final state
        sleep 2

        # Kill the dialog processes
        kill $dialog_pid 2>/dev/null || true
        kill $tail_pid 2>/dev/null || true

        # Show completion dialog
        dialog --colors --title "Optimization Complete" --msgbox "\Z6All tables in database '$db_name' have been optimized.\n\nSee full details in the optimization log." 8 70

        # Display the log in a scrollable viewer
        dialog --colors --title "Optimization Results" --textbox "$opt_log_file" 20 76

        # Clean up
        rm -f "$opt_log_file"

    } &

    # Wait for the background process to complete
    wait