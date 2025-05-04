#!/bin/bash
# SDBTT: Simple Database Transfer Tool
# Enhanced MySQL Database Import Script with Synthwave Theme
# Version: 1.0.0

# Default configuration
CONFIG_DIR="$HOME/.sdbtt"
CONFIG_FILE="$CONFIG_DIR/config.conf"
TEMP_DIR="/tmp/sdbtt_$(date +%Y%m%d_%H%M%S)"
LOG_DIR="$CONFIG_DIR/logs"
LOG_FILE="$LOG_DIR/sdbtt_$(date +%Y%m%d_%H%M%S).log"
PASS_STORE="$CONFIG_DIR/.passstore"
VERSION="1.0.0"
REPO_URL="https://github.com/eraxe/sdbtt"

# Theme settings - CRITICAL FIX for blue screen issue
# These settings directly modify dialog colors to create a synthwave theme
# Manually override dialog's blue background to black
export DIALOGRC="/tmp/dialogrc_sdbtt_$$"
cat > "$DIALOGRC" << 'EOF'
# Dialog configuration with Synthwave theme
# Set aspect-ratio and screen edge
aspect = 0
separate_widget = ""
tab_len = 0
visit_items = OFF
use_shadow = ON
use_colors = ON

# Synthwave color scheme
screen_color = (BLACK,BLACK,OFF)
shadow_color = (BLACK,BLACK,OFF)
dialog_color = (MAGENTA,BLACK,OFF)
title_color = (BRIGHTMAGENTA,BLACK,ON)
border_color = (MAGENTA,BLACK,ON)
button_active_color = (BLACK,BRIGHTMAGENTA,ON)
button_inactive_color = (BLACK,MAGENTA,ON)
button_key_active_color = (BLACK,BRIGHTMAGENTA,ON)
button_key_inactive_color = (BLACK,MAGENTA,ON)
button_label_active_color = (BLACK,BRIGHTMAGENTA,ON)
button_label_inactive_color = (BLACK,MAGENTA,ON)
inputbox_color = (MAGENTA,BLACK,OFF)
inputbox_border_color = (MAGENTA,BLACK,ON)
searchbox_color = (MAGENTA,BLACK,OFF)
searchbox_title_color = (BRIGHTMAGENTA,BLACK,ON)
searchbox_border_color = (MAGENTA,BLACK,ON)
position_indicator_color = (BRIGHTMAGENTA,BLACK,ON)
menubox_color = (MAGENTA,BLACK,OFF)
menubox_border_color = (MAGENTA,BLACK,ON)
item_color = (MAGENTA,BLACK,OFF)
item_selected_color = (BLACK,MAGENTA,ON)
tag_color = (BRIGHTMAGENTA,BLACK,ON)
tag_selected_color = (BLACK,BRIGHTMAGENTA,ON)
tag_key_color = (BRIGHTMAGENTA,BLACK,ON)
tag_key_selected_color = (BLACK,BRIGHTMAGENTA,ON)
check_color = (MAGENTA,BLACK,OFF)
check_selected_color = (BLACK,MAGENTA,ON)
uarrow_color = (BRIGHTMAGENTA,BLACK,ON)
darrow_color = (BRIGHTMAGENTA,BLACK,ON)
itemhelp_color = (MAGENTA,BLACK,OFF)
form_active_text_color = (BLACK,MAGENTA,ON)
form_text_color = (MAGENTA,BLACK,ON)
form_item_readonly_color = (CYAN,BLACK,ON)
gauge_color = (BRIGHTMAGENTA,BLACK,ON)
EOF

# ANSI color codes for terminal output
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
BRIGHTBLACK="\033[90m"
BRIGHTRED="\033[91m"
BRIGHTGREEN="\033[92m"
BRIGHTYELLOW="\033[93m"
BRIGHTBLUE="\033[94m"
BRIGHTMAGENTA="\033[95m"
BRIGHTCYAN="\033[96m"
BRIGHTWHITE="\033[97m"
BGBLACK="\033[40m"
BGMAGENTA="\033[45m"

# Function to set terminal title and background
set_term_appearance() {
    # Try to set terminal title
    echo -ne "\033]0;SDBTT - Synthwave\007"
    
    # Clear screen with magenta/black gradient effect
    clear
    for i in {1..5}; do
        echo -e "${BGBLACK}${MAGENTA}$(printf '%*s' $COLUMNS | tr ' ' '═')${RESET}"
    done
    echo -e "${BGBLACK}${BRIGHTMAGENTA}$(printf '%*s' $COLUMNS | tr ' ' '═')${RESET}"
    for i in {1..20}; do
        echo -e "${BGBLACK}$(printf '%*s' $COLUMNS)${RESET}"
    done
    
    # Return cursor to top
    tput cup 0 0
}

# Ensure required tools are installed
check_dependencies() {
    local missing_deps=()
    
    for cmd in dialog mysql mysqldump sed awk git openssl; do
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        echo -e "${RED}Error: Missing required dependencies: ${missing_deps[*]}${RESET}"
        echo "Please install them before running this script."
        exit 1
    fi
}

# Display fancy ASCII art header
show_header() {
    # Return cursor to top
    tput cup 0 0
    
    # Using ANSI color codes for terminal 
    echo -e "${BRIGHTMAGENTA}"
    cat << "EOF"
 ██████╗██████╗ ██████╗ ████████╗████████╗
██╔════╝██╔══██╗██╔══██╗╚══██╔══╝╚══██╔══╝
╚█████╗ ██║  ██║██████╔╝   ██║      ██║   
 ╚═══██╗██║  ██║██╔══██╗   ██║      ██║   
██████╔╝██████╔╝██████╔╝   ██║      ██║   
╚═════╝ ╚═════╝ ╚═════╝    ╚═╝      ╚═╝   
EOF
    echo -e "${MAGENTA}░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░"
    echo -e "${BRIGHTMAGENTA}Simple Database Transfer Tool v$VERSION${RESET}"
    echo -e "${MAGENTA}░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░${RESET}"
}

# Create required directories
initialize_directories() {
    mkdir -p "$CONFIG_DIR" "$LOG_DIR" "$TEMP_DIR"
    # Secure the configuration directory
    chmod 700 "$CONFIG_DIR"
}

# Function to log messages
log_message() {
    local message="$1"
    local timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$timestamp] $message" | tee -a "$LOG_FILE"
}

# Function to handle errors
error_exit() {
    log_message "ERROR: $1"
    if [ -n "$DIALOG" ]; then
        dialog --title "Error" --colors --msgbox "\Z1ERROR: $1\Z0" 8 60
    else
        echo -e "${RED}ERROR: $1${RESET}" >&2
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

# Update the script from GitHub
update_script() {
    local temp_dir="/tmp/sdbtt_update_$(date +%s)"
    local current_dir=$(pwd)
    
    dialog --colors --title "Update" --infobox "\Z5Checking for updates from $REPO_URL..." 5 60
    
    # Create temp directory
    mkdir -p "$temp_dir"
    cd "$temp_dir" || return 1
    
    # Clone the repository
    if ! git clone "$REPO_URL" . >/dev/null 2>&1; then
        dialog --colors --title "Update Failed" --msgbox "\Z1Failed to clone repository. Check your internet connection and try again." 8 60
        rm -rf "$temp_dir"
        cd "$current_dir" || return 1
        return 1
    fi
    
    # Check if there's a newer version
    if [ -f "VERSION" ]; then
        REPO_VERSION=$(cat VERSION)
    else
        REPO_VERSION=$(grep "^VERSION=" sdbtt | cut -d'"' -f2)
    fi
    
    if [ -z "$REPO_VERSION" ]; then
        dialog --colors --title "Update Failed" --msgbox "\Z1Could not determine repository version." 8 60
        rm -rf "$temp_dir"
        cd "$current_dir" || return 1
        return 1
    fi
    
    # Compare versions
    if [ "$VERSION" = "$REPO_VERSION" ]; then
        dialog --colors --title "No Updates" --msgbox "\Z5Your version ($VERSION) is already up to date." 8 60
        rm -rf "$temp_dir"
        cd "$current_dir" || return 1
        return 0
    fi
    
    # Confirm update
    dialog --colors --title "Update Available" --yesno "\Z5A new version is available.\n\nCurrent version: $VERSION\nNew version: $REPO_VERSION\n\nDo you want to update?" 10 60
    
    if [ $? -eq 0 ]; then
        # If installed as system script, use sudo
        if [ -f "/usr/local/bin/sdbtt" ]; then
            if [ "$(id -u)" -ne 0 ]; then
                dialog --colors --title "Error" --msgbox "\Z1Update requires root privileges. Please run with sudo." 8 60
                rm -rf "$temp_dir"
                cd "$current_dir" || return 1
                return 1
            fi
            
            # Update system installation
            cp "sdbtt" "/usr/local/bin/sdbtt"
            chmod 755 "/usr/local/bin/sdbtt"
        else
            # Update current script
            cp "sdbtt" "$0"
            chmod 755 "$0"
        fi
        
        dialog --colors --title "Update Successful" --msgbox "\Z5Updated from version $VERSION to $REPO_VERSION.\n\nPlease restart the script for changes to take effect." 10 60
        
        # Cleanup and exit
        rm -rf "$temp_dir"
        cd "$current_dir" || return 1
        exit 0
    else
        dialog --colors --title "Update Cancelled" --msgbox "\Z5Update cancelled. Keeping version $VERSION." 8 60
        rm -rf "$temp_dir"
        cd "$current_dir" || return 1
        return 0
    fi
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

# Display the about information
show_about() {
    dialog --colors --title "About SDBTT" --msgbox "\
\Z5Simple Database Transfer Tool (SDBTT) v$VERSION\Z0
\n
A tool for importing and managing MySQL databases with ease.
\n
\Z5Features:\Z0
- Interactive TUI with Synthwave theme
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

# Display the MySQL administration menu
mysql_admin_menu() {
    if [ -z "$MYSQL_USER" ] || [ -z "$MYSQL_PASS" ]; then
        dialog --colors --title "MySQL Admin" --msgbox "\Z1MySQL credentials not configured.\n\nPlease set your MySQL username and password first." 8 60
        return
    fi
    
    while true; do
        local choice
        choice=$(dialog --colors --clear --backtitle "\Z5SDBTT MySQL Administration\Z0" \
            --title "MySQL Administration" --menu "Choose an option:" 15 60 8 \
            "1" "\Z5List All Databases\Z0" \
            "2" "\Z5List All Users\Z0" \
            "3" "\Z5Show User Privileges\Z0" \
            "4" "\Z5Show Database Size\Z0" \
            "5" "\Z5Optimize Tables\Z0" \
            "6" "\Z5Check Database Integrity\Z0" \
            "7" "\Z5MySQL Status\Z0" \
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

# List all databases
list_databases() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW DATABASES;" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve databases. Check your MySQL credentials." 8 60
        return
    fi
    
    # Format the output for display
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/Database/\\Z5Database\\Z0/g')
    
    dialog --colors --title "MySQL Databases" --msgbox "$formatted_result" 20 60
}

# List all MySQL users
list_users() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT User, Host FROM mysql.user;" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve users. Check your MySQL credentials." 8 60
        return
    fi
    
    # Format the output for display
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/User/\\Z5User\\Z0/g' | sed 's/Host/\\Z5Host\\Z0/g')
    
    dialog --colors --title "MySQL Users" --msgbox "$formatted_result" 20 60
}

# Show privileges for a specific user
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
    
    dialog --colors --title "Privileges for $username" --msgbox "$result" 20 70
}

# Show database sizes
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
    
    # Format the output for display
    local formatted_result
    formatted_result=$(echo "$result" | sed 's/Database/\\Z5Database\\Z0/g' | sed 's/Size (MB)/\\Z5Size (MB)\\Z0/g')
    
    dialog --colors --title "Database Sizes" --msgbox "$formatted_result" 20 70
}

# Optimize tables in a database
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
    
    # Create a progress dialog
    (
        echo "0"
        echo "XXX"
        echo "Preparing to optimize tables..."
        echo "XXX"
        
        local i=0
        local total=$(echo "$tables" | wc -l)
        
        for table in $tables; do
            i=$((i + 1))
            progress=$((i * 100 / total))
            
            echo "$progress"
            echo "XXX"
            echo "Optimizing table: $table ($i of $total)"
            echo "XXX"
            
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "OPTIMIZE TABLE \`$db_name\`.\`$table\`;" >/dev/null 2>&1
            sleep 0.1
        done
        
        echo "100"
        echo "XXX"
        echo "All tables optimized."
        echo "XXX"
    ) | dialog --colors --title "Optimizing Database" --gauge "Preparing to optimize tables..." 10 70 0
    
    dialog --colors --title "Optimization Complete" --msgbox "\Z5All tables in database '$db_name' have been optimized." 8 60
}

# Check database integrity
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
    
    # Create a temporary file for results
    local results_file=$(mktemp)
    
    # Create a progress dialog
    (
        echo "0"
        echo "XXX"
        echo "Preparing to check tables..."
        echo "XXX"
        
        local i=0
        local total=$(echo "$tables" | wc -l)
        
        for table in $tables; do
            i=$((i + 1))
            progress=$((i * 100 / total))
            
            echo "$progress"
            echo "XXX"
            echo "Checking table: $table ($i of $total)"
            echo "XXX"
            
            mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "CHECK TABLE \`$db_name\`.\`$table\`;" >> "$results_file" 2>/dev/null
            sleep 0.1
        done
        
        echo "100"
        echo "XXX"
        echo "All tables checked."
        echo "XXX"
    ) | dialog --colors --title "Checking Database Integrity" --gauge "Preparing to check tables..." 10 70 0
    
    # Display results
    local results
    results=$(cat "$results_file")
    
    dialog --colors --title "Integrity Check Results" --msgbox "\Z5Results for database '$db_name':\n\n$results" 20 70
    
    # Clean up
    rm -f "$results_file"
}

# Show MySQL server status
show_mysql_status() {
    local result
    result=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SHOW STATUS;" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        dialog --colors --title "Error" --msgbox "\Z1Failed to retrieve MySQL status." 8 60
        return
    fi
    
    # Format important status variables
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
    
    # Format MySQL version
    local version
    version=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "SELECT VERSION();" 2>/dev/null)
    
    # Format the output for display
    formatted_result=$(echo -e "MySQL Version:\n$version\n\nStatus Variables:\n$formatted_result" | sed 's/Variable_name/\\Z5Variable_name\\Z0/g' | sed 's/Value/\\Z5Value\\Z0/g')
    
    dialog --colors --title "MySQL Server Status" --msgbox "$formatted_result" 20 70
}

# Display main menu
show_main_menu() {
    local choice
    
    while true; do
        choice=$(dialog --colors --clear --backtitle "\Z5SDBTT - Simple Database Transfer Tool v$VERSION\Z0" \
            --title "Main Menu" --menu "Choose an option:" 17 60 10 \
            "1" "\Z6Import Databases\Z0" \
            "2" "\Z6Configure Settings\Z0" \
            "3" "\Z6Browse & Select Directories\Z0" \
            "4" "\Z6MySQL Administration\Z0" \
            "5" "\Z6View Logs\Z0" \
            "6" "\Z6Save Current Settings\Z0" \
            "7" "\Z6Load Saved Settings\Z0" \
            "8" "\Z6About SDBTT\Z0" \
            "9" "\Z6Help\Z0" \
            "0" "\Z1Exit\Z0" \
            3>&1 1>&2 2>&3)
            
        case $choice in
            1) import_databases_menu ;;
            2) configure_settings ;;
            3) browse_directories ;;
            4) mysql_admin_menu ;;
            5) view_logs ;;
            6) save_config ;;
            7) 
                if load_config; then
                    dialog --colors --title "Configuration Loaded" --msgbox "\Z5Settings have been loaded from $CONFIG_FILE" 8 60
                else
                    dialog --colors --title "Error" --msgbox "\Z1No saved configuration found at $CONFIG_FILE" 8 60
                fi
                ;;
            8) show_about ;;
            9) show_help ;;
            0) 
                dialog --colors --title "Goodbye" --msgbox "\Z5Thank you for using SDBTT" 8 60
                # Clean up and reset terminal
                rm -f "$DIALOGRC"
                clear
                exit 0
                ;;
            *) 
                # User pressed Cancel or ESC
                if [ -z "$choice" ]; then
                    dialog --colors --title "Exit Confirmation" --yesno "\Z1Are you sure you want to exit?" 8 60
                    if [ $? -eq 0 ]; then
                        # Clean up and reset terminal
                        rm -f "$DIALOGRC"
                        clear
                        exit 0
                    fi
                fi
                ;;
        esac
    done
}

# Configure settings menu
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

# Browse and select directories
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
                # Format for display
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

# Import databases menu
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
            
            # Show original name → new name
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

# Show import plan
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
            
            # Show original name → new name
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

# Start the import process
start_import_process() {
    local file_list="$1"
    local db_count=0
    local success_count=0
    local failure_count=0
    
    # Create temp directory if it doesn't exist
    mkdir -p "$TEMP_DIR"
    
    # Initialize log file
    echo "Starting database import process at $(date)" > "$LOG_FILE"
    echo "MySQL user: $MYSQL_USER" >> "$LOG_FILE"
    echo "Database owner: $DB_OWNER" >> "$LOG_FILE"
    echo "Database prefix: $DB_PREFIX" >> "$LOG_FILE"
    echo "SQL file pattern: $SQL_PATTERN" >> "$LOG_FILE"
    
    # Check MySQL server's default charset
    local default_charset=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW VARIABLES LIKE 'character_set_server';" | awk '{print $2}')
    local default_collation=$(mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -N -e "SHOW VARIABLES LIKE 'collation_server';" | awk '{print $2}')
    log_message "MySQL server default charset: $default_charset, collation: $default_collation"
    
    # Create a temporary file for progress calculation
    local progress_file=$(mktemp)
    echo "0" > "$progress_file"
    
    # Calculate total files
    local total_files=$(echo "$file_list" | wc -w)
    
    # Use a background process to update the progress
    (
        local current=0
        while [ "$current" -le 100 ]; do
            current=$(cat "$progress_file")
            echo "XXX"
            echo "$current"
            echo "\Z5Importing databases... ($current%)\Z0"
            echo "XXX"
            sleep 0.5
        done
    ) | dialog --colors --title "Import Progress" --gauge "Preparing to import databases..." 10 70 0 &
    local dialog_pid=$!
    
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
        
        # Update progress
        local progress=$((db_count * 100 / total_files))
        echo "$progress" > "$progress_file"
    done
    
    # Mark as 100% complete
    echo "100" > "$progress_file"
    
    # Wait a moment for the dialog to update
    sleep 1
    
    # Kill the progress dialog
    kill $dialog_pid 2>/dev/null
    
    # Apply privileges
    log_message "Flushing privileges..."
    mysql -u "$MYSQL_USER" -p"$MYSQL_PASS" -e "FLUSH PRIVILEGES;" 2>> "$LOG_FILE"
    
    # Clean up temporary files
    log_message "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    rm -f "$progress_file"
    
    log_message "All databases have been processed"
    
    # Show the result summary
    dialog --colors --title "Import Complete" --msgbox "\Z5Import process complete.\Z0\n\nTotal databases processed: \Z6$db_count\Z0\nSuccessful imports: \Z2$success_count\Z0\nFailed imports: \Z1$failure_count\Z0\n\nLog file saved to: \Z6$LOG_FILE\Z0" 12 70
}

# Select from previously used directories
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

# View logs menu
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
            
            # View log file
            dialog --colors --title "Log File: $(basename "$selection")" --textbox "$selection" 25 78
            ;;
    esac
}

# Help screen
show_help() {
    dialog --colors --title "SDBTT Help" --msgbox "\
\Z5Simple Database Transfer Tool (SDBTT) Help\Z0
------------------------------------

This tool helps you import MySQL databases from SQL files with the following features:

* Interactive text-based user interface with Synthwave theme
* Directory navigation and selection
* Configuration management with secure password storage
* Automatic charset conversion
* Multiple import methods for compatibility
* Prefix replacement
* MySQL administration tools
* Privilege management

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

\Z5Security features:\Z0
* Passwords are encrypted and stored securely
* Restricted file permissions for sensitive files
* No plaintext passwords in config files

The tool saves your settings for future use and keeps logs of all operations.

\Z6Press OK to return to the main menu.\Z0
" 25 78
}

# Process command line arguments
process_arguments() {
    case "$1" in
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
  --install    Install SDBTT to system
  --update     Update SDBTT from GitHub
  --remove     Remove SDBTT from system
  --help       Show this help message

When run without options, launches the interactive TUI.
EOF
            exit 0
            ;;
    esac
}

# Main function
main() {
    # Process command line arguments if any
    if [ $# -gt 0 ]; then
        process_arguments "$1"
    fi
    
    check_dependencies
    set_term_appearance
    show_header
    initialize_directories
    
    # Set default values if not loaded from config
    MYSQL_USER=${MYSQL_USER:-"root"}
    SQL_PATTERN=${SQL_PATTERN:-"*.sql"}
    
    # Try to load config
    load_config
    
    # Try to retrieve password if we have a username
    if [ -n "$MYSQL_USER" ] && [ -z "$MYSQL_PASS" ]; then
        MYSQL_PASS=$(get_password "$MYSQL_USER")
    fi
    
    # Show main menu
    show_main_menu
    
    # Clean up on exit
    rm -f "$DIALOGRC"
}

# Start the script
main "$@"
