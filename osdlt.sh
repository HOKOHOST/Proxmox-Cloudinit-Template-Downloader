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
  "Rocky Linux 9"
  "CentOS 7 - No Support"
  "CentOS 8 Stream - No Support"
  "CentOS 9 Stream - No Support"
  "CloudLinux 8.8 with DirectAdmin"
)

declare -A os_images=(
  ["Debian 10 EOL-No Support"]="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
  ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
  ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
  ["Ubuntu Server 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
  ["Ubuntu Server 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
  ["Alma Linux 8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
  ["Alma Linux 9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
  ["Rocky Linux 9"]="https://download.rockylinux.org/pub/rocky/9.3/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
  ["CentOS 7 - No Support"]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-20150628_01.qcow2"
  ["CentOS 8 Stream - No Support"]="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
  ["CentOS 9 Stream - No Support"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
  ["CloudLinux 8.8 with DirectAdmin"]="https://download.cloudlinux.com/cloudlinux/images/cloudlinux-8.8-x86_64-directadmin-openstack-20230622.qcow2"
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

while true; do
    read -rp "Do you want to install qemu-guest-agent in the VM image? [y/N] " install_qga
    case "$install_qga" in
        y|Y)
            if ! command -v virt-customize &>/dev/null; then
                while true; do
                    read -rp "virt-customize is required but not installed. Install now? [y/N] " install_vc
                    case "$install_vc" in
                        y|Y)
                            apt-get update && apt-get install -y libguestfs-tools
                            if [ $? -ne 0 ]; then
                                echo "Failed to install libguestfs-tools. Please manually install the package and try again."
                                exit 1
                            fi
                            break ;;
                        n|N)
                            echo "Skipping the installation of qemu-guest-agent."
                            return 0 ;;
                        *)
                            echo "Invalid input. Please answer y or n." ;;
                    esac
                done
            fi
            
if virt-customize -a "/var/tmp/image.qcow2" \
  --install qemu-guest-agent \
  --run-command 'ln -s /lib/systemd/system/qemu-guest-agent.service /etc/systemd/system/multi-user.target.wants/'; then
    echo "qemu-guest-agent has been successfully installed and enabled in the image."
else
    echo "Failed to install and enable qemu-guest-agent."
    exit 1
fi
            break ;;
        n|N)
            echo "Continuing without installing qemu-guest-agent."
            break ;;
        *)
            echo "Invalid input. Please answer y or n." ;;
    esac
done

  
while true; do
    read -rp "Do you want to enable ssh access in the VM image? (If default is no) [y/N] " install_qga
    case "$install_qga" in
      y|Y)
        if ! command -v virt-customize &>/dev/null; then
          while true; do
            read -rp "virt-customize is required but not installed. Install now? [y/N] " install_vc
            case "$install_vc" in
              y|Y)
                apt-get update && apt-get install -y libguestfs-tools
                if [ $? -ne 0 ]; then
                  echo "Failed to install libguestfs-tools. Please manually install the package and try again."
                  exit 1
                fi
                break ;;
              n|N)
                echo "Skipping the enabling ssh access."
                return 0 ;;
              *)
                echo "Invalid input. Please answer y or n." ;;
            esac
          done
        fi

        if virt-customize -a "/var/tmp/image.qcow2" --run-command "sed -i -e 's/^#Port 22/Port 22/' \
           -e 's/^#AddressFamily any/AddressFamily any/' \
           -e 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' \
           -e 's/^#ListenAddress ::/ListenAddress ::/' /etc/ssh/sshd_config"; then
          echo "SSH access has been successfully allowed in the image."
        else
          echo "Failed to enable SSH access."
          exit 1
        fi
        break ;;
      n|N)
        echo "Continuing without enabling SSH access."
        break ;;
      *)
        echo "Invalid input. Please answer y or n." ;;
    esac
done

while true; do
    read -rp "Do you want to allow PasswordAuthentication in the VM image? (If the default is no) [y/N] " install_qga
    case "$install_qga" in
      y|Y)
        if ! command -v virt-customize &>/dev/null; then
          while true; do
            read -rp "virt-customize is required but not installed. Install now? [y/N] " install_vc
            case "$install_vc" in
              y|Y)
                apt-get update && apt-get install -y libguestfs-tools
                if [ $? -ne 0 ]; then
                  echo "Failed to install libguestfs-tools. Please manually install the package and try again."
                  exit 1
                fi
                break ;;
              n|N)
                echo "Skipping the PasswordAuthentication setup."
                return 0 ;;
              *)
                echo "Invalid input. Please answer y or n." ;;
            esac
          done
        fi

        if virt-customize -a "/var/tmp/image.qcow2" --run-command "sed -i '/^#PasswordAuthentication[[:space:]]/c\PasswordAuthentication yes' /etc/ssh/sshd_config" --run-command "sed -i '/^PasswordAuthentication no/c\PasswordAuthentication yes' /etc/ssh/sshd_config"; then
          echo "PasswordAuthentication has been successfully allowed in the image."
        else
          echo "Failed to set up SSH PasswordAuthentication."
          exit 1
        fi
        break ;;
      n|N)
        echo "Continuing without setting up SSH PasswordAuthentication."
        break ;;
      *)
        echo "Invalid input. Please answer y or n." ;;
    esac
  done

  echo "Creating the VM as '$os_name'..."
  qm create "$vmid" --name "$os_name" --memory 2048 --agent 1 --net0 virtio,bridge=vmbr0

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
  setup_template
  want_to_continue
done
