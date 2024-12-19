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

    if [ -n "$disk_path" ] && [ -e "$disk_path" ]; then
        msg_ok "Found disk path: ${CL}${BL}$disk_path${CL}"
        echo "$disk_path"
        return 0
    else
        msg_error "Cannot find disk path for VM $vmid"
        return 1
    fi
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
    msg_info "Resizing disk to ${size}GB..."
    if ! qm resize $vmid scsi0 ${size}G; then
        msg_error "Failed to resize disk"
        return 1
    fi
    msg_ok "Disk resized to ${size}GB"
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
