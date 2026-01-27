#!/bin/bash
# ============================================================================
# Ubuntu Desktop Environment Installer
# ============================================================================
# This script installs XFCE4 desktop environment, VNC server, and Brave
# browser in the Ubuntu rootfs running under Termux.
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

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
    echo "  Ubuntu Desktop Environment Installer"
    echo "  XFCE4 + VNC + Brave Browser"
    echo "========================================"
    echo ""
}

check_internet() {
    log_info "Checking internet connectivity..."
    
    if ping -c 1 8.8.8.8 > /dev/null 2>&1; then
        log_success "Internet connection: OK ✓"
    else
        log_error "No internet connection detected"
        log_error "Please check your network and try again"
        exit 1
    fi
}

check_space() {
    log_info "Checking available disk space..."
    
    local available=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//')
    local required=2
    
    # Basic check (assumes GB, might need adjustment)
    if [ "${available%.*}" -lt "$required" ] 2>/dev/null; then
        log_warning "Low disk space detected: ${available}G available"
        log_warning "Recommended: ${required}G+"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            log_info "Installation cancelled"
            exit 0
        fi
    else
        log_success "Disk space check passed ✓"
    fi
}

fix_resolv_conf() {
    log_info "Configuring DNS..."
    
    cat > /etc/resolv.conf <<DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
DNS
    
    log_success "DNS configured ✓"
}

update_system() {
    log_info "Updating package lists..."
    log_warning "This may take a few minutes..."
    
    # Set non-interactive mode
    export DEBIAN_FRONTEND=noninteractive
    
    # Update with retry logic
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        if apt-get update; then
            log_success "Package lists updated ✓"
            return 0
        else
            log_warning "Update attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Retrying in 5 seconds..."
                sleep 5
                attempt=$((attempt + 1))
            else
                log_error "Failed to update package lists after $max_attempts attempts"
                return 1
            fi
        fi
    done
}

install_desktop() {
    log_info "Installing XFCE4 desktop environment..."
    log_warning "This will take 15-30 minutes depending on your connection"
    echo ""
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Install desktop with progress
    apt-get install -y \
        xfce4 \
        xfce4-goodies \
        xfce4-terminal \
        dbus-x11 \
        || {
            log_error "Desktop installation failed"
            return 1
        }
    
    log_success "Desktop environment installed ✓"
}

install_vnc() {
    log_info "Installing VNC server..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-common \
        || {
            log_error "VNC installation failed"
            return 1
        }
    
    log_success "VNC server installed ✓"
}

install_utilities() {
    log_info "Installing essential utilities..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get install -y \
        nano \
        vim \
        wget \
        curl \
        git \
        htop \
        net-tools \
        iputils-ping \
        nmap \
        gpg \
        ca-certificates \
        || {
            log_warning "Some utilities failed to install"
        }
    
    log_success "Utilities installed ✓"
}

install_brave() {
    log_info "Installing Brave browser..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Add Brave repository
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || {
        log_warning "Failed to download Brave keyring"
        return 1
    }
    
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    
    # Update and install
    apt-get update
    apt-get install -y brave-browser || {
        log_warning "Brave browser installation failed"
        log_info "You can use Firefox instead: apt install firefox-esr"
        return 1
    }
    
    log_success "Brave browser installed ✓"
}

configure_brave() {
    log_info "Configuring Brave for proot environment..."
    
    if ! dpkg -s brave-browser &> /dev/null; then
        log_warning "Brave not installed, skipping configuration"
        return 0
    fi
    
    # Find and patch all Brave desktop files
    local patched=0
    while IFS= read -r desktop_file; do
        if [ -f "$desktop_file" ]; then
            if ! grep -q -- "--no-sandbox" "$desktop_file"; then
                sed -i 's|\(Exec=[^ ]*brave-browser[^ ]*\)|\1 --no-sandbox --test-type --disable-dev-shm-usage|g' "$desktop_file"
                patched=$((patched + 1))
            fi
        fi
    done < <(find /usr/share/applications -name "brave-browser*.desktop" 2>/dev/null)
    
    if [ $patched -gt 0 ]; then
        log_success "Patched $patched Brave desktop file(s) ✓"
    fi
    
    # Set as default browser
    local brave_desktop=$(find /usr/share/applications -name "brave-browser.desktop" ! -name "*private*" ! -name "*incognito*" -print -quit)
    
    if [ -n "$brave_desktop" ]; then
        mkdir -p /root/.config/xfce4
        local basename=$(basename "$brave_desktop")
        echo -e "[Desktop Entry]\nWebBrowser=$basename" > /root/.config/xfce4/helpers.rc
        log_success "Brave set as default browser ✓"
    fi
}

configure_vnc() {
    log_info "Configuring VNC server..."
    
    mkdir -p /root/.vnc
    
    # Create xstartup script
    cat > /root/.vnc/xstartup <<'XSTARTUP'
#!/bin/sh
# VNC xstartup script for XFCE4

unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax)
fi

# Start XFCE4
exec /usr/bin/startxfce4
XSTARTUP
    
    chmod +x /root/.vnc/xstartup
    log_success "VNC startup script created ✓"
    
    # Create VNC config
    cat > /root/.vnc/config <<CONFIG
geometry=1280x720
depth=24
dpi=96
CONFIG
    
    log_success "VNC configured ✓"
}

setup_vnc_password() {
    echo ""
    log_info "Setting up VNC password..."
    log_warning "You will be prompted to enter a password for VNC access"
    echo ""
    
    if vncpasswd; then
        log_success "VNC password set ✓"
    else
        log_error "Failed to set VNC password"
        return 1
    fi
}

create_desktop_shortcuts() {
    log_info "Creating desktop shortcuts..."
    
    mkdir -p /root/Desktop
    
    # Create README
    cat > /root/Desktop/README.txt <<README
╔════════════════════════════════════════╗
║   Welcome to Ubuntu on Termux!        ║
╚════════════════════════════════════════╝

Your desktop environment is now installed!

Quick Start:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. Start VNC Server:
   Open a terminal and run: vncserver
   
2. Connect to VNC:
   • Use a VNC viewer app on your Android device
   • Connect to: localhost:5901
   • Use the password you just set

3. Stop VNC Server:
   vncserver -kill :1

Useful Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• List VNC sessions:  vncserver -list
• Update system:      apt update && apt upgrade
• Install software:   apt install <package>
• Clean up:           apt autoremove && apt clean

Tips:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• VNC display :1 corresponds to port 5901
• For better performance, use 1024x768 resolution
• Brave browser is pre-configured for proot
• Some systemd services won't work in proot

Troubleshooting:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Black screen? Check ~/.vnc/xstartup permissions
• DNS issues? Edit /etc/resolv.conf
• Browser crash? Use: brave-browser --no-sandbox

Enjoy your Ubuntu desktop environment!
README
    
    # Create start VNC script
    cat > /root/Desktop/start-vnc.sh <<'VNCSRIPT'
#!/bin/bash
# Start VNC Server

echo "Starting VNC Server..."
vncserver -geometry 1280x720 -depth 24

echo ""
echo "VNC Server started!"
echo "Connect to: localhost:5901"
echo ""
echo "To stop: vncserver -kill :1"
VNCSRIPT
    
    chmod +x /root/Desktop/start-vnc.sh
    
    log_success "Desktop shortcuts created ✓"
}

cleanup() {
    log_info "Cleaning up..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get autoremove -y > /dev/null 2>&1 || true
    apt-get clean > /dev/null 2>&1 || true
    rm -rf /var/lib/apt/lists/* /var/cache/apt/*.bin /tmp/* /var/tmp/* || true
    
    log_success "Cleanup complete ✓"
}

show_completion_message() {
    clear
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════╗"
    echo -e "║   Desktop Installation Complete! 🎉   ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${BLUE}What's Installed:${NC}"
    echo "  ✓ XFCE4 Desktop Environment"
    echo "  ✓ TigerVNC Server"
    echo "  ✓ Brave Browser (proot-ready)"
    echo "  ✓ Essential utilities"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "  1. Start VNC server:"
    echo -e "     ${YELLOW}vncserver${NC}"
    echo ""
    echo "  2. Connect with VNC Viewer:"
    echo -e "     ${YELLOW}localhost:5901${NC}"
    echo ""
    echo "  3. Stop VNC when done:"
    echo -e "     ${YELLOW}vncserver -kill :1${NC}"
    echo ""
    echo -e "${BLUE}Recommended VNC Viewers:${NC}"
    echo "  • AVNC (F-Droid)"
    echo "  • RealVNC Viewer (Google Play)"
    echo "  • VNC Viewer (Google Play)"
    echo ""
    echo -e "${GREEN}Check ~/Desktop/README.txt for more info!${NC}"
    echo ""
}

error_handler() {
    log_error "Installation encountered an error"
    log_info "Check the output above for details"
    exit 1
}

# Set trap for errors
trap error_handler ERR

# --- MAIN EXECUTION ---

main() {
    banner
    
    log_info "This will install a full desktop environment"
    log_info "Estimated time: 20-40 minutes"
    log_warning "Make sure you have a stable internet connection"
    echo ""
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Starting installation..."
    echo ""
    
    check_internet
    check_space
    fix_resolv_conf
    
    if ! update_system; then
        log_warning "Package list update failed, but continuing..."
    fi
    
    install_desktop
    install_vnc
    install_utilities
    
    # Brave is optional
    if install_brave; then
        configure_brave
    fi
    
    configure_vnc
    setup_vnc_password
    create_desktop_shortcuts
    cleanup
    
    show_completion_message
}

# Run main function
main "$@"
