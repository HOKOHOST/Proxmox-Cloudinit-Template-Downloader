#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CL='\033[0m'
BL='\033[36m'
GN='\033[32m'

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
    local storage_info
    local disk_path
    local storage_name
    local storage_type
    
    msg_info "Detecting storage configuration..."
    
    # Get disk configuration from VM config
    local disk_config=$(qm config $vmid | grep '^scsi0:')
    local storage_info=$(echo "$disk_config" | sed -E 's/^scsi0: ([^,]+),.*/\1/')
    
    if [ -z "$storage_info" ]; then
        msg_error "No disk configuration found"
        return 1
    fi
    
    storage_name=$(echo "$storage_info" | cut -d':' -f1)
    storage_type=$(pvesm status | grep "^$storage_name" | awk '{print $2}')
    
    msg_ok "Found storage: ${CL}${BL}$storage_name${CL} (Type: $storage_type)"
    
    # Get physical path
    disk_path=$(pvesm path "$storage_info" 2>/dev/null)
    
    if [ -z "$disk_path" ] && [ "$storage_type" = "zfs" ]; then
        local vm_disk=$(echo "$storage_info" | cut -d':' -f2)
        disk_path="/dev/zvol/${storage_name}${vm_disk}"
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

function verify_vmid() {
    local vmid=$1
    if ! qm status $vmid >/dev/null 2>&1; then
        msg_error "VM ID $vmid does not exist!"
        return 1
    fi
    
    if ! get_storage_and_disk_path $vmid >/dev/null; then
        msg_error "Cannot find disk path for VM $vmid!"
        return 1
    fi
    
    return 0
}

function add_qemu_agent() {
    local vmid=$1
    msg_info "Adding QEMU Guest Agent..."
    if qm set $vmid --agent enabled=1,fstrim_cloned_disks=1; then
        msg_ok "QEMU Guest Agent enabled"
    else
        msg_error "Failed to enable QEMU Guest Agent"
        return 1
    fi
}

function enable_ssh() {
    local vmid=$1
    local disk_path=$(get_storage_and_disk_path $vmid)
    msg_info "Enabling SSH access..."
    if ! virt-customize -a "$disk_path" --run-command "systemctl enable ssh" 2>/dev/null; then
        msg_error "Failed to enable SSH"
        return 1
    fi
    msg_ok "SSH enabled"
}

function enable_password_auth() {
    local vmid=$1
    local disk_path=$(get_storage_and_disk_path $vmid)
    msg_info "Enabling password authentication..."
    if ! virt-customize -a "$disk_path" --run-command "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config" 2>/dev/null; then
        msg_error "Failed to enable password authentication"
        return 1
    fi
    msg_ok "Password authentication enabled"
}

function enable_root_ssh() {
    local vmid=$1
    local disk_path=$(get_storage_and_disk_path $vmid)
    msg_info "Enabling root SSH login..."
    if ! virt-customize -a "$disk_path" --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config" 2>/dev/null; then
        msg_error "Failed to enable root SSH login"
        return 1
    fi
    msg_ok "Root SSH login enabled"
}

function resize_disk() {
    local vmid=$1
    local size=$2
    local current_size=$(qm config $vmid | grep '^scsi0:' | grep -oP 'size=\K\d+')
    
    if [ -n "$current_size" ] && [ "$current_size" -gt "$size" ]; then
        msg_info "Current disk size (${current_size}G) is larger than requested size (${size}G). Skipping resize."
        return 0
    fi
    
    msg_info "Resizing disk to ${size}GB..."
    if qm resize $vmid scsi0 ${size}G; then
        msg_ok "Disk resized to ${size}GB"
    else
        msg_error "Failed to resize disk"
        return 1
    fi
}

function convert_to_template() {
    local vmid=$1
    msg_info "Converting VM to template..."
    if ! qm template $vmid; then
        msg_error "Failed to convert to template"
        return 1
    fi
    msg_ok "Converted to template"
}

function setup_vm() {
    local vmid=$1
    local mode=$2
    
    if [ "$mode" = "default" ]; then
        add_qemu_agent $vmid
        enable_ssh $vmid
        enable_password_auth $vmid
        enable_root_ssh $vmid
        resize_disk $vmid 20
        convert_to_template $vmid
    else
        echo "Choose options to configure:"
        read -p "Add QEMU Guest Agent? (y/n): " add_agent
        read -p "Enable SSH? (y/n): " enable_ssh_opt
        read -p "Enable password authentication? (y/n): " enable_pass
        read -p "Enable root SSH login? (y/n): " enable_root
        read -p "Resize disk? (y/n): " resize_disk_opt
        read -p "Convert to template? (y/n): " convert_template
        
        [[ $add_agent == [Yy]* ]] && add_qemu_agent $vmid
        [[ $enable_ssh_opt == [Yy]* ]] && enable_ssh $vmid
        [[ $enable_pass == [Yy]* ]] && enable_password_auth $vmid
        [[ $enable_root == [Yy]* ]] && enable_root_ssh $vmid
        if [[ $resize_disk_opt == [Yy]* ]]; then
            read -p "Enter new size in GB: " new_size
            resize_disk $vmid $new_size
        fi
        [[ $convert_template == [Yy]* ]] && convert_to_template $vmid
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
