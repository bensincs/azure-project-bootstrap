# Azure API Management for centralized JWT validation and API gateway

# API Management Service
resource "azurerm_api_management" "core" {
  name                = "apim-${var.resource_name_prefix}-${var.environment}-${random_string.suffix.result}"
  location            = azurerm_resource_group.core.location
  resource_group_name = azurerm_resource_group.core.name
  publisher_name      = var.apim_publisher_name
  publisher_email     = var.apim_publisher_email

  # Use Developer tier for dev/test, change to Standard or Premium for production
  sku_name = var.apim_sku_name

  identity {
    type = "SystemAssigned"
  }

  # Virtual network integration - Internal mode (private IP only, accessible from VNet)
  virtual_network_type = "Internal"

  virtual_network_configuration {
    subnet_id = azurerm_subnet.apim.id
  }

  tags = local.common_tags
}

# API Management API for your backend services
resource "azurerm_api_management_api" "main" {
  name                = "main-api"
  resource_group_name = azurerm_resource_group.core.name
  api_management_name = azurerm_api_management.core.name
  revision            = "1"
  display_name        = "Main API"
  path                = ""
  protocols           = ["https"]

  subscription_required = false

  # APIM will route directly to Container Apps private endpoints
  service_url = "https://${azurerm_container_app.api_service.ingress[0].fqdn}"
}

# API Management Policy - JWT Validation
resource "azurerm_api_management_api_policy" "main" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <!-- Validate JWT tokens from Azure AD -->
        <validate-jwt header-name="Authorization" failed-validation-httpcode="401" failed-validation-error-message="Unauthorized. Valid JWT token required.">
            <openid-config url="https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0/.well-known/openid-configuration" />
            <audiences>
                <audience>${azuread_application.main.client_id}</audience>
            </audiences>
            <issuers>
                <issuer>https://login.microsoftonline.com/${data.azuread_client_config.current.tenant_id}/v2.0</issuer>
            </issuers>
            <required-claims>
                <claim name="aud" match="any">
                    <value>${azuread_application.main.client_id}</value>
                </claim>
            </required-claims>
        </validate-jwt>

        <!-- Route directly to Container Apps based on path -->
        <choose>
            <when condition="@(context.Request.Url.Path.StartsWith("/api"))">
                <set-backend-service base-url="https://${azurerm_container_app.api_service.ingress[0].fqdn}" />
            </when>
            <when condition="@(context.Request.Url.Path.StartsWith("/notify") || context.Request.Url.Path.StartsWith("/ws"))">
                <set-backend-service base-url="https://${azurerm_container_app.notification_service.ingress[0].fqdn}" />
            </when>
            <otherwise>
                <set-backend-service base-url="https://${azurerm_container_app.ui_service.ingress[0].fqdn}" />
            </otherwise>
        </choose>

        <!-- Forward original host header -->
        <set-header name="X-Forwarded-Host" exists-action="override">
            <value>@(context.Request.OriginalUrl.Host)</value>
        </set-header>

        <!-- Add user claims as headers for backend services -->
        <set-header name="X-User-Email" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","")
                .Replace("Bearer ", "")
                .AsJwt()?.Claims.GetValueOrDefault("email", ""))</value>
        </set-header>
        <set-header name="X-User-OID" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","")
                .Replace("Bearer ", "")
                .AsJwt()?.Claims.GetValueOrDefault("oid", ""))</value>
        </set-header>
        <set-header name="X-User-Name" exists-action="override">
            <value>@(context.Request.Headers.GetValueOrDefault("Authorization","")
                .Replace("Bearer ", "")
                .AsJwt()?.Claims.GetValueOrDefault("name", ""))</value>
        </set-header>

        <!-- CORS policy -->
        <cors allow-credentials="true">
            <allowed-origins>
                <origin>*</origin>
            </allowed-origins>
            <allowed-methods>
                <method>GET</method>
                <method>POST</method>
                <method>PUT</method>
                <method>DELETE</method>
                <method>OPTIONS</method>
            </allowed-methods>
            <allowed-headers>
                <header>*</header>
            </allowed-headers>
            <expose-headers>
                <header>*</header>
            </expose-headers>
        </cors>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML

  depends_on = [
    azurerm_api_management_api.main
  ]
}

# API Operations - Define your API endpoints

# Health check endpoint (no JWT required)
resource "azurerm_api_management_api_operation" "health" {
  operation_id        = "health"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "Health Check"
  method              = "GET"
  url_template        = "/health"
  description         = "Health check endpoint"
}

# Override policy for health endpoint - no JWT validation
resource "azurerm_api_management_api_operation_policy" "health" {
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  operation_id        = azurerm_api_management_api_operation.health.operation_id

  xml_content = <<XML
<policies>
    <inbound>
        <base />
        <!-- Skip JWT validation for health check -->
        <return-response>
            <set-status code="200" />
            <set-header name="Content-Type" exists-action="override">
                <value>application/json</value>
            </set-header>
            <set-body>{"status":"healthy"}</set-body>
        </return-response>
    </inbound>
    <backend>
        <base />
    </backend>
    <outbound>
        <base />
    </outbound>
    <on-error>
        <base />
    </on-error>
</policies>
XML
}

# Catch-all operation for all other endpoints (JWT required)
resource "azurerm_api_management_api_operation" "catchall" {
  operation_id        = "catchall"
  api_name            = azurerm_api_management_api.main.name
  api_management_name = azurerm_api_management.core.name
  resource_group_name = azurerm_resource_group.core.name
  display_name        = "All Endpoints"
  method              = "*"
  url_template        = "/*"
  description         = "All API endpoints (JWT required)"
}
