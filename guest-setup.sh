#!/bin/bash

# Constants
QEMU_GUEST_AGENT_PKG="qemu-guest-agent"
SSH_CONFIG="/etc/ssh/sshd_config"

# Helper functions
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
}

error() {
    log "ERROR: $1" >&2
    exit 1
}

# Validate Proxmox environment
check_proxmox() {
    if ! command -v pvesh >/dev/null; then
        error "This script must run on a Proxmox host"
    }
}

# Detect storage type and path
get_storage_info() {
    local vmid=$1
    local conf_file="/etc/pve/qemu-server/${vmid}.conf"
    
    if [ ! -f "$conf_file" ]; then
        error "VM configuration file not found for VMID ${vmid}"
    }
    
    # Get storage information from config
    local disk_line=$(grep "^scsi0:" "$conf_file")
    if [ -z "$disk_line" ]; then
        error "Unable to find disk configuration for VM ${vmid}"
    }
    
    # Parse storage type and path
    local storage_name=$(echo "$disk_line" | cut -d':' -f2 | cut -d',' -f1)
    local storage_type=$(pvesm status -storage "$storage_name" | awk 'NR>1 {print $2}')
    
    echo "$storage_type:$storage_name"
}

# Get disk path for VM
get_disk_path() {
    local vmid=$1
    local storage_info=$2
    
    local storage_type=${storage_info%:*}
    local storage_name=${storage_info#*:}
    
    case "$storage_type" in
        zfs)
            echo "/dev/zvol/rpool/data/vm-${vmid}-disk-0"
            ;;
        dir|nfs)
            echo "/var/lib/vz/images/${vmid}/vm-${vmid}-disk-0.raw"
            ;;
        btrfs)
            echo "/var/lib/vz/images/${vmid}/vm-${vmid}-disk-0"
            ;;
        *)
            error "Unsupported storage type: ${storage_type}"
            ;;
    esac
}

# Configure VM settings
configure_vm() {
    local vmid=$1
    local disk_path=$2
    
    # Stop VM if running
    if qm status "$vmid" | grep -q running; then
        qm stop "$vmid"
        sleep 5
    fi
    
    # Enable QEMU Guest Agent
    qm set "$vmid" --agent enabled=1,fstrim_cloned_disks=1
    
    # Configure SSH using guestfish instead of virt-customize for better compatibility
    guestfish -a "$disk_path" -i <<EOF
        mount /dev/sda1 /
        write-append /etc/ssh/sshd_config "PermitRootLogin yes\nPasswordAuthentication yes\n"
        chmod 0644 /etc/ssh/sshd_config
EOF
    
    if [ $? -ne 0 ]; then
        error "Failed to configure SSH settings"
    }
}

# Resize disk
resize_disk() {
    local vmid=$1
    local new_size=$2
    local storage_info=$3
    
    # Convert size to bytes for consistent handling
    local size_bytes=$(numfmt --from=iec "$new_size")
    
    # Resize based on storage type
    local storage_type=${storage_info%:*}
    
    case "$storage_type" in
        zfs)
            zfs set volsize="$new_size" "rpool/data/vm-${vmid}-disk-0"
            ;;
        *)
            qm resize "$vmid" scsi0 "$new_size"
            ;;
    esac
}

# Convert to template
convert_to_template() {
    local vmid=$1
    
    if qm status "$vmid" | grep -q running; then
        qm stop "$vmid"
        sleep 5
    }
    
    qm template "$vmid"
}

# Main function
main() {
    local vmid=$1
    local new_size=$2
    
    # Validate inputs
    if [ -z "$vmid" ] || [ -z "$new_size" ]; then
        error "Usage: $0 <vmid> <new_size>"
    }
    
    # Check Proxmox environment
    check_proxmox
    
    # Get storage information
    local storage_info=$(get_storage_info "$vmid")
    local disk_path=$(get_disk_path "$vmid" "$storage_info")
    
    log "Configuring VM ${vmid}"
    configure_vm "$vmid" "$disk_path"
    
    log "Resizing disk to ${new_size}"
    resize_disk "$vmid" "$new_size" "$storage_info"
    
    log "Converting to template"
    convert_to_template "$vmid"
    
    log "Setup completed successfully"
}

# Execute main function with provided arguments
main "$@"
