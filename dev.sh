#!/bin/bash

# Greeting message
clear
echo "This script is proudly presented to you by HOKOHOST."
echo "Stay updated with the latest versions by visiting our website at https://hokohost.com/scripts."
echo "If you find this script valuable and would like to support our work,"
echo "Please consider making a donation at https://hokohost.com/donate."
echo "Your support is greatly appreciated!"
echo ""

os_images_ordered=(
  "Debian 10 EOL-No Support"
  "Debian 11"
  "Debian 12"
  "Ubuntu Server 20.04"
  "Ubuntu Server 22.04"
  "Alma Linux 8"
  "Alma Linux 9"
)

declare -A os_images=(
  ["Debian 10 EOL-No Support"]="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
  ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
  ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  ["Ubuntu Server 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  ["Ubuntu Server 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  ["Alma Linux 8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
  ["Alma Linux 9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
)

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

specify_storage() {
  while true; do
    read -rp "Enter the target storage (e.g., local-lvm): " storage
    if [ -z "$storage" ]; then
      echo "You must input a storage to continue."
    elif ! pvesm list "$storage" &>/dev/null; then
      echo "The specified storage does not exist. Please try again."
    else
      echo "Selected storage: $storage"
      break
    fi
  done
}

specify_vmid() {
  while true; do
    read -rp "Enter the VMID you want to assign (e.g., 1000): " vmid
    if [ -z "$vmid" ]; then
      echo "You must input a VMID to continue."
    elif qm status "$vmid" &>/dev/null; then
      echo "The VMID $vmid is already in use. Please enter another one."
    else
      echo "Selected VMID: $vmid"
      break
    fi
  done
}

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

install_qemu_guest_agent() {
  read -rp "Do you want to install qemu-guest-agent in the VM image? [y/N] " install_qga
  if [[ "$install_qga" =~ ^[yY]$ ]]; then
    if ! command -v virt-customize &>/dev/null; then
      echo "virt-customize is not installed. It is required to install qemu-guest-agent."
      read -rp "Would you like to install virt-customize? [y/N] " install_vc
      if [[ "$install_vc" =~ ^[yY]$ ]]; then
        apt-get update && apt-get install -y libguestfs-tools
        if [ $? -ne 0 ]; then
          echo "Failed to install libguestfs-tools. Please manually install the package and try again."
          return 1
        fi
      else
        echo "Skipping the installation of qemu-guest-agent."
        return 0
      fi
    fi
    virt-customize -a "/var/lib/vz/images/$vmid/disk-0.qcow2" --install qemu-guest-agent
    if [ $? -ne 0 ]; then
      echo "Failed to install qemu-guest-agent."
      exit 1
    fi
  else
    echo "Continuing without installing qemu-guest-agent."
  fi
}

want_to_continue() {
  read -rp "Do you want to continue and make another OS template? [y/N] " choice
  case "$choice" in
    y|Y ) ;;
    * ) echo "Exiting script."; exit 0 ;;
  esac
}

# Main loop
while true; do
  select_os
  specify_storage
  specify_vmid
  if setup_template; then
    install_qemu_guest_agent
  fi
  want_to_continue
done
