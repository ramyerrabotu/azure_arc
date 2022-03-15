variable "resource_group_name" {
  type        = string
  description = "Azure Resource Group"
}

variable "virtual_network_name" {
  type        = string
  description = "ArcBox vNET name."
}

variable "subnet_name" {
  type        = string
  description = "ArcBox subnet name."
}

variable "workspace_name" {
  type        = string
  description = "Log Analytics workspace name."
}

variable "deploy_bastion" {
  type       = string
  description = "Choice to deploy Bastion to connect to the client VM"
  default = "No"
  validation {
    condition = contains(["Yes","No"],var.deploy_bastion)
    error_message = "Valid options for Bastion deployment: 'Yes', and 'No'."
  }
}
locals {
  vnet_address_space    = ["172.16.0.0/16"]
  subnet_address_prefix = "172.16.1.0/24"
  solutions             = ["Updates", "VMInsights", "ChangeTracking", "Security"]
  bastionSubnetName     = "AzureBastionSubnet"
  bastionSubnetRef      = "${var.virtual_network_name.id}/subnets/${local.bastionSubnetName}"
  bastionName           = "ArcBox-Bastion"
  bastionSubnetIpPrefix = "172.16.3.0/27"
  bastionPublicIpAddressName = "${local.bastionName}-PIP"
}

resource "random_string" "random" {
  length  = 13
  special = false
  number  = true
  upper   = false
}

data "azurerm_resource_group" "rg" {
  name = var.resource_group_name
}

resource "azurerm_virtual_network" "vnet" {
  name                = var.virtual_network_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  address_space       = local.vnet_address_space

  subnet {
    name           = var.subnet_name
    address_prefix = local.subnet_address_prefix
  }

  subnet {
    name           = "AzureBastionSubnet"
    address_prefix = local.bastionSubnetIpPrefix
  }
}

resource "azurerm_log_analytics_workspace" "workspace" {
  name                = var.workspace_name
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku                 = "PerGB2018"
  retention_in_days   = 30
}

resource "azurerm_log_analytics_solution" "update_solution" {
  for_each              = toset(local.solutions)
  solution_name         = "${each.value}"
  location              = data.azurerm_resource_group.rg.location
  resource_group_name   = data.azurerm_resource_group.rg.name
  workspace_resource_id = azurerm_log_analytics_workspace.workspace.id
  workspace_name        = azurerm_log_analytics_workspace.workspace.name

  plan {
    publisher = "Microsoft"
    product   = "OMSGallery/${each.value}"
  }
}

resource "azurerm_automation_account" "automation" {
  name                = "ArcBox-Automation-${random_string.random.result}"
  location            = data.azurerm_resource_group.rg.location
  resource_group_name = data.azurerm_resource_group.rg.name
  sku_name            = "Basic"
}

resource "azurerm_log_analytics_linked_service" "linked_service" {
  resource_group_name = data.azurerm_resource_group.rg.name
  workspace_id        = azurerm_log_analytics_workspace.workspace.id
  read_access_id      = azurerm_automation_account.automation.id
}

resource "azurerm_public_ip" "publicIpAddress" {
  count               = var.deploy_bastion == "Yes" ? 1: 0
  name                = local.bastionPublicIpAddressName
  location            = var.location
  allocation_method   = "Static"
  ip_version          = "IPv4"
  idle_timeout_in_minutes = 4
  sku                 = "Standard"

}

resource "azurerm_bastion_host" "bastionHost" {
  name                = local.bastionName
  location            = var.location
  ip_configuration {
    public_ip_address_id = azurerm_public_ip.publicIpAddress.id
    subnet_id = local.bastionSubnetRef
  }

}
output "workspace_id" {
  value = azurerm_log_analytics_workspace.workspace.id
}
