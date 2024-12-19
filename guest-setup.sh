#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CL='\033[0m'
BL='\033[36m'
GN='\033[32m'

# Helper Functions
function get_vm_disk_format() {
    local vmid=$1
    local format
    
    format=$(qm config $vmid | grep '^scsi0\|^virtio0\|^ide0' | grep -oP 'format=\K[^,]+')
    if [ -z "$format" ]; then
        format="raw"  # default format if not specified
    fi
    echo "$format"
}

function get_vm_storage_type() {
    local storage_name=$1
    pvesm status | grep "^$storage_name" | awk '{print $2}'
}

function get_vm_storage_content() {
    local vmid=$1
    qm config $vmid | grep '^scsi0\|^virtio0\|^ide0' | grep -oP 'file=\K[^,]+' || true
}

# Message Functions
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
    local disk_ref

    # Get VM's storage information directly from config
    local conf_storage=$(get_vm_storage_content $vmid)
    
    if [ -n "$conf_storage" ]; then
        storage_name=$(echo $conf_storage | cut -d':' -f1)
        storage_type=$(get_vm_storage_type "$storage_name")
        msg_ok "Found storage: ${CL}${BL}$storage_name${CL} (Type: $storage_type)"
        disk_ref="$conf_storage"
    else
        # Fallback to detecting storage if not found in config
        storage_info=$(pvesm status -content images | awk 'NR>1 {print $1,$2}' | head -n1)
        if [ -z "$storage_info" ]; then
            msg_error "No valid storage location detected"
            return 1
        fi
        
        storage_name=$(echo $storage_info | awk '{print $1}')
        storage_type=$(echo $storage_info | awk '{print $2}')
        msg_ok "Found storage: ${CL}${BL}$storage_name${CL} (Type: $storage_type)"

        # Determine disk extension based on storage type
        case $storage_type in
            nfs|dir)
                disk_ext=".qcow2"
                ;;
            btrfs|zfs|rbd)
                disk_ext=".raw"
                ;;
            *)
                disk_ext=".raw"
                ;;
        esac

        disk_name="vm-${vmid}-disk-0${disk_ext}"
        disk_ref="${storage_name}:${vmid}/${disk_name}"
    fi

    # Get the actual physical path
    disk_path=$(pvesm path "$disk_ref" 2>/dev/null)
    
    if [ -z "$disk_path" ]; then
        # Try alternative path formats for ZFS
        if [ "$storage_type" = "zfs" ]; then
            # Try to find ZFS volume directly
            local zfs_pool=$(zfs list -H -o name | grep "${vmid}-disk-0" | head -n1)
            if [ -n "$zfs_pool" ]; then
                disk_path="/dev/zvol/$zfs_pool"
            fi
        fi
    fi

    # Debug information
    msg_info "Debug Info:"
    msg_info "Storage Name: $storage_name"
    msg_info "Storage Type: $storage_type"
    msg_info "Disk Reference: $disk_ref"
    msg_info "Disk Path: $disk_path"

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
    
    # Verify disk path can be found
    if ! get_storage_and_disk_path $vmid >/dev/null; then
        msg_error "Cannot find disk path for VM $vmid!"
        return 1
    fi
    
    return 0
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
