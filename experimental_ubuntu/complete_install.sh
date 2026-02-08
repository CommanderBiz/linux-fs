#!/bin/bash
# ============================================================================
# Ubuntu Commander v1.3 - Unified Desktop Installer
# ============================================================================
# Interactive installer with choice of:
#   Desktop: XFCE4 or MATE
#   Protocol: VNC, Termux:X11, or Both
# ============================================================================

set -e
set -u

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
DESKTOP_ENV=""
DISPLAY_PROTOCOL=""

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════════════════╗"
    echo "║      Ubuntu Commander - Desktop Installer v1.3    ║"
    echo "╚════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_menu() {
    banner
    echo -e "${CYAN}Choose Your Configuration:${NC}"
    echo ""
    echo -e "${YELLOW}Desktop Environments:${NC}"
    echo "  XFCE4: Lightweight, fast, proven stable"
    echo "  MATE:  Polished, classic GNOME 2 experience"
    echo ""
    echo -e "${YELLOW}Display Protocols:${NC}"
    echo "  VNC:        Universal, any VNC viewer"
    echo "  Termux:X11: Best performance (requires X11 app)"
    echo "  Both:       Maximum flexibility"
    echo ""
    echo -e "${GREEN}Quick Options:${NC}"
    echo "  ${GREEN}1)${NC} XFCE4 + VNC        (Recommended for beginners)"
    echo "  ${GREEN}2)${NC} XFCE4 + X11        (Best performance)"
    echo "  ${GREEN}3)${NC} XFCE4 + Both       (Maximum flexibility)"
    echo "  ${GREEN}4)${NC} MATE + VNC         (Classic look, universal)"
    echo "  ${GREEN}5)${NC} MATE + X11         (Classic look, best performance)"
    echo "  ${GREEN}6)${NC} MATE + Both        (Classic look, maximum flexibility)"
    echo "  ${YELLOW}7)${NC} Custom            (Choose each option)"
    echo "  ${RED}8)${NC} Exit"
    echo ""
}

choose_configuration() {
    while true; do
        show_menu
        read -p "Enter your choice [1-8]: " choice
        
        case $choice in
            1) DESKTOP_ENV="xfce"; DISPLAY_PROTOCOL="vnc"; break ;;
            2) DESKTOP_ENV="xfce"; DISPLAY_PROTOCOL="x11"; break ;;
            3) DESKTOP_ENV="xfce"; DISPLAY_PROTOCOL="both"; break ;;
            4) DESKTOP_ENV="mate"; DISPLAY_PROTOCOL="vnc"; break ;;
            5) DESKTOP_ENV="mate"; DISPLAY_PROTOCOL="x11"; break ;;
            6) DESKTOP_ENV="mate"; DISPLAY_PROTOCOL="both"; break ;;
            7) custom_configuration; break ;;
            8) log_info "Installation cancelled"; exit 0 ;;
            *) log_error "Invalid choice"; sleep 2 ;;
        esac
    done
}

custom_configuration() {
    # Choose desktop
    while true; do
        clear
        banner
        echo -e "${CYAN}Step 1: Choose Desktop Environment${NC}"
        echo ""
        echo "  ${GREEN}1)${NC} XFCE4 - Lightweight and fast"
        echo "  ${GREEN}2)${NC} MATE  - Classic and polished"
        echo ""
        read -p "Choice [1-2]: " de_choice
        
        case $de_choice in
            1) DESKTOP_ENV="xfce"; break ;;
            2) DESKTOP_ENV="mate"; break ;;
            *) log_error "Invalid choice"; sleep 1 ;;
        esac
    done
    
    # Choose protocol
    while true; do
        clear
        banner
        echo -e "${CYAN}Desktop: ${GREEN}${DESKTOP_ENV^^}${NC}"
        echo ""
        echo -e "${CYAN}Step 2: Choose Display Protocol${NC}"
        echo ""
        echo "  ${GREEN}1)${NC} VNC only        - Universal compatibility"
        echo "  ${GREEN}2)${NC} Termux:X11 only - Best performance"
        echo "  ${GREEN}3)${NC} Both            - Install both options"
        echo ""
        read -p "Choice [1-3]: " proto_choice
        
        case $proto_choice in
            1) DISPLAY_PROTOCOL="vnc"; break ;;
            2) DISPLAY_PROTOCOL="x11"; break ;;
            3) DISPLAY_PROTOCOL="both"; break ;;
            *) log_error "Invalid choice"; sleep 1 ;;
        esac
    done
}

confirm_installation() {
    clear
    banner
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}           Installation Summary                     ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  Desktop Environment: ${GREEN}${DESKTOP_ENV^^}${NC}"
    echo -e "  Display Protocol:    ${GREEN}${DISPLAY_PROTOCOL^^}${NC}"
    echo ""
    
    local size="2-2.5GB"
    local time="20-30 min"
    [ "$DESKTOP_ENV" = "mate" ] && size="2.5-3GB" && time="25-35 min"
    [ "$DISPLAY_PROTOCOL" = "both" ] && size="${size}+200MB"
    
    echo -e "${YELLOW}Requirements:${NC}"
    echo "  • Space: ~$size"
    echo "  • Time: ~$time"
    echo "  • Internet required"
    echo ""
    
    read -p "Proceed? (y/N): " -n 1 -r
    echo
    echo ""
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Installation cancelled"
        exit 0
    fi
    
    log_success "Starting installation..."
}

# === SETUP FUNCTIONS ===

setup_system() {
    log_info "Configuring system..."
    
    # DNS
    cat > /etc/resolv.conf <<DNS
nameserver 8.8.8.8
nameserver 8.8.4.4
DNS
    
    # APT sources (HTTP for proot)
    cat > /etc/apt/sources.list <<SOURCES
deb http://ports.ubuntu.com/ubuntu-ports/ noble main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-updates main restricted universe multiverse
deb http://ports.ubuntu.com/ubuntu-ports/ noble-security main restricted universe multiverse
SOURCES
    
    # APT config
    cat > /etc/apt/apt.conf.d/99-proot <<APT
Acquire::http::Pipeline-Depth "0";
Acquire::http::No-Cache "true";
Acquire::BrokenProxy "true";
APT::Get::Assume-Yes "true";
APT::Install-Recommends "false";
APT::Install-Suggests "false";
APT
    
    export DEBIAN_FRONTEND=noninteractive
    
    log_info "Updating packages..."
    apt-get update || { log_error "Update failed"; return 1; }
    log_success "System configured ✓"
}

install_base() {
    log_info "Installing base utilities..."
    apt-get install -y \
        curl wget ca-certificates gnupg \
        nano vim git htop neofetch \
        net-tools iputils-ping \
        gedit file-roller \
        fonts-dejavu fonts-liberation \
        adwaita-icon-theme gnome-themes-extra \
        dbus-x11 \
        || return 1
    log_success "Base installed ✓"
}

install_xfce4() {
    log_info "Installing XFCE4 desktop..."
    apt-get install -y \
        xfce4 xfce4-goodies xfce4-terminal \
        thunar xfce4-whiskermenu-plugin \
        xfce4-clipman-plugin xfce4-systemload-plugin \
        || return 1
    log_success "XFCE4 installed ✓"
}

install_mate() {
    log_info "Installing MATE desktop..."
    apt-get install -y \
        mate-desktop-environment-core \
        mate-terminal caja pluma \
        mate-system-monitor mate-utils \
        mate-panel mate-session-manager \
        || return 1
    log_success "MATE installed ✓"
}

install_vnc() {
    log_info "Installing VNC server..."
    apt-get install -y \
        tigervnc-standalone-server \
        tigervnc-common \
        tigervnc-tools \
        || return 1
    log_success "VNC installed ✓"
}

configure_vnc() {
    log_info "Configuring VNC..."
    mkdir -p /root/.vnc
    
    # VNC startup for XFCE
    if [ "$DESKTOP_ENV" = "xfce" ]; then
        cat > /root/.vnc/xstartup <<'VNC'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
eval $(dbus-launch --sh-syntax)
exec startxfce4
VNC
    else
        # VNC startup for MATE
        cat > /root/.vnc/xstartup <<'VNC'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
eval $(dbus-launch --sh-syntax)
exec mate-session
VNC
    fi
    
    chmod +x /root/.vnc/xstartup
    
    cat > /root/.vnc/config <<CFG
geometry=1920x1080
depth=24
dpi=96
CFG
    
    log_success "VNC configured ✓"
}

configure_x11() {
    log_info "Configuring Termux:X11..."
    
    # X11 startup for XFCE
    if [ "$DESKTOP_ENV" = "xfce" ]; then
        cat > /usr/local/bin/start-x11 <<'X11'
#!/bin/bash
# Start XFCE4 with Termux:X11

# Kill any existing sessions
pkill -f startxfce4 2>/dev/null

# Wait for X11 to be ready
echo "Waiting for Termux:X11..."
for i in {1..10}; do
    if [ -e /tmp/.X11-unix/X0 ]; then
        echo "X11 display detected!"
        break
    fi
    sleep 1
done

# Set display
export DISPLAY=:0
export XDG_RUNTIME_DIR=${TMPDIR}
export PULSE_SERVER=127.0.0.1

# Start D-Bus if not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Launch XFCE4
echo "Starting XFCE4..."
startxfce4 &

echo ""
echo "XFCE4 started!"
echo "Check the Termux:X11 app for your desktop"
echo ""
X11
    else
        # X11 startup for MATE
        cat > /usr/local/bin/start-x11 <<'X11'
#!/bin/bash
# Start MATE with Termux:X11

# Kill any existing sessions
pkill -f mate-session 2>/dev/null

# Wait for X11 to be ready
echo "Waiting for Termux:X11..."
for i in {1..10}; do
    if [ -e /tmp/.X11-unix/X0 ]; then
        echo "X11 display detected!"
        break
    fi
    sleep 1
done

# Set display
export DISPLAY=:0
export XDG_RUNTIME_DIR=${TMPDIR}
export PULSE_SERVER=127.0.0.1

# Start D-Bus if not running
if [ -z "$DBUS_SESSION_BUS_ADDRESS" ]; then
    eval $(dbus-launch --sh-syntax --exit-with-session)
    export DBUS_SESSION_BUS_ADDRESS
fi

# Launch MATE
echo "Starting MATE..."
mate-session &

echo ""
echo "MATE started!"
echo "Check the Termux:X11 app for your desktop"
echo ""
X11
    fi
    
    chmod +x /usr/local/bin/start-x11
    
    log_success "X11 configured ✓"
}

install_brave() {
    log_info "Installing Brave..."
    
    curl -fsSLo /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg || return 1
    
    echo "deb [signed-by=/usr/share/keyrings/brave-browser-archive-keyring.gpg arch=arm64] https://brave-browser-apt-release.s3.brave.com/ stable main" \
        > /etc/apt/sources.list.d/brave-browser-release.list
    
    apt-get update
    apt-get install -y brave-browser || return 1
    
    # Patch for proot
    find /usr/share/applications -name "brave-browser*.desktop" -exec \
        sed -i 's|\(Exec=[^ ]*brave-browser[^ ]*\)|\1 --no-sandbox --test-type --disable-dev-shm-usage|g' {} \;
    
    log_success "Brave installed ✓"
}

create_desktop_content() {
    log_info "Creating desktop shortcuts..."
    mkdir -p /root/Desktop
    
    # Start scripts based on protocol
    if [ "$DISPLAY_PROTOCOL" = "vnc" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        cat > /root/Desktop/start-vnc.sh <<'VNCS'
#!/bin/bash
vncserver -kill :1 2>/dev/null
vncserver :1 -geometry 1920x1080 -depth 24
echo "VNC started! Connect to localhost:5901"
VNCS
        chmod +x /root/Desktop/start-vnc.sh
    fi
    
    if [ "$DISPLAY_PROTOCOL" = "x11" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        cat > /root/Desktop/start-x11.sh <<'X11S'
#!/bin/bash
echo "Starting X11..."
echo "Launch Termux:X11 app now, then run:"
echo "  start-x11"
X11S
        chmod +x /root/Desktop/start-x11.sh
    fi
    
    # README
    cat > /root/Desktop/README.txt <<README
╔════════════════════════════════════════╗
║   Ubuntu Commander v1.3                ║
║   Desktop: ${DESKTOP_ENV^^}                       ║
║   Protocol: ${DISPLAY_PROTOCOL^^}                    ║
╚════════════════════════════════════════╝

QUICK START:
README

    if [ "$DISPLAY_PROTOCOL" = "vnc" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        cat >> /root/Desktop/README.txt <<README

VNC:
  1. Run: vncserver
  2. Connect to: localhost:5901
  3. Stop: vncserver -kill :1
README
    fi
    
    if [ "$DISPLAY_PROTOCOL" = "x11" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        cat >> /root/Desktop/README.txt <<README

Termux:X11:
  1. In Termux: termux-x11 :0 &
  2. Launch Termux:X11 app
  3. In Ubuntu: start-x11
README
    fi
    
    log_success "Desktop content created ✓"
}

set_vnc_password() {
    if [ "$DISPLAY_PROTOCOL" = "vnc" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        echo ""
        log_info "Set VNC password..."
        vncpasswd || log_warning "VNC password setup skipped"
    fi
}

# === MAIN INSTALLATION ===

main() {
    banner
    choose_configuration
    confirm_installation
    
    setup_system || { log_error "Setup failed"; exit 1; }
    install_base || { log_error "Base install failed"; exit 1; }
    
    # Install chosen desktop
    if [ "$DESKTOP_ENV" = "xfce" ]; then
        install_xfce4 || { log_error "XFCE4 install failed"; exit 1; }
    else
        install_mate || { log_error "MATE install failed"; exit 1; }
    fi
    
    # Install chosen protocols
    if [ "$DISPLAY_PROTOCOL" = "vnc" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        install_vnc
        configure_vnc
    fi
    
    if [ "$DISPLAY_PROTOCOL" = "x11" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        configure_x11
    fi
    
    install_brave || log_warning "Brave install failed, continuing..."
    
    create_desktop_content
    set_vnc_password
    
    # Cleanup
    apt-get autoremove -y > /dev/null 2>&1
    apt-get clean > /dev/null 2>&1
    
    # Success message
    clear
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║         Installation Complete! 🎉                  ║${NC}"
    echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "Desktop: ${GREEN}${DESKTOP_ENV^^}${NC}"
    echo -e "Protocol: ${GREEN}${DISPLAY_PROTOCOL^^}${NC}"
    echo ""
    
    if [ "$DISPLAY_PROTOCOL" = "vnc" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        echo -e "${BLUE}VNC:${NC} vncserver → localhost:5901"
    fi
    if [ "$DISPLAY_PROTOCOL" = "x11" ] || [ "$DISPLAY_PROTOCOL" = "both" ]; then
        echo -e "${BLUE}X11:${NC} start-x11 (after launching Termux:X11 app)"
    fi
    echo ""
    echo -e "${GREEN}Check /root/Desktop/README.txt for details!${NC}"
    echo ""
}

main "$@"
