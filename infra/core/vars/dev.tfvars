# Auto-generated tfvars for core/dev
# Edit this file to customize your environment-specific variables

environment     = "dev"
location        = "westeurope"
subscription_id = "dd78ec54-2f00-41fc-8055-8c1f2ad66a1d"

# Add your custom variables below this line
# Example:
# resource_name_prefix = "dev"
# tags = {
#   Environment = "dev"
#   ManagedBy   = "Terraform"
# }

# API Management Configuration
apim_publisher_email = "admin@example.com" # Update with your email

# VPN Gateway Configuration
# Set to true to deploy VPN Gateway for secure remote access (takes 30-45 minutes to provision)
enable_vpn_gateway = false
