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
# - OpenVPN (install: brew install openvpn on macOS, apt install openvpn on Linux)
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
    - OpenVPN installed (macOS: brew install openvpn, Linux: apt install openvpn)
    - Azure CLI logged in (az login)
    - Terraform applied with enable_vpn_certificate_auth = true

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
    print_info "  macOS:  brew install openvpn"
    print_info "  Ubuntu: sudo apt-get install openvpn"
    print_info "  RHEL:   sudo yum install openvpn"
    echo ""
    exit 1
fi
print_success "OpenVPN found"

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

print_info "Downloading root certificate..."
az keyvault secret show \
    --vault-name "$KEY_VAULT_NAME" \
    --name "vpn-root-cert-pem" \
    --query value -o tsv > "${CERT_DIR}/ca.crt"
print_success "Root CA certificate downloaded"

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

print_success "All certificates downloaded to: $CERT_DIR"

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
unzip -q "$VPN_PROFILE_ZIP" -d "$VPN_PROFILE_DIR"

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
echo "  Root CA:             ${CERT_DIR}/ca.crt"
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

OVPN_CONFIG="${VPN_PROFILE_DIR}/OpenVPN/vpnconfig.ovpn"

if [ ! -f "$OVPN_CONFIG" ]; then
    print_error "OpenVPN configuration file not found in VPN profile."
    print_info "Expected location: $OVPN_CONFIG"
    exit 1
fi

# Add certificate paths to OpenVPN config
print_info "Configuring OpenVPN with certificates..."
cat >> "$OVPN_CONFIG" << EOF

# Client Certificate Authentication
ca ${CERT_DIR}/ca.crt
cert ${CERT_DIR}/client.crt
key ${CERT_DIR}/client.key
EOF

print_success "OpenVPN configuration updated"

# Display connection info
echo ""
print_info "VPN Gateway:    $VPN_GATEWAY_NAME"
print_info "Public IP:      $VPN_GATEWAY_PUBLIC_IP"
print_info "Config:         $OVPN_CONFIG"
print_info "Certificates:   $CERT_DIR"
echo ""

# Detect OS for sudo/permissions
OS_TYPE=$(uname -s)

case "$OS_TYPE" in
    Darwin|Linux)
        print_info "Starting OpenVPN connection..."
        print_warning "You may be prompted for your password (sudo required)"
        echo ""
        sudo openvpn --config "$OVPN_CONFIG"
        ;;
    *)
        print_error "Unsupported OS: $OS_TYPE"
        print_info "Please run manually: sudo openvpn --config $OVPN_CONFIG"
        exit 1
        ;;
esac

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
