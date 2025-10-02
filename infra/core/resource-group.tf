# Random suffix for globally unique names
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

# Resource Group
resource "azurerm_resource_group" "core" {
  name     = "rg-${var.resource_name_prefix}-${var.environment}"
  location = var.location
  tags     = local.common_tags
}
