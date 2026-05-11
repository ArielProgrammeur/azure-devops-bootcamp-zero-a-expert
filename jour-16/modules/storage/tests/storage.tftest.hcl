# ============================================
# TESTS TERRAFORM NATIFS - MODULE STORAGE
# Terraform v1.11+
# ============================================

variables {
  project_name        = "test"
  environment         = "dev"
  resource_group_name = "rg-test-storage"
  location            = "canadacentral"
}

# Configuration du provider pour les tests
provider "azurerm" {
  features {}
}

# Test 1: Création basique
run "basic_storage_creation" {
  command = plan 
  assert {
    condition     = azurerm_storage_account.main.account_tier == "Standard"
    error_message = "Account tier doit être Standard par défaut"
  }
  assert {
    condition     = azurerm_storage_account.main.https_traffic_only_enabled == true
    error_message = "HTTPS doit être obligatoire"
  }
}

# Test 2: Création avec conteneurs
run "storage_with_containers" {
  command = plan
  
  variables {
    containers = {
      "data" = { access_type = "private" }
      "logs" = { access_type = "private" }
      "public" = { access_type = "blob" }
    }
  }
  
  assert {
    condition     = length(azurerm_storage_container.containers) == 3
    error_message = "3 conteneurs doivent être créés"
  }
  
  assert {
    condition     = can(azurerm_storage_container.containers["data"])
    error_message = "Le conteneur 'data' doit exister"
  }
  
  assert {
    condition     = azurerm_storage_container.containers["data"].container_access_type == "private"
    error_message = "Le conteneur data doit être privé"
  }
}

# Test 3: Override du nom
run "storage_name_override" {
  command = plan
  
  variables {
    storage_account_name_override = "customstorage123"
  }
  
  assert {
    condition     = azurerm_storage_account.main.name == "customstorage123"
    error_message = "Le nom override n'a pas été appliqué"
  }
}

# Test 4: Validation des outputs
run "outputs_validation" {
  command = plan
  
  assert {
    condition     = can(output.storage_account_id)
    error_message = "Output storage_account_id manquant"
  }
  
  assert {
    condition     = can(output.storage_account_name)
    error_message = "Output storage_account_name manquant"
  }
  
  assert {
    condition     = can(output.primary_access_key)
    error_message = "Output primary_access_key manquant"
  }
  
  assert {
    condition     = output.primary_access_key.sensitive == true
    error_message = "La clé primaire doit être sensitive"
  }
}

# Test 5: Configuration Production
run "production_configuration" {
  command = plan
  
  variables {
    environment = "prod"
    account_replication_type = "GRS"
    soft_delete_retention_days = 90
  }
  
  assert {
    condition     = azurerm_storage_account.main.account_replication_type == "GRS"
    error_message = "La production doit utiliser GRS"
  }
  
  assert {
    condition     = azurerm_storage_account.main.blob_properties[0].versioning_enabled == true
    error_message = "Le versioning doit être activé en production"
  }
}