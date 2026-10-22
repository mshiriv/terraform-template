# Foundation (Azure): resource group, VNet, subnets, NSGs
#
# Subscription: staging. Region: westeurope.
# Azure has no provider-level default_tags, so every resource sets local.tags.

locals {
  name = "${var.environment}-${var.location}"

  tags = {
    ManagedBy   = "terraform"
    Repository  = "YOUR_GITHUB_ORG/YOUR_GITHUB_REPO"
    Environment = var.environment
    Region      = var.location
    Product     = "shared"
    Tier        = "foundation"
  }

  # /20 per subnet, same shape as the AWS CIDR plan.
  subnets = {
    app  = cidrsubnet(var.vnet_cidr, 4, 0)
    data = cidrsubnet(var.vnet_cidr, 4, 1)
  }
}

resource "azurerm_resource_group" "network" {
  name     = "rg-${local.name}-network"
  location = var.location
  tags     = local.tags
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${local.name}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  address_space       = [var.vnet_cidr]
  tags                = local.tags
}

resource "azurerm_subnet" "subnets" {
  for_each = local.subnets

  name                 = "snet-${each.key}"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.this.name
  address_prefixes     = [each.value]

  # No implicit outbound internet: egress must go through an explicit NAT
  # gateway / firewall when one is added.
  default_outbound_access_enabled = false
}

# One NSG per subnet. With no custom rules, Azure's defaults allow intra-VNet
# traffic and deny inbound from the internet.
resource "azurerm_network_security_group" "subnets" {
  for_each = local.subnets

  name                = "nsg-${local.name}-${each.key}"
  location            = azurerm_resource_group.network.location
  resource_group_name = azurerm_resource_group.network.name
  tags                = local.tags
}

resource "azurerm_subnet_network_security_group_association" "subnets" {
  for_each = local.subnets

  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.subnets[each.key].id
}
