#!/bin/bash
# =============================================================================
# VPN DNS Update Script for Dev Containers
# =============================================================================
# This script updates /etc/resolv.conf with VPN DNS settings
# Designed to work in dev containers where systemd-resolved is not available
# =============================================================================

set -e

ACTION="${1:-up}"
DNS_SERVER="${2:-}"
VPN_INTERFACE="${3:-tun0}"

RESOLV_CONF="/etc/resolv.conf"
RESOLV_BACKUP="/etc/resolv.conf.vpn-backup"

update_dns() {
    local dns_server="$1"

    if [ -z "$dns_server" ]; then
        echo "Error: DNS server not specified"
        return 1
    fi

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

restore_dns() {
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
