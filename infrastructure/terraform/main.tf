terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.0"
    }
  }
  required_version = ">= 1.0"
}

provider "azurerm" {
  features {}
}

# Resource Group
resource "azurerm_resource_group" "main" {
  name     = var.resource_group_name
  location = var.location
}

# AKS Cluster (multi-region HA prep; add West Europe secondary later)
resource "azurerm_kubernetes_cluster" "aks" {
  name                = "microservices-aks"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "microservices"

  default_node_pool {
    name       = "default"
    node_count = 2
    vm_size    = "Standard_D2_v3" # Available in West US 2 (general-purpose, 2 vCPU, 8  GB RAM)
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Demo"
  }
}

# Event Hubs Namespace (for distributed messaging, Kafka proxy)
resource "azurerm_eventhub_namespace" "ehub" {
  name                = "microservices-events"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  sku                 = "Standard"
  capacity            = 1
}

resource "azurerm_eventhub" "order_events" {
  name                = "order-events"
  namespace_name      = azurerm_eventhub_namespace.ehub.name
  resource_group_name = azurerm_resource_group.main.name
  partition_count     = 2
  message_retention   = 1
}

# SQL Managed Instance (HA, disaster-recoverable)
resource "azurerm_mssql_server" "sql" {
  name                         = "microservices-sql"
  resource_group_name          = azurerm_resource_group.main.name
  location                     = azurerm_resource_group.main.location
  version                      = "12.0"
  administrator_login          = "adminuser"
  administrator_login_password = "SecureP@ssw0rd123!"  # Change in tfvars!
}

# Outputs
output "aks_cluster_name" {
  value = azurerm_kubernetes_cluster.aks.name
}

output "eventhub_namespace" {
  value = azurerm_eventhub_namespace.ehub.name
}

output "sql_server_fqdn" {
  value = azurerm_mssql_server.sql.fully_qualified_domain_name
}
