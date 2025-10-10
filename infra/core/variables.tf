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

# API Management Configuration
variable "apim_publisher_name" {
  description = "Publisher name for API Management"
  type        = string
  default     = "MyCompany"
}

variable "apim_publisher_email" {
  description = "Publisher email for API Management"
  type        = string
}

variable "apim_sku_name" {
  description = "SKU for API Management (Developer_1, Basic_1, Standard_1, Premium_1)"
  type        = string
  default     = "Developer_1"
}

variable "apim_custom_domain_enabled" {
  description = "Enable custom domain for API Management"
  type        = bool
  default     = false
}

variable "apim_custom_domain" {
  description = "Custom domain for API Management gateway"
  type        = string
  default     = ""
}
