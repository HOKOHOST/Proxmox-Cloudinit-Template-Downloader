#!/bin/bash

SCRIPT_VERSION="1.0"
SCRIPT_URL="https://osdl.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

# Message functions
msg_error() {
    echo -e "${RED}ERROR: $1${NC}"
}

msg_info() {
    echo -e "${GREEN}INFO: $1${NC}"
}

function header_info {
    clear
    cat <<"EOF"
 ░▒▓██████▓▒░ ░▒▓███████▓▒░▒▓███████▓▒░░▒▓█▓▒░              ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░              ░▒▓██████▓▒░░▒▓████████▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░                    ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓██▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓███████▓▒░░▒▓████████▓▒░▒▓██▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
EOF
}

function check_root() {
    if [[ "$(id -u)" -ne 0 || $(ps -o comm= -p $PPID) == "sudo" ]]; then
        clear
        msg_error "Please run this script as root."
        echo -e "\nExiting..."
        sleep 2
        exit 1
    fi
}

function pve_check() {
    if ! pveversion | grep -Eq "pve-manager/8.[1-3]"; then
        msg_error "This version of Proxmox Virtual Environment is not supported"
        echo -e "Requires Proxmox Virtual Environment Version 8.1 or later."
        echo -e "Exiting..."
        sleep 2
        exit 1
    fi
}

function arch_check() {
    if [ "$(dpkg --print-architecture)" != "amd64" ]; then
        msg_error "This script will not work with PiMox! \n"
        echo -e "Exiting..."
        sleep 2
        exit 1
    fi
}

function ssh_check() {
    if command -v pveversion >/dev/null 2>&1; then
        if [ -n "${SSH_CLIENT:+x}" ]; then
            if whiptail --backtitle "OSDL.SH" --defaultno --title "SSH DETECTED" --yesno "It's suggested to use the Proxmox shell instead of SSH, since SSH can create issues while gathering variables. Would you like to proceed with using SSH?" 10 62; then
                echo "you've been warned"
            else
                clear
                exit 1
            fi
        fi
    fi
}

function show_welcome() {
    echo -e "\nWelcome to OSDL - Operating System Downloader for Proxmox VE (v$SCRIPT_VERSION)"
    echo "============================================================="
    echo "This script is maintained by CUHK LTD."
    echo "Download the latest version from: $SCRIPT_URL"
    echo
    echo "Usage Instructions:"
    echo "  - Visit https://osdl.sh for detailed usage instructions"
    echo "  - For support, contact us at info@cuhk.uk"
    echo
    echo "If you find this script helpful, we'd appreciate your support!"
    echo "Consider buying us a coffee to help maintain and improve OSDL."
    echo "You can find the donation link at https://osdl.sh"
    echo
    echo "Did you know? CUHK LTD. also provides enterprise-level Proxmox setup services."
    echo "Contact us to learn how we can optimize your infrastructure."
    echo
}

function run_script() {
    local url=$1
    local temp_script=$(mktemp)
    
    # Download the script
    if ! wget -q -O "$temp_script" "$url"; then
        echo -e "${RED}Failed to download script from $url${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
    
    # Check if the downloaded file is a valid shell script
    if head -n 1 "$temp_script" | grep -q "^#!.*sh" || file "$temp_script" | grep -q "shell script"; then
        # Execute the script
        bash "$temp_script"
        local exit_status=$?
        rm "$temp_script"
        
        # If exit status is 99, continue the menu loop
        # Otherwise, pass through the exit status
        if [ $exit_status -eq 99 ]; then
            return 0
        else
            exit $exit_status
        fi
    else
        echo -e "${RED}Invalid script format or URL returned HTML instead of script${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
}

function main_menu() {
    while true; do
        echo -e "\nPlease select an option:"
        echo "1. VM Tools (Coming Soon)"
        echo "2. Download Debian"
        echo "3. Download Ubuntu Server"
        echo "4. Download CentOS"
        echo "4. Download Alpine"
        echo "5. Exit"
        echo
        read -t 60 -p "Enter your choice (1-4): " choice
        
        if [ $? -ne 0 ]; then
            echo -e "\nNo input received. Exiting..."
            exit 0
        fi

        case $choice in
            1)
                run_script "https://osdl.sh/vm-tools.sh"
                ;;
            2)
                run_script "https://osdl.sh/debian.sh"
                ;;
            3)
                run_script "https://osdl.sh/ubuntu.sh"
                ;;
            4)
                run_script "https://osdl.sh/centos.sh"
                ;;
            5)
                run_script "https://osdl.sh/alpine.sh"
                ;;
            6)
                echo -e "\nThank you for using OSDL!"
                echo "If you found this helpful, please consider supporting us at https://osdl.sh"
                echo "Goodbye!"
                exit 0
                ;;
            *)
                echo -e "\nInvalid option. Please try again."
                ;;
        esac
    done
}

# Run system checks
header_info
check_root
pve_check
arch_check
ssh_check

# Show welcome message and main menu
show_welcome
main_menu
