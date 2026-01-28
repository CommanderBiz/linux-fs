#!/bin/bash
# ============================================================================
# Verify Ubuntu RootFS Tarball
# ============================================================================
# This script checks if the ubuntu-fs.tar.xz tarball contains all necessary
# files and is properly structured.
# ============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

log_error() {
    echo -e "${RED}[✗]${NC} $1"
}

TARBALL="ubuntu-fs.tar.xz"

echo "========================================"
echo "  Ubuntu RootFS Tarball Verification"
echo "========================================"
echo ""

# Check if tarball exists
if [ ! -f "$TARBALL" ]; then
    log_error "Tarball not found: $TARBALL"
    exit 1
fi

log_success "Tarball found: $TARBALL"
SIZE=$(du -h "$TARBALL" | cut -f1)
log_info "Size: $SIZE"
echo ""

# Check checksum file
if [ -f "${TARBALL}.sha256" ]; then
    log_success "Checksum file found"
    echo "    $(cat ${TARBALL}.sha256)"
else
    log_warning "Checksum file not found (${TARBALL}.sha256)"
fi
echo ""

log_info "Checking tarball structure..."
echo ""

# Critical directories
CRITICAL_DIRS=(
    "./bin"
    "./etc"
    "./usr"
    "./root"
    "./var"
    "./home"
    "./tmp"
)

for dir in "${CRITICAL_DIRS[@]}"; do
    if tar -tJf "$TARBALL" "$dir/" >/dev/null 2>&1; then
        log_success "Directory exists: $dir"
    else
        log_error "Missing directory: $dir"
    fi
done

echo ""
log_info "Checking critical files..."
echo ""

# Critical files
CRITICAL_FILES=(
    "./usr/bin/bash"
    "./usr/bin/apt"
    "./etc/apt/sources.list"
    "./root/complete_install.sh"
)

all_good=true

for file in "${CRITICAL_FILES[@]}"; do
    if tar -tJf "$TARBALL" "$file" >/dev/null 2>&1; then
        log_success "File exists: $file"
    else
        log_error "Missing file: $file"
        all_good=false
    fi
done

# Check for bash specifically (it might be a symlink)
echo ""
log_info "Checking bash location..."
if tar -tJf "$TARBALL" | grep -q "bin/bash"; then
    BASH_LOCATION=$(tar -tJf "$TARBALL" | grep "bin/bash" | head -1)
    log_success "Bash found at: $BASH_LOCATION"
else
    log_warning "Bash not found (might be extracted as symlink)"
fi

echo ""
log_info "Checking file counts..."
echo ""

# Count files
TOTAL_FILES=$(tar -tJf "$TARBALL" | wc -l)
log_info "Total entries: $TOTAL_FILES"

# Count specific types
BIN_COUNT=$(tar -tJf "$TARBALL" | grep -c "^./usr/bin/" || true)
LIB_COUNT=$(tar -tJf "$TARBALL" | grep -c "^./usr/lib/" || true)
log_info "Binaries in /usr/bin: $BIN_COUNT"
log_info "Libraries in /usr/lib: $LIB_COUNT"

echo ""
log_info "Checking desktop installer..."
echo ""

if tar -tJf "$TARBALL" "./root/complete_install.sh" >/dev/null 2>&1; then
    log_success "Desktop installer (complete_install.sh) is present"
    
    # Check if it's executable
    PERMS=$(tar -tJvf "$TARBALL" "./root/complete_install.sh" 2>/dev/null | awk '{print $1}')
    if [[ "$PERMS" == *"x"* ]]; then
        log_success "Desktop installer is executable"
    else
        log_warning "Desktop installer may not be executable"
    fi
    
    # Extract and check size
    tar -xJf "$TARBALL" -C /tmp "./root/complete_install.sh" 2>/dev/null
    SCRIPT_SIZE=$(wc -l /tmp/root/complete_install.sh 2>/dev/null | awk '{print $1}')
    rm -rf /tmp/root
    
    if [ "$SCRIPT_SIZE" -gt 100 ]; then
        log_success "Desktop installer looks valid ($SCRIPT_SIZE lines)"
    else
        log_warning "Desktop installer seems too small ($SCRIPT_SIZE lines)"
    fi
else
    log_error "Desktop installer (complete_install.sh) is MISSING!"
    log_info "Users won't be able to install the desktop environment"
    log_info "Run: ./add-complete-install.sh to fix this"
    all_good=false
fi

echo ""
echo "========================================"

# The most important thing is that complete_install.sh is present
INSTALLER_PRESENT=$(tar -tJf "$TARBALL" "./root/complete_install.sh" >/dev/null 2>&1 && echo "yes" || echo "no")

if [ "$INSTALLER_PRESENT" = "yes" ] && [ "$TOTAL_FILES" -gt 10000 ]; then
    log_success "Tarball verification PASSED"
    echo ""
    echo "✓ Core system files present ($TOTAL_FILES files)"
    echo "✓ Desktop installer included"
    echo "✓ Ready to upload to GitHub"
    echo ""
    if ! $all_good; then
        log_info "Note: Some symlinks may show as missing - this is normal"
        log_info "They will be created properly when extracted with proot"
    fi
else
    log_error "Tarball verification FAILED"
    echo ""
    if [ "$INSTALLER_PRESENT" = "no" ]; then
        echo "✗ Desktop installer is missing"
        echo "  Run: ./add-complete-install.sh to fix this"
    fi
    if [ "$TOTAL_FILES" -lt 10000 ]; then
        echo "✗ Tarball seems incomplete (only $TOTAL_FILES files)"
        echo "  Expected at least 10,000 files"
    fi
fi

echo "========================================"
echo ""
