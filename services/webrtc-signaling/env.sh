#!/bin/bash

# Generate .env file for WebRTC Signaling Service
# This script reads configuration from Terraform outputs

set -e

echo "🔧 Generating .env file for WebRTC Signaling Service..."

# Navigate to infrastructure directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../../infra/core"

cd "$INFRA_DIR"

# Check if Terraform is initialized
if [ ! -d ".terraform" ]; then
    echo "❌ Terraform not initialized in $INFRA_DIR"
    echo "   Please run: cd $INFRA_DIR && terraform init"
    exit 1
fi

# Get outputs from Terraform
echo "📋 Reading Terraform outputs..."

APP_GATEWAY_IP=$(terraform output -raw app_gateway_public_ip 2>/dev/null || echo "")
UI_SERVICE_FQDN=$(terraform output -raw ui_service_fqdn 2>/dev/null || echo "")
ENVIRONMENT=$(terraform output -raw environment 2>/dev/null || echo "dev")
AZURE_TENANT_ID=$(terraform output -raw azure_tenant_id 2>/dev/null || echo "")
AZURE_CLIENT_ID=$(terraform output -raw azure_client_id 2>/dev/null || echo "")

# Build allowed origins list
ALLOWED_ORIGINS=""
if [ -n "$APP_GATEWAY_IP" ]; then
    ALLOWED_ORIGINS="https://$APP_GATEWAY_IP"
fi
if [ -n "$UI_SERVICE_FQDN" ]; then
    if [ -n "$ALLOWED_ORIGINS" ]; then
        ALLOWED_ORIGINS="${ALLOWED_ORIGINS},https://$UI_SERVICE_FQDN"
    else
        ALLOWED_ORIGINS="https://$UI_SERVICE_FQDN"
    fi
fi

# Add localhost for development
ALLOWED_ORIGINS="${ALLOWED_ORIGINS},http://localhost:5173,http://localhost:3000"

# Generate .env file
cd "$SCRIPT_DIR"

cat > .env << EOF
# WebRTC Signaling Service Configuration
# Generated on $(date)

# Environment
NODE_ENV=production
PORT=3000

# Azure AD Authentication
AZURE_TENANT_ID=${AZURE_TENANT_ID}
AZURE_CLIENT_ID=${AZURE_CLIENT_ID}
SKIP_TOKEN_VERIFICATION=false

# CORS Configuration
ALLOWED_ORIGINS=${ALLOWED_ORIGINS}

# Base Path (for Application Gateway routing)
BASE_PATH=/wrtc-api

# Logging
LOG_LEVEL=info
EOF

echo "✅ Generated .env file at $SCRIPT_DIR/.env"
echo ""
echo "📋 Configuration:"
echo "   Environment: $ENVIRONMENT"
echo "   Azure Tenant ID: $AZURE_TENANT_ID"
echo "   Azure Client ID: $AZURE_CLIENT_ID"
echo "   Allowed Origins: $ALLOWED_ORIGINS"
echo "   Base Path: /wrtc-api"
echo ""
