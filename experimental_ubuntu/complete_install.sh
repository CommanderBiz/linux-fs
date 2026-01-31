#!/bin/bash
# ============================================================================
# Ubuntu Desktop Environment Installer
# ============================================================================
# This script installs XFCE4 desktop environment, VNC server, and Brave
# browser in the Ubuntu rootfs running under Termux.
# Optimized for ARM64 Ubuntu Noble - Tested and Reliable.
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
    echo "║      XFCE4 + VNC + Brave Browser      ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_features() {
    echo -e "${CYAN}What You'll Get:${NC}"
    echo ""
    echo "  ✓ XFCE4 Desktop - Fast, lightweight, beautiful"
    echo "  ✓ TigerVNC Server - Remote desktop access"
    echo "  ✓ Brave Browser - Privacy-focused web browser"
    echo "  ✓ Essential Apps - File manager, terminal, text editor"
    echo "  ✓ Customized Setup - Pre-configured for Termux/Android"
    echo ""
    echo -e "${BLUE}Installation Details:${NC}"
    echo "  • Time Required: 20-40 minutes"
    echo "  • Space Needed: ~2GB"
    echo "  • Internet Required: Yes (for downloading packages)"
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

install_vnc() {
    log_info "Installing VNC server..."
    
    export DEBIAN_FRONTEND=noninteractive
    
    # Install VNC server and tools (tools package has vncpasswd)
    apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-common \
        tigervnc-tools \
        || {
            log_error "VNC installation failed"
            return 1
        }
    
    log_success "VNC server installed ✓"
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
    
    # Then install everything else
    apt-get install -y \
        nano \
        vim \
        git \
        htop \
        neofetch \
        net-tools \
        iputils-ping \
        firefox \
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
        log_info "Firefox will be configured as fallback browser"
        return 1
    fi
    
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=arm64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    
    # Update and install
    log_info "Updating package lists for Brave..."
    if ! apt-get update; then
        log_warning "Failed to update Brave repository"
        log_info "Using Firefox as browser instead"
        return 1
    fi
    
    log_info "Installing Brave (this may take a few minutes)..."
    if ! apt-get install -y brave-browser; then
        log_warning "Brave browser installation failed"
        log_info "This is common on some devices/networks"
        log_info "Firefox is already installed and will be configured"
        return 1
    fi
    
    log_success "Brave browser installed ✓"
}

configure_brave() {
    log_info "Configuring Brave for proot environment..."
    
    if ! dpkg -s brave-browser &> /dev/null; then
        log_info "Brave not installed, Firefox will be your default browser"
        configure_firefox
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
    
    # Set as default browser - Multiple methods for reliability
    log_info "Setting Brave as default browser..."
    
    # Method 1: update-alternatives
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/brave-browser 200 2>/dev/null || true
    update-alternatives --set x-www-browser /usr/bin/brave-browser 2>/dev/null || true
    
    # Method 2: xdg-settings
    xdg-settings set default-web-browser brave-browser.desktop 2>/dev/null || true
    
    # Method 3: XFCE4 helpers.rc (proper format with custom command)
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
    
    # Method 4: mimeapps.list
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

configure_firefox() {
    log_info "Configuring Firefox as default browser..."
    
    # Set Firefox as default
    update-alternatives --install /usr/bin/x-www-browser x-www-browser /usr/bin/firefox 100 2>/dev/null || true
    update-alternatives --set x-www-browser /usr/bin/firefox 2>/dev/null || true
    
    # XFCE4 helpers
    mkdir -p /root/.config/xfce4
    cat > /root/.config/xfce4/helpers.rc <<HELPERS
[Desktop Entry]
WebBrowser=firefox
HELPERS
    
    # mimeapps.list for Firefox
    mkdir -p /root/.config /root/.local/share/applications
    cat > /root/.config/mimeapps.list <<MIMEAPPS
[Default Applications]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
x-scheme-handler/about=firefox.desktop
x-scheme-handler/unknown=firefox.desktop

[Added Associations]
text/html=firefox.desktop
x-scheme-handler/http=firefox.desktop
x-scheme-handler/https=firefox.desktop
MIMEAPPS
    
    log_success "Firefox configured as default browser ✓"
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
exec startxfce4
XSTARTUP
    
    chmod +x /root/.vnc/xstartup
    log_success "VNC startup script created ✓"
    
    # Create VNC config with high resolution
    cat > /root/.vnc/config <<CONFIG
geometry=1920x1080
depth=24
dpi=96
localhost=no
alwaysshared
CONFIG
    
    log_success "VNC configured for 1920x1080 resolution ✓"
}

customize_xfce() {
    log_info "Customizing XFCE4 for better user experience..."
    
    mkdir -p /root/.config/xfce4/xfconf/xfce-perchannel-xml
    
    # Configure XFCE4 panel for better layout
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
    
    # Set nice default wallpaper (XFCE's default blue)
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

    # Enable nice window manager theme
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

    # Set nice mouse cursor theme
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

setup_vnc_password() {
    echo ""
    log_info "Setting up VNC password..."
    log_warning "You will be prompted to enter a password for VNC access"
    echo ""
    
    # Check if vncpasswd exists
    if ! command -v vncpasswd &> /dev/null; then
        log_error "vncpasswd not found - VNC package may not have installed correctly"
        log_warning "Try running this manually after installation:"
        echo "  apt install tigervnc-standalone-server tigervnc-xorg-extension"
        echo "  vncpasswd"
        return 1
    fi
    
    if vncpasswd; then
        log_success "VNC password set ✓"
    else
        log_error "Failed to set VNC password"
        log_warning "You can set it manually later with: vncpasswd"
        return 1
    fi
}

create_desktop_content() {
    log_info "Creating desktop shortcuts and documentation..."
    
    mkdir -p /root/Desktop
    
    # Create comprehensive README
    cat > /root/Desktop/README.txt <<'README'
╔════════════════════════════════════════╗
║   Welcome to Ubuntu on Termux!        ║
║        XFCE4 Desktop Edition          ║
╚════════════════════════════════════════╝

Your desktop environment is ready to use!

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  QUICK START GUIDE
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

1. START VNC SERVER
   In the terminal, run:
   $ vncserver

2. CONNECT WITH VNC VIEWER
   • Open your VNC viewer app
   • Connect to: localhost:5901
   • Enter the password you set

3. STOP VNC SERVER
   $ vncserver -kill :1

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  DESKTOP FEATURES
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Applications Menu: Click the icon in top-left corner
• File Manager: Thunar (fast and lightweight)
• Web Browser: Brave or Firefox (pre-configured)
• Terminal: XFCE4 Terminal (keyboard shortcut ready)
• Text Editor: gedit (simple and clean)

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  USEFUL COMMANDS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

System Management:
$ apt update              # Update package lists
$ apt upgrade             # Upgrade installed packages
$ apt install <package>   # Install new software
$ apt search <keyword>    # Search for packages

VNC Management:
$ vncserver                     # Start VNC
$ vncserver -list               # List sessions
$ vncserver -kill :1            # Stop display :1
$ vncserver -geometry 1600x900  # Custom resolution

System Info:
$ neofetch                # Show system information
$ htop                    # System monitor
$ df -h                   # Disk space
$ free -h                 # Memory usage

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  CUSTOMIZATION
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Appearance:
• Settings → Appearance → Choose theme and icons
• Settings → Window Manager → Customize window borders
• Right-click desktop → Desktop Settings → Wallpaper

Panel:
• Right-click panel → Panel → Panel Preferences
• Add/remove items, change position
• Multiple panels supported

Keyboard Shortcuts:
• Settings → Keyboard → Application Shortcuts
• Add custom shortcuts for your favorite apps

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  RECOMMENDED VNC SETTINGS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

For Best Performance:
• Resolution: 1600x900 or 1920x1080
• Color Depth: 24-bit
• Compression: Medium

Recommended VNC Viewers:
• AVNC (F-Droid) - Best for Termux
• RealVNC Viewer (Google Play)
• bVNC (Google Play) - Feature-rich

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TROUBLESHOOTING
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Black screen in VNC?
$ chmod +x ~/.vnc/xstartup
$ vncserver -kill :*
$ vncserver

Slow performance?
$ vncserver -geometry 1280x720  # Lower resolution
• Close unused applications
• Disable compositor in Settings → Window Manager Tweaks

Browser won't start?
• Brave: Already configured with --no-sandbox
• Firefox: Alternative browser (pre-installed)
• Check: Settings → Default Applications

DNS not working?
$ echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  TIPS & TRICKS
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

• Use Whisker Menu for better app search
• Pin favorite apps to the panel for quick access
• Enable compositor for smooth animations
  (Settings → Window Manager Tweaks)
• Install additional themes:
  $ apt install numix-gtk-theme papirus-icon-theme
• Add workspaces for better organization
• Use Clipman for clipboard history

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Enjoy your Ubuntu desktop environment on Android!

For more help, visit: https://docs.xfce.org/
README
    
    # Create start VNC script
    cat > /root/Desktop/start-vnc.sh <<'VNCSCRIPT'
#!/bin/bash
# Start VNC Server

echo "╔════════════════════════════════════════╗"
echo "║       Starting VNC Server...          ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Kill any existing VNC sessions first
vncserver -kill :1 2>/dev/null

# Start with explicit high resolution
vncserver :1 -geometry 1920x1080 -depth 24

echo ""
echo "✓ VNC Server started!"
echo ""
echo "Resolution: 1920x1080"
echo "Connect to: localhost:5901"
echo ""
echo "To stop VNC: vncserver -kill :1"
echo ""
VNCSCRIPT
    
    chmod +x /root/Desktop/start-vnc.sh
    
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
    echo -e "║                                        ║"
    echo -e "╚════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  What's Installed${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  ✓ XFCE4 Desktop Environment"
    echo "  ✓ TigerVNC Server"
    
    # Check which browser is actually installed
    if dpkg -s brave-browser &> /dev/null; then
        echo "  ✓ Brave Browser (default)"
        echo "  ✓ Firefox (backup browser)"
    else
        echo "  ✓ Firefox (default browser)"
        echo "  ℹ Brave installation failed - Firefox configured instead"
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
    echo -e "  ${YELLOW}1.${NC} Start VNC server:"
    echo -e "     ${GREEN}vncserver${NC}"
    echo ""
    echo -e "  ${YELLOW}2.${NC} Open your VNC Viewer app and connect to:"
    echo -e "     ${GREEN}localhost:5901${NC}"
    echo ""
    echo -e "  ${YELLOW}3.${NC} When done, stop VNC:"
    echo -e "     ${GREEN}vncserver -kill :1${NC}"
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}  Quick Tips${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  • Check Desktop/README.txt for detailed guide"
    echo "  • Use Desktop/start-vnc.sh for easy VNC startup"
    echo "  • Recommended VNC apps: AVNC, RealVNC Viewer"
    echo "  • Default resolution: 1920x1080 (adjustable)"
    
    # Add note about Brave if it failed
    if ! dpkg -s brave-browser &> /dev/null; then
        echo ""
        echo -e "${YELLOW}  Note: Brave installation failed due to network/repo issues${NC}"
        echo "  You can try installing it later with:"
        echo "  apt install brave-browser"
    fi
    
    echo ""
    echo -e "${GREEN}Enjoy your new desktop environment!${NC}"
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
    install_vnc
    install_utilities
    
    # Try to install Brave, fall back to Firefox
    if install_brave; then
        configure_brave
    else
        log_info "Using Firefox as your web browser"
        configure_firefox
    fi
    
    configure_vnc
    customize_xfce
    setup_vnc_password
    create_desktop_content
    cleanup
    
    show_completion_message
}

# Run main function
main "$@"