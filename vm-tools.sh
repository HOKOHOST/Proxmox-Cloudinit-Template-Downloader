#!/bin/bash

# Color definitions
RED='\033[0;31m'
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

# Check if libguestfs-tools is installed
check_libguestfs() {
    if dpkg -l | grep -q libguestfs-tools; then
        return 0  # installed
    else
        return 1  # not installed
    fi
}

# Main script
header_info
echo
echo "Checking system configuration..."
echo

if check_libguestfs; then
    echo "libguestfs-tools is already installed. Proceeding with guest setup..."
    sleep 2
    run_script "https://osdl.sh/guest-setup.sh"
else
    echo "libguestfs-tools is not installed. This package is needed for VM tools."
    echo -n "Would you like to install libguestfs-tools? (y/n): "
    read answer

    case ${answer:0:1} in
        y|Y )
            echo "Installing libguestfs-tools..."
            run_script "https://osdl.sh/libguestfs-tools.sh"
            ;;
        * )
            echo "Proceeding without installing libguestfs-tools..."
            run_script "https://osdl.sh/start.sh"
            ;;
    esac
fi
