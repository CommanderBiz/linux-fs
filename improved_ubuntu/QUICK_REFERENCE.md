# Quick Reference Guide - Ubuntu on Termux

## 📋 Table of Contents
1. [Build Process (AMD64)](#build-process-amd64)
2. [Upload to GitHub](#upload-to-github)
3. [Installation (Termux)](#installation-termux)
4. [Desktop Setup](#desktop-setup)
5. [VNC Usage](#vnc-usage)
6. [Troubleshooting](#troubleshooting)
7. [Common Commands](#common-commands)

---

## 🏗️ Build Process (AMD64)

### One-Time Setup
```bash
# Install dependencies
sudo apt update
sudo apt install -y debootstrap proot qemu-user-static binfmt-support tar xz-utils wget
```

### Build RootFS
```bash
# Download the build script
wget https://raw.githubusercontent.com/YOUR_REPO/main/install_ubuntu_improved.sh

# Make executable
chmod +x install_ubuntu_improved.sh

# Run (no sudo needed - script handles it)
./install_ubuntu_improved.sh
```

### Output Files
After successful build:
```
✓ ubuntu-fs.tar.xz          (200-500 MB)
✓ ubuntu-fs.tar.xz.sha256   (checksum)
✓ README.md                 (auto-generated)
✓ debootstrap.log           (build log)
✓ setup.log                 (config log)
```

---

## 📤 Upload to GitHub

### Method 1: Using Helper Script (Recommended)
```bash
# Download helper
wget https://raw.githubusercontent.com/YOUR_REPO/main/upload-to-github.sh
chmod +x upload-to-github.sh

# Run interactive upload
./upload-to-github.sh
```

### Method 2: Manual Upload
```bash
# 1. Create release on GitHub web interface
# 2. Upload files:
#    - ubuntu-fs.tar.xz
#    - ubuntu-fs.tar.xz.sha256
#    - install_improved.sh

# 3. Get download URL:
# https://github.com/USER/REPO/releases/download/TAG/ubuntu-fs.tar.xz
```

### Method 3: GitHub CLI
```bash
# Install gh CLI
sudo apt install gh

# Login
gh auth login

# Create release
gh release create v1.0 \
  --title "Ubuntu Noble 24.04 for Termux" \
  --notes "Initial release" \
  ubuntu-fs.tar.xz \
  ubuntu-fs.tar.xz.sha256 \
  install_improved.sh
```

---

## 📱 Installation (Termux)

### Quick Install
```bash
# Download installer
wget https://github.com/YOUR_USER/YOUR_REPO/releases/latest/download/install_improved.sh

# Edit to add your release URL (if needed)
nano install_improved.sh
# Change: RELEASE_URL="https://github.com/..."

# Run installer
chmod +x install_improved.sh
./install_improved.sh
```

### What It Does
1. ✓ Checks ARM64 architecture
2. ✓ Verifies storage space (warns if <2GB)
3. ✓ Installs dependencies (proot, tar, wget)
4. ✓ Downloads ubuntu-fs.tar.xz
5. ✓ Verifies checksum (if configured)
6. ✓ Extracts rootfs to ubuntu-fs/
7. ✓ Creates start-ubuntu.sh launcher
8. ✓ Configures welcome message

---

## 🖥️ Desktop Setup

### Start Ubuntu Environment
```bash
./start-ubuntu.sh
```

### Install Desktop (Inside Ubuntu)
```bash
# Run the desktop installer
/root/complete_install.sh

# This installs:
# - XFCE4 desktop environment
# - TigerVNC server
# - Brave browser
# - Essential utilities
```

### Set VNC Password
During installation, you'll be prompted:
```
Please set your VNC password now.
Password: ********
Verify: ********
```

---

## 🖼️ VNC Usage

### Start VNC Server
```bash
# Default (1280x720)
vncserver

# Custom resolution
vncserver -geometry 1920x1080

# Custom display number
vncserver :2
```

### Connect to VNC
**On Android:**
1. Install VNC viewer (AVNC, RealVNC, etc.)
2. Connect to: `localhost:5901`
3. Enter your VNC password

**Port Numbers:**
- `:1` = Port 5901
- `:2` = Port 5902
- `:3` = Port 5903

### Stop VNC Server
```bash
# Stop specific display
vncserver -kill :1

# Stop all displays
vncserver -kill :*

# List active sessions
vncserver -list
```

### Change VNC Password
```bash
vncpasswd
```

---

## 🔧 Troubleshooting

### Build Issues (AMD64)

#### "debootstrap: command not found"
```bash
sudo apt install debootstrap
```

#### "QEMU binary not found"
```bash
sudo apt install qemu-user-static binfmt-support
```

#### "Bootstrap failed with GPG errors"
```bash
# Install Ubuntu keyring
sudo apt install ubuntu-keyring

# Or use --no-check-gpg (less secure)
# Already included in improved script
```

#### Build completes but tarball is small
```bash
# Check logs
cat debootstrap.log
cat setup.log

# Common issue: network problems during bootstrap
# Solution: Re-run the build script
```

### Installation Issues (Termux)

#### "Unsupported architecture"
```bash
# Check your architecture
uname -m
# Should show: aarch64 or arm64
# If not, you need an ARM64 device
```

#### "Download failed"
```bash
# Check internet connection
ping -c 3 8.8.8.8

# Verify URL in install_improved.sh is correct
# Try downloading manually:
wget YOUR_RELEASE_URL
```

#### "Extraction failed"
```bash
# Check available space
df -h

# Try manual extraction
mkdir -p ubuntu-fs
proot --link2symlink tar -xJf ubuntu-fs.tar.xz -C ubuntu-fs --exclude='dev/*'
```

#### Launcher won't start
```bash
# Check if ubuntu-fs exists
ls -la ubuntu-fs/

# Check launcher permissions
chmod +x start-ubuntu.sh

# Try running with bash explicitly
bash start-ubuntu.sh
```

### Desktop Issues

#### "apt update" fails inside Ubuntu
```bash
# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf

# Clear cache
rm -rf /var/lib/apt/lists/*
apt-get update
```

#### Brave browser won't start
```bash
# Already patched in improved script
# Manual fix:
sed -i 's|Exec=/usr/bin/brave-browser|Exec=/usr/bin/brave-browser --no-sandbox --test-type|' \
  /usr/share/applications/brave-browser.desktop

# Or use Firefox
apt install firefox-esr
```

#### VNC shows black screen
```bash
# Check xstartup
cat ~/.vnc/xstartup

# Should contain:
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec /usr/bin/startxfce4

# Fix permissions
chmod +x ~/.vnc/xstartup

# Restart VNC
vncserver -kill :1
vncserver
```

#### VNC connection refused
```bash
# Check if VNC is running
vncserver -list

# Check display number
# :1 = port 5901
# :2 = port 5902

# Kill and restart
vncserver -kill :*
vncserver
```

---

## 💻 Common Commands

### Package Management (Inside Ubuntu)
```bash
# Update package lists
apt update

# Upgrade packages
apt upgrade

# Install package
apt install package-name

# Remove package
apt remove package-name

# Clean cache
apt autoremove && apt clean

# Search for package
apt search keyword
```

### System Information
```bash
# Check Ubuntu version
cat /etc/os-release

# Check kernel
uname -a

# Check disk usage
df -h

# Check memory
free -h

# Check running processes
ps aux
htop
```

### File Operations
```bash
# List files
ls -lah

# Change directory
cd /path/to/dir

# Copy files
cp source destination

# Move files
mv source destination

# Delete files
rm file
rm -rf directory

# Find files
find /path -name "filename"
```

### Network
```bash
# Test connectivity
ping -c 3 google.com

# Check DNS
cat /etc/resolv.conf

# Download file
wget URL
curl -O URL

# Check open ports
netstat -tuln
```

### VNC Commands
```bash
# Start VNC
vncserver

# Stop VNC
vncserver -kill :1

# List VNC sessions
vncserver -list

# Change VNC password
vncpasswd

# View VNC log
cat ~/.vnc/*.log
```

---

## 🎯 Quick Troubleshooting Checklist

### Can't Build on AMD64?
- [ ] Install debootstrap
- [ ] Install qemu-user-static
- [ ] Install proot
- [ ] Check internet connection
- [ ] Ensure not running as root

### Can't Install on Termux?
- [ ] Verify ARM64 architecture (`uname -m`)
- [ ] Check storage space (`df -h`)
- [ ] Update Termux (`pkg upgrade`)
- [ ] Check internet connection
- [ ] Verify release URL is correct

### Desktop Won't Install?
- [ ] Check internet inside Ubuntu (`ping 8.8.8.8`)
- [ ] Fix DNS (`echo "nameserver 8.8.8.8" > /etc/resolv.conf`)
- [ ] Run `apt update` first
- [ ] Check disk space
- [ ] Review error messages

### VNC Not Working?
- [ ] Verify VNC server started (`vncserver -list`)
- [ ] Check correct port (`:1` = `5901`)
- [ ] Verify password was set (`vncpasswd`)
- [ ] Check xstartup permissions (`chmod +x ~/.vnc/xstartup`)
- [ ] Try killing and restarting (`vncserver -kill :*; vncserver`)

---

## 📚 File Locations

### On Build Host (AMD64)
```
/path/to/project/
├── install_ubuntu_improved.sh    (build script)
├── complete_install_improved.sh  (desktop installer)
├── ubuntu-rootfs/                (build directory)
├── ubuntu-fs.tar.xz              (output)
├── ubuntu-fs.tar.xz.sha256       (checksum)
├── debootstrap.log               (build log)
└── setup.log                     (config log)
```

### On Termux
```
/data/data/com.termux/files/home/
├── install_improved.sh           (installer script)
├── start-ubuntu.sh               (launcher)
└── ubuntu-fs/                    (extracted rootfs)
    ├── bin/
    ├── etc/
    ├── root/
    │   ├── complete_install.sh   (desktop installer)
    │   └── Desktop/
    │       ├── README.txt
    │       └── start-vnc.sh
    └── usr/
```

### Inside Ubuntu
```
/root/
├── .bashrc                       (shell config)
├── .vnc/
│   ├── config                    (VNC config)
│   ├── passwd                    (VNC password)
│   ├── xstartup                  (startup script)
│   └── *.log                     (VNC logs)
├── Desktop/
│   ├── README.txt               (help file)
│   └── start-vnc.sh             (VNC helper)
└── complete_install.sh          (desktop installer)
```

---

## 🔗 Useful Links

- **Termux Wiki:** https://wiki.termux.com/
- **Ubuntu Ports:** http://ports.ubuntu.com/ubuntu-ports/
- **XFCE Docs:** https://docs.xfce.org/
- **TigerVNC:** https://tigervnc.org/
- **GitHub CLI:** https://cli.github.com/

---

## 🆘 Getting Help

1. Check this guide first
2. Review error messages carefully
3. Check log files (debootstrap.log, setup.log, ~/.vnc/*.log)
4. Search existing GitHub issues
5. Create new issue with:
   - Full error message
   - Relevant log files
   - System information (`uname -a`)
   - Steps to reproduce

---

**Last Updated:** January 2026
