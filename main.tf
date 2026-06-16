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
  skip_provider_registrations = "true"
  features {}
}

# 3. Create the Lab Resource Group (Observation: The Foundational 
#Container)
resource "azurerm_resource_group" "lab_rg" {
  name     = "rg-lab-secret-sweep"
  location = "northeurope" # Set to North Europe (Ireland data center)
}
