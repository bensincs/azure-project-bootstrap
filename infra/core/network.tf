# Virtual Network
resource "azurerm_virtual_network" "core" {
  name                = "vnet-${var.resource_name_prefix}-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location
  address_space       = ["10.0.0.0/16"]

  tags = local.common_tags
}

# Subnet for Container Apps Environment
resource "azurerm_subnet" "container_apps" {
  name                 = "snet-container-apps"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.0.0/23"]

  delegation {
    name = "container-apps-delegation"

    service_delegation {
      name = "Microsoft.App/environments"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# Subnet for Private Endpoints
resource "azurerm_subnet" "private_endpoints" {
  name                 = "snet-private-endpoints"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Subnet for VPN Gateway
resource "azurerm_subnet" "gateway" {
  name                 = "GatewaySubnet" # Name must be exactly "GatewaySubnet"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.3.0/27"]
}

# Subnet for DNS Resolver Inbound Endpoint
resource "azurerm_subnet" "dns_resolver_inbound" {
  name                 = "snet-dns-resolver-inbound"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.4.0/28"]

  delegation {
    name = "dns-resolver-delegation"

    service_delegation {
      name = "Microsoft.Network/dnsResolvers"
      actions = [
        "Microsoft.Network/virtualNetworks/subnets/join/action"
      ]
    }
  }
}

# ============================================================================
# APPLICATION GATEWAY - Subnet and Network Security Group
# ============================================================================
# App Gateway is the public entry point (Internet-facing)
# - Receives HTTPS/HTTP from Internet
# - Routes to APIM (internal, private IP)
# - Handles SSL termination

# Subnet for Application Gateway
resource "azurerm_subnet" "app_gateway" {
  name                 = "snet-appgw-${var.environment}"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Network Security Group for Application Gateway
resource "azurerm_network_security_group" "app_gateway" {
  name                = "nsg-appgw-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}

# NSG Rule: Allow inbound HTTPS from Internet (public access)
resource "azurerm_network_security_rule" "app_gateway_https_internet" {
  name                        = "AllowHTTPSInbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}

# NSG Rule: Allow inbound HTTP from Internet (for redirect to HTTPS)
resource "azurerm_network_security_rule" "app_gateway_http_internet" {
  name                        = "AllowHTTPInbound"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}

# NSG Rule: Allow Azure infrastructure communication (REQUIRED for v2 SKU)
resource "azurerm_network_security_rule" "app_gateway_infrastructure" {
  name                        = "AllowGatewayManagerInbound"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}

# NSG Rule: Allow Azure Load Balancer health probes
resource "azurerm_network_security_rule" "app_gateway_load_balancer" {
  name                        = "AllowAzureLoadBalancerInbound"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.app_gateway.name
}

# Associate NSG with App Gateway subnet
resource "azurerm_subnet_network_security_group_association" "app_gateway" {
  subnet_id                 = azurerm_subnet.app_gateway.id
  network_security_group_id = azurerm_network_security_group.app_gateway.id

  depends_on = [
    azurerm_network_security_rule.app_gateway_https_internet,
    azurerm_network_security_rule.app_gateway_http_internet,
    azurerm_network_security_rule.app_gateway_infrastructure,
    azurerm_network_security_rule.app_gateway_load_balancer,
  ]
}

# ============================================================================
# API MANAGEMENT (APIM) - Subnet and Network Security Group
# ============================================================================
# APIM is internal-only (VNet mode, private IP)
# - Receives HTTPS from App Gateway (10.0.5.0/24)
# - Validates JWT tokens from Azure AD
# - Routes to Container Apps (10.0.0.0/23)

# Subnet for APIM
resource "azurerm_subnet" "apim" {
  name                 = "snet-apim-${var.environment}"
  resource_group_name  = azurerm_resource_group.core.name
  virtual_network_name = azurerm_virtual_network.core.name
  address_prefixes     = ["10.0.6.0/27"]
}

# Network Security Group for APIM
resource "azurerm_network_security_group" "apim" {
  name                = "nsg-apim-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}

# NSG Rule: Allow inbound management endpoint
resource "azurerm_network_security_rule" "apim_management" {
  name                        = "AllowAPIMManagement"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "3443"
  source_address_prefix       = "ApiManagement"
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# NSG Rule: Allow inbound HTTPS from Application Gateway to APIM
resource "azurerm_network_security_rule" "apim_https_from_appgw" {
  name                        = "AllowHTTPSFromAppGateway"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.5.0/24" # Application Gateway subnet
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# NSG Rule: Allow inbound HTTPS from VPN clients to APIM
resource "azurerm_network_security_rule" "apim_https_from_vpn" {
  name                        = "AllowHTTPSFromVPN"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "172.16.0.0/24" # VPN client address pool
  destination_address_prefix  = "VirtualNetwork"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# NSG Rule: Allow outbound to Storage
resource "azurerm_network_security_rule" "apim_storage" {
  name                        = "AllowStorageOutbound"
  priority                    = 100
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "Storage"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# NSG Rule: Allow outbound to SQL
resource "azurerm_network_security_rule" "apim_sql" {
  name                        = "AllowSQLOutbound"
  priority                    = 110
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "1433"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "Sql"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# NSG Rule: Allow outbound to Container Apps
resource "azurerm_network_security_rule" "apim_to_container_apps" {
  name                        = "AllowContainerAppsOutbound"
  priority                    = 120
  direction                   = "Outbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "10.0.0.0/23" # Container Apps subnet
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.apim.name
}

# Associate NSG with APIM Subnet
resource "azurerm_subnet_network_security_group_association" "apim" {
  subnet_id                 = azurerm_subnet.apim.id
  network_security_group_id = azurerm_network_security_group.apim.id
}

# ============================================================================
# CONTAINER APPS - Network Security Group
# ============================================================================
# Container Apps are fully private (internal load balancer)
# - Only accepts HTTPS from APIM (10.0.6.0/27)
# - No direct Internet or App Gateway access
# - Subnet: 10.0.0.0/23 (defined earlier with delegation)

# Network Security Group for Container Apps
resource "azurerm_network_security_group" "container_apps" {
  name                = "nsg-container-apps-${var.environment}"
  resource_group_name = azurerm_resource_group.core.name
  location            = azurerm_resource_group.core.location

  tags = local.common_tags
}
# NSG Rule: Allow inbound from APIM subnet to Container Apps
resource "azurerm_network_security_rule" "container_apps_from_apim" {
  name                        = "AllowAPIMInbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "10.0.6.0/27" # APIM subnet
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.core.name
  network_security_group_name = azurerm_network_security_group.container_apps.name
}

# Associate NSG with Container Apps Subnet
resource "azurerm_subnet_network_security_group_association" "container_apps" {
  subnet_id                 = azurerm_subnet.container_apps.id
  network_security_group_id = azurerm_network_security_group.container_apps.id
}

# Configure VNet DNS to use Private DNS Resolver
# This ensures VPN clients and VNet resources resolve private endpoints correctly
resource "azurerm_virtual_network_dns_servers" "core" {
  virtual_network_id = azurerm_virtual_network.core.id
  dns_servers = [
    azurerm_private_dns_resolver_inbound_endpoint.core.ip_configurations[0].private_ip_address
  ]

  depends_on = [
    azurerm_private_dns_resolver_inbound_endpoint.core
  ]
}
