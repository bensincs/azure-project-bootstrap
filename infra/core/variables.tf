variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
}

variable "subscription_id" {
  description = "Azure subscription ID"
  type        = string
}

variable "resource_name_prefix" {
  description = "Prefix for resource names"
  type        = string
  default     = "core"
}

# Bootstrap Key Vault (from bootstrap stack)
variable "key_vault_id" {
  description = "Bootstrap Key Vault resource ID (from bootstrap)"
  type        = string
}

variable "key_vault_name" {
  description = "Bootstrap Key Vault name (from bootstrap)"
  type        = string
}

variable "key_vault_uri" {
  description = "Bootstrap Key Vault URI (from bootstrap)"
  type        = string
}

variable "app_gateway_ssl_certificate_id" {
  description = "Application Gateway SSL certificate secret ID (from bootstrap Key Vault)"
  type        = string
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# VPN Gateway Configuration
variable "enable_vpn_gateway" {
  description = "Enable VPN Gateway for secure remote access"
  type        = bool
  default     = false
}
