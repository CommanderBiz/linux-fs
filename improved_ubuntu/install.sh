#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Ubuntu on Termux - Installer Script
# ============================================================================
# This script downloads and installs a pre-built Ubuntu Noble root filesystem
# in Termux on ARM64 Android devices.
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# --- CONFIGURATION ---
# PASTE YOUR RELEASE LINK HERE vvv
RELEASE_URL="https://github.com/CommanderBiz/linux-fs/releases/download/u0.3/ubuntu-fs.tar.xz"
CHECKSUM_URL=""  # Optional: Add SHA256 checksum URL for verification
# ^^^^^^^^^^^^^^^^^^^^^^^^^^^^

INSTALL_DIR="ubuntu-fs"
TAR_FILE="ubuntu-fs.tar.xz"
LAUNCHER_SCRIPT="start-ubuntu.sh"

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

banner() {
    clear
    echo "========================================"
    echo "   Ubuntu on Termux Installer"
    echo "   Version: 1.0"
    echo "========================================"
    echo ""
}

check_architecture() {
    log_info "Checking device architecture..."
    local arch=$(uname -m)
    
    if [[ "$arch" != "aarch64" && "$arch" != "arm64" ]]; then
        log_error "Unsupported architecture: $arch"
        log_error "This installer requires ARM64/AArch64 architecture"
        exit 1
    fi
    
    log_success "Architecture: $arch ✓"
}

check_storage() {
    log_info "Checking available storage..."
    local available=$(df -h "$PREFIX" | awk 'NR==2 {print $4}' | sed 's/G//' | sed 's/M//' | cut -d. -f1)
    local required=2000  # 2GB in MB
    
    # If output is in GB, convert to MB
    if df -h "$PREFIX" | awk 'NR==2 {print $4}' | grep -q "G"; then
        available=$(echo "$available * 1024" | bc 2>/dev/null || echo "5000")
    fi
    
    if [ "${available:-0}" -lt "$required" ]; then
        log_warning "Low storage space detected"
        log_warning "Available: ~${available}MB, Recommended: 2GB+"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        log_success "Storage check passed ✓"
    fi
}

check_existing_installation() {
    if [ -d "$INSTALL_DIR" ] || [ -f "$LAUNCHER_SCRIPT" ]; then
        log_warning "Existing installation detected"
        echo ""
        echo "Found:"
        [ -d "$INSTALL_DIR" ] && echo "  - $INSTALL_DIR/"
        [ -f "$LAUNCHER_SCRIPT" ] && echo "  - $LAUNCHER_SCRIPT"
        echo ""
        read -p "Remove and reinstall? (y/N): " -n 1 -r
        echo
        
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Removing existing installation..."
            rm -rf "$INSTALL_DIR" "$LAUNCHER_SCRIPT"
            log_success "Cleanup complete"
        else
            log_info "Installation cancelled"
            exit 0
        fi
    fi
}

install_dependencies() {
    log_info "Installing dependencies..."
    
    # Update package lists quietly
    pkg update -y > /dev/null 2>&1 || {
        log_warning "Package update failed, continuing anyway..."
    }
    
    local deps=("proot" "tar" "wget")
    local installed=0
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_info "Installing $dep..."
            pkg install -y "$dep" > /dev/null 2>&1 || {
                log_error "Failed to install $dep"
                exit 1
            }
            installed=$((installed + 1))
        fi
    done
    
    if [ $installed -eq 0 ]; then
        log_success "All dependencies already installed ✓"
    else
        log_success "Installed $installed package(s) ✓"
    fi
}

download_rootfs() {
    log_info "Downloading Ubuntu rootfs..."
    log_warning "This may take 5-15 minutes depending on your connection"
    echo ""
    
    # Remove old download if exists
    rm -f "$TAR_FILE"
    
    # Download with progress bar
    if wget --show-progress -O "$TAR_FILE" "$RELEASE_URL" 2>&1; then
        log_success "Download complete"
    else
        log_error "Download failed"
        log_error "Please check your internet connection and the URL"
        rm -f "$TAR_FILE"
        exit 1
    fi
    
    # Verify file exists and has content
    if [ ! -s "$TAR_FILE" ]; then
        log_error "Downloaded file is empty or missing"
        exit 1
    fi
    
    local size=$(du -h "$TAR_FILE" | cut -f1)
    log_info "Downloaded: $size"
}

verify_checksum() {
    if [ -n "$CHECKSUM_URL" ]; then
        log_info "Verifying checksum..."
        
        wget -q -O "${TAR_FILE}.sha256" "$CHECKSUM_URL" || {
            log_warning "Could not download checksum file"
            return
        }
        
        if sha256sum -c "${TAR_FILE}.sha256" 2>/dev/null; then
            log_success "Checksum verification passed ✓"
            rm -f "${TAR_FILE}.sha256"
        else
            log_error "Checksum verification failed!"
            log_error "File may be corrupted or tampered with"
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                exit 1
            fi
        fi
    fi
}

extract_rootfs() {
    log_info "Extracting rootfs..."
    log_warning "This may take 10-20 minutes..."
    echo ""
    
    mkdir -p "$INSTALL_DIR"
    
    # Extract with proot to handle symlinks properly
    if proot --link2symlink tar -xJf "$TAR_FILE" -C "$INSTALL_DIR" --exclude='dev/*' 2>&1 | \
        grep -v "Removing leading" | grep -v "tar:"; then
        :
    fi
    
    # Check if extraction succeeded
    if [ -d "$INSTALL_DIR/usr" ] && [ -d "$INSTALL_DIR/etc" ]; then
        log_success "Extraction complete ✓"
        
        # Cleanup tarball to save space
        log_info "Cleaning up..."
        rm -f "$TAR_FILE"
        
        local extracted_size=$(du -sh "$INSTALL_DIR" | cut -f1)
        log_info "Installed size: $extracted_size"
    else
        log_error "Extraction failed - rootfs structure incomplete"
        exit 1
    fi
}

create_launcher() {
    log_info "Creating launcher script..."
    
    cat > "$LAUNCHER_SCRIPT" <<'LAUNCHER'
#!/data/data/com.termux/files/usr/bin/bash
# ============================================================================
# Ubuntu Launcher for Termux
# ============================================================================

set -e

INSTALL_DIR="ubuntu-fs"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Check if installation exists
if [ ! -d "$INSTALL_DIR" ]; then
    echo -e "${RED}Error: Ubuntu installation not found at $INSTALL_DIR${NC}"
    echo "Please run the installer first"
    exit 1
fi

# Clear environment
unset LD_PRELOAD

# Setup DNS
echo "nameserver 8.8.8.8" > "$INSTALL_DIR/etc/resolv.conf"
echo "nameserver 8.8.4.4" >> "$INSTALL_DIR/etc/resolv.conf"

# Launch message
clear
echo -e "${BLUE}========================================"
echo "   Starting Ubuntu Noble 24.04 LTS"
echo "========================================${NC}"
echo ""

# Launch proot environment
proot --link2symlink \
    -0 \
    -r "$INSTALL_DIR" \
    -b /dev \
    -b "$PREFIX/tmp:/dev/shm" \
    -b /proc \
    -b /sys \
    -w /root \
    /usr/bin/env -i \
    HOME=/root \
    TERM=xterm-256color \
    LANG=C.UTF-8 \
    PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin \
    /bin/bash --login

# Exit message
echo ""
echo -e "${GREEN}Exited Ubuntu environment${NC}"
LAUNCHER

    chmod +x "$LAUNCHER_SCRIPT"
    log_success "Launcher created: $LAUNCHER_SCRIPT ✓"
}

create_welcome_message() {
    log_info "Creating welcome message..."
    
    cat > "$INSTALL_DIR/root/.bashrc" <<'BASHRC'
# Ubuntu on Termux - .bashrc

# If not running interactively, don't do anything
[[ $- != *i* ]] && return

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Welcome message (only on interactive login)
if [ -f /root/.show_welcome ]; then
    clear
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   Welcome to Ubuntu Noble 24.04 LTS   ║"
    echo -e "║        Running on Termux/Android      ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Quick Start:${NC}"
    echo "  • Choose desktop:  /root/choose_desktop.sh"
    echo "  • Update system:   apt update && apt upgrade"
    echo "  • Exit Ubuntu:     exit"
    echo ""
    echo -e "${YELLOW}Note:${NC} Some systemd services won't work in proot"
    echo ""
    rm /root/.show_welcome
fi

# Better prompt
PS1='\[\033[1;32m\]\u@ubuntu\[\033[0m\]:\[\033[1;34m\]\w\[\033[0m\]\$ '

# Useful aliases
alias ll='ls -lah'
alias update='apt update && apt upgrade'
alias cleanup='apt autoremove -y && apt clean'

# Set better history
HISTSIZE=10000
HISTFILESIZE=20000
HISTCONTROL=ignoredups:erasedups

BASHRC

    touch "$INSTALL_DIR/root/.show_welcome"
    log_success "Welcome message configured ✓"
}

show_completion_message() {
    clear
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║     Installation Complete! 🎉         ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
  1. Start Ubuntu:
     ${YELLOW}./$LAUNCHER_SCRIPT${NC}

  2. Inside Ubuntu, install desktop (optional):
     ${YELLOW}/root/choose_desktop.sh${NC}

  3. After desktop installation, start VNC:
     ${YELLOW}vncserver${NC}
    echo ""
    echo -e "${BLUE}Tips:${NC}"
    echo "  • VNC will be accessible at localhost:5901"
    echo "  • Use a VNC viewer app to connect"
    echo "  • Run 'apt update' inside Ubuntu for latest packages"
    echo ""
    echo -e "${GREEN}Enjoy your Ubuntu environment!${NC}"
    echo ""
}

cleanup_on_error() {
    log_error "Installation failed"
    log_info "Cleaning up..."
    rm -rf "$INSTALL_DIR" "$TAR_FILE" "$LAUNCHER_SCRIPT"
    exit 1
}

# Set trap for errors
trap cleanup_on_error ERR

# --- MAIN EXECUTION ---

main() {
    banner
    check_architecture
    check_storage
    check_existing_installation
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    install_dependencies
    download_rootfs
    verify_checksum
    extract_rootfs
    create_launcher
    create_welcome_message
    
    show_completion_message
}

# Run main function
main "$@"
