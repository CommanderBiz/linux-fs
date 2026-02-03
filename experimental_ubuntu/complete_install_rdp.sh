#!/bin/bash
# ============================================================================
# Ubuntu Desktop Environment Installer - RDP Edition
# ============================================================================
# This script installs XFCE4 desktop environment, xRDP server, and Brave
# browser in the Ubuntu rootfs running under Termux.
# Optimized for ARM64 Ubuntu Noble with RDP instead of VNC.
# ============================================================================

set -e  # Exit on error
set -u  # Exit on undefined variable

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Ubuntu Desktop Environment Installer ║"
    echo "║       XFCE4 + RDP + Brave Browser     ║"
    echo "║          EXPERIMENTAL - RDP            ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_features() {
    echo -e "${CYAN}What You'll Get:${NC}"
    echo ""
    echo "  ✓ XFCE4 Desktop - Fast, lightweight, beautiful"
    echo "  ✓ xRDP Server - Better performance than VNC"
    echo "  ✓ Brave Browser - Privacy-focused web browser"
    echo "  ✓ Essential Apps - File manager, terminal, text editor"
    echo "  ✓ Customized Setup - Pre-configured for Termux/Android"
    echo ""
    echo -e "${BLUE}RDP Advantages:${NC}"
    echo "  • Better image quality and compression"
    echo "  • Lower bandwidth usage"
    echo "  • Built-in sound support (when available)"
    echo "  • Better clipboard integration"
    echo "  • Microsoft Remote Desktop app (Android/iOS)"
    echo ""
    echo -e "${BLUE}Installation Details:${NC}"
    echo "  • Time Required: 25-45 minutes"
    echo "  • Space Needed: ~2.5GB"
    echo "  • Internet Required: Yes (for downloading packages)"
    echo ""
    echo -e "${YELLOW}⚠ EXPERIMENTAL:${NC} RDP in proot is untested - VNC is stable fallback"
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
        log_success "Disk space check passed (${available}G available) ✓"
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

fix_apt_sources() {
    log_info "Configuring APT for proot environment..."
    
    # Use HTTP instead of HTTPS to avoid SSL issues in proot
    cat > /etc/apt/sources.list <<SOURCES
deb http://ports.ubuntu.com/ubuntu-ports/ noble main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse
SOURCES
    
    # Configure APT to work better in proot
    cat > /etc/apt/apt.conf.d/99-termux <<APTCONF
Acquire::http::Pipeline-Depth "0";
Acquire::http::No-Cache "true";
Acquire::BrokenProxy "true";
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APTCONF
    
    log_success "APT configured for proot ✓"
}

update_system() {
    log_info "Updating package lists..."
    log_warning "This may take a few minutes..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Update with retry logic
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        log_info "Attempt $attempt of $max_attempts..."
        if apt-get update 2>&1; then
            log_success "Package lists updated ✓"
            return 0
        else
            log_warning "Update attempt $attempt failed"
            if [ $attempt -lt $max_attempts ]; then
                log_info "Retrying in 10 seconds..."
                sleep 10
                attempt=$((attempt + 1))
            else
                log_error "Failed to update package lists after $max_attempts attempts"
                log_error "This is usually a network issue. Try again later or check your connection."
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
    
    # Install XFCE4 and essential components
    apt-get install -y \
        xfce4 \
        xfce4-goodies \
        xfce4-terminal \
        thunar \
        xfce4-whiskermenu-plugin \
        xfce4-clipman-plugin \
        xfce4-systemload-plugin \
        dbus-x11 \
        || {
            log_error "Desktop installation failed"
            return 1
        }
    
    log_success "Desktop environment installed ✓"
}

install_rdp() {
    log_info "Installing xRDP server..."
    log_warning "This is experimental - xRDP in proot hasn't been extensively tested"
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Install xRDP and dependencies
    apt-get install -y \
        xrdp \
        xorgxrdp \
        || {
            log_error "xRDP installation failed"
            log_info "You may want to use VNC instead (complete_install.sh)"
            return 1
        }
    
    log_success "xRDP server installed ✓"
}

install_utilities() {
    log_info "Installing essential utilities and applications..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # First install curl and wget - needed for other installations
    apt-get install -y \
        curl \
        wget \
        ca-certificates \
        gnupg \
        || {
            log_error "Failed to install basic utilities"
            return 1
        }
    
    # Then install everything else (NO Firefox - Brave only)
    apt-get install -y \
        nano \
        vim \
        git \
        htop \
        neofetch \
        net-tools \
        iputils-ping \
        gedit \
        file-roller \
        fonts-dejavu \
        fonts-liberation \
        adwaita-icon-theme \
        gnome-themes-extra \
        || {
            log_warning "Some utilities failed to install (continuing...)"
        }
    
    log_success "Utilities and applications installed ✓"
}

install_brave() {
    log_info "Installing Brave browser..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Add Brave repository
    if ! curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg; then
        log_warning "Failed to download Brave keyring"
        log_info "This might be a temporary network issue"
        return 1
    fi
    
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=arm64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    
    # Update and install
    log_info "Updating package lists for Brave..."
    if ! apt-get update; then
        log_warning "Failed to update Brave repository"
        return 1
    fi
    
    log_info "Installing Brave (this may take a few minutes)..."
    if ! apt-get install -y brave-browser; then
        log_warning "Brave browser installation failed"
        log_info "This is common on some devices/networks"
        return 1
    fi
    
    log_success "Brave browser installed ✓"
}

configure_brave() {
    log_info "Configuring Brave for proot environment..."
    
    if ! dpkg -s brave-browser &> /dev/null; then
        log_warning "Brave not installed, skipping configuration"
        return 0
    fi
    
    # Patch all Brave desktop files
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
    log_info "Setting Brave as default browser..."
    
    # update-alternatives
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200 2>/dev/null || true
    update-alternatives --set x-www-browser /usr/bin/brave-browser 2>/dev/null || true
    
    # xdg-settings
    export DISPLAY=:10
    xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || true
    
    # XFCE4 helpers.rc (proper exo format)
    mkdir -p /root/.config/xfce4
    cat > /root/.config/xfce4/helpers.rc <<'HELPERS'
WebBrowser=custom-WebBrowser

[custom-WebBrowser]
Icon=brave-browser
Type=X-XFCE-Helper
X-XFCE-Category=WebBrowser
X-XFCE-Commands=/usr/bin/brave-browser --no-sandbox --test-type --disable-dev-shm-usage
X-XFCE-CommandsWithParameter=/usr/bin/brave-browser --no-sandbox --test-type --disable-dev-shm-usage "%s"
HELPERS
    
    # mimeapps.list
    mkdir -p /root/.config /root/.local/share/applications
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
MIMEAPPS
    
    log_success "Brave configured as default browser ✓"
}

configure_rdp() {
    log_info "Configuring xRDP server for XFCE4..."
    
    # Neutralize systemd service (incompatible with proot)
    log_info "Disabling systemd services (incompatible with proot)..."
    
    # Prevent xrdp from trying to use systemd
    if [ -f /var/lib/dpkg/info/xrdp.postinst ]; then
        sed -i 's|systemctl|true|g' /var/lib/dpkg/info/xrdp.postinst 2>/dev/null || true
    fi
    
    # Create xRDP session configuration for XFCE
    mkdir -p /etc/xrdp
    
    cat > /etc/xrdp/startwm.sh <<'STARTWM'
#!/bin/sh
# xRDP session startup script for XFCE4

# Unset session manager
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS

# Start D-Bus
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Set display
if [ -z "$DISPLAY" ]; then
    export DISPLAY=:10
fi

# Disable accessibility bus
export NO_AT_BRIDGE=1

# Start XFCE4
exec startxfce4
STARTWM
    
    chmod +x /etc/xrdp/startwm.sh
    log_success "xRDP session script created ✓"
    
    # Configure xRDP settings
    cat > /etc/xrdp/xrdp.ini <<'XRDPINI'
[Globals]
ini_version=1
fork=true
port=3389
tcp_nodelay=true
tcp_keepalive=true
security_layer=negotiate
crypt_level=high
certificate=
key_file=
ssl_protocols=TLSv1.2, TLSv1.3
bitmap_cache=true
bitmap_compression=true
max_bpp=32
blue=009cb5
grey=dedede

[Xorg]
name=Xorg
lib=libxup.so
username=ask
password=ask
ip=127.0.0.1
port=-1
code=20
XRDPINI
    
    log_success "xRDP configured ✓"
    
    # Create manual start script since systemd won't work
    cat > /usr/local/bin/start-xrdp <<'STARTRDP'
#!/bin/bash
# Manual xRDP starter for proot

echo "Starting xRDP server..."

# Create necessary directories
mkdir -p /var/run/xrdp
mkdir -p /var/log/xrdp

# Start xrdp-sesman (session manager)
/usr/sbin/xrdp-sesman --nodaemon &
SESMAN_PID=$!

# Give it a moment to start
sleep 2

# Start xrdp
/usr/sbin/xrdp --nodaemon &
XRDP_PID=$!

echo "xRDP started!"
echo "  xrdp-sesman PID: $SESMAN_PID"
echo "  xrdp PID: $XRDP_PID"
echo ""
echo "Connect to: localhost:3389"
echo "Use Microsoft Remote Desktop app"
echo ""
echo "To stop: kill $XRDP_PID $SESMAN_PID"

# Keep script running
wait
STARTRDP
    
    chmod +x /usr/local/bin/start-xrdp
    log_success "xRDP start script created ✓"
}

customize_xfce() {
    log_info "Customizing XFCE4 for better user experience..."
    
    mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
    
    # Configure XFCE4 panel
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-panel.xml <<'PANEL'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-panel" version="1.0">
  <property name="configver" type="int" value="2"/>
  <property name="panels" type="array">
    <value type="int" value="1"/>
    <property name="dark-mode" type="bool" value="false"/>
    <property name="panel-1" type="empty">
      <property name="position" type="string" value="p=6;x=0;y=0"/>
      <property name="length" type="uint" value="100"/>
      <property name="position-locked" type="bool" value="true"/>
      <property name="icon-size" type="uint" value="16"/>
      <property name="size" type="uint" value="26"/>
      <property name="plugin-ids" type="array">
        <value type="int" value="1"/>
        <value type="int" value="2"/>
        <value type="int" value="3"/>
        <value type="int" value="4"/>
        <value type="int" value="5"/>
        <value type="int" value="6"/>
        <value type="int" value="7"/>
        <value type="int" value="8"/>
      </property>
    </property>
  </property>
  <property name="plugins" type="empty">
    <property name="plugin-1" type="string" value="whiskermenu"/>
    <property name="plugin-2" type="string" value="tasklist">
      <property name="grouping" type="uint" value="1"/>
    </property>
    <property name="plugin-3" type="string" value="separator">
      <property name="expand" type="bool" value="true"/>
      <property name="style" type="uint" value="0"/>
    </property>
    <property name="plugin-4" type="string" value="systray">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-5" type="string" value="statusnotifier">
      <property name="square-icons" type="bool" value="true"/>
    </property>
    <property name="plugin-6" type="string" value="pulseaudio">
      <property name="enable-keyboard-shortcuts" type="bool" value="true"/>
    </property>
    <property name="plugin-7" type="string" value="clock">
      <property name="digital-format" type="string" value="%I:%M %p"/>
    </property>
    <property name="plugin-8" type="string" value="actions"/>
  </property>
</channel>
PANEL
    
    # Set desktop wallpaper
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfce4-desktop.xml <<'DESKTOP'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfce4-desktop" version="1.0">
  <property name="backdrop" type="empty">
    <property name="screen0" type="empty">
      <property name="monitorVNC-0" type="empty">
        <property name="workspace0" type="empty">
          <property name="color-style" type="int" value="0"/>
          <property name="image-style" type="int" value="5"/>
          <property name="rgba1" type="array">
            <value type="double" value="0.101961"/>
            <value type="double" value="0.141176"/>
            <value type="double" value="0.231373"/>
            <value type="double" value="1.000000"/>
          </property>
          <property name="rgba2" type="array">
            <value type="double" value="0.160784"/>
            <value type="double" value="0.203922"/>
            <value type="double" value="0.321569"/>
            <value type="double" value="1.000000"/>
          </property>
        </property>
      </property>
    </property>
  </property>
</channel>
DESKTOP

    # Window manager theme
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xfwm4.xml <<'XFWM4'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xfwm4" version="1.0">
  <property name="general" type="empty">
    <property name="theme" type="string" value="Default"/>
    <property name="button_layout" type="string" value="O|SHMC"/>
    <property name="button_offset" type="int" value="0"/>
    <property name="button_spacing" type="int" value="0"/>
    <property name="click_to_focus" type="bool" value="true"/>
    <property name="focus_delay" type="int" value="250"/>
    <property name="focus_hint" type="bool" value="true"/>
    <property name="focus_new" type="bool" value="true"/>
    <property name="raise_delay" type="int" value="250"/>
    <property name="raise_on_click" type="bool" value="true"/>
    <property name="raise_on_focus" type="bool" value="false"/>
    <property name="show_popup_shadow" type="bool" value="true"/>
    <property name="snap_to_border" type="bool" value="true"/>
    <property name="snap_to_windows" type="bool" value="false"/>
    <property name="snap_width" type="int" value="10"/>
    <property name="titleless_maximize" type="bool" value="false"/>
    <property name="title_alignment" type="string" value="center"/>
    <property name="title_font" type="string" value="Sans Bold 9"/>
    <property name="workspace_count" type="int" value="4"/>
  </property>
</channel>
XFWM4

    # Mouse cursor theme
    cat > /root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml <<'XSETTINGS'
<?xml version="1.0" encoding="UTF-8"?>
<channel name="xsettings" version="1.0">
  <property name="Gtk" type="empty">
    <property name="CursorThemeName" type="string" value="Adwaita"/>
    <property name="CursorThemeSize" type="int" value="24"/>
  </property>
</channel>
XSETTINGS
    
    log_success "XFCE4 customized ✓"
}

create_desktop_content() {
    log_info "Creating desktop shortcuts and documentation..."
    
    mkdir -p /root/Desktop
    
    # Create comprehensive README
    cat > /root/Desktop/README.txt <<'README'
╔════════════════════════════════════════╗
║   Welcome to Ubuntu on Termux!        ║
║      XFCE4 Desktop - RDP Edition      ║
╚════════════════════════════════════════╝

Your desktop environment with xRDP is ready!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  QUICK START GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. START RDP SERVER
   In the terminal, run:
   $ start-xrdp

   Or manually:
   $ /usr/sbin/xrdp-sesman &
   $ /usr/sbin/xrdp &

2. CONNECT WITH RDP CLIENT
   • Download "Microsoft Remote Desktop" app
   • Add new connection:
     - PC name: localhost:3389
     - Username: root
     - Password: (your Ubuntu password)
   • Connect!

3. STOP RDP SERVER
   $ pkill xrdp
   $ pkill xrdp-sesman

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RDP VS VNC
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

RDP Advantages:
• Better image quality and compression
• Lower bandwidth usage
• Better clipboard integration
• Superior performance on slow connections
• Microsoft Remote Desktop app (excellent)

RDP Port: 3389 (default)
VNC Port: 5901 (if you use VNC instead)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DESKTOP FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Applications Menu: Click the icon in top-left corner
• File Manager: Thunar (fast and lightweight)
• Web Browser: Brave (pre-configured for proot)
• Terminal: XFCE4 Terminal
• Text Editor: gedit

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  USEFUL COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

System Management:
$ apt update              # Update package lists
$ apt upgrade             # Upgrade installed packages
$ apt install <package>   # Install new software

RDP Management:
$ start-xrdp              # Start RDP server
$ pkill xrdp              # Stop RDP
$ netstat -tlnp | grep 3389   # Check if RDP is running

System Info:
$ neofetch                # Show system information
$ htop                    # System monitor

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Can't connect to RDP?
1. Check if xrdp is running: ps aux | grep xrdp
2. Check port: netstat -tlnp | grep 3389
3. Try restarting: pkill xrdp; start-xrdp

Black screen?
• Wait 10-15 seconds after connecting
• Try disconnecting and reconnecting
• Check ~/.xsession-errors for errors

Slow performance?
• RDP should be faster than VNC
• Check your network connection
• Try lower color depth in RDP client settings

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RECOMMENDED RDP CLIENTS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Android/iOS:
• Microsoft Remote Desktop (Best)
• RD Client (Alternative)

Settings to use:
• Resolution: 1920x1080 or lower
• Color depth: 32-bit
• Compression: Enabled

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enjoy your Ubuntu RDP desktop environment!

Note: This is EXPERIMENTAL. If RDP doesn't work well,
use the VNC version (complete_install.sh) instead.
README
    
    # Create start RDP script
    cat > /root/Desktop/start-rdp.sh <<'RDPSCRIPT'
#!/bin/bash
# Start RDP Server

echo "╔════════════════════════════════════════╗"
echo "║       Starting xRDP Server...         ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Kill any existing sessions
pkill xrdp 2>/dev/null
pkill xrdp-sesman 2>/dev/null
sleep 1

# Create directories
mkdir -p /var/run/xrdp
mkdir -p /var/log/xrdp

# Start session manager
echo "Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman &
sleep 2

# Start xrdp
echo "Starting xrdp..."
/usr/sbin/xrdp &
sleep 2

echo ""
echo "✓ RDP Server started!"
echo ""
echo "Connect to: localhost:3389"
echo "Use: Microsoft Remote Desktop app"
echo ""
echo "To stop: pkill xrdp; pkill xrdp-sesman"
echo ""
RDPSCRIPT
    
    chmod +x /root/Desktop/start-rdp.sh
    
    # Create system info script
    cat > /root/Desktop/system-info.sh <<'SYSINFO'
#!/bin/bash
# Display System Information

clear
echo "╔════════════════════════════════════════╗"
echo "║         System Information            ║"
echo "╚════════════════════════════════════════╝"
echo ""

if command -v neofetch &> /dev/null; then
    neofetch
else
    echo "OS: $(lsb_release -d | cut -f2)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo ""
    echo "Memory Usage:"
    free -h
    echo ""
    echo "Disk Usage:"
    df -h /
fi

echo ""
echo "RDP Status:"
if pgrep xrdp > /dev/null; then
    echo "  ✓ xRDP is running"
    echo "  Port: 3389"
else
    echo "  ✗ xRDP is not running"
    echo "  Start with: start-xrdp"
fi

echo ""
echo "Press Enter to close..."
read
SYSINFO
    
    chmod +x /root/Desktop/system-info.sh
    
    log_success "Desktop content created ✓"
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
    echo -e "║                                        ║"
    echo -e "║    Installation Complete! 🎉           ║"
    echo -e "║          RDP EXPERIMENTAL              ║"
    echo -e "║                                        ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  What's Installed${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  ✓ XFCE4 Desktop Environment"
    echo "  ✓ xRDP Server (port 3389)"
    
    if dpkg -s brave-browser &> /dev/null; then
        echo "  ✓ Brave Browser (default)"
    else
        echo "  ✗ Brave Browser installation failed"
    fi
    
    echo "  ✓ File Manager (Thunar)"
    echo "  ✓ Text Editor (gedit)"
    echo "  ✓ Terminal Emulator"
    echo "  ✓ Essential Utilities"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Next Steps${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "  ${YELLOW}1.${NC} Start RDP server:"
    echo -e "     ${GREEN}start-xrdp${NC}"
    echo ""
    echo -e "  ${YELLOW}2.${NC} Download Microsoft Remote Desktop app:"
    echo "     • Android: Play Store"
    echo "     • iOS: App Store"
    echo ""
    echo -e "  ${YELLOW}3.${NC} Connect to:"
    echo -e "     ${GREEN}localhost:3389${NC}"
    echo "     Username: root"
    echo "     Password: (your password)"
    echo ""
    echo -e "  ${YELLOW}4.${NC} To stop RDP:"
    echo -e "     ${GREEN}pkill xrdp; pkill xrdp-sesman${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Important Notes${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo -e "${YELLOW}⚠ EXPERIMENTAL:${NC} xRDP in proot is untested"
    echo "  • If it doesn't work well, use VNC instead"
    echo "  • RDP should give better quality/performance"
    echo "  • Check Desktop/README.txt for troubleshooting"
    echo ""
    echo -e "${BLUE}RDP Advantages:${NC}"
    echo "  • Better compression and image quality"
    echo "  • Lower bandwidth usage"
    echo "  • Better clipboard integration"
    echo "  • Superior performance"
    echo ""
    echo -e "${GREEN}Test it out and let us know how it performs!${NC}"
    echo ""
}

error_handler() {
    echo ""
    log_error "Installation encountered an error"
    log_info "Please check the output above for details"
    echo ""
    exit 1
}

# Set trap for errors
trap error_handler ERR

# --- MAIN EXECUTION ---

main() {
    banner
    show_features
    
    read -p "Ready to install? (y/N): " -n 1 -r
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
    fix_apt_sources
    
    if ! update_system; then
        log_error "Cannot proceed without package lists"
        log_info "Please check your internet connection and try again"
        exit 1
    fi
    
    install_desktop
    install_rdp
    install_utilities
    
    # Try to install Brave
    if install_brave; then
        configure_brave
    else
        log_warning "Continuing without Brave - you can install it later"
    fi
    
    configure_rdp
    customize_xfce
    create_desktop_content
    cleanup
    
    show_completion_message
}

# Run main function
main "$@"
