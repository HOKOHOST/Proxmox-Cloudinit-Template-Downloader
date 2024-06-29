#!/bin/bash

SCRIPT_VERSION="1.9.0"
SCRIPT_URL="https://osdl.sh/pve.sh"

check_for_updates() {
    echo "Checking for updates..."
    local latest_version
    local script_content

    # Download the entire script content
    script_content=$(curl -s "$SCRIPT_URL")
    if [ -z "$script_content" ]; then
        echo "Failed to check for updates. Please check your internet connection."
        return
    fi

    # Extract the version from the downloaded script
    latest_version=$(echo "$script_content" | grep "^SCRIPT_VERSION=" | cut -d'"' -f2)

    # Clean up the versions (remove any non-numeric or non-dot characters)
    latest_version=$(echo "$latest_version" | tr -cd '0-9.')
    current_version=$(echo "$SCRIPT_VERSION" | tr -cd '0-9.')

    if [ -z "$latest_version" ]; then
        echo "Failed to determine the latest version. Skipping update check."
        return
    fi

    if [ "$latest_version" != "$current_version" ]; then
        echo "A new version ($latest_version) is available. Current version is $current_version."
        read -rp "Do you want to update? [y/N] " update_choice
        if [[ $update_choice =~ ^[Yy]$ ]]; then
            echo "Updating script..."
            if echo "$script_content" > "$0"; then
                echo "Update complete. Please run the script again."
                exit 0
            else
                echo "Update failed. Please try again later or download manually from $SCRIPT_URL"
            fi
        fi
    else
        echo "You are running the latest version ($current_version)."
    fi
}


show_welcome_message() {
    clear
    cat << "EOF"
 ░▒▓██████▓▒░ ░▒▓███████▓▒░▒▓███████▓▒░░▒▓█▓▒░              ░▒▓███████▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░             ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░              ░▒▓██████▓▒░░▒▓████████▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░                    ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
░▒▓█▓▒░░▒▓█▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░      ░▒▓██▓▒░      ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░ 
 ░▒▓██████▓▒░░▒▓███████▓▒░░▒▓███████▓▒░░▒▓████████▓▒░▒▓██▓▒░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░ 
                                                                                       
EOF
    echo -e "\nWelcome to OSDL - Operating System Downloader for Proxmox VE (v$SCRIPT_VERSION)"
    echo "============================================================="
    echo "This script is maintained by CUHK LTD."
    echo "Download the latest version from: $SCRIPT_URL"
    echo
    echo "Usage Instructions:"
    echo "  - Visit https://osdl.sh for detailed usage instructions"
    echo "  - For support, contact us at info@cuhk.uk"
    echo
    echo "If you find this script helpful, we'd appreciate your support!"
    echo "Consider buying us a coffee to help maintain and improve OSDL."
    echo "You can find the donation link at https://osdl.sh"
    echo
    echo "Did you know? CUHK LTD. also provides enterprise-level Proxmox setup services."
    echo "Contact us to learn how we can optimize your infrastructure."
    echo
}

declare -A os_images=(
    ["Debian 9 (EOL)"]="https://cloud.debian.org/images/cloud/stretch/latest/debian-9-generic-amd64.qcow2"
    ["Debian 10 (EOL)"]="https://cloud.debian.org/images/cloud/buster/latest/debian-10-generic-amd64.qcow2"
    ["Debian 11"]="https://cloud.debian.org/images/cloud/bullseye/latest/debian-11-generic-amd64.qcow2"
    ["Debian 12"]="https://cloud.debian.org/images/cloud/bookworm/latest/debian-12-generic-amd64.qcow2"
    ["Ubuntu Server 18.04 (EOL)"]="https://cloud-images.ubuntu.com/bionic/current/bionic-server-cloudimg-amd64.img"
    ["Ubuntu Server 20.04"]="https://cloud-images.ubuntu.com/focal/current/focal-server-cloudimg-amd64.img"
    ["Ubuntu Server 22.04"]="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
    ["Ubuntu Server 24.04"]="https://cloud-images.ubuntu.com/noble/current/noble-server-cloudimg-amd64.img"
    ["CentOS 7 (EOL)"]="https://cloud.centos.org/centos/7/images/CentOS-7-x86_64-GenericCloud-2009.qcow2"
    ["CentOS 8 (EOL)"]="https://cloud.centos.org/centos/8/x86_64/images/CentOS-8-GenericCloud-8.4.2105-20210603.0.x86_64.qcow2"
    ["CentOS 8 Stream"]="https://cloud.centos.org/centos/8-stream/x86_64/images/CentOS-Stream-GenericCloud-8-latest.x86_64.qcow2"
    ["CentOS 9 Stream"]="https://cloud.centos.org/centos/9-stream/x86_64/images/CentOS-Stream-GenericCloud-9-latest.x86_64.qcow2"
    ["Alma Linux 8"]="https://repo.almalinux.org/almalinux/8/cloud/x86_64/images/AlmaLinux-8-GenericCloud-latest.x86_64.qcow2"
    ["Alma Linux 9"]="https://repo.almalinux.org/almalinux/9/cloud/x86_64/images/AlmaLinux-9-GenericCloud-latest.x86_64.qcow2"
    ["Rocky Linux 8"]="https://download.rockylinux.org/pub/rocky/8/images/x86_64/Rocky-8-GenericCloud.latest.x86_64.qcow2"
    ["Rocky Linux 9"]="https://download.rockylinux.org/pub/rocky/9/images/x86_64/Rocky-9-GenericCloud.latest.x86_64.qcow2"
    ["Fedora 38"]="https://download.fedoraproject.org/pub/fedora/linux/releases/38/Cloud/x86_64/images/Fedora-Cloud-Base-38-1.6.x86_64.qcow2"
    ["Oracle Linux 8"]="https://yum.oracle.com/templates/OracleLinux/OL8/u7/x86_64/OL8U7_x86_64-kvm-b198.qcow2"
    ["Oracle Linux 9"]="https://yum.oracle.com/templates/OracleLinux/OL9/u2/x86_64/OL9U2_x86_64-kvm-b140.qcow2"
    ["openSUSE Leap 15.4"]="https://download.opensuse.org/repositories/Cloud:/Images:/Leap_15.4/images/openSUSE-Leap-15.4.x86_64-1.0.0-NoCloud-Build3.48.qcow2"
)

basic_bundle=("Debian 12" "Ubuntu 22.04" "CentOS Stream 9" "Alma Linux 9" "Rocky Linux 9")
basic_bundle_with_eol=("${basic_bundle[@]}" "Debian 10 (EOL)" "Ubuntu 18.04 (EOL)" "CentOS 7 (EOL)")
extended_bundle=("Debian 11" "Debian 12" "Ubuntu 20.04" "Ubuntu 22.04" "Ubuntu 24.04" "CentOS Stream 8" "CentOS Stream 9" "Alma Linux 8" "Alma Linux 9" "Rocky Linux 8" "Rocky Linux 9" "Fedora 38" "Oracle Linux 8" "Oracle Linux 9" "openSUSE Leap 15.4")
extended_bundle_with_eol=("${!os_images[@]}")

select_mode() {
    echo "Please select a mode:"
    echo "1. Single OS selection"
    echo "2. Basic bundle (Latest stable versions)"
    echo "3. Basic bundle with EOL versions"
    echo "4. Extended bundle (All supported versions)"
    echo "5. Extended bundle with EOL versions"
    read -rp "Enter your choice (1-5): " mode_choice
    case $mode_choice in
        1) single_os_mode ;;
        2) bundle_mode "basic" ;;
        3) bundle_mode "basic_with_eol" ;;
        4) bundle_mode "extended" ;;
        5) bundle_mode "extended_with_eol" ;;
        *) echo "Invalid choice. Exiting."; exit 1 ;;
    esac
}

single_os_mode() {
    select_os
    specify_storage
    specify_vmid
    setup_template
}

bundle_mode() {
    local bundle_type=$1
    specify_storage
    case "$bundle_type" in
        "basic")
            for os in "${basic_bundle[@]}"; do
                os_choice=$os
                specify_vmid_auto
                setup_template
            done
            ;;
        "basic_with_eol")
            for os in "${basic_bundle_with_eol[@]}"; do
                os_choice=$os
                specify_vmid_auto
                setup_template
            done
            ;;
        "extended")
            for os in "${extended_bundle[@]}"; do
                os_choice=$os
                specify_vmid_auto
                setup_template
            done
            ;;
        "extended_with_eol")
            for os in "${extended_bundle_with_eol[@]}"; do
                os_choice=$os
                specify_vmid_auto
                setup_template
            done
            ;;
    esac
}

select_os() {
    echo "Please select the OS you want to import:"
    local count=1
    local distros=("Debian" "Ubuntu Server" "CentOS" "Alma Linux" "Rocky Linux" "Fedora" "Oracle Linux" "openSUSE Leap")
    local options=()

    for distro in "${distros[@]}"; do
        echo
        echo "$distro:"
        # Collect all versions for this distro
        local versions=()
        for os in "${!os_images[@]}"; do
            if [[ $os == $distro* ]]; then
                versions+=("$os")
            fi
        done
        # Sort versions
        IFS=$'\n' sorted_versions=($(sort -V <<<"${versions[*]}"))
        unset IFS
        # Print sorted versions
        for version in "${sorted_versions[@]}"; do
            printf "%3d) %s\n" $count "$version"
            options+=("$version")
            ((count++))
        done
    done
    
    while true; do
        read -rp "Enter your choice (1-$((count-1))): " os_choice
        if [[ "$os_choice" =~ ^[0-9]+$ ]] && [ "$os_choice" -ge 1 ] && [ "$os_choice" -lt "$count" ]; then
            os_choice=${options[$((os_choice-1))]}
            if [[ $os_choice == *"(EOL)"* ]]; then
                echo "Warning: $os_choice is End of Life. It's not recommended for use due to potential security issues."
                read -rp "Do you still want to continue? [y/N] " continue_choice
                if [[ ! $continue_choice =~ ^[Yy]$ ]]; then
                    echo "Operation cancelled. Please select a supported OS."
                    select_os
                    return
                fi
            fi
            echo "You have selected: $os_choice"
            return 0
        else
            echo "Invalid selection. Please try again."
        fi
    done
}

specify_storage() {
    local default_storage="local-zfs"
    while true; do
        read -rp "Enter the target storage (default: $default_storage): " storage
        if [ -z "$storage" ]; then
            storage=$default_storage
            echo "Using default storage: $storage"
            return 0
        elif pvesm list "$storage" &>/dev/null; then
            echo "Selected storage: $storage"
            return 0
        else
            echo "The specified storage '$storage' does not exist. Please try again."
        fi
    done
}

specify_vmid() {
    while true; do
        read -rp "Enter the VMID you want to assign (e.g., 1000): " vmid
        if [[ ! $vmid =~ ^[0-9]+$ ]]; then
            echo "Invalid input. Please enter a number."
        elif qm status "$vmid" &>/dev/null; then
            echo "The VMID $vmid is already in use. Please enter another one."
        else
            echo "Selected VMID: $vmid"
            return 0
        fi
    done
}

specify_vmid_auto() {
    local base_vmid
    case $os_choice in
        Debian*) base_vmid=1000 ;;
        Ubuntu*) base_vmid=1100 ;;
        CentOS*) base_vmid=1200 ;;
        Alma*) base_vmid=1300 ;;
        Rocky*) base_vmid=1400 ;;
        Fedora*) base_vmid=1500 ;;
        "Oracle Linux"*) base_vmid=1600 ;;
        openSUSE*) base_vmid=1700 ;;
        *) base_vmid=2000 ;;
    esac

    while true; do
        if ! qm status "$base_vmid" &>/dev/null; then
            vmid=$base_vmid
            echo "Assigned VMID: $vmid"
            return 0
        fi
        ((base_vmid++))
    done
}

install_package() {
    local package=$1
    if ! dpkg -s "$package" >/dev/null 2>&1; then
        echo "$package is not installed."
        read -rp "Do you want to install $package? [y/N] " install_choice
        if [[ $install_choice =~ ^[Yy]$ ]]; then
            echo "Installing $package..."
            if ! apt-get update && apt-get install -y "$package"; then
                echo "Failed to install $package. Some functions might be unavailable."
                return 1
            fi
        else
            echo "Skipping installation of $package. Some functions might be unavailable."
            return 1
        fi
    fi
    return 0
}

customize_image() {
    local action=$1
    local command=$2
    
    if ! command -v virt-customize &>/dev/null; then
        echo "virt-customize is not installed. Skipping $action."
        return 1
    fi
    
    if ! virt-customize -a "/var/tmp/image.qcow2" $command; then
        echo "Failed to $action."
        return 1
    fi
    echo "Successfully $action."
}

setup_template() {
    local image_url="${os_images[$os_choice]}"
    echo "Downloading the OS image for $os_choice from $image_url..."
    cd /var/tmp || exit
    
    # Download with progress and error checking
    if ! wget -O image.qcow2 "$image_url" --progress=bar:force:noscroll; then
        echo "Failed to download the image. Please check your internet connection and try again."
        return 1
    fi

    # Check if the downloaded file is empty
    if [ ! -s image.qcow2 ]; then
        echo "The downloaded image file is empty. Please try again or choose a different OS."
        rm -f image.qcow2
        return 1
    fi

    install_package "libguestfs-tools"

    local options=(
        "Install qemu-guest-agent"
        "Enable SSH access"
        "Allow PasswordAuthentication"
        "Enable root SSH login"
    )

    for option in "${options[@]}"; do
        local command=""
        case "$option" in
            "Install qemu-guest-agent")
                command="--install qemu-guest-agent --run-command 'systemctl enable qemu-guest-agent'"
                ;;
            "Enable SSH access")
                command="--run-command \"sed -i -e 's/^#Port 22/Port 22/' -e 's/^#AddressFamily any/AddressFamily any/' -e 's/^#ListenAddress 0.0.0.0/ListenAddress 0.0.0.0/' -e 's/^#ListenAddress ::/ListenAddress ::/' /etc/ssh/sshd_config\""
                ;;
            "Allow PasswordAuthentication")
                command="--run-command \"sed -i '/^#PasswordAuthentication[[:space:]]/c\PasswordAuthentication yes' /etc/ssh/sshd_config && sed -i '/^PasswordAuthentication no/c\PasswordAuthentication yes' /etc/ssh/sshd_config\""
                ;;
            "Enable root SSH login")
                command="--run-command \"sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config\""
                ;;
        esac

        read -rp "Do you want to $option? [y/N] " choice
        case "$choice" in
            y|Y) customize_image "$option" "$command" ;;
            *) echo "Skipping $option." ;;
        esac
    done

    # Create a valid VM name
    local vm_name=$(echo "$os_choice" | sed 's/ (EOL)//; s/ /-/g')
    echo "Creating the VM as '$vm_name'..."
    qm create "$vmid" --name "$vm_name" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

    echo "Importing the disk image..."
    local disk_import
    disk_import=$(qm importdisk "$vmid" image.qcow2 "$storage" --format qcow2)
    local disk
    disk=$(echo "$disk_import" | grep 'Successfully imported disk as' | cut -d "'" -f 2)
    local disk_path="${disk#*:}"

    if [[ -n "$disk_path" ]]; then
        echo "Disk image imported as $disk_path"

        echo "Configuring VM to use the imported disk..."
        qm set "$vmid" --scsihw virtio-scsi-pci --scsi0 "$disk_path"
        qm set "$vmid" --ide2 "$storage":cloudinit
        qm set "$vmid" --boot c --bootdisk scsi0
        qm set "$vmid" --serial0 socket --vga serial0
        qm template "$vmid"

        echo "New template created for $os_choice with VMID $vmid."

        echo "Deleting the downloaded image to save space..."
        rm -f /var/tmp/image.qcow2
    else
        echo "Failed to import the disk image."
        rm -f /var/tmp/image.qcow2
        return 1
    fi
}


main() {
    show_welcome_message
    check_for_updates
    echo "Press any key to continue..."
    read -n 1 -s -r
    echo
    select_mode
    echo "Thank you for using OSDL!"
    echo "Remember, CUHK LTD. offers enterprise-level Proxmox setup services."
    echo "Visit https://osdl.sh or contact info@cuhk.uk for more information."
    echo "Your support helps us continue improving. Consider a donation if you found this useful!"
}

main
