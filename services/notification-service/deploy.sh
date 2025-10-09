#!/bin/bash
set -e

# This script builds and deploys the notification API to Azure Container Apps

echo "🔨 Building and deploying notification API..."

# Get infrastructure outputs
cd ../../infra/core
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
ACR_NAME=$(terraform output -raw container_registry_name)
ACR_LOGIN_SERVER=$(terraform output -raw container_registry_login_server)
CONTAINER_APP_NAME=$(terraform output -raw container_app_name)
cd ../../services/notification-service

echo "📦 Resource Group: $RESOURCE_GROUP"
echo "📦 Container Registry: $ACR_NAME"
echo "📦 Container App: $CONTAINER_APP_NAME"
echo "🌐 Login Server: $ACR_LOGIN_SERVER"

# Login to ACR
echo "🔐 Logging in to Azure Container Registry..."
az acr login --name $ACR_NAME

# Generate timestamp for image tag
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
IMAGE_NAME="$ACR_LOGIN_SERVER/notification-service"
IMAGE_TAG="$IMAGE_NAME:$TIMESTAMP"

# Build and push Docker image (with linux/amd64 platform for Azure)
echo "🐳 Building Docker image: $IMAGE_TAG"
docker build --platform linux/amd64 -t $IMAGE_TAG .

# Also tag as latest for convenience
docker tag $IMAGE_TAG $IMAGE_NAME:latest

echo "📤 Pushing images to ACR..."
docker push $IMAGE_TAG
docker push $IMAGE_NAME:latest

echo "🏷️  Deployed version: $TIMESTAMP"

# Load environment variables from local .env if it exists
ENV_VARS_ARG=""
if [ -f ".env" ]; then
  echo "📝 Loading environment variables from .env..."

  # Read .env and build --env-vars argument
  # Skip empty lines and comments
  ENV_VARS=""
  while IFS='=' read -r key value || [ -n "$key" ]; do
    # Skip empty lines and comments
    if [[ -z "$key" || "$key" =~ ^[[:space:]]*# ]]; then
      continue
    fi

    # Trim whitespace
    key=$(echo "$key" | xargs)
    value=$(echo "$value" | xargs)

    if [ -n "$key" ] && [ -n "$value" ]; then
      if [ -z "$ENV_VARS" ]; then
        ENV_VARS="$key=$value"
      else
        ENV_VARS="$ENV_VARS $key=$value"
      fi
      echo "  ✓ $key"
    fi
  done < .env

  if [ -n "$ENV_VARS" ]; then
    ENV_VARS_ARG="--set-env-vars $ENV_VARS"
  fi
fi

# Update Container App with new image (rolling deployment, no downtime!)
echo "🚀 Updating Container App with new image..."
az containerapp update \
  --name $CONTAINER_APP_NAME \
  --resource-group $RESOURCE_GROUP \
  --image $IMAGE_TAG \
  $ENV_VARS_ARG

echo "⏳ Waiting for deployment to complete..."
sleep 5

echo ""
echo "✅ Deployment complete!"
echo ""
echo "🌐 API URL:"
cd ../../infra/core
terraform output notification_api_url
echo ""
echo "🔌 WebSocket URL:"
terraform output notification_api_websocket_url
