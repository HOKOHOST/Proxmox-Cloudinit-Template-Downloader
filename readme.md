# Proxmox Cloud-init Template Downloader

This bash script facilitates the downloading and setup of Cloud-init OS templates for Proxmox Virtual Environment (PVE). It automates the download of specified operating system images and imports them into Proxmox as VM templates, streamlining the process of creating new VMs with various operating systems.

# Known Issues: Proxmox 8.3 or up might have issues running the script, will revamp when I have time.

## Features

- Supports a wide range of cloud-init enabled OS images
- Automated QEMU Guest Agent installation
- Enabling of SSH access for VMs
- Configuration of SSH to permit password authentication
- Option to enable root SSH login
- Bulk download and customization options
- Improved error handling and debugging information

## Supported Operating Systems

- Debian (10, 11, 12)
- Ubuntu Server (18.04, 20.04, 22.04, 24.04)
- CentOS (7, 8 Stream, 9 Stream)
- Alma Linux (8, 9)
- Rocky Linux (8, 9)
- Fedora 38
- Oracle Linux (8, 9)
- openSUSE Leap 15.4

## Prerequisites

- A Proxmox VE installation
- Internet connectivity to download OS images
- Sufficient storage space in your desired storage location for the image files

## Usage

### Option 1: Quick Single-Line Command (Recommended)

Use this command to download and run the script in one go:

```bash
bash <(wget -qO- osdl.sh/pve.sh)
```

### Option 2: Download and Save for Repeated Use

1. Download the script:
    ```bash
    wget osdl.sh/pve.sh
    ```

2. Make the script executable:
    ```bash
    chmod +x pve.sh
    ```

3. Run the script:
    ```bash
    ./pve.sh
    ```

## Interactive Prompts

You will be prompted for the following information:

1. **Operating System Selection**: Choose from the list of supported OS templates.
2. **Target Storage**: Enter the target storage ID (e.g., 'local-zfs').
3. **VMID**: Assign a VMID that is not already in use on your Proxmox server.
4. **Customization Options**: Choose whether to install QEMU Guest Agent, enable SSH access, allow password authentication, and enable root SSH login.

For bulk operations, you'll have the option to apply these customizations to all downloads or be prompted for each.

## Error Handling and Debugging

The script now includes improved error handling and provides more detailed debugging information if issues occur during the download or customization process.

## Contributions

Your contributions are most welcome. Feel free to make improvements by submitting pull requests.

## Support

This script is provided by [HOKOHOST](https://hokohost.com/). If you find it valuable and wish to support further development or say thanks, please consider making a donation using [Stripe](https://donate.stripe.com/6oE00Y8fUe6V6uQ002). Your support is greatly appreciated.

## License

This project is licensed under the [MIT License](LICENSE) - see the LICENSE file for details.

## Disclaimer

This script is provided 'as-is', without any warranty or guarantee of any kind. Use it at your own risk.

## Author Information

This script is proudly presented to you by [HOKOHOST](https://hokohost.com). Stay updated with the latest versions by visiting our website.
