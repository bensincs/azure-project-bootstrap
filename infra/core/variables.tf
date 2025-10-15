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
