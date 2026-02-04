#!/bin/bash
# ============================================================================
# Improved xRDP Starter for proot
# ============================================================================
# This script properly starts xRDP with all necessary setup
# ============================================================================

echo "╔════════════════════════════════════════╗"
echo "║       Starting xRDP Server...         ║"
echo "╚════════════════════════════════════════╝"
echo ""

# Kill any existing sessions
echo "[*] Stopping any existing xRDP sessions..."
pkill xrdp 2>/dev/null
pkill xrdp-sesman 2>/dev/null
sleep 2

# Create necessary directories
echo "[*] Creating required directories..."
mkdir -p /var/run/xrdp
mkdir -p /var/log/xrdp
mkdir -p /etc/xrdp

# Generate SSL certificates if they don't exist
if [ ! -f /etc/xrdp/cert.pem ] || [ ! -f /etc/xrdp/key.pem ]; then
    echo "[*] Generating SSL certificates..."
    
    # Check if xrdp-keygen exists
    if command -v xrdp-keygen &> /dev/null; then
        xrdp-keygen xrdp /etc/xrdp/
    else
        # Generate certificates manually with openssl
        openssl req -x509 -newkey rsa:2048 -nodes \
            -keyout /etc/xrdp/key.pem \
            -out /etc/xrdp/cert.pem \
            -days 365 \
            -subj "/C=US/ST=State/L=City/O=Organization/CN=localhost" 2>/dev/null
        
        chmod 400 /etc/xrdp/key.pem
        chmod 644 /etc/xrdp/cert.pem
    fi
    
    if [ -f /etc/xrdp/cert.pem ]; then
        echo "    ✓ Certificates generated"
    else
        echo "    ✗ Failed to generate certificates"
        echo "    This might cause connection issues"
    fi
fi

# Fix permissions
echo "[*] Setting permissions..."
chmod 755 /var/run/xrdp
chmod 755 /var/log/xrdp

# Verify xrdp configuration exists
if [ ! -f /etc/xrdp/xrdp.ini ]; then
    echo "[!] WARNING: /etc/xrdp/xrdp.ini not found!"
    echo "    xRDP may not start properly"
fi

# Start xrdp-sesman (session manager)
echo "[*] Starting xrdp-sesman..."
/usr/sbin/xrdp-sesman 2>&1 | head -5 &
SESMAN_PID=$!
sleep 3

# Check if sesman started
if ! pgrep xrdp-sesman > /dev/null; then
    echo "[!] ERROR: xrdp-sesman failed to start"
    echo "    Check /var/log/xrdp-sesman.log for details"
    exit 1
fi

echo "    ✓ xrdp-sesman started (PID: $SESMAN_PID)"

# Start xrdp
echo "[*] Starting xrdp..."
/usr/sbin/xrdp 2>&1 | head -5 &
XRDP_PID=$!
sleep 3

# Check if xrdp started
if ! pgrep xrdp > /dev/null; then
    echo "[!] ERROR: xrdp failed to start"
    echo "    Check /var/log/xrdp.log for details"
    echo ""
    echo "Try running in foreground mode for debugging:"
    echo "  /usr/sbin/xrdp -n"
    exit 1
fi

echo "    ✓ xrdp started (PID: $XRDP_PID)"
echo ""

# Verify port is listening
sleep 2
if netstat -tln 2>/dev/null | grep -q :3389; then
    echo "✓ xRDP Server is running!"
    echo ""
    echo "Connection Details:"
    echo "  • Address: localhost:3389"
    echo "  • Port: 3389"
    echo "  • Username: root"
    echo "  • Password: (your Ubuntu password)"
    echo ""
    echo "Use Microsoft Remote Desktop app to connect"
    echo ""
    echo "To stop xRDP:"
    echo "  pkill xrdp; pkill xrdp-sesman"
    echo ""
    echo "To check status:"
    echo "  ps aux | grep xrdp"
    echo "  netstat -tln | grep 3389"
    echo ""
else
    echo "[!] WARNING: Port 3389 is not listening!"
    echo ""
    echo "Debugging steps:"
    echo "  1. Check logs: tail /var/log/xrdp.log"
    echo "  2. Check sesman: tail /var/log/xrdp-sesman.log"
    echo "  3. Run in foreground: /usr/sbin/xrdp -n"
    echo ""
    echo "xRDP may not work properly in proot."
    echo "Consider using VNC instead: complete_install.sh"
    echo ""
fi
