#!/bin/bash

# =============================================================================
# VPN Disconnect Script
# =============================================================================
# Disconnect from the VPN and clean up
# =============================================================================

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  VPN Disconnect${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if PID file exists
if [ -f /tmp/vpn-connection.pid ]; then
    PID=$(cat /tmp/vpn-connection.pid)

    # Check if process is running
    if ps -p "$PID" > /dev/null 2>&1; then
        print_info "Stopping OpenVPN (PID: $PID)..."
        sudo kill "$PID"
        sleep 2

        # Force kill if still running
        if ps -p "$PID" > /dev/null 2>&1; then
            print_warning "Process still running, forcing termination..."
            sudo kill -9 "$PID"
        fi

        print_success "VPN disconnected"
    else
        print_warning "OpenVPN process not running (PID file was stale)"
    fi

    # Clean up DNS configuration
    print_info "Removing DNS configuration..."

    # Use custom DNS updater to restore original DNS
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    if [ -f "$SCRIPT_DIR/vpn-dns-update.sh" ]; then
        if sudo "$SCRIPT_DIR/vpn-dns-update.sh" down >/dev/null 2>&1; then
            print_success "DNS configuration restored"
        fi
    fi    # Clean up PID file
    rm -f /tmp/vpn-connection.pid
else
    # Try to kill any running openvpn processes
    if pgrep -f 'openvpn.*--config' > /dev/null; then
        print_warning "No PID file found, but OpenVPN is running"
        print_info "Killing all OpenVPN processes..."
        sudo pkill -f 'openvpn.*--config'
        sleep 1
        print_success "VPN disconnected"
    else
        print_info "VPN is not running"
    fi
fi

# Clean up temporary files
print_info "Cleaning up temporary files..."
rm -rf /tmp/vpn-certs
rm -rf /tmp/vpn-profile
rm -f /tmp/vpn-profile.zip
rm -f /tmp/vpn-profile.zip.url
sudo rm -f /tmp/vpn-connection.log

print_success "Cleanup complete"
echo ""
