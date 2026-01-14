# ---------------------------------------------------------------------------------------------------------------------
# NETWORKING MODULE
# Thin wrapper around Azure Verified Module for Virtual Network
# Creates VNet with AKS subnet and private endpoints subnet
# ---------------------------------------------------------------------------------------------------------------------

module "vnet" {
  source  = "Azure/avm-res-network-virtualnetwork/azurerm"
  version = "~> 0.17"

  name          = var.vnet_name
  parent_id     = var.resource_group_id
  location      = var.location
  address_space = [var.address_space]

  subnets = {
    aks = {
      name             = "${var.name_prefix}-aks-subnet"
      address_prefixes = [var.aks_subnet_cidr]
    }
    private_endpoints = {
      name             = "${var.name_prefix}-pe-subnet"
      address_prefixes = [var.private_endpoints_subnet_cidr]
    }
  }

  tags = var.tags
}

# ---------------------------------------------------------------------------------------------------------------------
# NSG FOR AKS SUBNET
# ---------------------------------------------------------------------------------------------------------------------

resource "azurerm_network_security_group" "aks" {
  name                = "${var.name_prefix}-aks-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name

  # Allow HTTPS inbound (for ingress controller)
  security_rule {
    name                       = "AllowHTTPS"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "443"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow HTTP inbound (redirect to HTTPS)
  security_rule {
    name                       = "AllowHTTP"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  # Allow VNet internal traffic
  security_rule {
    name                       = "AllowVNetInternal"
    priority                   = 200
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "VirtualNetwork"
    destination_address_prefix = "VirtualNetwork"
  }

  # Allow Azure Load Balancer
  security_rule {
    name                       = "AllowAzureLoadBalancer"
    priority                   = 300
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "*"
    source_address_prefix      = "AzureLoadBalancer"
    destination_address_prefix = "*"
  }

  tags = var.tags
}

resource "azurerm_subnet_network_security_group_association" "aks" {
  subnet_id                 = module.vnet.subnets["aks"].resource_id
  network_security_group_id = azurerm_network_security_group.aks.id
}
