#!/bin/bash

# Deploy WebRTC Signaling Service to Azure Container Apps
# Usage: ./deploy.sh

set -e

SERVICE_NAME="webrtc-signaling-service"

echo "🚀 Deploying WebRTC Signaling Service..."

# Navigate to infrastructure directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../../infra/core"

cd "$INFRA_DIR"

# Get infrastructure outputs
echo "📋 Getting infrastructure details..."
RG_NAME=$(terraform output -raw resource_group_name)
ACR_NAME=$(terraform output -raw container_registry_name)
CONTAINER_APP_NAME=$(terraform output -raw webrtc_signaling_service_name 2>/dev/null || echo "")

if [ -z "$CONTAINER_APP_NAME" ]; then
    echo "⚠️  WebRTC service not found in Terraform outputs"
    echo "   You'll need to add this service to your Terraform configuration"
    echo "   For now, using default naming convention..."
    ENVIRONMENT=$(terraform output -raw environment)
    CONTAINER_APP_NAME="ca-core-webrtc-signaling-service-${ENVIRONMENT}"
fi

echo "Resource Group: $RG_NAME"
echo "Container Registry: $ACR_NAME"
echo "Container App: $CONTAINER_APP_NAME"

# Build and push Docker image
echo "🐳 Building Docker image..."
cd "$SCRIPT_DIR"

IMAGE_NAME="${ACR_NAME}.azurecr.io/${SERVICE_NAME}:latest"
IMAGE_TAG="${ACR_NAME}.azurecr.io/${SERVICE_NAME}:$(date +%s)"

echo "Building image: $IMAGE_TAG"

# Build the image for linux/amd64 (required by Azure Container Apps)
docker build --platform linux/amd64 -t "$IMAGE_NAME" -t "$IMAGE_TAG" .

echo "🔐 Logging into Azure Container Registry..."
az acr login --name "$ACR_NAME"

echo "⬆️  Pushing image to ACR..."
docker push "$IMAGE_NAME"
docker push "$IMAGE_TAG"

echo "📝 Reading environment variables from .env file..."
ENV_VARS=""
SECRETS=""
if [ -f "$SCRIPT_DIR/.env" ]; then
  # Read .env file and convert to --set-env-vars format
  while IFS='=' read -r key value; do
    # Skip empty lines and comments
    [[ -z "$key" || "$key" =~ ^#.*$ ]] && continue
    # Remove quotes from value if present
    value="${value%\"}"
    value="${value#\"}"
    # Remove trailing whitespace/comments
    value=$(echo "$value" | sed 's/[[:space:]]*#.*//')
    
    # Add to env vars string
    if [ -n "$ENV_VARS" ]; then
      ENV_VARS="${ENV_VARS} ${key}=${value}"
    else
      ENV_VARS="${key}=${value}"
    fi
  done < "$SCRIPT_DIR/.env"

  echo "✅ Loaded environment variables from .env"
  echo "   Variables: $(echo "$ENV_VARS" | grep -o '[A-Z_]*=' | tr '\n' ' ')"
else
  echo "⚠️  No .env file found at $SCRIPT_DIR/.env"
  echo "   Container App will use existing environment variables"
fi

echo "🔄 Updating Container App..."
if [ -n "$ENV_VARS" ]; then
  az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RG_NAME" \
    --image "$IMAGE_TAG" \
    --set-env-vars $ENV_VARS \
    --output none
else
  az containerapp update \
    --name "$CONTAINER_APP_NAME" \
    --resource-group "$RG_NAME" \
    --image "$IMAGE_TAG" \
    --output none
fi

echo "✅ Deployment complete!"

# Get the URL
FQDN=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RG_NAME" \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)

echo ""
echo "🌐 WebRTC Signaling Service URL (internal): https://$FQDN"
echo "📊 Health Check (internal): https://$FQDN/health"
echo ""
echo "🌍 Public access via Application Gateway:"
APPGW_IP=$(cd "$INFRA_DIR" && terraform output -raw app_gateway_public_ip)
echo "   Health: https://$APPGW_IP/webrtc/health"
echo ""
