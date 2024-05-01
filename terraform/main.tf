resource "random_pet" "rg_name" {
  prefix = var.resource_group_name_prefix
}

resource "azurerm_resource_group" "rg" {
  name     = random_pet.rg_name.id
  location = var.resource_group_location
}

resource "random_string" "azurerm_api_management_name" {
  length  = 13
  lower   = true
  numeric = false
  special = false
  upper   = false
}

resource "azurerm_api_management" "apim" {
  name                = "example-apim-${random_string.azurerm_api_management_name.result}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  publisher_email     = var.publisher_email
  publisher_name      = var.publisher_name
  sku_name            = "${var.sku}_${var.sku_count}"
}

resource "azurerm_api_management_api" "example" {
  name                = "example-api"
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  display_name = "FHIR API"
  revision     = "1"

  subscription_required = false
  protocols             = ["http", "https"]
  path                  = ""

  import {
    content_format = "openapi+json"
    content_value  = file("${path.module}/swagger.json")
  }
}

resource "azurerm_api_management_api_policy" "example" {
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name

  api_name    = azurerm_api_management_api.example.name
  xml_content = file("${path.module}/policies/base_apim_policy.xml")
}

resource "azurerm_api_management_api_operation_policy" "example" {
  for_each = {for op in local.operations : op.operationId => op}

  api_management_name = azurerm_api_management.apim.name
  resource_group_name = azurerm_resource_group.rg.name
  api_name            = azurerm_api_management_api.example.name

  operation_id = each.value.operationId
  xml_content  = each.value.policy
}