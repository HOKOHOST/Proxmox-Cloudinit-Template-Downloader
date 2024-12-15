#!/bin/bash

SCRIPT_VERSION="1.0"
SCRIPT_URL="https://osdl.sh"

# Color codes
GREEN='\033[0;32m'
NC='\033[0m' # No Color

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

function show_welcome() {
    echo -e "\nWelcome to Ubuntu Downloader for Proxmox VE (v$SCRIPT_VERSION)"
    echo "============================================================="
    echo "This script is maintained by CUHK LTD."
    echo "Download the latest version from: $SCRIPT_URL"
    echo
    echo "Select the Ubuntu version you'd like to install:"
}

function run_script() {
    local url=$1
    wget -O- "$url" | bash
}

function ubuntu_menu() {
    header_info  # Only clear and display the header once
    while true; do
        show_welcome
        echo -e "\nPlease select an option:"
        echo "1. Ubuntu 20.04 LTS (Focal Fossa)"
        echo "2. Ubuntu 22.04 LTS (Jammy Jellyfish)"
        echo "3. Ubuntu 24.04 LTS (Noble Numbat)"
        echo "4. Return to Main Menu"
        echo
        read -r choice
        
        case "$choice" in
            "1")
                echo -e "${GREEN}Downloading Ubuntu 20.04 LTS installation script...${NC}"
                run_script "https://osdl.sh/ubuntu2004.sh"
                break
                ;;
            "2")
                echo -e "${GREEN}Downloading Ubuntu 22.04 LTS installation script...${NC}"
                run_script "https://osdl.sh/ubuntu2204.sh"
                break
                ;;
            "3")
                echo -e "${GREEN}Downloading Ubuntu 24.04 LTS installation script...${NC}"
                run_script "https://osdl.sh/ubuntu2404.sh"
                break
                ;;
            "4")
                echo -e "${GREEN}Returning to main menu...${NC}"
                run_script "https://osdl.sh/test.sh"
                exit 0
                ;;
            *)
                echo -e "\nInvalid option. Please try again."
                sleep 2
                ;;
        esac
    done
}

# Start the menu
ubuntu_menu
