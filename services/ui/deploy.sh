#!/bin/bash
set -e

# This script builds and deploys the UI to Azure Storage Static Website

echo "🎨 Building and deploying UI..."

# Get infrastructure outputs from Terraform
cd ../../infra/core
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
WEBSITE_URL=$(terraform output -raw website_url)
WS_URL=$(terraform output -raw notification_api_websocket_url)
cd ../../services/ui

echo "📦 Storage Account: $STORAGE_ACCOUNT"
echo "🌐 Website URL: $WEBSITE_URL"
echo "🔌 WebSocket URL: $WS_URL"

# Build the React app
echo "🔨 Building React app..."
yarn build

# Deploy to Azure Storage
echo "📤 Uploading to Azure Storage..."
az storage blob upload-batch \
  --account-name $STORAGE_ACCOUNT \
  --destination '$web' \
  --source dist \
  --auth-mode login \
  --overwrite

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 Your site is live at:"
echo "$WEBSITE_URL"
echo ""
echo "🔌 WebSocket connected to:"
echo "$WS_URL"
