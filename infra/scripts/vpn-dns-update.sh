#!/bin/bash
# =============================================================================
# VPN DNS Update Script for Dev Containers and GitHub Actions
# =============================================================================
# This script updates DNS configuration to use VPN DNS settings
# Works with both direct resolv.conf and systemd-resolved
# =============================================================================

set -e

ACTION="${1:-up}"
DNS_SERVER="${2:-}"
VPN_INTERFACE="${3:-tun0}"

RESOLV_CONF="/etc/resolv.conf"
RESOLV_BACKUP="/etc/resolv.conf.vpn-backup"

# Check if systemd-resolved is running
is_systemd_resolved() {
    if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
        return 0
    fi
    if [ -L "$RESOLV_CONF" ] && readlink "$RESOLV_CONF" | grep -q "systemd"; then
        return 0
    fi
    return 1
}

update_dns_systemd() {
    local dns_server="$1"
    local interface="$2"

    echo "Configuring DNS via systemd-resolved for interface $interface..."

    # Set DNS for the VPN interface using resolvectl
    if command -v resolvectl &> /dev/null; then
        resolvectl dns "$interface" "$dns_server" 2>/dev/null || \
        systemd-resolve --interface="$interface" --set-dns="$dns_server" 2>/dev/null || {
            echo "Warning: Could not configure systemd-resolved for interface $interface"
            return 1
        }

        # Set DNS domain for the interface (optional, helps with routing)
        resolvectl domain "$interface" "~." 2>/dev/null || \
        systemd-resolve --interface="$interface" --set-domain="~." 2>/dev/null || true

        echo "DNS configured via systemd-resolved: $dns_server on $interface"
        return 0
    else
        echo "Warning: resolvectl not available"
        return 1
    fi
}

update_dns() {
    local dns_server="$1"

    if [ -z "$dns_server" ]; then
        echo "Error: DNS server not specified"
        return 1
    fi

    # Try systemd-resolved first if available
    if is_systemd_resolved; then
        if update_dns_systemd "$dns_server" "$VPN_INTERFACE"; then
            return 0
        fi
        echo "Falling back to direct resolv.conf modification..."
    fi

    # Fallback: Direct resolv.conf modification
    # Backup original resolv.conf if not already backed up
    if [ ! -f "$RESOLV_BACKUP" ]; then
        cp "$RESOLV_CONF" "$RESOLV_BACKUP"
    fi

    # Create new resolv.conf with VPN DNS first
    {
        echo "# VPN DNS Configuration (managed by vpn-dns-update.sh)"
        echo "# VPN Interface: $VPN_INTERFACE"
        echo "nameserver $dns_server"
        echo ""
        echo "# Original DNS servers (backup)"
        grep "^nameserver" "$RESOLV_BACKUP" | grep -v "$dns_server" || true
    } > "${RESOLV_CONF}.tmp"

    # Replace resolv.conf (handle Docker mounted file)
    # Use cat instead of mv to preserve the file inode
    cat "${RESOLV_CONF}.tmp" > "$RESOLV_CONF" 2>/dev/null || {
        # If that fails, try with truncate + write
        : > "$RESOLV_CONF"
        cat "${RESOLV_CONF}.tmp" > "$RESOLV_CONF"
    }
    rm -f "${RESOLV_CONF}.tmp"

    echo "DNS updated: $dns_server is now the primary nameserver"
}

restore_dns_systemd() {
    local interface="$1"

    echo "Restoring DNS via systemd-resolved for interface $interface..."

    if command -v resolvectl &> /dev/null; then
        resolvectl revert "$interface" 2>/dev/null || \
        systemd-resolve --interface="$interface" --revert 2>/dev/null || {
            echo "Warning: Could not revert systemd-resolved for interface $interface"
            return 1
        }
        echo "DNS reverted via systemd-resolved for $interface"
        return 0
    fi
    return 1
}

restore_dns() {
    # Try systemd-resolved first if available
    if is_systemd_resolved; then
        if restore_dns_systemd "$VPN_INTERFACE"; then
            return 0
        fi
        echo "Falling back to direct resolv.conf restoration..."
    fi

    # Fallback: Direct resolv.conf restoration
    if [ -f "$RESOLV_BACKUP" ]; then
        # Use cat to preserve file inode (Docker mounts)
        cat "$RESOLV_BACKUP" > "$RESOLV_CONF" 2>/dev/null || {
            : > "$RESOLV_CONF"
            cat "$RESOLV_BACKUP" > "$RESOLV_CONF"
        }
        rm -f "$RESOLV_BACKUP"
        echo "DNS restored to original configuration"
    else
        echo "No backup found, DNS configuration unchanged"
    fi
}

case "$ACTION" in
    up|update)
        update_dns "$DNS_SERVER"
        ;;
    down|restore)
        restore_dns
        ;;
    *)
        echo "Usage: $0 {up|down} [dns_server] [interface]"
        echo "  up     - Update DNS with VPN DNS server"
        echo "  down   - Restore original DNS configuration"
        exit 1
        ;;
esac
