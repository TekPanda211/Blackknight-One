terraform {
  required_version = ">= 1.5"

  required_providers {
    azuread = {
      source  = "hashicorp/azuread"
      version = "~> 3.0"
    }
  }
}

provider "azuread" {}

data "azuread_client_config" "current" {}

output "tenant_id" {
  value = data.azuread_client_config.current.tenant_id
}

output "client_id" {
  value = data.azuread_client_config.current.client_id
}

output "object_id" {
  value = data.azuread_client_config.current.object_id
}