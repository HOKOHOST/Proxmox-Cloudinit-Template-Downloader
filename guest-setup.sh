#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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
    
    if ! wget -q -O "$temp_script" "$url"; then
        echo -e "${RED}Failed to download script from $url${NC}"
        rm "$temp_script"
        sleep 2
        return 1
    fi
    
    if head -n 1 "$temp_script" | grep -q "^#!.*sh" || file "$temp_script" | grep -q "shell script"; then
        bash "$temp_script"
        local exit_status=$?
        rm "$temp_script"
        
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

function get_disk_path() {
    local vmid=$1
    # Try to get the disk path from qm config
    local disk_path=$(qm config $vmid | grep -oP 'scsi0: \K[^,]+' | sed 's/local://')
    if [ -n "$disk_path" ]; then
        # Check if the path exists in /dev/pve
        if [ -e "/dev/pve/$disk_path" ]; then
            echo "/dev/pve/$disk_path"
            return 0
        # Check if the path exists as is
        elif [ -e "$disk_path" ]; then
            echo "$disk_path"
            return 0
        fi
    fi
    return 1
}

function verify_vmid() {
    local vmid=$1
    if ! qm status $vmid >/dev/null 2>&1; then
        echo -e "${RED}VM ID $vmid does not exist!${NC}"
        return 1
    fi
    
    # Verify disk path can be found
    if ! get_disk_path $vmid >/dev/null; then
        echo -e "${RED}Cannot find disk path for VM $vmid!${NC}"
        return 1
    }
    
    return 0
}

function add_qemu_agent() {
    local vmid=$1
    echo "Adding QEMU Guest Agent..."
    qm set $vmid --agent enabled=1,fstrim_cloned_disks=1
}

function enable_ssh() {
    local vmid=$1
    local disk_path=$(get_disk_path $vmid)
    echo "Enabling SSH access..."
    if ! virt-customize -a "$disk_path" --run-command "systemctl enable ssh" 2>/dev/null; then
        echo -e "${RED}Failed to enable SSH${NC}"
        return 1
    fi
}

function enable_password_auth() {
    local vmid=$1
    local disk_path=$(get_disk_path $vmid)
    echo "Enabling password authentication..."
    if ! virt-customize -a "$disk_path" --run-command "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config" 2>/dev/null; then
        echo -e "${RED}Failed to enable password authentication${NC}"
        return 1
    fi
}

function enable_root_ssh() {
    local vmid=$1
    local disk_path=$(get_disk_path $vmid)
    echo "Enabling root SSH login..."
    if ! virt-customize -a "$disk_path" --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config" 2>/dev/null; then
        echo -e "${RED}Failed to enable root SSH login${NC}"
        return 1
    fi
}

function resize_disk() {
    local vmid=$1
    local size=$2
    echo "Resizing disk to ${size}GB..."
    if ! qm resize $vmid scsi0 ${size}G; then
        echo -e "${RED}Failed to resize disk${NC}"
        return 1
    fi
}

function convert_to_template() {
    local vmid=$1
    echo "Converting VM to template..."
    if ! qm template $vmid; then
        echo -e "${RED}Failed to convert to template${NC}"
        return 1
    fi
}

function setup_vm() {
    local vmid=$1
    local mode=$2
    local success=true

    if [ "$mode" = "default" ]; then
        echo -e "${YELLOW}Applying default settings to VM $vmid...${NC}"
        add_qemu_agent $vmid || success=false
        enable_ssh $vmid || success=false
        enable_password_auth $vmid || success=false
        enable_root_ssh $vmid || success=false
        resize_disk $vmid 20 || success=false
        convert_to_template $vmid || success=false
        
        if [ "$success" = true ]; then
            echo -e "${GREEN}Default setup completed successfully!${NC}"
        else
            echo -e "${RED}Some operations failed during setup${NC}"
        fi
    else
        echo -e "${YELLOW}Advanced setup mode for VM $vmid${NC}"
        
        read -p "Add QEMU Guest Agent? (y/n): " answer
        [[ $answer =~ ^[Yy] ]] && (add_qemu_agent $vmid || success=false)
        
        read -p "Enable SSH access? (y/n): " answer
        [[ $answer =~ ^[Yy] ]] && (enable_ssh $vmid || success=false)
        
        read -p "Enable password authentication? (y/n): " answer
        [[ $answer =~ ^[Yy] ]] && (enable_password_auth $vmid || success=false)
        
        read -p "Enable root SSH login? (y/n): " answer
        [[ $answer =~ ^[Yy] ]] && (enable_root_ssh $vmid || success=false)
        
        read -p "Resize disk? (y/n): " answer
        if [[ $answer =~ ^[Yy] ]]; then
            read -p "Enter new size in GB: " size
            resize_disk $vmid $size || success=false
        fi
        
        read -p "Convert to template? (y/n): " answer
        [[ $answer =~ ^[Yy] ]] && (convert_to_template $vmid || success=false)
        
        if [ "$success" = true ]; then
            echo -e "${GREEN}Advanced setup completed successfully!${NC}"
        else
            echo -e "${RED}Some operations failed during setup${NC}"
        fi
    fi
}

function main_loop() {
    while true; do
        header_info
        echo
        read -p "Enter VM ID to configure: " vmid
        
        if ! verify_vmid $vmid; then
            echo -e "${RED}Please check VM ID and disk path${NC}"
            sleep 2
            continue
        fi
        
        echo
        echo "Select setup mode:"
        echo "1) Default (All settings, 20GB disk)"
        echo "2) Advanced (Choose settings)"
        read -p "Enter choice (1/2): " mode
        
        case $mode in
            1) setup_vm $vmid "default" ;;
            2) setup_vm $vmid "advanced" ;;
            *) echo -e "${RED}Invalid choice${NC}"; sleep 2; continue ;;
        esac
        
        echo
        echo "What would you like to do next?"
        echo "1) Setup another VM"
        echo "2) Return to main menu"
        read -p "Enter choice (1/2): " next_action
        
        case $next_action in
            2) run_script "https://osdl.sh/start.sh"; break ;;
            *) continue ;;
        esac
    done
}

# Start the script
main_loop
