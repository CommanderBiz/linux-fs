#!/bin/bash
# ============================================================================
# Ubuntu Noble (24.04 LTS) RootFS Builder for Termux
# ============================================================================
# This script automates the process of building a custom Ubuntu Noble root
# filesystem for ARM64 Android devices running Termux.
#
# Output: ubuntu-fs.tar.xz (compressed rootfs tarball)
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# --- CONFIGURATION ---
ARCH="arm64"
ROOTFS_DIR="ubuntu-rootfs"
OUTPUT_FILE="ubuntu-fs.tar.xz"
UBUNTU_MIRROR="http://ports.ubuntu.com/ubuntu-ports/"
UBUNTU_RELEASE="noble"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- HELPER FUNCTIONS ---

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

check_root() {
    if [ "$EUID" -eq 0 ]; then
        log_error "Please do not run this script as root. It will use sudo when needed."
        exit 1
    fi
}

check_dependencies() {
    log_info "Checking dependencies..."
    local missing_deps=()
    local missing_packages=()
    
    # Check for commands (some package names differ from command names)
    local cmd_checks=(
        "debootstrap:debootstrap"
        "proot:proot"
        "tar:tar"
        "xz:xz-utils"
        "wget:wget"
    )
    
    for check in "${cmd_checks[@]}"; do
        local cmd="${check%%:*}"
        local pkg="${check##*:}"
        if ! command -v "$cmd" &> /dev/null; then
            missing_deps+=("$cmd")
            missing_packages+=("$pkg")
        fi
    done
    
    # Check for qemu-static
    local qemu_bin="qemu-aarch64-static"
    if [ ! -f "/usr/bin/$qemu_bin" ]; then
        missing_deps+=("$qemu_bin")
        missing_packages+=("qemu-user-static")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        log_error "Missing commands: ${missing_deps[*]}"
        log_info "Install them with: sudo apt install ${missing_packages[*]}"
        exit 1
    fi
    
    log_success "All dependencies satisfied"
}

cleanup_old() {
    log_info "Cleaning up old builds..."
    sudo rm -rf "$ROOTFS_DIR" "$OUTPUT_FILE" "$OUTPUT_FILE.sha256"
    log_success "Cleanup complete"
}

# --- MAIN BUILD PROCESS ---

banner() {
    echo "========================================"
    echo "  Ubuntu Noble RootFS Builder"
    echo "  Target: $ARCH"
    echo "  Release: $UBUNTU_RELEASE"
    echo "========================================"
}

bootstrap_ubuntu() {
    log_info "Bootstrapping Ubuntu $UBUNTU_RELEASE for $ARCH..."
    log_warning "This may take 10-20 minutes depending on your connection..."
    
    mkdir -p "$ROOTFS_DIR"
    
    # Note: --no-check-gpg is used for cross-architecture builds
    # For production, configure proper GPG verification
    sudo debootstrap \
        --arch="$ARCH" \
        --components=main,restricted,universe,multiverse \
        --no-check-gpg \
        --include=nano,wget,dbus-x11,ubuntu-keyring,ca-certificates \
        "$UBUNTU_RELEASE" \
        "./$ROOTFS_DIR" \
        "$UBUNTU_MIRROR" 2>&1 | tee debootstrap.log
    
    if [ ${PIPESTATUS[0]} -eq 0 ]; then
        log_success "Bootstrap complete"
    else
        log_error "Bootstrap failed. Check debootstrap.log for details"
        exit 1
    fi
}

create_setup_script() {
    log_info "Generating internal setup script..."
    
    cat <<'SETUP_SCRIPT' > "./$ROOTFS_DIR/setup.sh"
#!/bin/bash
set -e

# --- Environment Setup ---
export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
export DEBIAN_FRONTEND=noninteractive

echo "[*] Configuring APT sources..."
cat > /etc/apt/sources.list <<SOURCES
deb http://ports.ubuntu.com/ubuntu-ports/ noble main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse
SOURCES

# APT Workarounds for QEMU/proot
echo 'Acquire::http::Pipeline-Depth "0";' > /etc/apt/apt.conf.d/99-no-pipelining
echo 'Acquire::http::No-Cache "true";' >> /etc/apt/apt.conf.d/99-no-pipelining
echo 'Acquire::BrokenProxy "true";' >> /etc/apt/apt.conf.d/99-no-pipelining
echo 'APT::Get::Assume-Yes "true";' > /etc/apt/apt.conf.d/99-assume-yes

echo "[*] Updating package lists..."
# May fail under QEMU - that's expected
apt-get update || {
    echo "[WARNING] apt-get update failed (expected in QEMU). Continuing..."
    true
}

# --- Neutralize Systemd ---
neutralize_systemd() {
    echo "[*] Neutralizing systemd (incompatible with proot)..."
    local systemd_packages=("systemd" "udev" "systemd-sysv")
    
    for pkg in "${systemd_packages[@]}"; do
        if [ -f "/var/lib/dpkg/info/${pkg}.postinst" ]; then
            echo -e "#!/bin/sh\nexit 0" > "/var/lib/dpkg/info/${pkg}.postinst"
        fi
        if [ -f "/var/lib/dpkg/info/${pkg}.prerm" ]; then
            echo -e "#!/bin/sh\nexit 0" > "/var/lib/dpkg/info/${pkg}.prerm"
        fi
    done
    dpkg --configure -a 2>/dev/null || true
}

# --- Fix Broken Packages ---
fix_broken_packages() {
    echo "[*] Applying package workarounds..."
    local problematic_packages=("fuse3" "ntfs-3g" "desktop-base" "udisks2")
    
    for pkg in "${problematic_packages[@]}"; do
        if [ -f "/var/lib/dpkg/info/${pkg}.postinst" ]; then
            echo -e "#!/bin/sh\nexit 0" > "/var/lib/dpkg/info/${pkg}.postinst"
        fi
        if [ -f "/var/lib/dpkg/info/${pkg}.prerm" ]; then
            echo -e "#!/bin/sh\nexit 0" > "/var/lib/dpkg/info/${pkg}.prerm"
        fi
    done
    dpkg --configure -a 2>/dev/null || true
}

# --- Cleanup ---
cleanup_image() {
    echo "[*] Cleaning up to reduce image size..."
    apt-get autoremove -y 2>/dev/null || true
    apt-get clean 2>/dev/null || true
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/* /var/tmp/*
    
    # Remove documentation to save space (optional)
    # rm -rf /usr/share/doc/* /usr/share/man/*
}

# --- Execute Configuration ---
neutralize_systemd
fix_broken_packages
cleanup_image

echo "[*] Internal setup complete"
rm -f /setup.sh  # Self-destruct

SETUP_SCRIPT

    sudo chmod +x "./$ROOTFS_DIR/setup.sh"
    log_success "Setup script created"
}

copy_post_install() {
    log_info "Looking for desktop installer script..."
    
    local found=false
    local search_paths=(
        "./complete_install.sh"
        "$(dirname "$0")/complete_install.sh"
        "./ubuntu/complete_install.sh"
        "../complete_install.sh"
        "$HOME/complete_install.sh"
    )
    
    for path in "${search_paths[@]}"; do
        if [ -f "$path" ]; then
            log_success "Found complete_install.sh at: $path"
            
            # Ensure /root directory exists
            if ! sudo test -d "./$ROOTFS_DIR/root"; then
                sudo mkdir -p "./$ROOTFS_DIR/root" || {
                    log_error "Failed to create /root directory"
                    exit 1
                }
            fi
            
            # Copy the file
            if sudo cp "$path" "./$ROOTFS_DIR/root/complete_install.sh" 2>/dev/null; then
                sudo chmod +x "./$ROOTFS_DIR/root/complete_install.sh"
                
                # Verify it was copied (use sudo since file is owned by root)
                if sudo test -f "./$ROOTFS_DIR/root/complete_install.sh"; then
                    log_success "Desktop installer successfully added to rootfs ✓"
                    found=true
                    break
                else
                    log_error "File copied but verification failed"
                fi
            else
                log_error "Copy command failed"
            fi
        fi
    done
    
    if [ "$found" = false ]; then
        log_error "complete_install.sh not found or failed to copy!"
        log_info "Searched paths: ${search_paths[*]}"
        log_warning "Desktop installation will not be available in the final image."
        echo ""
        log_info "To fix this:"
        echo "  1. Place complete_install.sh in the same directory as this script"
        echo "  2. Or specify the path when prompted"
        echo ""
        read -p "Do you have complete_install.sh in another location? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter the full path to complete_install.sh: " custom_path
            if [ -f "$custom_path" ]; then
                log_success "Found complete_install.sh at: $custom_path"
                sudo mkdir -p "./$ROOTFS_DIR/root"
                sudo cp "$custom_path" "./$ROOTFS_DIR/root/complete_install.sh"
                sudo chmod +x "./$ROOTFS_DIR/root/complete_install.sh"
                
                if sudo test -f "./$ROOTFS_DIR/root/complete_install.sh"; then
                    log_success "Desktop installer successfully added to rootfs ✓"
                else
                    log_error "Failed to copy complete_install.sh to rootfs"
                fi
            else
                log_error "File not found at: $custom_path"
            fi
        fi
    fi
}

copy_utils() {
    log_info "Copying utility scripts..."
    
    local utils_dir="utils"
    local dest_dir="./$ROOTFS_DIR/usr/local/bin"
    
    # Ensure destination exists
    sudo mkdir -p "$dest_dir"
    
    # Copy start-xrdp
    if [ -f "$utils_dir/start-xrdp-improved.sh" ]; then
        sudo cp "$utils_dir/start-xrdp-improved.sh" "$dest_dir/start-xrdp"
        sudo chmod +x "$dest_dir/start-xrdp"
        log_success "start-xrdp installed"
    else
        log_warning "start-xrdp-improved.sh not found in utils/"
    fi
    
    # Copy diagnose-xrdp
    if [ -f "$utils_dir/diagnose-xrdp.sh" ]; then
        sudo cp "$utils_dir/diagnose-xrdp.sh" "$dest_dir/diagnose-xrdp"
        sudo chmod +x "$dest_dir/diagnose-xrdp"
        log_success "diagnose-xrdp installed"
    else
        log_warning "diagnose-xrdp.sh not found in utils/"
    fi
}

run_setup_in_chroot() {
    log_info "Entering proot environment to configure system..."
    log_warning "You may see some errors - this is normal in QEMU/proot"
    
    local qemu_static="qemu-aarch64-static"
    
    # Copy QEMU static binary
    if [ -f "/usr/bin/$qemu_static" ]; then
        sudo cp "/usr/bin/$qemu_static" "./$ROOTFS_DIR/usr/bin/"
        log_success "QEMU binary copied"
    else
        log_error "QEMU static binary not found at /usr/bin/$qemu_static"
        exit 1
    fi
    
    # Run setup script in proot
    # The || true prevents the build from failing on non-critical errors
    sudo proot \
        -q "$qemu_static" \
        -0 \
        -r "./$ROOTFS_DIR" \
        -b /dev \
        -b /proc \
        -b /sys \
        -w /root \
        /usr/bin/env -i \
        HOME=/root \
        PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
        TERM=xterm-256color \
        /bin/bash /setup.sh 2>&1 | tee setup.log || {
            log_warning "Setup script encountered errors (check setup.log)"
            log_info "Continuing with packaging..."
        }
    
    log_success "Configuration complete"
}

create_tarball() {
    log_info "Creating compressed tarball..."
    log_info "This may take 5-15 minutes..."
    
    # Create tarball with progress
    sudo tar -cJpf "$OUTPUT_FILE" -C "./$ROOTFS_DIR" . 2>&1 | \
        grep -v "Removing leading" || true
    
    if [ -f "$OUTPUT_FILE" ]; then
        local size=$(du -h "$OUTPUT_FILE" | cut -f1)
        log_success "Tarball created: $OUTPUT_FILE ($size)"
        
        # Generate checksum
        log_info "Generating SHA256 checksum..."
        sha256sum "$OUTPUT_FILE" > "$OUTPUT_FILE.sha256"
        log_success "Checksum: $(cat "$OUTPUT_FILE.sha256")"
    else
        log_error "Failed to create tarball"
        exit 1
    fi
}

create_readme() {
    log_info "Creating README..."
    
    cat > README.md <<'README'
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
- Essential utilities (nano, wget, ca-certificates)
- Pre-configured for proot environment
- Desktop environment installer script

## Support

For issues or questions, please open an issue on GitHub.
README

    log_success "README.md created"
}

# --- MAIN EXECUTION ---

main() {
    banner
    check_root
    check_dependencies
    cleanup_old
    
    echo ""
    log_info "Starting build process..."
    echo ""
    
    bootstrap_ubuntu
    create_setup_script
    copy_post_install
    copy_utils
    run_setup_in_chroot
    create_tarball
    create_readme
    
    echo ""
    echo "========================================"
    log_success "BUILD COMPLETE!"
    echo "========================================"
    echo ""
    echo "Output files:"
    echo "  - $OUTPUT_FILE"
    echo "  - $OUTPUT_FILE.sha256"
    echo "  - README.md"
    echo ""
    echo "Next steps:"
    echo "  1. Upload $OUTPUT_FILE to GitHub releases"
    echo "  2. Update the URL in install.sh"
    echo "  3. Distribute install.sh to users"
    echo ""
    echo "Build logs saved to:"
    echo "  - debootstrap.log"
    echo "  - setup.log"
    echo ""
}

# Run main function
main "$@"