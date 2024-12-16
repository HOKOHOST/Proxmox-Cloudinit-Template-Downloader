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
    echo -e "\nWelcome to Alpine Downloader for Proxmox VE (v$SCRIPT_VERSION)"
    echo "============================================================="
    echo "This script is maintained by CUHK LTD."
    echo "Download the latest version from: $SCRIPT_URL"
    echo
    echo "Select the Alpine version you'd like to install:"
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
        return $exit_status
    else
        echo -e "${RED}Invalid script format or URL returned HTML instead of script${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
}

function ubuntu_menu() {
    while true; do
        header_info
        show_welcome
        echo -e "\nPlease select an option:"
        echo "1. Alpine 3.20.3"
        echo "2. Alpine 3.21.0"
        echo "3. Return to Main Menu"
        echo
        
        read -t 60 -p "Enter your choice (1-3): " choice
        
        if [ $? -ne 0 ]; then
            echo -e "\nNo input received. Returning to main menu..."
            exit 0
        fi

        case "$choice" in
            1)
                echo -e "${GREEN}Downloading Alpine 3.20.3 installation script...${NC}"
                run_script "https://osdl.sh/alpine-3-20-3.sh"
                exit $?
                ;;
            2)
                echo -e "${GREEN}Downloading Alpine 3.21.0 installation script...${NC}"
                run_script "https://osdl.sh/alpine-3-21-0.sh"
                exit $?
                ;;
            3)
                echo -e "${GREEN}Returning to main menu...${NC}"
                run_script "https://osdl.sh/start.sh"
                exit $?
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
