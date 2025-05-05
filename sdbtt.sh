#!/bin/bash
# SDBTT: Simple Database Transfer Tool
# Enhanced MySQL Database Import Script with Retrowave Theme
# Version: 1.2.0

# Default configuration
CONFIG_DIR="$HOME/.sdbtt"
CONFIG_FILE="$CONFIG_DIR/config.conf"
TEMP_DIR="/tmp/sdbtt_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sdbtt_$(date +%Y%m%d_%H%M%S).log"
DISPLAY_LOG_FILE="/tmp/sdbtt_display_log_$(date +%Y%m%d_%H%M%S)"
PASS_STORE="$CONFIG_DIR/.passstore"
VERSION="1.1.0"
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

# Function to log messages - enhanced to also display to active log screen
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    
    # Write to main log file
    echo "[$timestamp] $message" >> "$LOG_FILE"
    
    # If we have an active display log file, write to it too
    if [ -f "$DISPLAY_LOG_FILE" ]; then
        echo "[$timestamp] $message" >> "$DISPLAY_LOG_FILE"
    fi
}

# Function to handle errors with themed error messages
error_exit() {
    log_message "ERROR: $1"
    if command -v dialog &>/dev/null && [ -f "$DIALOGRC" ]; then
        dialog --title "Error" --colors --msgbox "\Z1ERROR: $1\Z0" 8 60
    else
        echo -e "${RW_ALERT}ERROR: $1${RESET}" >&2
    fi
    exit 1
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
    
    # Create the update log file with timestamp
    mkdir -p "$temp_dir"
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
        if ! git clone "$REPO_URL" . >>$update_log 2>&1; then
            echo "[$(date)] ERROR: Failed to clone repository. Check your internet connection and try again." >> "$update_log"
            sleep 3
            kill $dialog_pid 2>/dev/null
            cd "$current_dir" || true
            dialog --colors --title "Update Failed" --msgbox "\Z1Failed to clone repository. Check your internet connection and try again." 8 60
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Check if there's a newer version
        echo "[$(date)] Checking version information..." >> "$update_log"
        if [ -f "VERSION" ]; then
            REPO_VERSION=$(cat VERSION)
            echo "[$(date)] Found explicit VERSION file: $REPO_VERSION" >> "$update_log"
        else
            REPO_VERSION=$(grep "^VERSION=" sdbtt | cut -d'"' -f2)
            echo "[$(date)] Extracted version from script: $REPO_VERSION" >> "$update_log"
        fi
        
        if [ -z "$REPO_VERSION" ]; then
            echo "[$(date)] ERROR: Could not determine repository version." >> "$update_log"
            sleep 2
            kill $dialog_pid 2>/dev/null
            cd "$current_dir" || true
            dialog --colors --title "Update Failed" --msgbox "\Z1Could not determine repository version." 8 60
            rm -rf "$temp_dir"
            return 1
        fi
        
        # Compare versions
        echo "[$(date)] Comparing versions - Current: $VERSION, Repository: $REPO_VERSION" >> "$update_log"
        
        if [ "$VERSION" = "$REPO_VERSION" ]; then
            echo "[$(date)] Your version ($VERSION) is already up to date." >> "$update_log"
            sleep 2
            kill $dialog_pid 2>/dev/null
            cd "$current_dir" || true
            dialog --colors --title "No Updates" --msgbox "\Z6Your version ($VERSION) is already up to date." 8 60
            rm -rf "$temp_dir"
            return 0
        fi
        
        # Kill tailbox before asking for confirmation
        sleep 1
        kill $dialog_pid 2>/dev/null
        
        # Confirm update
        dialog --colors --title "Update Available" --yesno "\Z6A new version is available.\n\nCurrent version: $VERSION\nNew version: $REPO_VERSION\n\nDo you want to update?" 10 60
        
        if [ $? -eq 0 ]; then
            # Use simpler display during update to avoid dialog issues
            echo "[$(date)] User confirmed update. Proceeding with installation..." > "$update_log"
            echo "Installing update, please wait..."
            
            # Update the script
            echo "[$(date)] Checking installation method..." >> "$update_log"
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
                cp "sdbtt" "/usr/local/bin/sdbtt" >> "$update_log" 2>&1
                chmod 755 "/usr/local/bin/sdbtt" >> "$update_log" 2>&1
                echo "[$(date)] System installation updated successfully." >> "$update_log"
            else
                echo "[$(date)] Updating current script..." >> "$update_log"
                cp "sdbtt" "$0" >> "$update_log" 2>&1
                chmod 755 "$0" >> "$update_log" 2>&1
                echo "[$(date)] Script updated successfully." >> "$update_log"
            fi
            
            # Update changelog information
            if [ -f "CHANGELOG.md" ]; then
                echo "[$(date)] Found changelog file. Extracting changes..." >> "$update_log"
                echo "[$(date)] Changes in version $REPO_VERSION:" >> "$update_log"
                grep -A 10 "## \[$REPO_VERSION\]" "CHANGELOG.md" >> "$update_log" 2>/dev/null || echo "No detailed changelog found for this version." >> "$update_log"
            else
                echo "[$(date)] No changelog found." >> "$update_log"
            fi
            
            sleep 2
            kill $install_dialog_pid 2>/dev/null
            
            # Extract a simple changelog to show to the user
            local changelog=""
            if [ -f "CHANGELOG.md" ]; then
                changelog=$(grep -A 10 "## \[$REPO_VERSION\]" "CHANGELOG.md" 2>/dev/null)
            fi
            
            if [ -n "$changelog" ]; then
                dialog --colors --title "Update Successful" --msgbox "\Z6Updated from version $VERSION to $REPO_VERSION.\n\nChanges in this version:\n$changelog\n\nPlease restart the script for changes to take effect." 16 70
            else
                dialog --colors --title "Update Successful" --msgbox "\Z6Updated from version $VERSION to $REPO_VERSION.\n\nPlease restart the script for changes to take effect." 10 60
            fi
            
            # Cleanup and exit
            rm -rf "$temp_dir"
            cd "$current_dir" || true
            exit 0
        else
            dialog --colors --title "Update Cancelled" --msgbox "\Z6Update cancelled. Keeping version $VERSION." 8 60
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

# Remove the script from the system
remove_script() {
    local script_path="/usr/local/bin/sdbtt"
    local conf_dir="/etc/sdbtt"
    
    # Check if running with sudo/root
    if [ "$(id -u)" -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Removal requires root privileges. Please run with sudo." 8 60
        return 1
    fi
    
    # Confirm removal
    dialog --colors --title "Remove SDBTT" --yesno "\Z1Are you sure you want to remove SDBTT from your system?\n\nThis will delete:\n- $script_path\n- $conf_dir\n\nYour personal configuration in $CONFIG_DIR will not be removed." 12 70
    
    if [ $? -eq 0 ]; then
        # Remove script and config
        rm -f "$script_path"
        rm -rf "$conf_dir"
        
        dialog --colors --title "Removal Complete" --msgbox "\Z6SDBTT has been removed from your system.\n\nYour personal configuration in $CONFIG_DIR has been kept.\nTo remove it completely, delete this directory manually." 10 70
        return 0
    else
        dialog --colors --title "Removal Cancelled" --msgbox "\Z6Removal cancelled." 8 60
        return 0
    fi
}

# Check for updates and notify user
check_for_updates() {
    dialog --colors --title "Checking for Updates" --infobox "\Z6Checking for updates from $REPO_URL..." 5 60
    
    # Create temp directory
    local temp_dir="/tmp/sdbtt_update_check_$(date +%s)"
    mkdir -p "$temp_dir"
    cd "$temp_dir" || return 1
    
    # Silent clone or fetch latest version info
    if ! git clone --depth 1 "$REPO_URL" . >/dev/null 2>&1; then
        dialog --colors --title "Update Check Failed" --msgbox "\Z1Failed to check for updates. Check your internet connection and try again." 8 60
        rm -rf "$temp_dir"
        return 1
    fi
    
    # Get latest version
    local REPO_VERSION=""
    if [ -f "VERSION" ]; then
        REPO_VERSION=$(cat VERSION)
    else
        REPO_VERSION=$(grep "^VERSION=" sdbtt | cut -d'"' -f2)
    fi
    
    # Clean up
    cd - >/dev/null
    rm -rf "$temp_dir"
    
    if [ -z "$REPO_VERSION" ]; then
        dialog --colors --title "Update Check Failed" --msgbox "\Z1Could not determine repository version." 8 60
        return 1
    fi
    
    # Compare versions
    if [ "$VERSION" = "$REPO_VERSION" ]; then
        dialog --colors --title "No Updates" --msgbox "\Z6Your version ($VERSION) is already up to date." 8 60
        return 0
    else
        dialog --colors --title "Update Available" --yesno "\Z6A new version is available.\n\nCurrent version: $VERSION\nNew version: $REPO_VERSION\n\nDo you want to update now?" 10 60
        
        if [ $? -eq 0 ]; then
            update_script
            return $?
        fi
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

# Display the MySQL administration menu with enhanced colors
mysql_admin_menu() {
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
        dialog --colors --title "MySQL Admin" --msgbox "\Z1MySQL credentials not configured.\n\nPlease set your MySQL username and password first." 8 60
        return
    fi
    
    while true; do
        local choice
        choice=$(dialog --colors --clear --backtitle "\Z6SDBTT MySQL Administration\Z0" \
            --title "MySQL Administration" --menu "Choose an option:" 15 60 9 \
            "1" "\Z6List All Databases\Z0" \
            "2" "\Z6List All Users\Z0" \
            "3" "\Z6Show User Privileges\Z0" \
            "4" "\Z6Show Database Size\Z0" \
            "5" "\Z6Optimize Tables\Z0" \
            "6" "\Z6Check Database Integrity\Z0" \
            "7" "\Z6MySQL Status\Z0" \
            "8" "\Z6Manage MySQL Users\Z0" \
            "9" "\Z1Back to Main Menu\Z0" \
            3>&1 1>&2 2>&3)
            
        case $choice in
            1) list_databases ;;
            2) list_users ;;
            3) show_user_privileges ;;
            4) show_database_size ;;
            5) optimize_tables ;;
            6) check_database_integrity ;;
            7) show_mysql_status ;;
            8) manage_mysql_users ;;
            9|"") break ;;
        esac
    done
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
    local opt_log_file="/tmp/sdbtt_optimize_$$.log"
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
        dialog --colors --title "No Tables" --msgbox "\Z6Database '$db_name' has no tables to check." 8 60
        return
    fi
    
    # Create a temporary log file for check progress
    local check_log_file="/tmp/sdbtt_check_$$.log"
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

# Manage MySQL users with enhanced UI
manage_mysql_users() {
    while true; do
        local choice
        choice=$(dialog --colors --clear --backtitle "\Z6SDBTT MySQL User Management\Z0" \
            --title "MySQL User Management" --menu "Choose an option:" 15 60 6 \
            "1" "\Z6Create New MySQL User\Z0" \
            "2" "\Z6Change User Password\Z0" \
            "3" "\Z6Delete MySQL User\Z0" \
            "4" "\Z6Grant Privileges to User\Z0" \
            "5" "\Z6Revoke Privileges from User\Z0" \
            "6" "\Z1Back to Admin Menu\Z0" \
            3>&1 1>&2 2>&3)
            
        case $choice in
            1) create_mysql_user ;;
            2) change_mysql_password ;;
            3) delete_mysql_user ;;
            4) grant_user_privileges ;;
            5) revoke_user_privileges ;;
            6|"") break ;;
        esac
    done
}

# Create a new MySQL user with enhanced UI
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

# Grant privileges to user
grant_user_privileges() {
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
    selected_user=$(dialog --colors --title "Select User" --menu "Select MySQL user to grant privileges:" 15 60 8 "${user_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ -z "$selected_user" ]; then
        return
    fi
    
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
    selected_dbs=$(dialog --colors --title "Select Databases" --checklist "Select databases to grant privileges to '$selected_user':" 15 60 8 "${db_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ -z "$selected_dbs" ]; then
        return
    fi
    
    # Remove quotes from the output
    selected_dbs=$(echo "$selected_dbs" | tr -d '"')
    
    # Choose privilege type
    local privilege_type
    privilege_type=$(dialog --colors --title "Privilege Type" --menu "Select type of privileges to grant:" 15 60 3 \
        "ALL" "All privileges (SELECT, INSERT, UPDATE, DELETE, etc.)" \
        "RO" "Read-only privileges (SELECT)" \
        "RW" "Read-write privileges (SELECT, INSERT, UPDATE, DELETE)" \
        3>&1 1>&2 2>&3)
    
    if [ -z "$privilege_type" ]; then
        return
    fi
    
    # Grant privileges based on type
    for db in $selected_dbs; do
        case $privilege_type in
            "ALL")
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON \`$db\`.* TO '$selected_user'@'localhost';" 2>/dev/null
                ;;
            "RO")
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT SELECT ON \`$db\`.* TO '$selected_user'@'localhost';" 2>/dev/null
                ;;
            "RW")
                mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT SELECT, INSERT, UPDATE, DELETE ON \`$db\`.* TO '$selected_user'@'localhost';" 2>/dev/null
                ;;
        esac
        
        if [ $? -ne 0 ]; then
            dialog --colors --title "Warning" --msgbox "\Z3Warning: Failed to grant privileges on database '$db' to user '$selected_user'." 8 70
        fi
    done
    
    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    dialog --colors --title "Success" --msgbox "\Z6Privileges granted to MySQL user '$selected_user' on selected databases." 8 70
}

# Revoke privileges from user
revoke_user_privileges() {
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
    selected_user=$(dialog --colors --title "Select User" --menu "Select MySQL user to revoke privileges:" 15 60 8 "${user_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ -z "$selected_user" ]; then
        return
    fi
    
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
    selected_dbs=$(dialog --colors --title "Select Databases" --checklist "Select databases to revoke privileges from '$selected_user':" 15 60 8 "${db_options[@]}" 3>&1 1>&2 2>&3)
    
    if [ -z "$selected_dbs" ]; then
        return
    fi
    
    # Remove quotes from the output
    selected_dbs=$(echo "$selected_dbs" | tr -d '"')
    
    # Revoke privileges
    for db in $selected_dbs; do
        mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "REVOKE ALL PRIVILEGES ON \`$db\`.* FROM '$selected_user'@'localhost';" 2>/dev/null
        
        if [ $? -ne 0 ]; then
            dialog --colors --title "Warning" --msgbox "\Z3Warning: Failed to revoke privileges on database '$db' from user '$selected_user'." 8 70
        fi
    done
    
    # Flush privileges
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>/dev/null
    
    dialog --colors --title "Success" --msgbox "\Z6Privileges revoked from MySQL user '$selected_user' on selected databases." 8 70
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
            5) mysql_admin_menu ;;
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

# Improved import_sql_file function with better encoding handling
import_sql_file() {
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
    
    # Second step: Fix charset declarations and other issues
    log_message "Applying charset fixes and other corrections..."
    
    # Process for charset declarations and other fixes
    sed -e 's/utf8mb3/utf8mb4/g' \
        -e 's/utf8/utf8mb4/g' \
        -e 's/SET NAMES utf8;/SET NAMES utf8mb4;/g' \
        -e 's/SET character_set_client = utf8;/SET character_set_client = utf8mb4;/g' \
        -e 's/DEFAULT CHARSET=utf8/DEFAULT CHARSET=utf8mb4/g' \
        -e 's/CHARSET=utf8/CHARSET=utf8mb4/g' \
        -e 's/CHARACTER SET utf8/CHARACTER SET utf8mb4/g' \
        -e 's/COLLATE=utf8_general_ci/COLLATE=utf8mb4_unicode_ci/g' \
        -e 's/COLLATE utf8_general_ci/COLLATE utf8mb4_unicode_ci/g' \
        -e 's/COLLATE=utf8_/COLLATE=utf8mb4_/g' \
        -e 's/SET @saved_cs_client     = @@character_set_client/SET @saved_cs_client = @@character_set_client/g' \
        -e 's/^\s*\\-/-- -/g' \
        "$utf8_file" > "$processed_file"
        
    log_message "File processed for encoding issues. Attempting import..."
    
    # Try direct import with charset parameters
    log_message "Attempting direct import with charset parameters for $db_name..."
    mysql --default-character-set=utf8mb4 -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" < "$processed_file" 2>> "$LOG_FILE"
    
    # Check if import succeeded by counting tables
    local table_count
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        log_message "Import successful - $table_count tables created in $db_name"
        
        # Fix character set and collation for tables and columns
        log_message "Fixing character sets and collations for tables and columns..."
        
        # Get list of all tables
        local tables
        tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)
        
        for table in $tables; do
            # Convert table to utf8mb4
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER TABLE \`$db_name\`.\`$table\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"
            
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
        done
        
        log_message "Character set and collation fixes completed for all tables in $db_name"
        return 0
    fi
    
    log_message "Direct import failed, trying alternative import method..."
    
    # Try importing with source command
    log_message "Attempting import with SOURCE command..."
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" -e "SOURCE $processed_file;" 2>> "$LOG_FILE"
    
    # Check again
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        log_message "Import via SOURCE command successful - $table_count tables created in $db_name"
        
        # Fix character set and collation for tables and columns
        log_message "Fixing character sets and collations for tables and columns..."
        
        # Get list of all tables
        local tables
        tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)
        
        for table in $tables; do
            # Convert table to utf8mb4
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER TABLE \`$db_name\`.\`$table\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"
        done
        
        log_message "Character set and collation fixes completed for all tables in $db_name"
        return 0
    fi
    
    log_message "Both import methods failed. As a last resort, trying with mysqlimport..."
    
    # Try running mysqlimport as a last resort
    mysqlimport --local --user="$MYSQL_USER" --password="$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" "$processed_file" 2>> "$LOG_FILE"
    
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ -n "$table_count" ] && [ "$table_count" -gt 0 ]; then
        log_message "Final import attempt successful - $table_count tables created in $db_name"
        
        # Fix character set and collation for tables and columns
        log_message "Fixing character sets and collations for tables and columns..."
        
        # Get list of all tables
        local tables
        tables=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW TABLES FROM \`$db_name\`;" 2>/dev/null)
        
        for table in $tables; do
            # Convert table to utf8mb4
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "ALTER TABLE \`$db_name\`.\`$table\` CONVERT TO CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;" 2>> "$LOG_FILE"
        done
        
        log_message "Character set and collation fixes completed for all tables in $db_name"
        return 0
     else {
        log_message "All import methods failed for $db_name"
        log_message "Manual inspection required:"
        log_message "mysql -u root -p --default-character-set=utf8mb4"
        log_message "CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        log_message "USE $db_name;"
        log_message "SOURCE $sql_file;"
        return 1
    }
    fi
}

# Grant privileges to database owner
grant_privileges() {
    local db_name="$1"
    local db_owner="$2"
    
    log_message "Granting privileges on $db_name to user '$db_owner'..."
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "GRANT ALL PRIVILEGES ON \`$db_name\`.* TO '$db_owner'@'localhost';" 2>> "$LOG_FILE" || {
        log_message "Warning: Failed to grant privileges on $db_name to $db_owner"
    }
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
            
            # Import the SQL file
            if import_sql_file "$db_name" "$sql_file" "$processed_file"; then
                # Grant privileges if import was successful
                grant_privileges "$db_name" "$DB_OWNER"
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
        
        # Import the SQL file
        if import_sql_file "$target_db_name" "$selected_file" "$processed_file"; then
            # Update progress - 70%
            echo 70 | dialog --title "Transfer Progress" \
                   --gauge "Granting privileges to $DB_OWNER..." 10 70 70 \
                   2>/dev/null
            
            # Grant privileges
            grant_privileges "$target_db_name" "$DB_OWNER"
            
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

# Start the script
main "$@"