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

        <!-- Skip JWT validation for UI requests (/, /assets/*, /favicon.ico, etc.) and health endpoints -->
        <!-- JWT is required for /api/* and /notify/* and /ws/* (except health endpoints) -->
        <choose>
            <when condition="@(context.Request.Url.Path.Equals("/health") || context.Request.Url.Path.Equals("/api/health") || context.Request.Url.Path.Equals("/notify/health"))">
                <!-- Health endpoints - no JWT validation required -->
            </when>
            <when condition="@(context.Request.Url.Path.StartsWith("/api") || context.Request.Url.Path.StartsWith("/notify") || context.Request.Url.Path.StartsWith("/ws"))">
                <!-- Validate JWT tokens from Azure AD for API and notification endpoints -->
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

                <!-- Add user claims as headers for authenticated requests -->
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

                <!-- Add user groups for RBAC -->
                <set-header name="X-User-Groups" exists-action="override">
                    <value>@{
                        var jwt = context.Request.Headers.GetValueOrDefault("Authorization","").Replace("Bearer ", "").AsJwt();
                        var groups = jwt?.Claims.GetValueOrDefault("groups", "");
                        return groups;
                    }</value>
                </set-header>

                <!-- Add user roles (if using App Roles) -->
                <set-header name="X-User-Roles" exists-action="override">
                    <value>@{
                        var jwt = context.Request.Headers.GetValueOrDefault("Authorization","").Replace("Bearer ", "").AsJwt();
                        var roles = jwt?.Claims.GetValueOrDefault("roles", "");
                        return roles;
                    }</value>
                </set-header>
            </when>
            <otherwise>
                <!-- UI requests - no JWT validation, no user headers -->
            </otherwise>
        </choose>

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
