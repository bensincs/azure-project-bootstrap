#!/bin/bash

# Deploy API Service to Azure Container Apps
# Usage: ./deploy.sh <environment>
# Example: ./deploy.sh dev

set -e

ENVIRONMENT=${1:-dev}
SERVICE_NAME="api-service"

echo "🚀 Deploying API Service to $ENVIRONMENT environment..."

# Navigate to infrastructure directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INFRA_DIR="$SCRIPT_DIR/../../infra/core"

cd "$INFRA_DIR"

# Get infrastructure outputs
echo "📋 Getting infrastructure details..."
RG_NAME=$(terraform output -raw resource_group_name)
ACR_NAME=$(terraform output -raw container_registry_name)
CONTAINER_APP_NAME=$(terraform output -raw api_service_name)

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

echo "🔄 Updating Container App..."
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RG_NAME" \
  --image "$IMAGE_TAG" \
  --output none

echo "✅ Deployment complete!"

# Get the URL
FQDN=$(az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RG_NAME" \
  --query "properties.configuration.ingress.fqdn" \
  --output tsv)

echo ""
echo "🌐 API Service URL: https://$FQDN"
echo "📊 Health Check: https://$FQDN/api/health"
echo "👋 Hello Endpoint: https://$FQDN/api/hello"
echo "📖 Swagger UI: https://$FQDN/swagger"
echo ""

# Import OpenAPI spec into APIM
echo "📥 Importing OpenAPI spec into APIM..."
APIM_NAME=$(cd "$INFRA_DIR" && terraform output -raw apim_name)
TENANT_ID=$(cd "$INFRA_DIR" && terraform output -raw tenant_id)
CLIENT_ID=$(cd "$INFRA_DIR" && terraform output -raw client_id)

# Update policy with current values
POLICY_FILE="$SCRIPT_DIR/apim-policy.xml"
POLICY_CONTENT=$(cat "$POLICY_FILE")
POLICY_CONTENT="${POLICY_CONTENT//\$\{BACKEND_URL\}/https://$FQDN}"
POLICY_CONTENT="${POLICY_CONTENT//\$\{TENANT_ID\}/$TENANT_ID}"
POLICY_CONTENT="${POLICY_CONTENT//\$\{CLIENT_ID\}/$CLIENT_ID}"

# Create temp policy file
TEMP_POLICY=$(mktemp)
echo "$POLICY_CONTENT" > "$TEMP_POLICY"

# Import OpenAPI spec
az apim api import \
  --resource-group "$RG_NAME" \
  --service-name "$APIM_NAME" \
  --path "api" \
  --api-id "api-service" \
  --specification-url "https://$FQDN/swagger/v1/swagger.json" \
  --specification-format OpenApiJson \
  --display-name "API Service" \
  --protocols https \
  --subscription-required false \
  --api-type http \
  --no-wait

echo "⏳ Waiting for OpenAPI import to complete..."
sleep 5

# Apply custom policy
echo "📋 Applying APIM policy..."
az apim api policy create \
  --resource-group "$RG_NAME" \
  --service-name "$APIM_NAME" \
  --api-id "api-service" \
  --xml-content "@$TEMP_POLICY"

# Clean up temp file
rm "$TEMP_POLICY"

echo "✅ OpenAPI spec imported and policy applied!"
echo ""
