#!/bin/bash
# ============================================================================
# Ubuntu Desktop Environment Chooser
# ============================================================================
# This script lets users choose between GNOME and XFCE desktop environments
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

banner() {
    clear
    echo -e "${CYAN}"
    echo "╔════════════════════════════════════════╗"
    echo "║  Ubuntu Desktop Environment Installer ║"
    echo "║            Choose Your DE              ║"
    echo "╚════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
}

show_comparison() {
    echo -e "${BLUE}Desktop Environment Comparison:${NC}"
    echo ""
    echo "┌─────────────┬──────────────┬──────────────┐"
    echo "│   Feature   │    GNOME     │     XFCE     │"
    echo "├─────────────┼──────────────┼──────────────┤"
    echo "│ Size        │ ~2.5-3 GB    │ ~1.5-2 GB    │"
    echo "│ RAM Usage   │ 600-800 MB   │ 300-400 MB   │"
    echo "│ Speed       │ Moderate     │ Fast         │"
    echo "│ Appearance  │ Modern       │ Traditional  │"
    echo "│ Features    │ Rich         │ Lightweight  │"
    echo "│ Experience  │ Ubuntu       │ Xubuntu      │"
    echo "└─────────────┴──────────────┴──────────────┘"
    echo ""
}

show_gnome_details() {
    echo -e "${GREEN}GNOME Desktop:${NC}"
    echo ""
    echo "✓ Modern, polished interface"
    echo "✓ Default Ubuntu desktop experience"
    echo "✓ Rich feature set with Extensions"
    echo "✓ Better touchscreen support"
    echo "✓ Integrated settings and tweaks"
    echo "✓ Activities overview"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "• 3GB+ free space"
    echo "• Modern Android device (2GB+ RAM)"
    echo "• Good performance recommended"
    echo ""
    echo -e "${BLUE}Best for:${NC}"
    echo "• Users wanting full Ubuntu experience"
    echo "• Modern devices with good specs"
    echo "• Those who prefer aesthetics"
    echo ""
}

show_xfce_details() {
    echo -e "${GREEN}XFCE Desktop:${NC}"
    echo ""
    echo "✓ Lightweight and fast"
    echo "✓ Lower resource usage"
    echo "✓ Traditional desktop layout"
    echo "✓ Highly customizable"
    echo "✓ Reliable and stable"
    echo "✓ Xubuntu experience"
    echo ""
    echo -e "${YELLOW}Requirements:${NC}"
    echo "• 2GB+ free space"
    echo "• Works on older devices"
    echo "• Lower RAM usage"
    echo ""
    echo -e "${BLUE}Best for:${NC}"
    echo "• Older or lower-spec devices"
    echo "• Users prioritizing performance"
    echo "• Those familiar with Windows-like layout"
    echo ""
}

check_available_space() {
    local available=$(df -h / | awk 'NR==2 {print $4}' | sed 's/G//' | cut -d. -f1)
    
    echo -e "${BLUE}Available Space:${NC} ${available}G"
    echo ""
    
    if [ "${available:-0}" -lt 2 ]; then
        log_warning "Less than 2GB free - both options may be tight"
        return 1
    elif [ "${available:-0}" -lt 3 ]; then
        log_warning "Less than 3GB free - GNOME might be tight"
        echo "  Recommendation: Choose XFCE for better fit"
        return 0
    else
        log_success "Plenty of space for either desktop"
        return 0
    fi
}

download_installer() {
    local choice=$1
    local script_name=""
    
    if [ "$choice" = "gnome" ]; then
        script_name="complete_install_gnome.sh"
    else
        script_name="complete_install_xfce.sh"
    fi
    
    # Check if script exists locally
    if [ -f "/root/$script_name" ]; then
        log_success "Found installer: $script_name"
        return 0
    fi
    
    log_info "Installer script not found locally"
    log_info "Expected: /root/$script_name"
    echo ""
    echo "This should have been included in your rootfs build."
    echo "You can download it manually from your repository."
    return 1
}

main() {
    banner
    
    show_comparison
    
    echo ""
    check_available_space
    echo ""
    
    echo -e "${CYAN}Which desktop environment would you like?${NC}"
    echo ""
    echo "  1) GNOME  - Modern Ubuntu experience (recommended for newer devices)"
    echo "  2) XFCE   - Lightweight Xubuntu experience (recommended for older devices)"
    echo "  3) Show detailed comparison"
    echo "  4) Cancel"
    echo ""
    
    read -p "Enter your choice [1-4]: " choice
    
    case $choice in
        1)
            echo ""
            show_gnome_details
            read -p "Install GNOME? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -f "/root/complete_install_gnome.sh" ]; then
                    log_success "Starting GNOME installation..."
                    exec /bin/bash /root/complete_install_gnome.sh
                else
                    log_warning "GNOME installer not found at /root/complete_install_gnome.sh"
                    echo ""
                    echo "Please ensure the file exists, or download it from:"
                    echo "https://github.com/YOUR_REPO/releases/latest/download/complete_install_gnome.sh"
                fi
            fi
            ;;
        2)
            echo ""
            show_xfce_details
            read -p "Install XFCE? (y/N): " confirm
            if [[ $confirm =~ ^[Yy]$ ]]; then
                if [ -f "/root/complete_install.sh" ] || [ -f "/root/complete_install_xfce.sh" ]; then
                    log_success "Starting XFCE installation..."
                    if [ -f "/root/complete_install_xfce.sh" ]; then
                        exec /bin/bash /root/complete_install_xfce.sh
                    else
                        exec /bin/bash /root/complete_install.sh
                    fi
                else
                    log_warning "XFCE installer not found"
                    echo ""
                    echo "Please ensure complete_install.sh exists in /root/"
                fi
            fi
            ;;
        3)
            clear
            banner
            show_gnome_details
            echo "═══════════════════════════════════════"
            echo ""
            show_xfce_details
            echo ""
            read -p "Press Enter to return to menu..." dummy
            exec $0
            ;;
        4)
            log_info "Installation cancelled"
            exit 0
            ;;
        *)
            log_warning "Invalid choice"
            sleep 2
            exec $0
            ;;
    esac
}

main "$@"
