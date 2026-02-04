# Ubuntu Noble RootFS for Termux (Commander v1.3)

This is a pre-built Ubuntu Noble (24.04 LTS) ARM64 root filesystem for use with Termux on Android devices.

## Files

- `ubuntu-fs.tar.xz` - Compressed root filesystem
- `ubuntu-fs.tar.xz.sha256` - SHA256 checksum for verification
- `install.sh` - Termux installer script

## Installation

1. Install Termux from F-Droid
2. Download and run the installer:
   ```bash
   pkg install wget -y
   wget https://raw.githubusercontent.com/CommanderBiz/linux-fs/main/improved_ubuntu/install.sh
   bash install.sh
   ```
3. Start Ubuntu:
   ```bash
   ./start-ubuntu.sh
   ```
4. Install desktop (optional):
   ```bash
   /root/complete_install.sh
   ```

## Verification

Verify the download integrity:
```bash
sha256sum -c ubuntu-fs.tar.xz.sha256
```

## Requirements

- ARM64 Android device
- Termux (latest version from F-Droid)
- At least 2GB free storage space
- Internet connection for initial setup

## What's Included

- Ubuntu Noble 24.04 LTS base system
- **Ubuntu Commander v1.3** Desktop Installer (`complete_install.sh`)
- **High-Performance X11 Support:** Integrated Termux:X11 configuration for best performance.
- **New:** `start-xrdp` utility for managing xRDP sessions.
- **New:** `diagnose-xrdp` tool for troubleshooting
- Essential utilities (nano, wget, ca-certificates)
- Pre-configured for proot environment

## Support

For issues or questions, please open an issue on GitHub.
