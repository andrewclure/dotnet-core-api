locals {
  common_tags                         = { azd-env-name : var.environment_name }
  tags = merge(local.common_tags, var.tags)
  sha                          = base64encode(sha256("${var.environment_name}${var.location}${data.azurerm_client_config.current.subscription_id}"))
  resource_token               = substr(replace(lower(local.sha), "[^A-Za-z0-9_]", ""), 0, 13)
}

resource "azurecaf_name" "rg_name" {
  name          = var.environment_name
  resource_type = "azurerm_resource_group"
  random_length = 0
  clean_input   = true
}

# Deploy resource group
resource "azurerm_resource_group" "primary_rg" {
  name     = azurecaf_name.rg_name.result
  location = var.location
  // Tag the resource group with the azd environment name
  // This should also be applied to all resources created in this module
  tags = local.tags
}

# Add resources to be provisioned below.
# To learn more, https://developer.hashicorp.com/terraform/tutorials/azure-get-started/azure-change
# Note that a tag:
#   azd-service-name: "<service name in azure.yaml>"
# should be applied to targeted service host resources, such as:
#  azurerm_linux_web_app, azurerm_windows_web_app for appservice
#  azurerm_function_app for function


resource "azurerm_service_plan" "win_uks" {
  name                = "asp-dev-win-uks-01"
  resource_group_name = azurerm_resource_group.primary_rg.name
  location            = azurerm_resource_group.primary_rg.location
  os_type             = "Windows"
  sku_name            = "S1"
  tags = local.tags
}

resource "azurerm_windows_web_app" "app_uks" {
  name                = "app-win-dev-uks"
  resource_group_name = azurerm_resource_group.primary_rg.name
  location            = azurerm_resource_group.primary_rg.location
  service_plan_id     = azurerm_service_plan.win_uks.id
  tags = local.tags
  
  app_settings = {
    #API_URL = "${azurerm_windows_web_app.api_uks.default_hostname}"
  }

  site_config {}
}

resource "azurerm_app_service_source_control" "app_uks" {
  app_id        = azurerm_windows_web_app.app_uks.id
  repo_url      = "https://github.com/andrewclure/dotnet-core-api"
  branch        = "main"
}
