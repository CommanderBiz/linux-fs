#!/bin/bash
# ============================================================================
# Dependency Diagnostic Script
# ============================================================================
# This script checks which dependencies are installed and provides detailed
# information about what's missing.
# ============================================================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo "========================================"
echo "  Dependency Diagnostic Tool"
echo "========================================"
echo ""

check_command() {
    local cmd="$1"
    local package="$2"
    
    if command -v "$cmd" &> /dev/null; then
        local version=$($cmd --version 2>&1 | head -1 || echo "installed")
        echo -e "${GREEN}✓${NC} $cmd (from $package) - $version"
        return 0
    else
        echo -e "${RED}✗${NC} $cmd (from $package) - NOT FOUND"
        return 1
    fi
}

check_file() {
    local file="$1"
    local package="$2"
    
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file (from $package) - EXISTS"
        return 0
    else
        echo -e "${RED}✗${NC} $file (from $package) - NOT FOUND"
        return 1
    fi
}

echo "Checking required commands..."
echo ""

all_good=true

check_command "debootstrap" "debootstrap" || all_good=false
check_command "proot" "proot" || all_good=false
check_command "tar" "tar" || all_good=false
check_command "xz" "xz-utils" || all_good=false
check_command "wget" "wget" || all_good=false
check_file "/usr/bin/qemu-aarch64-static" "qemu-user-static" || all_good=false

echo ""
echo "Additional useful tools:"
check_command "git" "git" || true
check_command "gh" "gh" || true

echo ""
echo "========================================"

if $all_good; then
    echo -e "${GREEN}All required dependencies are installed!${NC}"
    echo "You can run ./install_ubuntu_improved.sh"
else
    echo -e "${YELLOW}Some dependencies are missing.${NC}"
    echo ""
    echo "To install all required dependencies, run:"
    echo -e "${BLUE}sudo apt update && sudo apt install -y debootstrap proot tar xz-utils wget qemu-user-static binfmt-support${NC}"
fi

echo ""
echo "Checking which packages are actually installed..."
echo ""

for pkg in debootstrap proot tar xz-utils wget qemu-user-static binfmt-support; do
    if dpkg -l | grep -q "^ii  $pkg "; then
        echo -e "${GREEN}✓${NC} Package $pkg is installed"
    else
        echo -e "${RED}✗${NC} Package $pkg is NOT installed"
    fi
done

echo ""
echo "========================================"
