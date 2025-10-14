#!/bin/bash

# Script to retrieve Azure AD configuration from Terraform outputs
# and create .env.local file for UI development

echo "🔍 Retrieving Azure AD configuration from Terraform..."

cd ../../infra/core

# Check if terraform state exists
if [ ! -f "terraform.tfstate" ]; then
    echo "❌ Error: terraform.tfstate not found. Please run 'terraform apply' first."
    exit 1
fi

# Get values from terraform outputs
CLIENT_ID=$(terraform output -raw azure_ad_application_id 2>/dev/null)
TENANT_ID=$(terraform output -raw azure_ad_tenant_id 2>/dev/null)
APP_GATEWAY_IP=$(terraform output -raw app_gateway_public_ip 2>/dev/null)

# Check if values were retrieved
if [ -z "$CLIENT_ID" ] || [ -z "$TENANT_ID" ]; then
    echo "❌ Error: Could not retrieve Azure AD configuration from Terraform outputs."
    echo "Please ensure terraform apply has been run successfully."
    exit 1
fi

cd ../../services/ui

# Create .env.local file
cat > .env.local << EOF
# Azure AD Configuration
# Generated on $(date)

VITE_AZURE_AD_CLIENT_ID=$CLIENT_ID
VITE_AZURE_AD_TENANT_ID=$TENANT_ID
VITE_API_BASE_URL=http://localhost:5173

# Production URL (when deploying):
# VITE_API_BASE_URL=https://$APP_GATEWAY_IP
EOF

echo "✅ Configuration file created: .env.local"
echo ""
echo "📋 Azure AD Configuration:"
echo "   Client ID: $CLIENT_ID"
echo "   Tenant ID: $TENANT_ID"
echo "   App Gateway IP: $APP_GATEWAY_IP"
echo ""
echo "🔧 For local development:"
echo "   API Base URL is set to: http://localhost:5173 (proxies to App Gateway)"
echo ""
echo "🚀 For production deployment:"
echo "   Update VITE_API_BASE_URL to: https://$APP_GATEWAY_IP"
echo ""
echo "📝 Next steps:"
echo "   1. Follow the setup guide in AUTH-SETUP.md"
echo "   2. Install dependencies: npm install @azure/msal-browser @azure/msal-react"
echo "   3. Run UI locally: npm run dev"
echo "   4. Test authentication flow"
