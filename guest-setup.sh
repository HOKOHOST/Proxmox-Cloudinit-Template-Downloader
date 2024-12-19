#!/bin/bash

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CL='\033[0m'
BL='\033[36m'
GN='\033[32m'

# Enable debug mode
DEBUG=true

function debug_msg() {
    if [ "$DEBUG" = true ]; then
        echo -e "${YELLOW}[DEBUG] $1${NC}"
    fi
}

function msg_info() {
    echo -e "${YELLOW}[INFO] $1${NC}"
}

function msg_ok() {
    echo -e "${GREEN}[OK] $1${NC}"
}

function msg_error() {
    echo -e "${RED}[ERROR] $1${NC}"
}

function check_proxmox() {
    debug_msg "Checking if running on Proxmox"
    if [ ! -f /etc/pve/.version ]; then
        msg_error "This script must be run on a Proxmox VE host"
        return 1
    fi
    return 0
}

function get_vm_disk_info() {
    local vmid=$1
    debug_msg "Getting disk info for VM $vmid"
    
    # Check if VM exists
    if ! qm status $vmid >/dev/null 2>&1; then
        msg_error "VM $vmid does not exist"
        return 1
    fi
    
    # Get VM configuration
    local vm_config=$(qm config $vmid)
    debug_msg "VM Config:\n$vm_config"
    
    # Get disk configuration
    local disk_config=$(echo "$vm_config" | grep -E '^(scsi0|virtio0|ide0)')
    debug_msg "Disk Config: $disk_config"
    
    # Extract storage info
    local storage_info=$(echo "$disk_config" | grep -oP 'file=\K[^,]+')
    debug_msg "Storage Info: $storage_info"
    
    if [ -z "$storage_info" ]; then
        msg_error "No disk configuration found"
        return 1
    fi
    
    # Get physical path
    local disk_path=$(pvesm path "$storage_info" 2>/dev/null)
    debug_msg "Disk Path: $disk_path"
    
    if [ -n "$disk_path" ] && [ -e "$disk_path" ]; then
        msg_ok "Disk found at: $disk_path"
        echo "$disk_path"
        return 0
    else
        msg_error "Cannot find disk path"
        return 1
    fi
}

function enable_qemu_agent() {
    local vmid=$1
    debug_msg "Enabling QEMU Guest Agent for VM $vmid"
    
    if qm set $vmid --agent enabled=1,fstrim_cloned_disks=1; then
        msg_ok "QEMU Guest Agent enabled"
        return 0
    else
        msg_error "Failed to enable QEMU Guest Agent"
        return 1
    fi
}

function configure_ssh() {
    local vmid=$1
    local disk_path=$2
    debug_msg "Configuring SSH for VM $vmid on disk $disk_path"
    
    msg_info "Configuring SSH settings..."
    if virt-customize -a "$disk_path" \
        --run-command "systemctl enable ssh" \
        --run-command "sed -i 's/#PasswordAuthentication yes/PasswordAuthentication yes/' /etc/ssh/sshd_config" \
        --run-command "sed -i 's/#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config"; then
        msg_ok "SSH configured successfully"
        return 0
    else
        msg_error "Failed to configure SSH"
        return 1
    fi
}

function resize_disk() {
    local vmid=$1
    local size=$2
    debug_msg "Resizing disk for VM $vmid to ${size}G"
    
    if qm resize $vmid scsi0 ${size}G; then
        msg_ok "Disk resized to ${size}GB"
        return 0
    else
        msg_error "Failed to resize disk"
        return 1
    fi
}

function convert_to_template() {
    local vmid=$1
    debug_msg "Converting VM $vmid to template"
    
    if qm template $vmid; then
        msg_ok "Converted to template"
        return 0
    else
        msg_error "Failed to convert to template"
        return 1
    fi
}

function main() {
    debug_msg "Script started"
    
    # Check if running on Proxmox
    if ! check_proxmox; then
        exit 1
    fi
    
    # Get VM ID
    read -p "Enter VM ID to configure: " vmid
    debug_msg "User entered VMID: $vmid"
    
    # Validate VM ID
    if [[ ! $vmid =~ ^[0-9]+$ ]]; then
        msg_error "Invalid VM ID format"
        exit 1
    fi
    
    # Get disk path
    local disk_path=$(get_vm_disk_info $vmid)
    if [ $? -ne 0 ]; then
        exit 1
    fi
    
    # Show configuration menu
    echo -e "\nSelect configuration options:"
    echo "1) Configure all (QEMU agent, SSH, resize to 20GB, convert to template)"
    echo "2) Custom configuration"
    read -p "Enter choice (1/2): " choice
    
    case $choice in
        1)
            enable_qemu_agent $vmid
            configure_ssh $vmid "$disk_path"
            resize_disk $vmid 20
            convert_to_template $vmid
            ;;
        2)
            read -p "Enable QEMU Guest Agent? (y/n): " enable_agent
            read -p "Configure SSH? (y/n): " config_ssh
            read -p "Resize disk? (y/n): " do_resize
            read -p "Convert to template? (y/n): " do_template
            
            [[ $enable_agent == [Yy]* ]] && enable_qemu_agent $vmid
            [[ $config_ssh == [Yy]* ]] && configure_ssh $vmid "$disk_path"
            if [[ $do_resize == [Yy]* ]]; then
                read -p "Enter new size in GB: " new_size
                resize_disk $vmid $new_size
            fi
            [[ $do_template == [Yy]* ]] && convert_to_template $vmid
            ;;
        *)
            msg_error "Invalid choice"
            exit 1
            ;;
    esac
    
    msg_ok "Configuration completed"
}

# Run main function
main
