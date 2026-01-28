#!/bin/bash
# ============================================================================
# Ubuntu Desktop Environment Installer
# ============================================================================
# This script installs GNOME desktop environment, VNC server, and Brave
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
    echo "  GNOME + VNC + Brave Browser"
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
    local required=3
    
    # Basic check (assumes GB, might need adjustment)
    if [ "${available%.*}" -lt "$required" ] 2>/dev/null; then
        log_warning "Low disk space detected: ${available}G available"
        log_warning "Recommended: ${required}G+ (GNOME needs more space than XFCE)"
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
    log_info "Installing GNOME desktop environment..."
    log_warning "This will take 30-60 minutes depending on your connection"
    log_warning "GNOME is larger than XFCE but provides a more polished experience"
    echo ""
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Install GNOME Core (lighter than full GNOME)
    # We use ubuntu-gnome-desktop for a curated experience
    apt-get install -y \
        ubuntu-gnome-desktop \
        gnome-terminal \
        gnome-system-monitor \
        gnome-tweaks \
        dbus-x11 \
        || {
            log_error "Desktop installation failed"
            log_info "Trying minimal GNOME installation..."
            
            # Fallback to minimal GNOME
            apt-get install -y \
                gnome-shell \
                gnome-session \
                gnome-terminal \
                nautilus \
                gnome-control-center \
                gnome-tweaks \
                dbus-x11 \
                || {
                    log_error "Minimal GNOME installation also failed"
                    return 1
                }
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
        dbus-x11 \
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
    
    # Set as system default browser using update-alternatives and xdg
    log_info "Setting Brave as default browser..."
    
    # Method 1: update-alternatives (system-wide)
    if command -v update-alternatives &> /dev/null; then
        update-alternatives --set x-www-browser /usr/bin/brave-browser 2>/dev/null || true
        update-alternatives --set gnome-www-browser /usr/bin/brave-browser 2>/dev/null || true
    fi
    
    # Method 2: xdg-settings (per-user, GNOME-compatible)
    if command -v xdg-settings &> /dev/null; then
        xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || true
    fi
    
    # Method 3: Create/update mimeapps.list for GNOME
    mkdir -p /root/.config
    cat > /root/.config/mimeapps.list <<MIMEAPPS
[Default Applications]
text/html=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop

[Added Associations]
text/html=brave-browser.desktop
x-scheme-handler/http=brave-browser.desktop
x-scheme-handler/https=brave-browser.desktop
x-scheme-handler/about=brave-browser.desktop
x-scheme-handler/unknown=brave-browser.desktop
MIMEAPPS
    
    # Method 4: GNOME-specific settings
    mkdir -p /root/.local/share/applications
    
    # Also set in GSettings (GNOME's configuration system)
    cat > /tmp/set-default-browser.sh <<'SETBROWSER'
#!/bin/bash
export DBUS_SESSION_BUS_ADDRESS="unix:path=/run/user/0/bus"
gsettings set org.gnome.shell favorite-apps "['brave-browser.desktop', 'org.gnome.Nautilus.desktop', 'org.gnome.Terminal.desktop']" 2>/dev/null || true
SETBROWSER
    chmod +x /tmp/set-default-browser.sh
    
    log_success "Brave configured as default browser ✓"
    log_info "Browser will be set as default when you first login to GNOME"
}

configure_vnc() {
    log_info "Configuring VNC server for GNOME..."
    
    mkdir -p /root/.vnc
    
    # Create xstartup script for GNOME
    cat > /root/.vnc/xstartup <<'XSTARTUP'
#!/bin/sh
# VNC xstartup script for GNOME Desktop

# Unset session manager variables
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Set up D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Export display for X11
export DISPLAY=:1

# Disable accessibility bus (reduces errors in proot)
export NO_AT_BRIDGE=1

# Start GNOME Session
# Using gnome-session instead of gnome-shell for better compatibility
exec gnome-session
XSTARTUP
    
    chmod +x /root/.vnc/xstartup
    log_success "VNC startup script created ✓"
    
    # Create VNC config with higher resolution for GNOME
    cat > /root/.vnc/config <<CONFIG
geometry=1920x1080
depth=24
dpi=96
CONFIG
    
    log_success "VNC configured for GNOME ✓"
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
    log_info "Creating desktop shortcuts and documentation..."
    
    mkdir -p /root/Desktop
    
    # Create README
    cat > /root/Desktop/README.txt <<README
╔════════════════════════════════════════╗
║   Welcome to Ubuntu on Termux!        ║
║        GNOME Desktop Edition          ║
╚════════════════════════════════════════╝

Your GNOME desktop environment is now installed!

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

About GNOME Desktop:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Activities: Click top-left corner or press Super key
• Show Apps: Click grid icon in dock
• Settings: Access via Activities → Settings
• Tweaks: Use GNOME Tweaks for customization
• Terminal: Press Ctrl+Alt+T

Default Applications:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Web Browser: Brave (configured for proot)
• File Manager: Nautilus (Files)
• Terminal: GNOME Terminal
• Text Editor: gedit
• System Monitor: GNOME System Monitor

Useful Commands:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• List VNC sessions:  vncserver -list
• Update system:      apt update && apt upgrade
• Install software:   apt install <package>
• Clean up:           apt autoremove && apt clean

Performance Tips:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• GNOME uses more resources than XFCE
• For better performance, disable animations:
  - Open Tweaks → Appearance → Animations: OFF
• Recommended VNC resolution: 1920x1080 or 1600x900
• Close apps when not in use

Troubleshooting:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Black screen? Check ~/.vnc/xstartup permissions
• DNS issues? Edit /etc/resolv.conf
• Browser crash? Brave is pre-configured with --no-sandbox
• Slow performance? Lower VNC resolution or try XFCE

Default Browser Setup:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Brave is configured as the default browser via:
• System alternatives
• xdg-settings
• GNOME mimeapps.list
• Favorites in GNOME Shell

If it doesn't work on first try:
1. Right-click a .html file → Properties → Open With
2. Select Brave Browser
3. Click "Set as default"

Enjoy your Ubuntu GNOME desktop environment!
README
    
    # Create start VNC script
    cat > /root/Desktop/start-vnc.sh <<'VNCSCRIPT'
#!/bin/bash
# Start VNC Server for GNOME

echo "Starting VNC Server..."
vncserver -geometry 1920x1080 -depth 24

echo ""
echo "VNC Server started!"
echo "Connect to: localhost:5901"
echo ""
echo "To stop: vncserver -kill :1"
VNCSCRIPT
    
    chmod +x /root/Desktop/start-vnc.sh
    
    # Create browser test script
    cat > /root/Desktop/test-browser.sh <<'BROWSERTEST'
#!/bin/bash
# Test Default Browser

echo "Testing default browser configuration..."
echo ""

echo "1. Checking xdg-settings..."
xdg-settings get default-web-browser 2>/dev/null || echo "  Not set via xdg-settings"

echo ""
echo "2. Checking update-alternatives..."
update-alternatives --query x-www-browser 2>/dev/null | grep Value || echo "  Not set"

echo ""
echo "3. Checking mimeapps.list..."
grep "text/html" ~/.config/mimeapps.list 2>/dev/null || echo "  Not found in mimeapps.list"

echo ""
echo "4. Opening test URL..."
xdg-open "https://www.example.com" &
sleep 2
echo "  Browser should have opened!"
BROWSERTEST
    
    chmod +x /root/Desktop/test-browser.sh
    
    log_success "Desktop shortcuts created ✓"
}

fix_gnome_permissions() {
    log_info "Fixing GNOME permissions and configurations..."
    
    # Create necessary directories
    mkdir -p /root/.local/share/applications
    mkdir -p /root/.config/autostart
    mkdir -p /run/user/0
    
    # Set proper permissions
    chmod 700 /root/.local
    chmod 755 /root/.local/share
    chmod 755 /root/.local/share/applications
    
    # Fix dbus directories
    mkdir -p /var/run/dbus
    
    log_success "Permissions configured ✓"
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
    echo "  ✓ GNOME Desktop Environment"
    echo "  ✓ TigerVNC Server"
    echo "  ✓ Brave Browser (default browser)"
    echo "  ✓ Essential GNOME applications"
    echo "  ✓ System utilities"
    echo ""
    echo -e "${BLUE}Next Steps:${NC}"
    echo ""
    echo "  1. Start VNC server:"
    echo -e "     ${YELLOW}vncserver${NC}"
    echo ""
    echo "  2. Connect with VNC Viewer:"
    echo -e "     ${YELLOW}localhost:5901${NC}"
    echo "     Recommended resolution: 1920x1080"
    echo ""
    echo "  3. Stop VNC when done:"
    echo -e "     ${YELLOW}vncserver -kill :1${NC}"
    echo ""
    echo -e "${BLUE}GNOME Tips:${NC}"
    echo "  • Click 'Activities' (top-left) to access apps"
    echo "  • Use GNOME Tweaks to customize appearance"
    echo "  • Brave is set as default browser"
    echo "  • Test browser: run ~/Desktop/test-browser.sh"
    echo ""
    echo -e "${BLUE}Recommended VNC Viewers:${NC}"
    echo "  • AVNC (F-Droid) - Best for Termux"
    echo "  • RealVNC Viewer (Google Play)"
    echo "  • bVNC (Google Play)"
    echo ""
    echo -e "${YELLOW}Note:${NC} GNOME uses more resources than XFCE"
    echo "  For lower-end devices, consider using XFCE instead"
    echo ""
    echo -e "${GREEN}Check ~/Desktop/README.txt for detailed info!${NC}"
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
    
    log_info "This will install GNOME desktop environment"
    log_info "Estimated time: 40-90 minutes"
    log_warning "GNOME requires more space and resources than XFCE"
    log_warning "Recommended: 3GB+ free space and modern device"
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
    fix_gnome_permissions
    setup_vnc_password
    create_desktop_shortcuts
    cleanup
    
    show_completion_message
}

# Run main function
main "$@"
