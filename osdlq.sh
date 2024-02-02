#!/bin/bash

# Greeting message
echo "This is not a working script"
echo "Please use osdl.sh instead of osdlq.sh"
echo "This script is only for testing and dev."
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
  if [[ ! "$vmid" =~ ^[0-9]+$ ]]; then
    echo "Invalid VMID. Please enter a numeric value."
    specify_vmid
  else
    echo "Selected VMID: $vmid"
  fi
}

# Function to ask user about installing qemu-guest-agent
ask_install_qemu_guest_agent() {
  read -rp "Do you want qemu-guest-agent to be installed on the first run? [y/N] " choice
  if [[ "$choice" =~ ^[yY](es)?$ ]]; then
    INSTALL_QEMU_GUEST_AGENT=true
  else
    INSTALL_QEMU_GUEST_AGENT=false
  fi
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
  qm importdisk "$vmid" image.qcow2 "$storage"

  echo "Configuring VM with imported disk image..."
  qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$storage:vm-$vmid-disk-0"
  qm set "$vmid" --ide2 "$storage:cloudinit"
  qm set "$vmid" --boot c --bootdisk scsi0
  qm set "$vmid" --serial0 socket

  if [ "$INSTALL_QEMU_GUEST_AGENT" = true ]; then
    mkdir -p /var/lib/vz/snippets
    cat <<EOF > /var/lib/vz/snippets/user-data.qemu-guest-agent.yaml
#cloud-config
package_upgrade: true
packages:
  - qemu-guest-agent
EOF
    qm set "$vmid" --cicustom "user=local:snippets/user-data.qemu-guest-agent.yaml"
    echo "The QEMU guest agent will be installed on the first boot of the VM."
  fi

  qm template "$vmid"
  echo "New template created for $os with VMID $vmid."

  echo "Cleaning up downloaded image..."
  rm -f /var/tmp/image.qcow2
}

# Function to check whether the user wants to continue
want_to_continue() {
  read -rp "Do you want to continue and make another OS template? [y/N] " choice
  case "$choice" in
    [yY][eE][sS]|[yY]) ;;
    *) echo "Exiting script."; exit 0 ;;
  esac
}

# Main loop
while true; do
  select_os
  specify_storage
  specify_vmid
  ask_install_qemu_guest_agent
  setup_template
  want_to_continue
done
