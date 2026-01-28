#!/bin/bash
# ============================================================================
# GitHub Release Upload Helper
# ============================================================================
# This script helps you create a GitHub release and upload the built files
# using the GitHub CLI (gh).
# ============================================================================

set -e
set -u

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
    echo "  GitHub Release Upload Helper"
    echo "========================================"
    echo ""
}

check_gh_cli() {
    log_info "Checking for GitHub CLI..."
    
    if ! command -v gh &> /dev/null; then
        log_error "GitHub CLI (gh) not found"
        echo ""
        echo "Install it with:"
        echo "  Ubuntu/Debian: sudo apt install gh"
        echo "  macOS:         brew install gh"
        echo "  Or visit:      https://cli.github.com/"
        exit 1
    fi
    
    log_success "GitHub CLI found ✓"
}

check_auth() {
    log_info "Checking GitHub authentication..."
    
    if ! gh auth status &> /dev/null; then
        log_warning "Not authenticated with GitHub"
        log_info "Running: gh auth login"
        echo ""
        gh auth login
    else
        log_success "Already authenticated ✓"
    fi
}

check_files() {
    log_info "Checking for required files..."
    
    local missing=()
    
    if [ ! -f "ubuntu-fs.tar.xz" ]; then
        missing+=("ubuntu-fs.tar.xz")
    fi
    
    if [ ! -f "ubuntu-fs.tar.xz.sha256" ]; then
        log_warning "Checksum file not found, generating..."
        sha256sum ubuntu-fs.tar.xz > ubuntu-fs.tar.xz.sha256
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        log_error "Missing required files: ${missing[*]}"
        log_info "Please run install_ubuntu.sh first"
        exit 1
    fi
    
    log_success "All files present ✓"
    
    # Show file info
    echo ""
    log_info "Files to upload:"
    echo "  - ubuntu-fs.tar.xz ($(du -h ubuntu-fs.tar.xz | cut -f1))"
    echo "  - ubuntu-fs.tar.xz.sha256"
    if [ -f "install.sh" ]; then
        echo "  - install.sh (installer script)"
    fi
    echo ""
}

get_repo_info() {
    log_info "Detecting repository..."
    
    if ! git rev-parse --is-inside-work-tree &> /dev/null; then
        log_error "Not in a git repository"
        log_info "Please initialize a git repo: git init"
        exit 1
    fi
    
    # Try to get remote URL
    if ! REPO_URL=$(git config --get remote.origin.url 2>/dev/null); then
        log_error "No remote 'origin' found"
        log_info "Add a remote: git remote add origin <url>"
        exit 1
    fi
    
    # Extract owner/repo from URL
    REPO=$(echo "$REPO_URL" | sed -E 's/.*[:/]([^/]+\/[^/]+)(\.git)?$/\1/')
    
    log_success "Repository: $REPO ✓"
    echo ""
}

get_version() {
    echo ""
    log_info "Enter release version (e.g., v1.0, v1.0.0, v2.1):"
    read -r VERSION
    
    if [ -z "$VERSION" ]; then
        log_error "Version cannot be empty"
        exit 1
    fi
    
    # Add 'v' prefix if not present
    if [[ ! "$VERSION" =~ ^v ]]; then
        VERSION="v$VERSION"
    fi
    
    log_success "Version: $VERSION ✓"
}

get_release_notes() {
    echo ""
    log_info "Enter release title (or press Enter for default):"
    read -r TITLE
    
    if [ -z "$TITLE" ]; then
        TITLE="Ubuntu Noble 24.04 LTS for Termux - $VERSION"
    fi
    
    echo ""
    log_info "Enter release description (or press Enter for default):"
    read -r DESCRIPTION
    
    if [ -z "$DESCRIPTION" ]; then
        DESCRIPTION="Pre-built Ubuntu Noble (24.04 LTS) ARM64 root filesystem for Termux.

## Installation

\`\`\`bash
wget https://github.com/$REPO/releases/download/$VERSION/install.sh
chmod +x install.sh
./install.sh
\`\`\`

## What's Included

- Ubuntu Noble 24.04 LTS base system
- XFCE4 desktop environment installer
- VNC server support
- Pre-configured for proot

## Verification

\`\`\`bash
sha256sum -c ubuntu-fs.tar.xz.sha256
\`\`\`

## System Requirements

- ARM64 Android device
- Termux (from F-Droid)
- 2GB+ free storage
- Internet connection"
    fi
}

create_release() {
    echo ""
    log_info "Creating GitHub release..."
    echo ""
    log_warning "This will create a new release: $VERSION"
    read -p "Continue? (y/N): " -n 1 -r
    echo
    
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cancelled"
        exit 0
    fi
    
    echo ""
    log_info "Creating release and uploading files..."
    log_warning "This may take several minutes..."
    echo ""
    
    # Create release with files
    gh release create "$VERSION" \
        --repo "$REPO" \
        --title "$TITLE" \
        --notes "$DESCRIPTION" \
        ubuntu-fs.tar.xz \
        ubuntu-fs.tar.xz.sha256 \
        $([ -f "install.sh" ] && echo "install.sh")
    
    if [ $? -eq 0 ]; then
        log_success "Release created successfully! ✓"
        echo ""
        RELEASE_URL="https://github.com/$REPO/releases/download/$VERSION/ubuntu-fs.tar.xz"
        log_success "Download URL: $RELEASE_URL"
        echo ""
        log_info "Next steps:"
        echo "  1. Update install.sh with the release URL:"
        echo "     RELEASE_URL=\"$RELEASE_URL\""
        echo "  2. Distribute install.sh to users"
        echo ""
    else
        log_error "Failed to create release"
        exit 1
    fi
}

update_existing_release() {
    echo ""
    log_info "Available releases:"
    gh release list --repo "$REPO" | head -10
    echo ""
    log_info "Enter release tag to update (or 'new' for new release):"
    read -r TAG
    
    if [ "$TAG" = "new" ]; then
        get_version
        get_release_notes
        create_release
        return
    fi
    
    if [ -z "$TAG" ]; then
        log_error "Tag cannot be empty"
        exit 1
    fi
    
    echo ""
    log_info "Uploading files to existing release: $TAG"
    echo ""
    
    gh release upload "$TAG" \
        --repo "$REPO" \
        --clobber \
        ubuntu-fs.tar.xz \
        ubuntu-fs.tar.xz.sha256 \
        $([ -f "install.sh" ] && echo "install.sh")
    
    if [ $? -eq 0 ]; then
        log_success "Files uploaded successfully! ✓"
    else
        log_error "Upload failed"
        exit 1
    fi
}

main_menu() {
    echo ""
    echo "What would you like to do?"
    echo ""
    echo "  1) Create new release"
    echo "  2) Update existing release"
    echo "  3) List releases"
    echo "  4) Exit"
    echo ""
    read -p "Choose [1-4]: " -n 1 -r choice
    echo ""
    
    case $choice in
        1)
            get_version
            get_release_notes
            create_release
            ;;
        2)
            update_existing_release
            ;;
        3)
            echo ""
            log_info "Recent releases:"
            gh release list --repo "$REPO"
            echo ""
            ;;
        4)
            log_info "Goodbye!"
            exit 0
            ;;
        *)
            log_error "Invalid choice"
            exit 1
            ;;
    esac
}

main() {
    banner
    check_gh_cli
    check_auth
    check_files
    get_repo_info
    main_menu
}

main "$@"
