#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CL='\033[0m'
BL='\033[36m'
GN='\033[32m'

# Basic message functions
function msg_info() {
    local msg="$1"
    echo -e "${YELLOW}[INFO] ${msg}${NC}"
}

function msg_ok() {
    local msg="$1"
    echo -e "${GREEN}[OK] ${msg}${NC}"
}

function msg_error() {
    local msg="$1"
    echo -e "${RED}[ERROR] ${msg}${NC}"
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

function get_storage_and_disk_path() {
    local vmid=$1
    local disk_path
    
    msg_info "Detecting storage configuration..."
    
    # Get disk configuration from VM config
    local disk_config=$(qm config $vmid | grep '^scsi0:')
    if [ -z "$disk_config" ]; then
        msg_error "No SCSI disk configuration found"
        return 1
    fi
    
    local storage_info=$(echo "$disk_config" | sed -E 's/^scsi0: ([^,]+),.*/\1/')
    if [ -z "$storage_info" ]; then
        msg_error "Could not parse storage information"
        return 1
    fi
    
    local storage_name=$(echo "$storage_info" | cut -d':' -f1)
    local storage_type=$(pvesm status | grep "^$storage_name" | awk '{print $2}')
    
    if [ "$storage_type" = "zfs" ]; then
        local vm_disk=$(echo "$storage_info" | cut -d':' -f2)
        local zfs_path="${storage_name}${vm_disk}"
        if zfs list "$zfs_path" >/dev/null 2>&1; then
            disk_path="/dev/zvol/$zfs_path"
        fi
    else
        disk_path=$(pvesm path "$storage_info" 2>/dev/null)
    fi
    
    if [ -n "$disk_path" ] && [ -e "$disk_path" ]; then
        msg_ok "Found disk path: ${CL}${BL}$disk_path${CL}"
        echo "$disk_path"
        return 0
    else
        msg_error "Cannot find disk path for VM $vmid"
        return 1
    fi
}

function enable_ssh_settings() {
    local vmid=$1
    local disk_path=$2
    
    msg_info "Configuring SSH settings..."
    
    # Check if VM is running
    if qm status $vmid | grep -q running; then
        msg_info "Stopping VM for configuration..."
        qm stop $vmid
        sleep 5
    fi
    
    # Try to configure SSH
    if ! virt-customize -a "$disk_path" \
        --run-command "systemctl enable ssh || systemctl enable sshd" \
        --run-command "sed -i 's/^#*PasswordAuthentication .*/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
        --run-command "sed -i 's/^#*PermitRootLogin .*/PermitRootLogin yes/' /etc/ssh/sshd_config" >/dev/null 2>&1; then
        msg_error "Failed to configure SSH settings"
        return 1
    fi
    
    msg_ok "SSH settings configured"
    return 0
}

function setup_vm() {
    local vmid=$1
    local mode=$2
    local disk_path
    
    # Get disk path once and reuse it
    disk_path=$(get_storage_and_disk_path $vmid)
    if [ -z "$disk_path" ]; then
        msg_error "Failed to get disk path"
        return 1
    fi
    
    if [ "$mode" = "default" ]; then
        # Default mode: configure everything
        local failed=0
        
        add_qemu_agent $vmid || failed=1
        enable_ssh_settings $vmid "$disk_path" || failed=1
        resize_disk $vmid 20 || failed=1
        convert_to_template $vmid || failed=1
        
        if [ $failed -eq 1 ]; then
            msg_error "Some operations failed. Please check the messages above."
            return 1
        fi
    else
        # Advanced mode: custom configuration
        echo "Choose options to configure:"
        read -p "Add QEMU Guest Agent? (y/n): " add_agent
        read -p "Configure SSH settings? (y/n): " config_ssh
        read -p "Resize disk? (y/n): " resize_disk_opt
        read -p "Convert to template? (y/n): " convert_template
        
        local failed=0
        
        if [[ $add_agent == [Yy]* ]]; then
            add_qemu_agent $vmid || failed=1
        fi
        
        if [[ $config_ssh == [Yy]* ]]; then
            enable_ssh_settings $vmid "$disk_path" || failed=1
        fi
        
        if [[ $resize_disk_opt == [Yy]* ]]; then
            read -p "Enter new size in GB: " new_size
            if [[ "$new_size" =~ ^[0-9]+$ ]]; then
                resize_disk $vmid $new_size || failed=1
            else
                msg_error "Invalid size entered"
                failed=1
            fi
        fi
        
        if [[ $convert_template == [Yy]* ]]; then
            convert_to_template $vmid || failed=1
        fi
        
        if [ $failed -eq 1 ]; then
            msg_error "Some operations failed. Please check the messages above."
            return 1
        fi
    fi
    
    return 0
}

function main_loop() {
    while true; do
        header_info
        echo
        read -p "Enter VM ID to configure: " vmid
        
        # Validate VM ID
        if [[ ! $vmid =~ ^[0-9]+$ ]]; then
            msg_error "Invalid VM ID format"
            sleep 2
            continue
        fi
        
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
        echo "2) Exit"
        read -p "Enter choice (1/2): " next_action
        
        case $next_action in
            2) break ;;
            *) continue ;;
        esac
    done
}

# Start the script
main_loop
