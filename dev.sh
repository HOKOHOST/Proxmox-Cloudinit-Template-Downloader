#!/bin/bash

# Greeting message
clear
echo "This script is proudly presented to you by HOKOHOST."
echo "Stay updated with the latest versions by visiting our website at https://hokohost.com/scripts."
echo "If you find this script valuable and would like to support our work,"
echo "Please consider making a donation at https://hokohost.com/donate."
echo "Your support is greatly appreciated!"
echo ""

# Define an ordered list for cloud-init OS images
os_images_ordered=(
  "Debian 10 EOL-No Support"
  "Debian 11"
  "Debian 12"
  "Ubuntu Server 20.04"
  "Ubuntu Server 22.04"
  "Alma Linux 8"
  "Alma Linux 9"
)

# Associative array mapping the OS names to their respective image URLs
declare -A os_images=(
  ["Debian 10 EOL-No Support"]="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
  ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
  ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  ["Ubuntu Server 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  ["Ubuntu Server 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  ["Alma Linux 8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
  ["Alma Linux 9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
)

# Select OS function
select_os() {
  echo "Please select the OS you want to import:"
  select os_choice in "${os_images_ordered[@]}"; do
    os=${os_choice}
    if [ -n "$os" ]; then
      os_name=$(echo "$os" | tr ' ' '-') # Convert spaces to hyphens for VM name
      echo "You have selected: $os"
      break
    else
      echo "Invalid selection. Please try again."
    fi
  done
}

# Specify storage target function
specify_storage() {
  read -rp "Enter the target storage (e.g., local): " storage
  echo "Selected storage: $storage"
}

# Specify VM ID function
specify_vmid() {
  read -rp "Enter the VMID you want to assign (e.g., 1000): " vmid
  echo "Selected VMID: $vmid"
}

# Download and setup template function
setup_template() {
  image_url="${os_images[$os]}"
  echo "Downloading the OS image from $image_url..."
  cd /var/tmp || exit
  wget -O image.qcow2 "$image_url" --quiet --show-progress
  
  echo "Creating the VM as '$os_name'..."
  qm create "$vmid" --name "$os_name" --memory 2048 --net0 virtio,bridge=vmbr0
  
  echo "Importing the disk image..."
  disk_import=$(qm importdisk "$vmid" image.qcow2 "$storage" --format qcow2)
  disk=$(echo "$disk_import" | grep 'Successfully imported disk as' | cut -d "'" -f 2)
  disk_path="${disk#*:}"
  
  if [[ -n "$disk_path" ]]; then
    echo "Disk image imported as $disk_path"
    
    echo "Configuring VM to use the imported disk..."
    qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$disk_path"
    qm set "$vmid" --ide2 "$storage":cloudinit
    qm set "$vmid" --boot c --bootdisk scsi0
    qm set "$vmid" --serial0 socket
    qm template "$vmid"
    
    echo "New template created for $os with VMID $vmid."
    echo "Deleting the downloaded image to save space..."
    rm -f /var/tmp/image.qcow2
    
    echo "Checking for the installation of qemu-guest-agent..."
    
    # Ask whether to install qemu-guest-agent
    read -rp "Do you want to install qemu-guest-agent? [y/N] " install_agent
    if [ "$install_agent" == "y" ] || [ "$install_agent" == "Y" ]; then
      # Check for virt-customize utility
      if ! command -v virt-customize &>/dev/null; then
        echo "virt-customize is not installed. It is required to install qemu-guest-agent."
        read -rp "Do you want to install virt-customize now? [y/N] " install_vc
        if [ "$install_vc" == "y" ] || [ "$install_vc" == "Y" ]; then
          # Attempt to install libguestfs-tools
          echo "Installing virt-customize..."
          apt-get update && apt-get install -y libguestfs-tools
          if [ $? -ne 0 ]; then
            echo "Failed to install libguestfs-tools, required by virt-customize."
            echo "Unable to proceed with qemu-guest-agent installation."
            return 1
          fi
        else
          echo "Skipping the installation of qemu-guest-agent."
          return 0
        fi
      fi
      # Now install qemu-guest-agent
      virt-customize -a "$disk_path" --install qemu-guest-agent
      if [ $? -eq 0 ]; then
        echo "qemu-guest-agent has been successfully installed in the image."
      else
        echo "Failed to install qemu-guest-agent."
        return 1
      fi
    else
      echo "Skipping the installation of qemu-guest-agent."
    fi
  else
    echo "Failed to import the disk image."
    return 1
  fi
}

# Want to continue function
want_to_continue() {
  read -rp "Do you want to continue and make another OS template? [y/N] " choice
  case "$choice" in
    y|Y ) return 0 ;;
    * ) echo "Exiting script."; exit 0 ;;
  esac
}

# Main loop
while true; do
  select_os
  specify_storage
  specify_vmid
  setup_template && ask_qemu_guest_agent
  want_to_continue
done
