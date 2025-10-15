#!/bin/bash
set -e

echo "🎨 Building and deploying UI..."

# Get infrastructure outputs from Terraform
cd ../../infra/core
CONTAINER_REGISTRY=$(terraform output -raw container_registry_login_server)
CONTAINER_APP_NAME="ca-core-ui-service-dev"
RESOURCE_GROUP=$(terraform output -raw resource_group_name)
cd ../../services/ui

echo "📦 Container Registry: $CONTAINER_REGISTRY"
echo "📦 Container App: $CONTAINER_APP_NAME"
echo "📦 Resource Group: $RESOURCE_GROUP"

# Build and push Docker image
IMAGE_NAME="$CONTAINER_REGISTRY/ui-service"
IMAGE_TAG="$(date +%Y%m%d-%H%M%S)"
FULL_IMAGE="$IMAGE_NAME:$IMAGE_TAG"

echo ""
echo "� Building Docker image..."
docker build --platform linux/amd64 -t "$FULL_IMAGE" -t "$IMAGE_NAME:latest" .

echo ""
echo "🔐 Logging in to ACR..."
az acr login --name "${CONTAINER_REGISTRY%%.*}"

echo ""
echo "📤 Pushing image to ACR..."
docker push "$FULL_IMAGE"
docker push "$IMAGE_NAME:latest"

echo ""
echo "🚀 Updating Container App..."

# Load environment variables from local .env if it exists
ENV_VARS_ARG=""
if [ -f ".env" ]; then
  echo "📝 Loading environment variables from .env..."

  # Read .env and build --set-env-vars argument
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
else
  echo "⚠️  No .env file found - deploying without environment variables"
fi

az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$FULL_IMAGE" \
  $ENV_VARS_ARG

echo ""
echo "✅ Deployment complete!"

# Get the URL
FQDN=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)

echo ""
echo "🌐 UI Service URL: https://$FQDN"
echo ""

# Apply UI policy to APIM (no OpenAPI, just policy)
cd ../../infra/core
echo "📋 Applying APIM policy for UI service..."
APIM_NAME=$(terraform output -raw apim_name)
cd ../../services/ui

# Update policy with current values
POLICY_FILE="./apim-policy.xml"
POLICY_CONTENT=$(cat "$POLICY_FILE")
POLICY_CONTENT="${POLICY_CONTENT//\$\{BACKEND_URL\}/https://$FQDN}"

# Create temp policy file
TEMP_POLICY=$(mktemp)
echo "$POLICY_CONTENT" > "$TEMP_POLICY"

# Apply custom policy
az apim api policy create \
  --resource-group "$RESOURCE_GROUP" \
  --service-name "$APIM_NAME" \
  --api-id "ui-service" \
  --xml-content "@$TEMP_POLICY" || echo "⚠️  Policy update failed (API may not exist yet)"

# Clean up temp file
rm "$TEMP_POLICY"

echo "✅ Policy applied!"
echo ""
