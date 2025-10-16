# Azure AD App Registration for JWT validation

# Azure AD Application Registration
resource "azuread_application" "main" {
  display_name = "app-${var.resource_name_prefix}-${var.environment}"
  owners       = [data.azuread_client_config.current.object_id]

  # Enable group membership claims in the token
  group_membership_claims = ["SecurityGroup", "DirectoryRole"]

  # Optional claims - include groups in both access tokens and ID tokens
  optional_claims {
    access_token {
      name = "groups"
    }

    id_token {
      name = "groups"
    }
  }

  # Single Page Application configuration (Authorization Code Flow with PKCE)
  single_page_application {
    redirect_uris = concat(
      var.custom_domain != "" ? [
        "https://${var.custom_domain}/",
        "https://${var.custom_domain}/auth/callback",
        ] : [
        "https://${azurerm_public_ip.app_gateway.ip_address}/",
        "https://${azurerm_public_ip.app_gateway.ip_address}/auth/callback",
      ],
      [
        "http://localhost:5173/",              # Vite dev server
        "http://localhost:5173/auth/callback", # Vite callback
      ]
    )
  }

  # Required resource access (Microsoft Graph)
  required_resource_access {
    resource_app_id = "00000003-0000-0000-c000-000000000000" # Microsoft Graph

    resource_access {
      id   = "e1fe6dd8-ba31-4d61-89e7-88639da4683d" # User.Read
      type = "Scope"
    }

    resource_access {
      id   = "37f7f235-527c-4136-accd-4a02d197296e" # openid
      type = "Scope"
    }

    resource_access {
      id   = "7427e0e9-2fba-42fe-b0c0-848c9e6a8182" # offline_access
      type = "Scope"
    }

    resource_access {
      id   = "64a6cdd6-aab1-4aaf-94b8-3cc8405e90d0" # email
      type = "Scope"
    }

    resource_access {
      id   = "14dad69e-099b-42c9-810b-d002981feec1" # profile
      type = "Scope"
    }

    resource_access {
      id   = "7ab1d382-f21e-4acd-a863-ba3e13f7da61" # Directory.Read.All (to read group details)
      type = "Scope"
    }
  }

  # API permissions exposed by this application
  api {
    requested_access_token_version = 2

    oauth2_permission_scope {
      admin_consent_description  = "Allow the application to access the API on behalf of the signed-in user"
      admin_consent_display_name = "Access API"
      enabled                    = true
      id                         = "96183846-204b-4b43-82e1-5d2222eb4b9b"
      type                       = "User"
      user_consent_description   = "Allow the application to access the API on your behalf"
      user_consent_display_name  = "Access API"
      value                      = "api.access"
    }
  }

  # Note: identifier_uris will be set separately to avoid circular dependency

  tags = [
    var.environment,
    "terraform-managed"
  ]
}

# Update the application to set identifier_uris (must be done after app is created)
resource "azuread_application_identifier_uri" "main" {
  application_id = azuread_application.main.id
  identifier_uri = "api://${azuread_application.main.client_id}"
}

# Service Principal for the App Registration
resource "azuread_service_principal" "main" {
  client_id                    = azuread_application.main.client_id
  app_role_assignment_required = false
  owners                       = [data.azuread_client_config.current.object_id]

  tags = [
    var.environment,
    "terraform-managed"
  ]
}

# Data source for current Azure AD config
data "azuread_client_config" "current" {}
