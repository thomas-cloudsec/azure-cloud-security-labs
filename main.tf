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

# 1. Create a Public IP Address so the VM can be reached from the internet
resource "azurerm_public_ip" "honeypot_pip" {
  name                = "pip-honeypot"
  location            = azurerm_resource_group.lab_rg.location
  resource_group_name = azurerm_resource_group.lab_rg.name
  allocation_method   = "Dynamic"
}

# 2. Create the Network Interface Card (NIC)
resource "azurerm_network_interface" "honeypot_nic" {
  name                = "nic-honeypot"
  location            = azurerm_resource_group.lab_rg.location
  resource_group_name = azurerm_resource_group.lab_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.lab_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.honeypot_pip.id
  }
}

# 3. Connect the Security Group (NSG) to our Network Interface (NIC)
resource "azurerm_network_interface_security_group_association" "nic_nsg_link" {
  network_interface_id      = azurerm_network_interface.honeypot_nic.id
  network_security_group_id = azurerm_network_security_group.lab_nsg.id
}

# 4. Create an SSH Key Pair for secure admin authentication
resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# 5. Deploy the Ubuntu Linux Honeypot Virtual Machine
resource "azurerm_linux_virtual_machine" "honeypot_vm" {
  name                = "vm-honeypot-v1"
  resource_group_name = azurerm_resource_group.lab_rg.name
  location            = azurerm_resource_group.lab_rg.location
  size                = "Standard_B1s" # Low-cost burstable
  admin_username      = "attacker_bait"

  network_interface_ids = [
    azurerm_network_interface.honeypot_nic.id,
  ]

  admin_ssh_key {
    username   = "attacker_bait"
    public_key = tls_private_key.ssh_key.public_key_openssh
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }
}

# Output the Public IP Address when deployment finishes
output "honeypot_public_ip" {
  value       = azurerm_public_ip.honeypot_pip.ip_address
  description = "The public IP address of the honeypot VM."
}