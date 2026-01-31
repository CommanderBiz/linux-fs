# Ubuntu Noble RootFS for Termux

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
4. Install desktop (XFCE4 + Brave + VNC):
   ```bash
   /root/complete_install.sh
   ```

## Desktop & Browsers

The included `complete_install.sh` script sets up a lightweight XFCE4 desktop environment.

**Web Browser:**
- **Brave Browser** is the default installed web browser.
- **Access:** Click the **Mouse icon** (Application Menu) in the upper left corner > **Internet** > **Brave Web Browser**.

**Installing other browsers:**
To install Firefox:
```bash
apt update
apt install firefox
```

To install Chromium:
```bash
apt update
apt install chromium-browser
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
- Essential utilities (nano, wget, ca-certificates)
- Pre-configured for proot environment
- Desktop environment installer script (XFCE4, Brave Browser, TigerVNC)

## Support

For issues or questions, please open an issue on GitHub.
