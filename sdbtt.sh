#!/bin/bash
# SDBTT: Simple Database Transfer Tool
# Enhanced MySQL Database Import Script with Synthwave Theme
# Version: 1.0.3

# Default configuration
CONFIG_DIR="$HOME/.sdbtt"
CONFIG_FILE="$CONFIG_DIR/config.conf"
TEMP_DIR="/tmp/sdbtt_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sdbtt_$(date +%Y%m%d_%H%M%S).log"
DISPLAY_LOG_FILE="/tmp/sdbtt_display_log_$(date +%Y%m%d_%H%M%S)"
PASS_STORE="$CONFIG_DIR/.passstore"
VERSION="1.0.3"
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

# Enhanced theme settings with more synthwave colors
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
    
    # Create the dialog configuration file with simplified synthwave colors
    # Using more compatible dialog theme settings
    cat > "$dialogrc_file" << 'EOF'
# Dialog configuration with Synthwave theme
# Set aspect-ratio and screen edge
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = OFF
use_shadow = ON
use_colors = ON

# Simplified Synthwave color scheme for better compatibility
screen_color = (BLACK,BLACK,OFF)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (MAGENTA,BLACK,OFF)
title_color = (MAGENTA,BLACK,ON)
border_color = (MAGENTA,BLACK,ON)
button_active_color = (BLACK,MAGENTA,ON)
button_inactive_color = (MAGENTA,BLACK,OFF)
button_key_active_color = (BLACK,MAGENTA,ON)
button_key_inactive_color = (MAGENTA,BLACK,OFF)
button_label_active_color = (BLACK,MAGENTA,ON)
button_label_inactive_color = (MAGENTA,BLACK,OFF)
inputbox_color = (MAGENTA,BLACK,OFF)
inputbox_border_color = (MAGENTA,BLACK,ON)
searchbox_color = (MAGENTA,BLACK,OFF)
searchbox_title_color = (MAGENTA,BLACK,ON)
searchbox_border_color = (MAGENTA,BLACK,ON)
position_indicator_color = (MAGENTA,BLACK,ON)
menubox_color = (MAGENTA,BLACK,OFF)
menubox_border_color = (MAGENTA,BLACK,ON)
item_color = (MAGENTA,BLACK,OFF)
item_selected_color = (BLACK,MAGENTA,ON)
tag_color = (MAGENTA,BLACK,ON)
tag_selected_color = (BLACK,MAGENTA,ON)
tag_key_color = (MAGENTA,BLACK,ON)
tag_key_selected_color = (BLACK,MAGENTA,ON)
check_color = (MAGENTA,BLACK,OFF)
check_selected_color = (BLACK,MAGENTA,ON)
uarrow_color = (MAGENTA,BLACK,ON)
darrow_color = (MAGENTA,BLACK,ON)
itemhelp_color = (MAGENTA,BLACK,OFF)
form_active_text_color = (BLACK,MAGENTA,ON)
form_text_color = (MAGENTA,BLACK,ON)
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

# Simplified ANSI color codes for better compatibility
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
    # Limit bright colors to essential ones
    BRIGHTMAGENTA="\033[95m"
    BRIGHTCYAN="\033[96m"
    BGBLACK="\033[40m"
    BGMAGENTA="\033[45m"
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

# Simplified color presets for better compatibility
SYN_PRIMARY="${MAGENTA}"
SYN_SECONDARY="${CYAN}"
SYN_ALERT="${RED}"
SYN_SUCCESS="${GREEN}"
SYN_WARNING="${YELLOW}"
SYN_BG="${BGBLACK}"
SYN_HEADER="${MAGENTA}${BOLD}"

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
        echo -ne "\033]0;SDBTT - Synthwave\007"
        
        # Simple clear with basic synthwave effect
        clear
        # Top border
        echo -e "${BGBLACK}${MAGENTA}$(printf '%*s' ${COLUMNS} | tr ' ' '═')${RESET}"
        
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
    
    for cmd in dialog mysql mysqldump sed awk git openssl curl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${SYN_ALERT}Error: Missing required dependencies: ${missing_deps[*]}${RESET}"
        echo "Please install them before running this script."
        exit 1
    fi
    
    debug_log "All dependencies found"
}

# Display fancy ASCII art header with enhanced colors
show_header() {
    debug_log "Showing header"
    
    # Return cursor to top (if possible)
    if command -v tput > /dev/null 2>&1; then
        tput cup 0 0 2>/dev/null || true
    fi
    
    # Using enhanced synthwave colors
    if [ "$USE_COLORS" -eq 1 ]; then
        echo -e "${SYN_HEADER}"
        cat << "EOF"
 ██████╗██████╗ ██████╗ ████████╗████████╗
██╔════╝██╔══██╗██╔══██╗╚══██╔══╝╚══██╔══╝
╚█████╗ ██║  ██║██████╔╝   ██║      ██║   
 ╚═══██╗██║  ██║██╔══██╗   ██║      ██║   
██████╔╝██████╔╝██████╔╝   ██║      ██║   
╚═════╝ ╚═════╝ ╚═════╝    ╚═╝      ╚═╝   
EOF
        echo -e "${BRIGHTMAGENTA}░▒▓${MAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTMAGENTA}░▒▓${MAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTMAGENTA}░▒▓${MAGENTA}█${BRIGHTCYAN}▓▒░${BRIGHTMAGENTA}░▒▓${MAGENTA}█${BRIGHTCYAN}▓▒░"
        echo -e "${SYN_HEADER}Simple Database Transfer Tool v$VERSION${RESET}"
        echo -e "${BRIGHTCYAN}░▒▓${CYAN}█${BRIGHTMAGENTA}▓▒░${BRIGHTCYAN}░▒▓${CYAN}█${BRIGHTMAGENTA}▓▒░${BRIGHTCYAN}░▒▓${CYAN}█${BRIGHTMAGENTA}▓▒░${BRIGHTCYAN}░▒▓${CYAN}█${BRIGHTMAGENTA}▓▒░${RESET}"
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
        echo -e "${SYN_ALERT}ERROR: $1${RESET}" >&2
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
    dialog --colors --title "Configuration Saved" --msgbox "\Z5Settings have been saved to $CONFIG_FILE" 8 60
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
    
    dialog --colors --title "Installation Complete" --msgbox "\Z5SDBTT has been installed to $install_dir/$script_name\n\nYou can now run it by typing 'sdbtt' in your terminal." 10 70
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
            dialog --colors --title "No Updates" --msgbox "\Z5Your version ($VERSION) is already up to date." 8 60
            rm -rf "$temp_dir"
            return 0
        fi
        
        # Kill tailbox before asking for confirmation
        sleep 1
        kill $dialog_pid 2>/dev/null
        
        # Confirm update
        dialog --colors --title "Update Available" --yesno "\Z5A new version is available.\n\nCurrent version: $VERSION\nNew version: $REPO_VERSION\n\nDo you want to update?" 10 60
        
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
                dialog --colors --title "Update Successful" --msgbox "\Z5Updated from version $VERSION to $REPO_VERSION.\n\nChanges in this version:\n$changelog\n\nPlease restart the script for changes to take effect." 16 70
            else
                dialog --colors --title "Update Successful" --msgbox "\Z5Updated from version $VERSION to $REPO_VERSION.\n\nPlease restart the script for changes to take effect." 10 60
            fi
            
            # Cleanup and exit
            rm -rf "$temp_dir"
            cd "$current_dir" || true
            exit 0
        else
            dialog --colors --title "Update Cancelled" --msgbox "\Z5Update cancelled. Keeping version $VERSION." 8 60
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
        
        dialog --colors --title "Removal Complete" --msgbox "\Z5SDBTT has been removed from your system.\n\nYour personal configuration in $CONFIG_DIR has been kept.\nTo remove it completely, delete this directory manually." 10 70
        return 0
    else
        dialog --colors --title "Removal Cancelled" --msgbox "\Z5Removal cancelled." 8 60
        return 0
    fi
}

# Check for updates and notify user
check_for_updates() {
    dialog --colors --title "Checking for Updates" --infobox "\Z5Checking for updates from $REPO_URL..." 5 60
    
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
        dialog --colors --title "No Updates" --msgbox "\Z5Your version ($VERSION) is already up to date." 8 60
        return 0
    else
        dialog --colors --title "Update Available" --yesno "\Z5A new version is available.\n\nCurrent version: $VERSION\nNew version: $REPO_VERSION\n\nDo you want to update now?" 10 60
        
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
\Z5Features:\Z0
- Interactive TUI with enhanced Synthwave theme
- Directory navigation and selection
- Secure password management
- Multiple import methods for compatibility
- MySQL database administration
- Auto-update from GitHub
\n
\Z5GitHub:\Z0 $REPO_URL
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
        choice=$(dialog --colors --clear --backtitle "\Z5SDBTT MySQL Administration\Z0" \
            --title "MySQL Administration" --menu "Choose an option:" 15 60 8 \
            "1" "\Z6List All Databases\Z0" \
            "2" "\Z6List All Users\Z0" \
            "3" "\Z6Show User Privileges\Z0" \
            "4" "\Z6Show Database Size\Z0" \
            "5" "\Z6Optimize Tables\Z0" \
            "6" "\Z6Check Database Integrity\Z0" \
            "7" "\Z6MySQL Status\Z0" \
            "8" "\Z1Back to Main Menu\Z0" \
            3>&1 1>&2 2>&3)
            
        case $choice in
            1) list_databases ;;
            2) list_users ;;
            3) show_user_privileges ;;
            4) show_database_size ;;
            5) optimize_tables ;;
            6) check_database_integrity ;;
            7) show_mysql_status ;;
            8|"") break ;;
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
        dialog --colors --title "No Tables" --msgbox "\Z5Database '$db_name' has no tables to optimize." 8 60
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
        dialog --colors --title "Optimization Complete" --msgbox "\Z5All tables in database '$db_name' have been optimized.\n\nSee full details in the optimization log." 8 70
        
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
        dialog --colors --title "No Tables" --msgbox "\Z5Database '$db_name' has no tables to check." 8 60
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
        dialog --colors --title "Integrity Check Complete" --msgbox "\Z5All tables in database '$db_name' have been checked.\n\nSee full details in the check log." 8 70
        
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

# Display main menu with enhanced theming
show_main_menu() {
    local choice
    
    debug_log "Displaying main menu"
    
    while true; do
        # Try to use a simpler menu format without colors while troubleshooting
        choice=$(dialog --clear --backtitle "SDBTT - Simple Database Transfer Tool v$VERSION" \
            --title "Main Menu" --menu "Choose an option:" 18 60 11 \
            "1" "Import Databases" \
            "2" "Configure Settings" \
            "3" "Browse & Select Directories" \
            "4" "MySQL Administration" \
            "5" "View Logs" \
            "6" "Save Current Settings" \
            "7" "Load Saved Settings" \
            "8" "Check for Updates" \
            "9" "About SDBTT" \
            "10" "Help" \
            "0" "Exit" \
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
            2) configure_settings ;;
            3) browse_directories ;;
            4) mysql_admin_menu ;;
            5) view_logs ;;
            6) save_config ;;
            7) 
                if load_config; then
                    dialog --title "Configuration Loaded" --msgbox "Settings have been loaded from $CONFIG_FILE" 8 60
                else
                    dialog --title "Error" --msgbox "No saved configuration found at $CONFIG_FILE" 8 60
                fi
                ;;
            8) check_for_updates ;;
            9) show_about ;;
            10) show_help ;;
            0) 
                # Clean up and reset terminal without showing goodbye message
                rm -f "$DIALOGRC" 2>/dev/null
                clear
                exit 0
                ;;
            *) 
                # User pressed Cancel or ESC
                if [ -z "$choice" ]; then
                    dialog --title "Exit Confirmation" --yesno "Are you sure you want to exit?" 8 60
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
        settings_menu=$(dialog --colors --clear --backtitle "\Z5SDBTT - Configuration\Z0" \
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
                        dialog --colors --title "Connection Success" --msgbox "\Z5Successfully connected to MySQL server and securely stored password." 8 60
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
        
        selection=$(dialog --colors --clear --backtitle "\Z5SDBTT - Directory Browser\Z0" \
            --title "Directory Browser" \
            --menu "Current: \Z5$current_dir\Z0\n\nNavigate to directory containing SQL files:" 20 76 12 \
            "${options[@]}" 3>&1 1>&2 2>&3)
        
        case $selection in
            "SELECT_DIR")
                SQL_DIR="$current_dir"
                dialog --colors --title "Directory Selected" --msgbox "\Z5Selected directory: $SQL_DIR" 8 60
                
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
                    dialog --colors --title "File Selected" --msgbox "\Z5Selected file: $selection\n\nThis is a file, not a directory. Please select a directory." 10 60
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
    process_choice=$(dialog --colors --clear --backtitle "\Z5SDBTT - Import\Z0" \
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
            selected_files=$(dialog --colors --clear --backtitle "\Z5SDBTT - Import\Z0" \
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
    
    # Set encoding parameters
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" "$db_name" -e "SET NAMES utf8mb4; SET character_set_client = utf8mb4;" 2>> "$LOG_FILE"
}

# Import the SQL file using various methods
import_sql_file() {
    local db_name="$1"
    local sql_file="$2"
    local processed_file="$3"
    
    log_message "Attempting direct import with charset parameters for $db_name..."
    
    # Try direct import first with charset parameters
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" -e "SOURCE $sql_file;" 2>> "$LOG_FILE"
    
    # Check if import succeeded by counting tables
    local table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ "$table_count" -gt 0 ]; then
        log_message "Import successful - $table_count tables created in $db_name"
        return 0
    fi
    
    log_message "Direct import failed, trying alternative method..."
    
    # Process the SQL file - replacing charset definitions and handling other issues
    sed -e 's/utf8mb3/utf8mb4/g' \
        -e 's/SET @saved_cs_client     = @@character_set_client/SET @saved_cs_client = @@character_set_client/g' \
        -e 's/^\s*\\-/-- -/g' \
        "$sql_file" > "$processed_file"
    
    # Try the processed file with the correct charset
    log_message "Importing processed file for $db_name..."
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" < "$processed_file" 2>> "$LOG_FILE"
    
    # Check again
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ "$table_count" -gt 0 ]; then
        log_message "Processed import successful - $table_count tables created in $db_name"
        return 0
    fi
    
    log_message "Both import methods failed. As a last resort, trying with mysqlimport..."
    
    # Try running mysqlimport as a last resort
    mysqlimport --local --user="$MYSQL_USER" --password="$MYSQL_PASS" --default-character-set=utf8mb4 "$db_name" "$processed_file" 2>> "$LOG_FILE"
    
    table_count=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SELECT COUNT(TABLE_NAME) FROM information_schema.tables WHERE table_schema = '$db_name';" 2>/dev/null)
    
    if [ "$table_count" -gt 0 ]; then
        log_message "Final import attempt successful - $table_count tables created in $db_name"
        return 0
    else
        log_message "All import methods failed for $db_name"
        log_message "Manual inspection required:"
        log_message "mysql -u root -p --default-character-set=utf8mb4"
        log_message "CREATE DATABASE $db_name CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;"
        log_message "USE $db_name;"
        log_message "SOURCE $sql_file;"
        return 1
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
        
        # Show the result summary without colors
        dialog --title "Import Complete" --msgbox "Import process complete.\n\nTotal databases processed: $db_count\nSuccessful imports: $success_count\nFailed imports: $failure_count\n\nLog file saved to: $LOG_FILE" 12 70
        
        # Show the complete log if there were failures
        if [ $failure_count -gt 0 ]; then
            dialog --title "Import Log" --yesno "Some imports failed. Would you like to view the complete log?" 8 60
            if [ $? -eq 0 ]; then
                dialog --title "Complete Import Log" --textbox "$LOG_FILE" 25 78
            fi
        fi
        
        # Clean up
        rm -f "$progress_file"
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
    selection=$(dialog --colors --clear --backtitle "\Z5SDBTT - Recent Directories\Z0" \
        --title "Recent Directories" \
        --menu "Select a recently used directory:" 15 76 8 \
        "${dirs[@]}" 3>&1 1>&2 2>&3)
    
    case $selection in
        "BACK"|"")
            return 1
            ;;
        *)
            SQL_DIR="$selection"
            dialog --colors --title "Directory Selected" --msgbox "\Z5Selected directory: $SQL_DIR" 8 60
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
    selection=$(dialog --colors --clear --backtitle "\Z5SDBTT - Logs\Z0" \
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
            local temp_log="/tmp/sdbtt_colored_log_$$"
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

\Z6* Interactive TUI with enhanced Synthwave theme
* Directory navigation and selection 
* Configuration management with secure password storage
* Automatic charset conversion
* Multiple import methods for compatibility
* Prefix replacement
* MySQL administration tools
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
