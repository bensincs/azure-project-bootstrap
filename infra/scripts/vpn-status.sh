#!/bin/bash

# =============================================================================
# VPN Status Check Script
# =============================================================================
# Quickly check if your VPN connection is active and working
# =============================================================================

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}  VPN Connection Status${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo ""

# Check if OpenVPN process is running
echo -e "${BLUE}OpenVPN Process:${NC}"
if ps aux | grep -i '[o]penvpn.*--config' > /dev/null; then
    PID=$(ps aux | grep -i '[o]penvpn.*--config' | awk '{print $2}' | head -1)
    CONFIG=$(ps aux | grep -i '[o]penvpn.*--config' | head -1 | sed 's/.*--config //' | awk '{print $1}')
    echo -e "  ${GREEN}✓${NC} Running (PID: $PID)"
    echo -e "  ${BLUE}ℹ${NC} Config: $CONFIG"
else
    echo -e "  ${RED}✗${NC} Not running"
    echo ""
    echo -e "${YELLOW}To start VPN:${NC} ./connect.sh"
    exit 1
fi

echo ""
echo -e "${BLUE}VPN Tunnel Interfaces:${NC}"

# Linux uses ip command
ip -4 addr show | grep -E "^[0-9]+: tun" | while read num iface rest; do
    IFACE=$(echo $iface | sed 's/://')
    IP=$(ip -4 addr show $IFACE | grep "inet " | awk '{print $2}' | cut -d/ -f1)
    if [ -n "$IP" ]; then
        echo -e "  ${GREEN}✓${NC} $IFACE: $IP"
    else
        echo -e "  ${YELLOW}○${NC} $IFACE: (no IPv4)"
    fi
done

echo ""
echo -e "${BLUE}VPN Client IP (from config):${NC}"

# Get VPN IP (Linux)
VPN_IP=$(ip -4 addr show | grep "inet 172.16.0" | awk '{print $2}' | cut -d/ -f1 | head -1)
if [ -n "$VPN_IP" ]; then
    echo -e "  ${GREEN}✓${NC} $VPN_IP (connected to Azure VPN)"
else
    echo -e "  ${YELLOW}⚠${NC} No IP in VPN range (172.16.0.0/24) - may still be connecting..."
fi

echo ""
echo -e "${BLUE}Routes via VPN:${NC}"

# Linux uses ip route
if ip route | grep -q "172.16.0"; then
    echo -e "  ${GREEN}✓${NC} VPN routes configured"
    ip route | grep -E "172.16.0|10.0.0.0" | head -5 | while read line; do
        echo "    $line"
    done
else
    echo -e "  ${YELLOW}⚠${NC} No specific VPN routes found (may use default routing)"
fi

echo ""
echo -e "${BLUE}DNS Configuration:${NC}"
# Get private DNS resolver from VPN logs
DNS_RESOLVER=$(grep "dhcp-option DNS" /tmp/vpn-connection.log 2>/dev/null | sed 's/.*dhcp-option DNS \([0-9.]*\).*/\1/' | head -1)

if [ -n "$DNS_RESOLVER" ]; then
    echo -e "  ${GREEN}✓${NC} VPN DNS Server: $DNS_RESOLVER"
    
    # Check if systemd-resolved is running
    if systemctl is-active --quiet systemd-resolved 2>/dev/null || [ -L /etc/resolv.conf ] && readlink /etc/resolv.conf | grep -q "systemd"; then
        echo -e "  ${BLUE}ℹ${NC} Using systemd-resolved"
        
        # Get VPN interface
        VPN_IFACE=$(ip -4 addr show | grep "inet 172.16.0" | awk '{print $NF}' | head -1)
        
        # Check if DNS is configured for the VPN interface
        if command -v resolvectl &> /dev/null; then
            if resolvectl status "$VPN_IFACE" 2>/dev/null | grep -q "$DNS_RESOLVER"; then
                echo -e "  ${GREEN}✓${NC} DNS configured via systemd-resolved for $VPN_IFACE"
            else
                echo -e "  ${YELLOW}⚠${NC} DNS not configured for $VPN_IFACE in systemd-resolved"
            fi
        fi
    else
        # Direct resolv.conf check (dev containers)
        if grep -q "$DNS_RESOLVER" /etc/resolv.conf 2>/dev/null; then
            echo -e "  ${GREEN}✓${NC} DNS configured in /etc/resolv.conf"
        else
            echo -e "  ${YELLOW}⚠${NC} DNS not configured in /etc/resolv.conf"
        fi
    fi
else
    echo -e "  ${YELLOW}⚠${NC} No DNS resolver found in VPN configuration"
fi

echo ""
echo -e "${BLUE}Commands:${NC}"
echo "  View full logs: sudo tail -f /tmp/vpn-connection.log"
echo "  Disconnect:     ./disconnect.sh"
echo "  Reconnect:      ./connect.sh"
echo ""
