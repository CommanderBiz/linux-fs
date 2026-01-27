# Complete Step-by-Step Tutorial: Ubuntu on Termux

## 🎯 Goal
Build a custom Ubuntu Noble (24.04 LTS) rootfs on an AMD64 computer, upload it to GitHub, and install it on an ARM64 Android device running Termux with a full XFCE4 desktop accessible via VNC.

---

## 📊 Prerequisites

### On AMD64 Host Computer
- Ubuntu 20.04+ or Debian-based Linux
- 4GB+ RAM
- 10GB+ free disk space
- Stable internet connection
- GitHub account
- `sudo` access

### On Android Device
- ARM64/AArch64 processor (check: Settings → About → Processor)
- Android 7.0+
- 3GB+ free storage
- Termux app (from F-Droid, NOT Google Play)
- Internet connection

---

## 🚀 Phase 1: Setup Build Environment (AMD64 Host)

### Step 1.1: Install Dependencies
```bash
# Update your system
sudo apt update && sudo apt upgrade -y

# Install required packages
sudo apt install -y \
    debootstrap \
    proot \
    qemu-user-static \
    binfmt-support \
    tar \
    xz-utils \
    wget \
    git

# Verify installations
debootstrap --version
proot --version
qemu-aarch64-static --version
```

**Expected Output:**
```
debootstrap 1.0.xxx
proot version x.x.x
qemu-aarch64 version x.x.x
```

### Step 1.2: Create Project Directory
```bash
# Create and enter project directory
mkdir ~/ubuntu-termux-build
cd ~/ubuntu-termux-build

# Download the improved scripts
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/install_ubuntu_improved.sh
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/complete_install_improved.sh

# Make scripts executable
chmod +x install_ubuntu_improved.sh complete_install_improved.sh
```

### Step 1.3: Verify Setup
```bash
# Check you're NOT running as root
whoami
# Should output your username, NOT "root"

# Check available disk space
df -h .
# Should show at least 10GB free
```

---

## 🏗️ Phase 2: Build Ubuntu RootFS

### Step 2.1: Run the Build Script
```bash
# Start the build (this takes 15-30 minutes)
./install_ubuntu_improved.sh
```

**What Happens:**
1. ✅ Checks dependencies
2. ✅ Cleans old builds
3. ✅ Bootstraps Ubuntu Noble for ARM64
4. ✅ Creates internal setup script
5. ✅ Copies desktop installer
6. ✅ Configures system in proot
7. ✅ Creates compressed tarball
8. ✅ Generates SHA256 checksum
9. ✅ Creates README

**You'll see output like:**
```
========================================
  Ubuntu Noble RootFS Builder
  Target: arm64
  Release: noble
========================================

[INFO] Checking dependencies...
[SUCCESS] All dependencies satisfied ✓
[INFO] Cleaning up old builds...
[SUCCESS] Cleanup complete ✓
[INFO] Bootstrapping Ubuntu noble for arm64...
[WARNING] This may take 10-20 minutes depending on your connection...
```

### Step 2.2: Verify Build Output
```bash
# Check the output files
ls -lh

# You should see:
# ubuntu-fs.tar.xz         (200-500 MB)
# ubuntu-fs.tar.xz.sha256  (checksum file)
# README.md                (auto-generated)
# debootstrap.log          (build log)
# setup.log                (config log)

# Verify the tarball
tar -tJf ubuntu-fs.tar.xz | head -20

# Check the checksum
cat ubuntu-fs.tar.xz.sha256
```

**Expected:**
```
-rw-r--r-- 1 user user 350M Jan 26 10:30 ubuntu-fs.tar.xz
-rw-r--r-- 1 user user   89 Jan 26 10:30 ubuntu-fs.tar.xz.sha256
-rw-r--r-- 1 user user 1.2K Jan 26 10:30 README.md
```

---

## 📤 Phase 3: Upload to GitHub

### Step 3.1: Setup GitHub Repository

**Option A: Via GitHub Website**
1. Go to https://github.com/new
2. Repository name: `ubuntu-termux` (or your choice)
3. Description: "Ubuntu Noble 24.04 LTS for Termux"
4. Public or Private (your choice)
5. Click "Create repository"

**Option B: Via Command Line**
```bash
# Initialize git repo
git init
git add .
git commit -m "Initial commit"

# Create GitHub repo (requires gh CLI)
gh repo create ubuntu-termux --public
git remote add origin https://github.com/YOUR_USERNAME/ubuntu-termux.git
git push -u origin main
```

### Step 3.2: Create GitHub Release

**Option A: Using Helper Script (Easiest)**
```bash
# Download helper script
wget https://raw.githubusercontent.com/YOUR_USERNAME/YOUR_REPO/main/upload-to-github.sh
chmod +x upload-to-github.sh

# Run interactive upload
./upload-to-github.sh

# Follow the prompts:
# 1. Choose "Create new release"
# 2. Enter version (e.g., v1.0)
# 3. Enter title or use default
# 4. Enter description or use default
# 5. Confirm upload
```

**Option B: Via GitHub Website**
1. Go to your repository
2. Click "Releases" → "Draft a new release"
3. Tag version: `v1.0`
4. Release title: `Ubuntu Noble 24.04 for Termux - v1.0`
5. Description:
   ```markdown
   Pre-built Ubuntu Noble (24.04 LTS) ARM64 root filesystem for Termux.
   
   ## Installation
   See [README.md](README.md) for instructions.
   
   ## Files
   - `ubuntu-fs.tar.xz` - Root filesystem (350 MB)
   - `ubuntu-fs.tar.xz.sha256` - Checksum
   - `install_improved.sh` - Installer script
   ```
6. Upload files:
   - `ubuntu-fs.tar.xz`
   - `ubuntu-fs.tar.xz.sha256`
   - `install_improved.sh` (if available)
7. Click "Publish release"

**Option C: Via GitHub CLI**
```bash
# Install GitHub CLI if not already
sudo apt install gh

# Login
gh auth login

# Create release
gh release create v1.0 \
  --title "Ubuntu Noble 24.04 for Termux" \
  --notes "Initial release with XFCE4 desktop support" \
  ubuntu-fs.tar.xz \
  ubuntu-fs.tar.xz.sha256 \
  install_improved.sh
```

### Step 3.3: Get Release URLs
After creating the release, note the download URL:
```
https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/ubuntu-fs.tar.xz
```

You'll need this for the installer script!

---

## 📱 Phase 4: Install on Android Device

### Step 4.1: Setup Termux

1. **Install Termux:**
   - Download from F-Droid (https://f-droid.org/)
   - DO NOT use Google Play version (outdated)

2. **Open Termux and update:**
   ```bash
   pkg update && pkg upgrade
   
   # If asked about modified files, choose "Y" to install maintainer's version
   ```

3. **Grant storage permission (optional but recommended):**
   ```bash
   termux-setup-storage
   # Tap "Allow" when prompted
   ```

### Step 4.2: Download Installer Script

**Method A: Direct Download**
```bash
# Download from GitHub release
wget https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/install_improved.sh

# Or download latest
wget https://github.com/YOUR_USERNAME/YOUR_REPO/releases/latest/download/install_improved.sh
```

**Method B: Using Git**
```bash
pkg install git
git clone https://github.com/YOUR_USERNAME/YOUR_REPO.git
cd YOUR_REPO
```

### Step 4.3: Configure Installer
```bash
# Edit the installer to add your release URL
nano install_improved.sh

# Find this line (near the top):
RELEASE_URL="https://github.com/CommanderBiz/andronix-lab/releases/download/V0.1/ubuntu-fs.tar.xz"

# Replace with YOUR release URL:
RELEASE_URL="https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/ubuntu-fs.tar.xz"

# Optional: Add checksum URL
CHECKSUM_URL="https://github.com/YOUR_USERNAME/YOUR_REPO/releases/download/v1.0/ubuntu-fs.tar.xz.sha256"

# Save: Ctrl+O, Enter, Ctrl+X
```

### Step 4.4: Run Installer
```bash
# Make executable
chmod +x install_improved.sh

# Run the installer
./install_improved.sh
```

**You'll see:**
```
========================================
   Ubuntu on Termux Installer
   Version: 1.0
========================================

[INFO] Checking device architecture...
[SUCCESS] Architecture: aarch64 ✓
[INFO] Checking available storage...
[SUCCESS] Storage check passed ✓
[INFO] Installing dependencies...
[SUCCESS] All dependencies already installed ✓
[INFO] Downloading Ubuntu rootfs...
[WARNING] This may take 5-15 minutes depending on your connection

ubuntu-fs.tar.xz    100%[===================>] 350.00M  10.2MB/s    in 35s

[SUCCESS] Download complete
[INFO] Extracting rootfs...
[WARNING] This may take 10-20 minutes...
```

**Wait for completion!** This can take 20-40 minutes total.

### Step 4.5: Verify Installation
```bash
# Check installation
ls -la

# You should see:
# ubuntu-fs/          (directory)
# start-ubuntu.sh     (launcher script)

# Check launcher
cat start-ubuntu.sh
```

---

## 🖥️ Phase 5: Setup Desktop Environment

### Step 5.1: Start Ubuntu
```bash
# Launch Ubuntu
./start-ubuntu.sh
```

**You'll see:**
```
========================================
   Starting Ubuntu Noble 24.04 LTS
========================================

╔════════════════════════════════════════╗
║   Welcome to Ubuntu Noble 24.04 LTS   ║
║        Running on Termux/Android      ║
╚════════════════════════════════════════╝

Quick Start:
  • Install desktop: /root/complete_install.sh
  • Update system:   apt update && apt upgrade
  • Exit Ubuntu:     exit

Note: Some systemd services won't work in proot

root@ubuntu:~#
```

### Step 5.2: Verify Ubuntu Environment
```bash
# Check Ubuntu version
cat /etc/os-release

# Check network
ping -c 3 google.com

# Update package lists
apt update
```

### Step 5.3: Install Desktop Environment
```bash
# Run the desktop installer
/root/complete_install.sh
```

**You'll see:**
```
========================================
  Ubuntu Desktop Environment Installer
  XFCE4 + VNC + Brave Browser
========================================

This will install a full desktop environment
Estimated time: 20-40 minutes
Make sure you have a stable internet connection

Continue? (y/N): y

[INFO] Checking internet connectivity...
[SUCCESS] Internet connection: OK ✓
[INFO] Checking available disk space...
[SUCCESS] Disk space check passed ✓
[INFO] Configuring DNS...
[SUCCESS] DNS configured ✓
[INFO] Updating package lists...
[WARNING] This may take a few minutes...
```

**During installation:**
- Answer "Y" to prompts
- Wait patiently (can take 30+ minutes)
- Don't close Termux!

### Step 5.4: Set VNC Password
When prompted:
```
[INFO] Setting up VNC password...
[WARNING] You will be prompted to enter a password for VNC access

Password: ********
Verify:   ********
Would you like to enter a view-only password (y/n)? n

[SUCCESS] VNC password set ✓
```

**Remember this password!** You'll need it to connect.

### Step 5.5: Wait for Completion
```bash
# Installation continues...
[INFO] Installing XFCE4 desktop environment...
[INFO] Installing VNC server...
[INFO] Installing Brave browser...
[INFO] Configuring desktop...
[INFO] Creating desktop shortcuts...
[INFO] Cleaning up...

╔════════════════════════════════════════╗
║   Desktop Installation Complete! 🎉   ║
╚════════════════════════════════════════╝

What's Installed:
  ✓ XFCE4 Desktop Environment
  ✓ TigerVNC Server
  ✓ Brave Browser (proot-ready)
  ✓ Essential utilities

Next Steps:
  1. Start VNC server: vncserver
  2. Connect with VNC Viewer: localhost:5901
  3. Stop VNC when done: vncserver -kill :1
```

---

## 🖼️ Phase 6: Connect to Desktop via VNC

### Step 6.1: Start VNC Server (In Ubuntu)
```bash
# Start VNC with default settings
vncserver

# Or with custom resolution
vncserver -geometry 1920x1080
```

**You'll see:**
```
New 'X' desktop is localhost:1

Starting applications specified in /root/.vnc/xstartup
Log file is /root/.vnc/localhost:1.log
```

**Note the display number (`:1`)!**
- `:1` = Port `5901`
- `:2` = Port `5902`

### Step 6.2: Install VNC Viewer on Android

**Recommended VNC Viewers:**
1. **AVNC** (Best for Termux)
   - F-Droid: https://f-droid.org/packages/com.gaurav.avnc/
   - Free, open-source
   - Works great with localhost

2. **RealVNC Viewer**
   - Google Play Store
   - Free version available

3. **VNC Viewer** (by RealVNC)
   - Google Play Store
   - Simple and reliable

### Step 6.3: Connect to VNC

**Using AVNC:**
1. Open AVNC
2. Tap "+"
3. Settings:
   - Name: `Ubuntu Termux`
   - Host: `localhost`
   - Port: `5901`
4. Tap "Save"
5. Tap the connection
6. Enter your VNC password
7. Tap "Connect"

**Using RealVNC Viewer:**
1. Open VNC Viewer
2. Tap "+"
3. Address: `localhost:5901`
4. Name: `Ubuntu Termux`
5. Tap "Create"
6. Tap the connection
7. Enter password
8. Tap "Connect"

### Step 6.4: Use the Desktop!
You should now see the XFCE4 desktop!

**Things to try:**
- Click Applications menu (top left)
- Open Terminal Emulator
- Launch Brave Browser
- Explore File Manager
- Open README.txt on Desktop

---

## 🎛️ Phase 7: Managing VNC Sessions

### Stop VNC Server
```bash
# Inside Ubuntu environment
vncserver -kill :1

# Or stop all sessions
vncserver -kill :*
```

### List Active Sessions
```bash
vncserver -list
```

### View VNC Logs
```bash
cat ~/.vnc/*.log
```

### Change VNC Password
```bash
vncpasswd
```

### Change Resolution
```bash
# Method 1: Kill and restart with new geometry
vncserver -kill :1
vncserver -geometry 1920x1080

# Method 2: Edit config
nano ~/.vnc/config
# Add: geometry=1920x1080
```

---

## 📖 Phase 8: Daily Usage

### Starting Your Environment

**Every time you want to use Ubuntu:**
```bash
# 1. Open Termux
# 2. Start Ubuntu
./start-ubuntu.sh

# 3. Start VNC
vncserver

# 4. Open VNC Viewer and connect to localhost:5901
```

### Stopping Everything

**When you're done:**
```bash
# 1. In VNC, close all applications
# 2. In Ubuntu terminal, stop VNC
vncserver -kill :1

# 3. Exit Ubuntu
exit

# 4. Close Termux (or leave it running in background)
```

### Updating Ubuntu
```bash
# Inside Ubuntu environment
apt update
apt upgrade

# Clean up
apt autoremove
apt clean
```

### Installing Software
```bash
# Example: Install Firefox
apt install firefox-esr

# Example: Install Python
apt install python3 python3-pip

# Example: Install development tools
apt install build-essential git
```

---

## 🐛 Common Issues & Solutions

### Issue: VNC Shows Black Screen

**Solution 1: Check xstartup**
```bash
cat ~/.vnc/xstartup
chmod +x ~/.vnc/xstartup
vncserver -kill :1
vncserver
```

**Solution 2: Reinstall desktop**
```bash
apt install --reinstall xfce4
```

### Issue: "apt update" Fails

**Solution:**
```bash
# Fix DNS
echo "nameserver 8.8.8.8" > /etc/resolv.conf
echo "nameserver 8.8.4.4" >> /etc/resolv.conf

# Clear cache
rm -rf /var/lib/apt/lists/*
apt-get update
```

### Issue: Brave Browser Crashes

**Solution:**
```bash
# Use Firefox instead
apt install firefox-esr

# Or manually fix Brave
sed -i 's|Exec=/usr/bin/brave-browser|Exec=/usr/bin/brave-browser --no-sandbox|' \
  /usr/share/applications/brave-browser.desktop
```

### Issue: VNC Connection Refused

**Solution:**
```bash
# Check if VNC is running
vncserver -list

# If not running, start it
vncserver

# Check the port (should be 5901 for :1)
# Connect to localhost:5901
```

### Issue: Low Performance

**Solutions:**
- Use lower resolution: `vncserver -geometry 1024x768`
- Close unnecessary applications
- Reduce color depth (already set to 24-bit)
- Use lighter apps (nano instead of GUI editors)

---

## 🎓 Tips & Best Practices

### Performance Tips
1. Use terminal when possible (faster than GUI)
2. Keep VNC resolution reasonable (1280x720 or 1024x768)
3. Close applications when not in use
4. Regular cleanup: `apt autoremove && apt clean`

### Security Tips
1. Don't expose VNC to external network
2. Use strong VNC password
3. Keep system updated: `apt update && apt upgrade`
4. Only install trusted software

### Backup Tips
1. Export important files to Termux storage:
   ```bash
   # In Ubuntu
   cp /root/important-file /mnt/sdcard/
   ```
2. Backup your VNC password
3. Keep installer script for reinstallation

### Space Management
1. Regular cleanup:
   ```bash
   apt autoremove -y
   apt clean
   rm -rf /tmp/*
   ```
2. Remove unused packages:
   ```bash
   apt list --installed | wc -l  # Count packages
   apt remove package-name
   ```
3. Check space:
   ```bash
   df -h
   du -sh /root  # Check home directory size
   ```

---

## 🎉 Congratulations!

You now have a fully functional Ubuntu 24.04 LTS desktop environment running on your Android device via Termux!

**What you can do now:**
- Browse the web with Brave
- Develop software (Python, Node.js, etc.)
- Use Linux tools (git, vim, etc.)
- Learn Linux commands
- Run server applications
- And much more!

**Next steps:**
- Explore the Applications menu
- Install your favorite tools
- Customize XFCE4 appearance
- Learn more about Linux

**Enjoy your mobile Linux desktop!** 🐧📱

---

## 📞 Need Help?

- Re-read this tutorial carefully
- Check the [Quick Reference Guide](QUICK_REFERENCE.md)
- Review the [Improvements Documentation](IMPROVEMENTS.md)
- Check GitHub Issues
- Create a new issue with detailed error information

---

**Last Updated:** January 2026
**Version:** 1.0
