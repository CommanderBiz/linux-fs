#!/bin/bash
# ============================================================================
# xRDP Diagnostic Script
# ============================================================================
# Run this inside Ubuntu to diagnose xRDP connection issues
# ============================================================================

echo "╔════════════════════════════════════════╗"
echo "║       xRDP Diagnostics Tool           ║"
echo "╚════════════════════════════════════════╝"
echo ""

echo "1. Checking if xRDP processes are running..."
echo "   ────────────────────────────────────────"
if pgrep -a xrdp; then
    echo "   ✓ xRDP processes found"
else
    echo "   ✗ No xRDP processes running"
    echo "   Start with: start-xrdp"
fi
echo ""

echo "2. Checking listening ports..."
echo "   ────────────────────────────────────────"
netstat -tlnp 2>/dev/null | grep -E "3389|3350" || echo "   ✗ Port 3389 not listening"
echo ""

echo "3. Checking xRDP logs..."
echo "   ────────────────────────────────────────"
if [ -f /var/log/xrdp.log ]; then
    echo "   Last 10 lines of xrdp.log:"
    tail -10 /var/log/xrdp.log | sed 's/^/   /'
else
    echo "   ✗ No xrdp.log found"
fi
echo ""

echo "4. Checking xRDP-sesman logs..."
echo "   ────────────────────────────────────────"
if [ -f /var/log/xrdp-sesman.log ]; then
    echo "   Last 10 lines of xrdp-sesman.log:"
    tail -10 /var/log/xrdp-sesman.log | sed 's/^/   /'
else
    echo "   ✗ No xrdp-sesman.log found"
fi
echo ""

echo "5. Checking xRDP configuration..."
echo "   ────────────────────────────────────────"
if [ -f /etc/xrdp/xrdp.ini ]; then
    echo "   Port configured:"
    grep "^port=" /etc/xrdp/xrdp.ini | sed 's/^/   /'
else
    echo "   ✗ No xrdp.ini found"
fi
echo ""

echo "6. Checking for certificate issues..."
echo "   ────────────────────────────────────────"
if [ -f /etc/xrdp/cert.pem ]; then
    echo "   ✓ Certificate exists"
else
    echo "   ✗ No certificate - this might be the issue!"
fi
echo ""

echo "7. Testing local connection..."
echo "   ────────────────────────────────────────"
if command -v nc &> /dev/null; then
    timeout 2 nc -zv localhost 3389 2>&1 | sed 's/^/   /'
else
    echo "   ℹ nc (netcat) not installed - can't test connection"
fi
echo ""

echo "════════════════════════════════════════════"
echo "RECOMMENDATIONS:"
echo "════════════════════════════════════════════"
echo ""

if ! pgrep xrdp > /dev/null; then
    echo "→ Start xRDP: start-xrdp"
fi

if [ ! -f /etc/xrdp/cert.pem ]; then
    echo "→ Generate certificates: /etc/xrdp/xrdp-keygen xrdp /etc/xrdp"
fi

if ! netstat -tlnp 2>/dev/null | grep -q 3389; then
    echo "→ Port 3389 not listening - check logs above"
    echo "→ Try running xrdp manually: /usr/sbin/xrdp -n"
    echo "   (Press Ctrl+C after seeing any errors)"
fi

echo ""
echo "For detailed debugging, check:"
echo "  • /var/log/xrdp.log"
echo "  • /var/log/xrdp-sesman.log"
echo "  • Run: /usr/sbin/xrdp -n (foreground mode)"
echo ""
