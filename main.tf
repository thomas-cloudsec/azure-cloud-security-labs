# 1. Define the Required Providers and Versions
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
}

# 2. Configure the Microsoft Azure Provider
provider "azurerm" {
  skip_provider_registration = true
  features {}
}

# 3. Create the Lab Resource Group (Observation: The Foundational 
#Container)
resource "azurerm_resource_group" "lab_rg" {
  name     = "rg-lab-secret-sweep"
  location = "northeurope" # Set to North Europe (Ireland data center)
}

# 4. Create a Virtual Network
resource "azurerm_virtual_network" "lab_vnet" {
    name                = "vnet-security-lab"
    address_space       = ["10.0.0.0/16"]
    location            = azurerm_resource_group.lab_rg.location
    resource_group_name = azurerm_resource_group.lab_rg.name
}

# 5. Create a Subnet for the Honeypot VM
resource "azurerm_subnet" "lab_subnet" {
    name                    = "sub-honeypot"
    resource_group_name     = azurerm_resource_group.lab_rg.name
    virtual_network_name    = azurerm_virtual_network.lab_vnet.name
    address_prefixes        = ["10.0.1.0/24"]
}

# 6. Creating a Network Security Grup (Firewall)
resource "azurerm_network_security_group" "lab-nsg" {
    name                    = "nsg-honeypot"
    location                = azurerm_resource_group.lab_rg.location
    resource_group_name     = azurerm_resource_group.lab_rg.name

# RULE to allow SSH from the internet for testing/attack simulation
security_rule {
    name                        = "Allow-SSH-Inbound"
    priority                    = 1000
    direction                   = "Inbound"
    access                      = "Allow"
    protocol                    = "Tcp"
    source_port_range           = "*"
    destination_port_range      = "22"
    source_address_prefix       = "*"
    destination_address_prefix  = "*"
 }
}