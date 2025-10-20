#!/bin/bash
set -e

# =============================================================================
# VPN Gateway Certificate Connection Script (OpenVPN)
# =============================================================================
# This script connects to the Azure VPN Gateway using certificate-based
# authentication via OpenVPN. It retrieves certificates from Key Vault and
# configures OpenVPN to connect automatically.
#
# Requirements:
# - Azure CLI (az)
# - Terraform
# - OpenVPN (install: apt install openvpn)
# - resolvconf or systemd-resolved for DNS configuration
#
# Usage:
#   ./connect.sh [OPTIONS]
#
# Options:
#   -d, --download           Download certificates only (don't connect)
#   -c, --client-cert NAME   Name of client cert in Key Vault (default: github-actions)
#   -h, --help               Show this help message
# =============================================================================

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
DOWNLOAD_ONLY=false
CLIENT_CERT_NAME="github-actions"
CORE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../core" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# =============================================================================
# Helper Functions
# =============================================================================

print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
    echo ""
}

show_help() {
    cat << EOF
VPN Gateway Certificate Connection Script (OpenVPN)

USAGE:
    ./connect.sh [OPTIONS]

OPTIONS:
    -d, --download              Download certificates only (don't connect)
    -c, --client-cert NAME      Name of client cert in Key Vault (default: github-actions)
    -h, --help                  Show this help message

EXAMPLES:
    # Connect to VPN using OpenVPN
    ./connect.sh

    # Download certificates only (don't connect)
    ./connect.sh --download

    # Use custom client certificate from Key Vault
    ./connect.sh --client-cert dev-client

REQUIREMENTS:
    - OpenVPN installed (apt install openvpn)
    - Azure CLI logged in (az login)
    - Terraform applied with enable_vpn_certificate_auth = true
    - resolvconf or systemd-resolved for DNS configuration

NOTE:
    This script uses the currently initialized Terraform workspace.
    Make sure you've run 'terraform init' in the infra/core directory.

EOF
}

# =============================================================================
# Parse Arguments
# =============================================================================

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--download)
            DOWNLOAD_ONLY=true
            shift
            ;;
        -c|--client-cert)
            CLIENT_CERT_NAME="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# =============================================================================
# Validate Requirements
# =============================================================================

print_header "Validating Requirements"

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    print_error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
fi
print_success "Azure CLI found"

# Check if OpenVPN is installed
if ! command -v openvpn &> /dev/null; then
    print_error "OpenVPN is not installed."
    echo ""
    print_info "Install OpenVPN:"
    print_info "  Ubuntu/Debian: sudo apt-get install openvpn resolvconf"
    print_info "  RHEL/CentOS:   sudo yum install openvpn"
    echo ""
    exit 1
fi
print_success "OpenVPN found at: $(which openvpn)"

# Check if Terraform is installed
if ! command -v terraform &> /dev/null; then
    print_error "Terraform is not installed. Please install it from https://www.terraform.io/downloads"
    exit 1
fi
print_success "Terraform found"

# Check if logged in to Azure
if ! az account show &> /dev/null; then
    print_error "Not logged in to Azure. Please run 'az login' first."
    exit 1
fi
print_success "Logged in to Azure"

# =============================================================================
# Get Terraform Outputs
# =============================================================================

print_header "Retrieving VPN Configuration"

cd "$CORE_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    print_error "Terraform is not initialized in $CORE_DIR"
    print_info "Please run: cd $CORE_DIR && terraform init"
    exit 1
fi

print_info "Reading Terraform outputs..."

# Get all VPN-related outputs
VPN_GATEWAY_NAME=$(terraform output -raw vpn_gateway_name 2>/dev/null || echo "")
VPN_GATEWAY_PUBLIC_IP=$(terraform output -raw vpn_gateway_public_ip 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
KEY_VAULT_NAME=$(terraform output -raw key_vault_name 2>/dev/null || echo "")
CERT_AUTH_ENABLED=$(terraform output -raw vpn_certificate_auth_enabled 2>/dev/null || echo "false")

# Validate outputs
if [ -z "$VPN_GATEWAY_NAME" ] || [ "$VPN_GATEWAY_NAME" == "null" ]; then
    print_error "VPN Gateway is not enabled. Please set 'enable_vpn_gateway = true' in your tfvars and run 'terraform apply'."
    exit 1
fi

print_success "VPN Gateway Name: $VPN_GATEWAY_NAME"
print_success "Resource Group: $RESOURCE_GROUP"
print_success "Public IP: $VPN_GATEWAY_PUBLIC_IP"
print_success "Certificate Auth: $CERT_AUTH_ENABLED"

# Verify certificate auth is enabled
if [ "$CERT_AUTH_ENABLED" != "true" ]; then
    print_error "Certificate authentication is not enabled in Terraform."
    print_info "Please set 'enable_vpn_certificate_auth = true' in your tfvars and run 'terraform apply'."
    exit 1
fi

# =============================================================================
# Download Certificates from Key Vault
# =============================================================================

print_header "Downloading Certificates from Key Vault"

CERT_DIR="/tmp/vpn-certs"
mkdir -p "$CERT_DIR"

print_info "Downloading client certificate..."
az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "${CLIENT_CERT_NAME}-client-cert-pem" \
    --query value -o tsv > "${CERT_DIR}/client.crt"
print_success "Client certificate downloaded"

print_info "Downloading client private key..."
az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "${CLIENT_CERT_NAME}-client-key-pem" \
    --query value -o tsv > "${CERT_DIR}/client.key"
print_success "Client private key downloaded"

# Set secure permissions on the private key
chmod 600 "${CERT_DIR}/client.key"

print_success "Client certificates downloaded to: $CERT_DIR"

# =============================================================================
# Generate VPN Profile
# =============================================================================

print_header "Generating VPN Configuration"

VPN_PROFILE_DIR="/tmp/vpn-profile"
VPN_PROFILE_ZIP="${VPN_PROFILE_DIR}.zip"

# Clean up old profile
rm -rf "$VPN_PROFILE_DIR" "$VPN_PROFILE_ZIP"

print_info "Generating VPN client configuration..."

# Generate VPN client configuration URL
az network vnet-gateway vpn-client generate \
    --resource-group "$RESOURCE_GROUP" \
    --name "$VPN_GATEWAY_NAME" \
    --authentication-method EAPTLS \
    --output tsv > "${VPN_PROFILE_ZIP}.url"

VPN_PROFILE_URL=$(cat "${VPN_PROFILE_ZIP}.url")
print_success "VPN profile URL generated"

# Download the profile
print_info "Downloading VPN profile..."
curl -s -L "$VPN_PROFILE_URL" -o "$VPN_PROFILE_ZIP"

# Extract the profile
print_info "Extracting VPN profile..."
mkdir -p "$VPN_PROFILE_DIR"
unzip -qq "$VPN_PROFILE_ZIP" -d "$VPN_PROFILE_DIR" 2>&1 | grep -v "appears to use backslashes" || true

print_success "VPN profile downloaded to: $VPN_PROFILE_DIR"

# =============================================================================
# Display Connection Information
# =============================================================================

print_header "VPN Connection Information"

echo ""
echo "  VPN Gateway:         $VPN_GATEWAY_NAME"
echo "  Public IP:           $VPN_GATEWAY_PUBLIC_IP"
echo "  Authentication:      Certificate-based"
echo "  Certificates:        $CERT_DIR"
echo "  Profile Directory:   $VPN_PROFILE_DIR"
echo ""
echo "  Client Certificate:  ${CERT_DIR}/client.crt"
echo "  Client Key:          ${CERT_DIR}/client.key"
echo ""

# =============================================================================
# Connect to VPN
# =============================================================================

if [ "$DOWNLOAD_ONLY" = true ]; then
    print_success "VPN profile downloaded successfully!"
    print_info "Certificates: $CERT_DIR"
    print_info "Profile: $VPN_PROFILE_DIR"
    exit 0
fi

print_header "Connecting to VPN with OpenVPN"

# Look for the OpenVPN config file (can be vpnconfig.ovpn or vpnconfig_cert.ovpn)
OVPN_CONFIG=""
if [ -f "${VPN_PROFILE_DIR}/OpenVPN/vpnconfig_cert.ovpn" ]; then
    OVPN_CONFIG="${VPN_PROFILE_DIR}/OpenVPN/vpnconfig_cert.ovpn"
elif [ -f "${VPN_PROFILE_DIR}/OpenVPN/vpnconfig.ovpn" ]; then
    OVPN_CONFIG="${VPN_PROFILE_DIR}/OpenVPN/vpnconfig.ovpn"
fi

if [ -z "$OVPN_CONFIG" ]; then
    print_error "OpenVPN configuration file not found in VPN profile."
    print_info "Expected location: ${VPN_PROFILE_DIR}/OpenVPN/"
    print_info "Available files:"
    ls -la "${VPN_PROFILE_DIR}/OpenVPN/" 2>/dev/null || echo "  Directory not found"
    exit 1
fi

print_success "Found OpenVPN config: $(basename $OVPN_CONFIG)"

# Add certificate paths to OpenVPN config
print_info "Configuring OpenVPN with certificates..."

# Update log file path in config to use absolute path
sed -i "s|log openvpn.log|log /tmp/vpn-connection.log|" "$OVPN_CONFIG"

# Remove the verify-x509-name directive and remote-cert-tls since Azure's server cert
# is signed by Microsoft CA, not our self-signed CA. Our CA is only for client authentication.
sed -i '/^verify-x509-name/d' "$OVPN_CONFIG"
sed -i '/^remote-cert-tls/d' "$OVPN_CONFIG"

# Remove the inline cert/key sections with placeholders and replace with file paths
# Remove everything from <cert> to </cert>
sed -i '/<cert>/,/<\/cert>/d' "$OVPN_CONFIG"
# Remove everything from <key> to </key>
sed -i '/<key>/,/<\/key>/d' "$OVPN_CONFIG"

# Add certificate file paths at the end
cat >> "$OVPN_CONFIG" << EOF

# Client Certificate Authentication (using external files)
# Note: ca.crt is our root CA for client authentication only
# Server certificate verification is disabled because Azure uses Microsoft's CA
cert ${CERT_DIR}/client.crt
key ${CERT_DIR}/client.key
EOF

print_success "OpenVPN configuration updated"

# Create a log file for OpenVPN
LOG_FILE="/tmp/vpn-connection.log"
echo "OpenVPN Connection Log - $(date)" > "$LOG_FILE"

# Display connection info
echo ""
print_info "VPN Gateway:    $VPN_GATEWAY_NAME"
print_info "Public IP:      $VPN_GATEWAY_PUBLIC_IP"
print_info "Config:         $OVPN_CONFIG"
print_info "Certificates:   $CERT_DIR"
print_info "Log file:       $LOG_FILE"
echo ""

print_info "Starting OpenVPN connection..."
print_warning "You will be prompted for your password (sudo required)"
echo ""

# Start OpenVPN in the background with logging
print_info "Connecting in background... (this may take 10-30 seconds)"

sudo openvpn --config "$OVPN_CONFIG" \
    --log "$LOG_FILE" \
    --daemon \
    --writepid /tmp/vpn-connection.pid

# Wait a few seconds for connection to establish
sleep 3

# Check if process is running
if [ -f /tmp/vpn-connection.pid ] && ps -p $(cat /tmp/vpn-connection.pid) > /dev/null 2>&1; then
    print_success "OpenVPN started successfully!"
    echo ""

    # Monitor connection for 30 seconds
    print_info "Waiting for connection to establish..."
    for i in {1..30}; do
        sleep 1

        # Check for successful connection in logs
        if grep -q "Initialization Sequence Completed" "$LOG_FILE" 2>/dev/null; then
            echo ""
            print_success "✓ VPN Connected successfully!"

            # Get assigned IP and interface (Linux)
            VPN_IP=$(ip -4 addr show | grep "inet 172.16.0" | awk '{print $2}' | cut -d/ -f1 | head -1)
            if [ -n "$VPN_IP" ]; then
                VPN_INTERFACE=$(ip -4 addr show | grep -B 2 "$VPN_IP" | grep -E "^[0-9]+:" | awk '{print $2}' | sed 's/://' | head -1)
            else
                VPN_INTERFACE="unknown"
            fi

            if [ -n "$VPN_IP" ]; then
                print_success "✓ VPN IP assigned: $VPN_IP"
            fi

            # Configure DNS for private Azure DNS zones
            print_info "Configuring DNS resolver..."

            # The DNS server is pushed by Azure in the VPN config (dhcp-option DNS 10.0.4.4)
            # Extract the correct IP from the log
            DNS_RESOLVER_IP=$(grep "dhcp-option DNS" "$LOG_FILE" | sed 's/.*dhcp-option DNS \([0-9.]*\).*/\1/' | head -1)

            if [ -z "$DNS_RESOLVER_IP" ]; then
                # Fallback: get from Terraform
                DNS_RESOLVER_IP=$(cd "$(dirname "$0")/../core" 2>/dev/null && terraform output -raw dns_resolver_inbound_endpoint_ip 2>/dev/null || echo "")
            fi

            if [ -n "$DNS_RESOLVER_IP" ]; then
                print_success "✓ DNS resolver available: $DNS_RESOLVER_IP"

                # Use custom DNS updater for dev containers
                if [ -f "$SCRIPT_DIR/vpn-dns-update.sh" ]; then
                    print_info "Updating DNS configuration..."
                    if sudo "$SCRIPT_DIR/vpn-dns-update.sh" up "$DNS_RESOLVER_IP" "$VPN_INTERFACE" 2>/dev/null; then
                        print_success "✓ DNS configured successfully"

                        # Verify
                        if grep -q "$DNS_RESOLVER_IP" /etc/resolv.conf 2>/dev/null; then
                            print_success "✓ DNS verified in /etc/resolv.conf"
                            print_info "  Private DNS queries will now work automatically"
                        fi
                    else
                        print_warning "⚠ Could not auto-configure DNS"
                        print_info "  You may need to configure DNS manually"
                    fi
                else
                    print_warning "⚠ DNS update script not found at: $SCRIPT_DIR/vpn-dns-update.sh"
                    print_info "  DNS configuration skipped"
                fi

                print_info "  Test DNS with standard tools (nslookup, dig, host)"
            fi
            echo ""
            print_info "Connection Details:"
            echo "  PID:       $(cat /tmp/vpn-connection.pid)"
            echo "  Interface: $VPN_INTERFACE"
            echo "  VPN IP:    $VPN_IP"
            echo "  DNS:       $DNS_RESOLVER_IP"
            echo "  Log:       $LOG_FILE"
            echo "  Status:    ./vpn-status.sh"
            echo ""
            print_info "To disconnect: ./disconnect.sh"
            echo ""
            exit 0
        fi

        # Check for errors
        if grep -qi "error\|failed\|cannot" "$LOG_FILE" 2>/dev/null; then
            echo ""
            print_error "Connection failed. Last 10 log lines:"
            tail -10 "$LOG_FILE"
            echo ""
            print_info "Full log: $LOG_FILE"
            exit 1
        fi

        # Show progress
        printf "."
    done

    echo ""
    print_warning "Connection is taking longer than expected..."
    print_info "Check status with: ./vpn-status.sh"
    print_info "View logs with: tail -f $LOG_FILE"
    print_info "Disconnect with: ./disconnect.sh"
    echo ""
else
    print_error "Failed to start OpenVPN"
    if [ -f "$LOG_FILE" ]; then
        print_info "Check logs: $LOG_FILE"
        tail -20 "$LOG_FILE"
    fi
    exit 1
fi

# =============================================================================
# Cleanup Instructions
# =============================================================================

echo ""
print_info "To disconnect from VPN:"
print_info "  - Press Ctrl+C if running in foreground"
print_info "  - Or use your VPN client's disconnect function"
echo ""
print_info "Certificate locations:"
print_info "  Certificates: $CERT_DIR"
print_info "  VPN Profile:  $VPN_PROFILE_DIR"
echo ""
print_info "To remove downloaded files:"
print_info "  rm -rf $CERT_DIR $VPN_PROFILE_DIR $VPN_PROFILE_ZIP"
echo ""

print_success "Setup complete!"
