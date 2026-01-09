resource "azurerm_resource_group" "rg" {
  name     = local.resource_group_name
  location = "westus2"
}

resource "azurerm_static_web_app" "crc_stat_site" {
  name                = "crc-stat-site"
  resource_group_name = local.resource_group_name
  location            = local.resource_location
  repository_branch = "main"
  repository_url = "https://github.com/AcceptableSpring1/super-palm-tree-CRC.git"
  repository_token = var.github_token

}

resource "azurerm_cdn_frontdoor_profile" "crc_frontdoor" {
  name                = "crcfrontdoor"
  resource_group_name = local.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
}

resource "azurerm_cdn_frontdoor_origin_group" "crc_origin_group" {
  name                     = "crc-origin-group"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.crc_frontdoor.id
  session_affinity_enabled = false

  restore_traffic_time_to_healed_or_new_endpoint_in_minutes = 10

  health_probe {

    interval_in_seconds = 240
    path                = "/"
    protocol            = "Https"
    request_type        = "HEAD"
  }

  load_balancing {
    additional_latency_in_milliseconds = 0
    sample_size                        = 4
    successful_samples_required        = 3
  }
}

resource "azurerm_cdn_frontdoor_origin" "crc_storage" {
  name                          = "origin-storage"
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.crc_origin_group.id
  enabled                       = true
  host_name                     = "lemon-glacier-0672f581e.1.azurestaticapps.net" # static site endpoint

  certificate_name_check_enabled = false

}

resource "azurerm_cdn_frontdoor_endpoint" "crc-endp" {
  name                     = "fde-crc-site"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.crc_frontdoor.id
}

resource "azurerm_cdn_frontdoor_custom_domain" "crc_custom_domain" {
  name                     = "zays-project-site"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.crc_frontdoor.id
  host_name                = "www.zaysprojectsite.com"

  tls {
    certificate_type    = "ManagedCertificate"
  }
}

resource "azurerm_cdn_frontdoor_route" "crc_fdr_route" {
  name                          = "crc-route"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.crc-endp.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.crc_origin_group.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.crc_storage.id]
  enabled                       = true
  patterns_to_match     = ["/*"]
  supported_protocols   = ["Http", "Https"]
  forwarding_protocol   = "MatchRequest"

  cdn_frontdoor_custom_domain_ids = [azurerm_cdn_frontdoor_custom_domain.crc_custom_domain.id]

}

resource "azurerm_cdn_frontdoor_custom_domain_association" "www_to_route" {
  cdn_frontdoor_custom_domain_id = azurerm_cdn_frontdoor_custom_domain.crc_custom_domain.id
  cdn_frontdoor_route_ids        = [azurerm_cdn_frontdoor_route.crc_fdr_route.id]

}

resource "azurerm_cosmosdb_account" "crc_cosmosdb_acc" {
  name                = "crc-cosmosdb-acc"
  location            = local.resource_location
  resource_group_name = local.resource_group_name
  offer_type          = "Standard"
  kind                = "GlobalDocumentDB"

  consistency_policy {
  consistency_level = "Session"
  }
    capabilities {
  name = "EnableTable"
  }

    geo_location {
    location = "eastus"
    failover_priority = 0
  }


  geo_location {
    location = "westus"
    failover_priority = 1
  }
}


resource "azurerm_cosmosdb_table" "crc_cosmosdb_table" {
  name                = "crc-cosmosdb-table"
  resource_group_name = local.resource_group_name
  account_name        = "crc-cosmosdb-acc"
  throughput          = 400
}

resource "azurerm_storage_account" "crc_store_acc" {
  name                     = "crcstoreacc"
  resource_group_name      = local.resource_group_name
  location                 = local.resource_location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

resource "azurerm_service_plan" "crc_func_sp" {
  name                = "crc-func-sp"
  resource_group_name = local.resource_group_name
  location            = local.resource_location
  os_type             = "Linux"
  sku_name            = "Y1"
}

resource "azurerm_linux_function_app" "crc_function_app" {
  name                       = "crc-func-app"
  location                   = local.resource_location
  resource_group_name        = local.resource_group_name

  storage_account_name       = azurerm_storage_account.crc_store_acc.name
  storage_account_access_key = azurerm_storage_account.crc_store_acc.primary_access_key
  service_plan_id            = azurerm_service_plan.crc_func_sp.id
      
  app_settings = {
    FUNCTIONS_WORKER_RUNTIME = "python"

    "PARTITION_KEY"              = "/counter"
    "ROW_KEY"                    = "visitors"
}

  site_config {
    application_stack {
      python_version = "3.11"
    }
  }

  identity {type = "SystemAssigned"}

}

resource "azurerm_role_assignment" "az-func-cosmos" {
  scope                 = azurerm_cosmosdb_account.crc_cosmosdb_acc.id
  role_definition_name  = "Contributor"
  principal_id          = azurerm_linux_function_app.crc_function_app.identity[0].principal_id
}







