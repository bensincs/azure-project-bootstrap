#!/bin/bash
# Import OpenAPI specs into APIM after services are deployed

set -e

echo "🔄 Importing OpenAPI specifications into APIM..."

# Get resource names from Terraform output
cd "$(dirname "$0")/infra/core"
APIM_NAME=$(terraform output -raw apim_name 2>/dev/null || echo "")
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "rg-core-dev")
API_FQDN=$(terraform output -raw api_service_fqdn 2>/dev/null || echo "")
NOTIFY_FQDN=$(terraform output -raw notification_service_fqdn 2>/dev/null || echo "")

if [ -z "$APIM_NAME" ]; then
    echo "❌ Could not get APIM name from Terraform output"
    echo "Please provide APIM name manually:"
    read -r APIM_NAME
fi

echo "📦 APIM Name: $APIM_NAME"
echo "📦 Resource Group: $RESOURCE_GROUP"

# Import API Service OpenAPI spec
if [ -n "$API_FQDN" ]; then
    echo ""
    echo "📥 Importing API Service OpenAPI spec..."
    az apim api import \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --path "api" \
        --api-id "api-service" \
        --specification-url "https://$API_FQDN/swagger/v1/swagger.json" \
        --specification-format OpenApi \
        --display-name "API Service" \
        --protocols https \
        --no-wait

    echo "✅ API Service OpenAPI import started"
else
    echo "⚠️  API Service FQDN not found, skipping API import"
    echo "   You can manually import later from Azure Portal"
fi

# Import Notification Service OpenAPI spec
if [ -n "$NOTIFY_FQDN" ]; then
    echo ""
    echo "📥 Importing Notification Service OpenAPI spec..."
    az apim api import \
        --resource-group "$RESOURCE_GROUP" \
        --service-name "$APIM_NAME" \
        --path "notify" \
        --api-id "notification-service" \
        --specification-url "https://$NOTIFY_FQDN/swagger.json" \
        --specification-format OpenApi \
        --display-name "Notification Service" \
        --protocols https wss \
        --no-wait

    echo "✅ Notification Service OpenAPI import started"
else
    echo "⚠️  Notification Service FQDN not found, skipping import"
    echo "   You can manually import later from Azure Portal"
fi

echo ""
echo "✨ OpenAPI import jobs submitted!"
echo ""
echo "📝 Note: Imports run asynchronously. Check Azure Portal in a few minutes."
echo "🔗 Portal: https://portal.azure.com/#view/HubsExtension/BrowseResource/resourceType/Microsoft.ApiManagement%2Fservice"
