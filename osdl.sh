#!/bin/bash

# Greeting message
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo ""  # For better readability :)
echo "This script is proudly presented to you by HOKOHOST."
echo "Stay updated with the latest versions by visiting our website at https://hokohost.com/scripts."
echo "If you find this script valuable and would like to support our work,"
echo "Please consider making a donation at https://hokohost.com/donate."
echo "Your support is greatly appreciated!"
echo ""  # For better readability :)

# Define an ordered list for cloud-init OS images
os_images_ordered=(
  "Debian 10 EOL-No Support"
  "Debian 11"
  "Debian 12"
  "Ubuntu Server 20.04"
  "Ubuntu Server 22.04"
  "Alma Linux 8"
  "Alma Linux 9"
  "CentOS 7 - No Support"
  "CentOS 8 Stream - No Support"
  "CentOS 9 Stream - No Support"
)

declare -A os_images=(
  ["Debian 10 EOL-No Support"]="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
  ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
  ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  ["Ubuntu Server 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  ["Ubuntu Server 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  ["Alma Linux 8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
  ["Alma Linux 9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
  ["CentOS 7 - No Support"]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-20150628_01.qcow2"
  ["CentOS 8 Stream - No Support"]="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
  ["CentOS 9 Stream - No Support"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
)

# Function to select an OS using the ordered list
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

# Function to specify the storage target
specify_storage() {
  read -rp "Enter the target storage (e.g., local): " storage
  echo "Selected storage: $storage"
}

# Function to specify the VM ID
specify_vmid() {
  read -rp "Enter the VMID you want to assign (e.g., 1000): " vmid
  echo "Selected VMID: $vmid"
}

# Function to download and setup the template
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
  else
    echo "Failed to import the disk image."
    return 1
  fi
}

# Function to check whether the user wants to continue
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
  setup_template
  want_to_continue
done
