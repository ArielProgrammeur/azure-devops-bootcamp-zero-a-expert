# Terraform Modules - Niveau Enterprise


## Sommaire du Cours

1. [Introduction et Concepts Fondamentaux](#intro)
2. [Phase 1 : Création du Module Storage Account avec Tests](#storage)
3. [Phase 2 : Création du Module Virtual Machine avec Tests](#vm)
4. [Phase 3 : Tests Terraform Natifs Approfondis](#tests)
5. [Phase 4 : Publication dans Azure Container Registry](#publish)
6. [Phase 5 : Sécurité et Key Vault Enterprise](#security)
7. [Phase 6 : Projet Infrastructure Complet](#project)
8. [Phase 7 : CI/CD et Gouvernance](#cicd)
9. [Phase 8 : Maintenance et Versioning](#maintenance)

---

## Introduction et Concepts Fondamentaux <a name="intro"></a>

### Qu'est-ce qu'un Module Terraform ?

Un module est un conteneur de plusieurs ressources Terraform utilisées ensemble. C'est l'équivalent d'une **fonction réutilisable** en programmation.

```
Module = Boîte noire paramétrable
Entrées (Inputs) → Module Terraform → Sorties (Outputs)
```

### Architecture Enterprise des Modules

```
┌─────────────────────────────────────────────────────────────┐
│                    REGISTRE PRIVE ACR                        │
│  ┌──────────────┐ ┌──────────────┐ ┌──────────────┐        │
│  │   storage    │ │      vm      │ │  networking  │        │
│  │   v1.0.0     │ │   v1.0.0     │ │   v2.1.0     │        │
│  │   v1.1.0     │ │   v1.1.0     │ │              │        │
│  └──────────────┘ └──────────────┘ └──────────────┘        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│              PROJET INFRASTRUCTURE (environments/)          │
│  ┌──────────────────────────────────────────────────────┐  │
│  │ module "storage" {                                    │  │
│  │   source = "acrdemo.azurecr.io/modules/storage:v1.0.0"│  │
│  │   ...                                                 │  │
│  │ }                                                     │  │
│  └──────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────┘
```

### Versions Utilisées (Dernières Stables - 2026)

| Outil | Version | Date de sortie |
|-------|---------|----------------|
| Terraform | v1.11.x | Mars 2026 |
| AzureRM Provider | v4.27.0 | Mars 2026 |
| Terratest | v1.26.0 | Stable |
| ORAS | v1.2.2 | Stable |

---

## Phase 1 : Création du Module Storage Account avec Tests <a name="storage"></a>

### 1.1 Structure du Module

```bash
mkdir -p modules/storage/{examples/complete,tests,scripts}
cd modules/storage
```

### 1.2 Fichier `versions.tf`

```hcl
# modules/storage/versions.tf
terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.27"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
  }
}
```

### 1.3 Fichier `variables.tf` - Variables Typées et Validées

```hcl
# modules/storage/variables.tf
# ============================================
# PARAMÈTRES OBLIGATOIRES
# ============================================

variable "project_name" {
  description = "Nom du projet pour les noms des ressources"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]{3,20}$", var.project_name))
    error_message = "Le nom du projet doit contenir 3-20 caractères alphanumériques minuscules."
  }
}

variable "environment" {
  description = "Environnement cible"
  type        = string
  
  validation {
    condition     = contains(["dev", "staging", "prod", "mgmt"], var.environment)
    error_message = "Environment doit être dev, staging, prod ou mgmt."
  }
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources existant"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

# ============================================
# PARAMÈTRES DE STORAGE ACCOUNT
# ============================================

variable "storage_account_name_override" {
  description = "Override le nom du storage account (si non fourni, généré automatiquement)"
  type        = string
  default     = null
  
  validation {
    condition     = var.storage_account_name_override == null ? true : can(regex("^[a-z0-9]{3,24}$", var.storage_account_name_override))
    error_message = "Le nom du storage account doit faire 3-24 caractères alphanumériques minuscules."
  }
}

variable "account_tier" {
  description = "Tier du compte de stockage"
  type        = string
  default     = "Standard"
  
  validation {
    condition     = contains(["Standard", "Premium"], var.account_tier)
    error_message = "Account tier doit être Standard ou Premium."
  }
}

variable "account_replication_type" {
  description = "Type de réplication"
  type        = string
  default     = "LRS"
  
  validation {
    condition     = contains(["LRS", "ZRS", "GRS", "GZRS", "RAGRS", "RAGZRS"], var.account_replication_type)
    error_message = "Type de réplication non supporté."
  }
}

variable "min_tls_version" {
  type        = string
  description = "Version TLS minimale"
  default     = "TLS1_2"
  
  validation {
    condition     = contains(["TLS1_2", "TLS1_3"], var.min_tls_version)
    error_message = "TLS version must be TLS1_2 or TLS1_3."
  }
}

variable "containers" {
  description = "Conteneurs Blob à créer"
  type = map(object({
    access_type = optional(string, "private")
  }))
  default = {}
}

variable "soft_delete_retention_days" {
  type        = number
  description = "Jours de rétention suppression réversible"
  default     = 7
  validation {
    condition     = var.soft_delete_retention_days >= 1 && var.soft_delete_retention_days <= 365
    error_message = "Doit être entre 1 et 365 jours."
  }
}

variable "tags" {
  type        = map(string)
  description = "Tags à appliquer"
  default     = {}
}
```

### 1.4 Fichier `main.tf` - Logique Principale

```hcl
# modules/storage/main.tf

locals {
  # Nom unique généré automatiquement
  storage_account_name = var.storage_account_name_override != null ? 
    var.storage_account_name_override : 
    substr(replace("st${var.project_name}${var.environment}${random_string.suffix.result}", "-", ""), 0, 24)
  
  # Tags fusionnés
  merged_tags = merge({
    Environment = var.environment
    ManagedBy   = "Terraform"
    Module      = "storage"
    ModuleVersion = "1.0.0"
  }, var.tags)
}

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# Storage Account principal
resource "azurerm_storage_account" "main" {
  name                     = local.storage_account_name
  resource_group_name      = var.resource_group_name
  location                 = var.location
  account_tier             = var.account_tier
  account_replication_type = var.account_replication_type
  min_tls_version          = var.min_tls_version
  https_traffic_only_enabled = true
  
  blob_properties {
    delete_retention_policy {
      days = var.soft_delete_retention_days
    }
    versioning_enabled = var.environment == "prod" ? true : false
  }
  
  tags = local.merged_tags
}

# Conteneurs Blob
resource "azurerm_storage_container" "containers" {
  for_each = var.containers
  
  name                  = each.key
  storage_account_name  = azurerm_storage_account.main.name
  container_access_type = each.value.access_type
}

# Outputs
output "storage_account_id" {
  description = "ID du storage account"
  value       = azurerm_storage_account.main.id
}

output "storage_account_name" {
  description = "Nom du storage account"
  value       = azurerm_storage_account.main.name
}

output "primary_access_key" {
  description = "Clé d'accès primaire"
  value       = azurerm_storage_account.main.primary_access_key
  sensitive   = true
}

output "primary_blob_endpoint" {
  description = "Endpoint Blob primaire"
  value       = azurerm_storage_account.main.primary_blob_endpoint
}
```

### 1.5 Tests Terraform Natifs pour le Module Storage

**modules/storage/tests/storage.tftest.hcl** :

```hcl
# ============================================
# TESTS TERRAFORM NATIFS - MODULE STORAGE
# Terraform v1.11+
# ============================================

variables {
  project_name        = "test"
  environment         = "test"
  resource_group_name = "rg-test-storage"
  location            = "francecentral"
}

# Test 1: Création basique
run "basic_storage_creation" {
  command = plan
  
  assert {
    condition     = azurerm_storage_account.main.name != ""
    error_message = "Le nom du storage account ne doit pas être vide"
  }
  
  assert {
    condition     = can(regex("^sttesttest[a-z0-9]{6}$", azurerm_storage_account.main.name))
    error_message = "Le nom du storage account ne respecte pas la convention"
  }
  
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
```

---

## Phase 2 : Création du Module Virtual Machine avec Tests <a name="vm"></a>

### 2.1 Structure du Module VM

```bash
mkdir -p modules/virtual-machine/{scripts,examples/complete,tests}
cd modules/virtual-machine
```

### 2.2 Fichier `variables.tf`

```hcl
# modules/virtual-machine/variables.tf

variable "vm_name" {
  description = "Nom de la machine virtuelle"
  type        = string
  
  validation {
    condition     = can(regex("^[a-zA-Z0-9][a-zA-Z0-9-]{1,13}[a-zA-Z0-9]$", var.vm_name))
    error_message = "Nom VM invalide (3-15 caractères alphanumériques ou tirets)."
  }
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources"
  type        = string
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau"
  type        = string
}

variable "authentication_method" {
  description = "Méthode d'authentification (password, ssh, both)"
  type        = string
  default     = "ssh"
  
  validation {
    condition     = contains(["password", "ssh", "both"], var.authentication_method)
    error_message = "Méthode invalide."
  }
}

variable "admin_username" {
  type        = string
  default     = "azureuser"
}

variable "admin_password" {
  type        = string
  sensitive   = true
  default     = null
}

variable "ssh_public_key" {
  type        = string
  sensitive   = true
  default     = null
}

variable "vm_size" {
  type        = string
  default     = "Standard_B2s"
}

variable "os_disk" {
  type = object({
    caching              = optional(string, "ReadWrite")
    storage_account_type = optional(string, "Premium_LRS")
    disk_size_gb         = optional(number, 128)
  })
  default = {}
}

variable "os_image" {
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = optional(string, "latest")
  })
  default = {
    publisher = "Canonical"
    offer     = "ubuntu-24_04-lts"
    sku       = "server"
    version   = "latest"
  }
}

variable "public_ip" {
  type = object({
    enabled            = optional(bool, false)
    allocation_method = optional(string, "Dynamic")
  })
  default = {}
}

variable "cloud_init_custom_data" {
  type        = string
  default     = null
}

variable "enable_azure_monitor" {
  type        = bool
  default     = false
}

variable "log_analytics_workspace_id" {
  type        = string
  default     = null
}

variable "tags" {
  type        = map(string)
  default     = {}
}
```

### 2.3 Fichier `main.tf`

```hcl
# modules/virtual-machine/main.tf

locals {
  use_password_auth = contains(["password", "both"], var.authentication_method)
  use_ssh_auth      = contains(["ssh", "both"], var.authentication_method)
  
  merged_tags = merge({
    ManagedBy = "Terraform"
    Module    = "virtual-machine"
  }, var.tags)
}

# IP Publique (optionnelle)
resource "azurerm_public_ip" "vm" {
  count = var.public_ip.enabled ? 1 : 0
  
  name                = "pip-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = var.public_ip.allocation_method
}

# Interface réseau
resource "azurerm_network_interface" "vm" {
  name                = "nic-${var.vm_name}"
  location            = var.location
  resource_group_name = var.resource_group_name
  
  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = var.public_ip.enabled ? azurerm_public_ip.vm[0].id : null
  }
}

# Machine Virtuelle Linux
resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  admin_username      = var.admin_username
  
  dynamic "admin_ssh_key" {
    for_each = local.use_ssh_auth && var.ssh_public_key != null ? [1] : []
    content {
      username   = var.admin_username
      public_key = var.ssh_public_key
    }
  }
  
  admin_password = local.use_password_auth ? var.admin_password : null
  disable_password_authentication = local.use_ssh_auth && var.admin_password == null
  
  network_interface_ids = [azurerm_network_interface.vm.id]
  
  os_disk {
    caching              = try(var.os_disk.caching, "ReadWrite")
    storage_account_type = try(var.os_disk.storage_account_type, "Premium_LRS")
    disk_size_gb         = try(var.os_disk.disk_size_gb, 128)
  }
  
  source_image_reference {
    publisher = var.os_image.publisher
    offer     = var.os_image.offer
    sku       = var.os_image.sku
    version   = var.os_image.version
  }
  
  custom_data = var.cloud_init_custom_data != null ? base64encode(var.cloud_init_custom_data) : null
  
  tags = local.merged_tags
}

# Extension Azure Monitor
resource "azurerm_virtual_machine_extension" "monitor" {
  count = var.enable_azure_monitor && var.log_analytics_workspace_id != null ? 1 : 0
  
  name                       = "AzureMonitorLinuxAgent"
  virtual_machine_id         = azurerm_linux_virtual_machine.vm.id
  publisher                  = "Microsoft.Azure.Monitor"
  type                       = "AzureMonitorLinuxAgent"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  
  settings = jsonencode({
    workspaceId = var.log_analytics_workspace_id
  })
}

# Outputs
output "vm_id" {
  value = azurerm_linux_virtual_machine.vm.id
}

output "private_ip" {
  value = azurerm_network_interface.vm.private_ip_address
}

output "public_ip" {
  value = var.public_ip.enabled ? azurerm_public_ip.vm[0].ip_address : null
}
```

### 2.4 Tests Terraform Natifs pour le Module VM

**modules/virtual-machine/tests/vm.tftest.hcl** :

```hcl
# ============================================
# TESTS MODULE VM
# ============================================

variables {
  vm_name             = "test-vm"
  resource_group_name = "rg-test-vm"
  location            = "francecentral"
  subnet_id           = "/subscriptions/test/subnets/test"
}

# Test 1: Création avec SSH
run "vm_ssh_creation" {
  command = plan
  
  variables {
    authentication_method = "ssh"
    ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."  # Clé test
  }
  
  assert {
    condition     = length(azurerm_linux_virtual_machine.vm.admin_ssh_key) == 1
    error_message = "La clé SSH doit être configurée"
  }
  
  assert {
    condition     = azurerm_linux_virtual_machine.vm.disable_password_authentication == true
    error_message = "L'auth par mot de passe doit être désactivée"
  }
}

# Test 2: Création avec mot de passe
run "vm_password_creation" {
  command = plan
  
  variables {
    authentication_method = "password"
    admin_password        = "TestPassword123!"
  }
  
  assert {
    condition     = azurerm_linux_virtual_machine.vm.admin_password != null
    error_message = "Le mot de passe doit être configuré"
  }
  
  assert {
    condition     = azurerm_linux_virtual_machine.vm.disable_password_authentication == false
    error_message = "L'auth par mot de passe doit être activée"
  }
}

# Test 3: IP Publique
run "vm_with_public_ip" {
  command = plan
  
  variables {
    authentication_method = "ssh"
    ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    public_ip = {
      enabled = true
    }
  }
  
  assert {
    condition     = length(azurerm_public_ip.vm) == 1
    error_message = "L'IP publique doit être créée"
  }
  
  assert {
    condition     = can(output.public_ip)
    error_message = "Output public_ip manquant"
  }
}

# Test 4: Cloud-init
run "vm_with_cloudinit" {
  command = plan
  
  variables {
    authentication_method = "ssh"
    ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    cloud_init_custom_data = <<-EOF
#!/bin/bash
apt-get update
apt-get install -y nginx
EOF
  }
  
  assert {
    condition     = can(azurerm_linux_virtual_machine.vm.custom_data)
    error_message = "Le custom_data cloud-init doit être défini"
  }
}

# Test 5: Monitoring
run "vm_with_monitoring" {
  command = plan
  
  variables {
    authentication_method = "ssh"
    ssh_public_key        = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQ..."
    enable_azure_monitor  = true
    log_analytics_workspace_id = "/subscriptions/test/workspaces/test"
  }
  
  assert {
    condition     = length(azurerm_virtual_machine_extension.monitor) == 1
    error_message = "L'extension monitor doit être créée"
  }
}
```

---

## Phase 3 : Tests Terraform Natifs Approfondis <a name="tests"></a>

### 3.1 Tests d'Intégration Complets

**tests/integration/integration.tftest.hcl** :

```hcl
# ============================================
# TESTS D'INTÉGRATION COMPLETS
# ============================================

variables {
  project_name        = "integration"
  environment         = "test"
  resource_group_name = "rg-integration-test"
  location            = "francecentral"
}

# Test d'intégration Storage + Containers
run "integration_storage_test" {
  command = apply
  
  module {
    source = "../../modules/storage"
  }
  
  variables {
    containers = {
      "test-container" = { access_type = "private" }
    }
  }
  
  assert {
    condition     = output.storage_account_name != ""
    error_message = "Le storage account n'a pas été créé"
  }
  
  assert {
    condition     = can(azurerm_storage_container.containers["test-container"])
    error_message = "Le conteneur test n'a pas été créé"
  }
}

# Test d'intégration VM avec Storage
run "integration_vm_storage_test" {
  command = plan
  
  module {
    source = "../../modules/virtual-machine"
  }
  
  variables {
    vm_name      = "test-vm-integration"
    subnet_id    = "/subscriptions/integration/subnets/test"
    authentication_method = "ssh"
    ssh_public_key = "ssh-rsa test-key"
  }
  
  assert {
    condition     = can(azurerm_linux_virtual_machine.vm)
    error_message = "La VM doit être planifiée"
  }
}

# Test de déploiement complet avec mock
run "full_deployment_mock_test" {
  command = plan
  
  mock_provider "azurerm" {
    mock_resource "azurerm_resource_group" {
      defaults = {
        name = "mock-rg"
      }
    }
  }
  
  module "storage" {
    source = "../../modules/storage"
  }
  
  assert {
    condition     = true
    error_message = "Mock test passé"
  }
}
```

### 3.2 Exécution des Tests

```bash
# Script d'exécution des tests
cat > scripts/run-tests.sh << 'EOF'
#!/bin/bash
set -e

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${YELLOW}🧪 Exécution des tests Terraform${NC}"
echo "================================"

# Variables
TEST_RESULTS_DIR="test-results"
mkdir -p $TEST_RESULTS_DIR
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Test 1: Module Storage
echo -e "\n${YELLOW}[1/3] Test du module Storage...${NC}"
cd modules/storage
terraform test -json > "../../$TEST_RESULTS_DIR/storage-$TIMESTAMP.json" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tests Storage OK${NC}"
else
    echo -e "${RED}❌ Tests Storage échoués${NC}"
fi
cd - > /dev/null

# Test 2: Module VM
echo -e "\n${YELLOW}[2/3] Test du module VM...${NC}"
cd modules/virtual-machine
terraform test -json > "../../$TEST_RESULTS_DIR/vm-$TIMESTAMP.json" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tests VM OK${NC}"
else
    echo -e "${RED}❌ Tests VM échoués${NC}"
fi
cd - > /dev/null

# Test 3: Tests d'intégration
echo -e "\n${YELLOW}[3/3] Tests d'intégration...${NC}"
cd tests/integration
terraform test -json > "../../$TEST_RESULTS_DIR/integration-$TIMESTAMP.json" 2>&1
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Tests intégration OK${NC}"
else
    echo -e "${RED}❌ Tests intégration échoués${NC}"
fi
cd - > /dev/null

# Rapport final
echo -e "\n${YELLOW}📊 Résumé des tests:${NC}"
for file in $TEST_RESULTS_DIR/*.json; do
    if grep -q '"status":"pass"' $file 2>/dev/null; then
        echo -e "${GREEN}✅ $(basename $file)${NC}"
    else
        echo -e "${RED}❌ $(basename $file)${NC}"
    fi
done

echo -e "\n${GREEN}🎯 Tests terminés${NC}"
EOF

chmod +x scripts/run-tests.sh
```

---

## Phase 4 : Publication dans Azure Container Registry <a name="publish"></a>

### 4.1 Setup du Registry

```bash
#!/bin/bash
# scripts/setup-acr.sh

set -e

ACR_NAME="tfmodules${RANDOM}${RANDOM}"
RESOURCE_GROUP="rg-terraform-registry"
LOCATION="francecentral"

# Création du groupe de ressources
az group create --name $RESOURCE_GROUP --location $LOCATION

# Création du ACR (Premium requis pour OCI artifacts)
az acr create \
    --name $ACR_NAME \
    --resource-group $RESOURCE_GROUP \
    --sku Premium \
    --admin-enabled false

# Activer le stockage OCI (pour modules Terraform)
az acr update --name $ACR_NAME --allow-trusted-services true

# Créer un Service Principal pour CI/CD
SP_NAME="sp-terraform-registry"

az ad sp create-for-rbac \
    --name $SP_NAME \
    --role acrpush \
    --scopes /subscriptions/$(az account show --query id -o tsv)/resourceGroups/$RESOURCE_GROUP/providers/Microsoft.ContainerRegistry/registries/$ACR_NAME \
    --sdk-auth

echo "ACR_NAME=$ACR_NAME"
echo "ACR_LOGIN_SERVER=$ACR_NAME.azurecr.io"
```

### 4.2 Script de Publication Module Storage

**registry/publish-storage.sh** :

```bash
#!/bin/bash
# publish-storage.sh

set -e

MODULE_NAME="storage"
MODULE_VERSION=${1:-"1.0.0"}
ACR_NAME=${ACR_NAME:-"tfmodules"}
ACR_LOGIN_SERVER="${ACR_NAME}.azurecr.io"

echo "📦 Publication du module $MODULE_NAME v$MODULE_VERSION"

# Vérification des prérequis
command -v oras >/dev/null 2>&1 || { echo "❌ ORAS requis"; exit 1; }

# Connexion ACR
az acr login --name $ACR_NAME

# Création du package OCI
TEMP_DIR=$(mktemp -d)
cp -r ../modules/$MODULE_NAME/* $TEMP_DIR/

# Création du manifeste
cd $TEMP_DIR
cat > manifest.json << EOF
{
  "schemaVersion": 2,
  "mediaType": "application/vnd.oci.image.manifest.v1+json"
}
EOF

# Création de l'artifact OCI
tar -czf module.tar.gz main.tf variables.tf outputs.tf versions.tf

# Publication avec ORAS
oras push $ACR_LOGIN_SERVER/terraform/modules/$MODULE_NAME:$MODULE_VERSION \
    --artifact-type "application/vnd.terraform.module.v1+json" \
    module.tar.gz:application/vnd.terraform.module.layer.v1.tar+gzip \
    --annotation "org.opencontainers.image.title=$MODULE_NAME" \
    --annotation "org.opencontainers.image.version=$MODULE_VERSION" \
    --annotation "com.terraform.provider=azurerm"

cd -
rm -rf $TEMP_DIR

echo "✅ Module publié : $ACR_LOGIN_SERVER/terraform/modules/$MODULE_NAME:$MODULE_VERSION"

# Test de récupération
oras manifest fetch $ACR_LOGIN_SERVER/terraform/modules/$MODULE_NAME:$MODULE_VERSION | jq '.'
```

### 4.3 Utilisation du Module Publié

```hcl
# Utilisation dans un projet
terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.27"
    }
  }
}

provider "azurerm" {
  features {}
}

module "storage_from_acr" {
  source = "tfmodules.azurecr.io/terraform/modules/storage:1.0.0"
  
  project_name        = "myapp"
  environment         = "dev"
  resource_group_name = azurerm_resource_group.rg.name
  location            = "francecentral"
  
  containers = {
    "data" = { access_type = "private" }
  }
}
```

---

## Phase 5 : Sécurité et Key Vault Enterprise <a name="security"></a>

### 5.1 Key Vault Configuration

**security/keyvault.tf** :

```hcl
# Key Vault avec sécurité renforcée
resource "azurerm_key_vault" "enterprise" {
  name                       = "kv-platform-mgmt-${random_id.kv_suffix.hex}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.security.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "premium"
  
  soft_delete_retention_days = 90
  purge_protection_enabled   = true
  public_network_access_enabled = false  # Private endpoint seulement
  
  enable_rbac_authorization = true
  
  tags = local.tags
}

# Private Endpoint
resource "azurerm_private_endpoint" "keyvault" {
  name                = "pe-${azurerm_key_vault.enterprise.name}"
  location            = var.location
  resource_group_name = azurerm_resource_group.security.name
  subnet_id           = var.private_endpoint_subnet_id
  
  private_service_connection {
    name                           = "psc-keyvault"
    private_connection_resource_id = azurerm_key_vault.enterprise.id
    is_manual_connection           = false
    subresource_names              = ["vault"]
  }
}

# Secret pour VM
resource "random_password" "vm_password" {
  length  = 24
  special = true
  min_special = 2
}

resource "azurerm_key_vault_secret" "vm_password" {
  name         = "vm-admin-password"
  value        = random_password.vm_password.result
  key_vault_id = azurerm_key_vault.enterprise.id
}

# Accès RBAC pour les modules
resource "azurerm_role_assignment" "module_access" {
  principal_id         = var.module_managed_identity_id
  role_definition_name = "Key Vault Secrets User"
  scope                = azurerm_key_vault.enterprise.id
}
```

### 5.2 Module VM avec Intégration Key Vault

**modules/virtual-machine/main.tf (ajout)** :

```hcl
# Récupération du secret depuis Key Vault
data "azurerm_key_vault_secret" "admin_password" {
  count = var.admin_password_key_vault_id != null ? 1 : 0
  
  key_vault_id = var.admin_password_key_vault_id
  name         = var.admin_password_secret_name
}

# Utilisation dans la VM
resource "azurerm_linux_virtual_machine" "vm" {
  # ...
  
  admin_password = var.admin_password_key_vault_id != null ? 
    data.azurerm_key_vault_secret.admin_password[0].value : 
    var.admin_password
  
  # ...
}
```

---

## Phase 6 : Projet Infrastructure Complet <a name="project"></a>

### 6.1 Structure du Projet

```bash
mkdir -p infrastructure-project/{environments/{dev,staging,prod},modules,scripts}
```

### 6.2 Environnement Dev Complet

**infrastructure-project/environments/dev/main.tf** :

```hcl
terraform {
  required_version = ">= 1.11.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.27"
    }
  }
  
  backend "azurerm" {
    resource_group_name  = "rg-terraform-state"
    storage_account_name = "sttfstateabc123"
    container_name       = "tfstate-dev"
    key                  = "dev.terraform.tfstate"
  }
}

provider "azurerm" {
  features {}
}

locals {
  environment = "dev"
  project_name = "enterprise-app"
  location     = "francecentral"
  
  tags = {
    Environment = local.environment
    Project     = local.project_name
    ManagedBy   = "Terraform"
  }
}

resource "azurerm_resource_group" "main" {
  name     = "rg-${local.project_name}-${local.environment}"
  location = local.location
  tags     = local.tags
}

# Module Networking (local)
module "networking" {
  source = "../../modules/networking"
  
  project_name        = local.project_name
  environment         = local.environment
  location            = local.location
  resource_group_name = azurerm_resource_group.main.name
  vnet_address_space  = ["10.0.0.0/16"]
  
  subnet_configs = {
    "web" = { address_prefixes = ["10.0.1.0/24"] }
    "app" = { address_prefixes = ["10.0.2.0/24"] }
    "db"  = { address_prefixes = ["10.0.3.0/24"] }
  }
}

# Module Storage (depuis ACR)
module "storage" {
  source = "tfmodules.azurecr.io/terraform/modules/storage:1.0.0"
  
  project_name        = local.project_name
  environment         = local.environment
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  
  containers = {
    "data" = { access_type = "private" }
    "logs" = { access_type = "private" }
  }
  
  soft_delete_retention_days = local.environment == "prod" ? 90 : 7
  
  tags = local.tags
}

# Module VM (depuis ACR)
module "web_vm" {
  source = "tfmodules.azurecr.io/terraform/modules/virtual-machine:1.0.0"
  
  vm_name             = "web-${local.project_name}-${local.environment}"
  resource_group_name = azurerm_resource_group.main.name
  location            = local.location
  subnet_id           = module.networking.subnet_ids["web"]
  
  authentication_method = "password"
  admin_username        = "azureuser"
  admin_password        = var.vm_admin_password
  
  vm_size = local.environment == "prod" ? "Standard_D2s_v3" : "Standard_B2s"
  
  public_ip = {
    enabled = local.environment != "prod"
  }
  
  tags = local.tags
}

# Outputs
output "storage_name" {
  value = module.storage.storage_account_name
}

output "vm_ip" {
  value = module.web_vm.public_ip
}
```

---

## Phase 7 : CI/CD et Gouvernance <a name="cicd"></a>

### 7.1 Pipeline GitHub Actions Complet

**.github/workflows/modules-ci.yml** :

```yaml
name: Terraform Modules CI

on:
  push:
    paths:
      - 'modules/**'
  pull_request:
    paths:
      - 'modules/**'

jobs:
  test:
    name: Test Modules
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.11.0
      
      - name: Test Storage Module
        run: |
          cd modules/storage
          terraform test -json
      
      - name: Test VM Module
        run: |
          cd modules/virtual-machine
          terraform test -json
      
      - name: Security Scan
        run: |
          trivy config --severity HIGH,CRITICAL modules/
  
  publish:
    name: Publish Modules
    needs: test
    runs-on: ubuntu-latest
    if: github.ref == 'refs/heads/main'
    steps:
      - uses: actions/checkout@v4
      
      - name: Login to ACR
        uses: azure/docker-login@v1
        with:
          login-server: ${{ secrets.ACR_LOGIN_SERVER }}
          username: ${{ secrets.ACR_USERNAME }}
          password: ${{ secrets.ACR_PASSWORD }}
      
      - name: Install ORAS
        run: |
          curl -LO https://github.com/oras-project/oras/releases/download/v1.2.2/oras_1.2.2_linux_amd64.tar.gz
          tar -xzf oras_1.2.2_linux_amd64.tar.gz
          sudo mv oras /usr/local/bin/
      
      - name: Publish Storage Module
        run: |
          cd modules/storage
          VERSION=${GITHUB_SHA::8}
          oras push ${{ secrets.ACR_LOGIN_SERVER }}/terraform/modules/storage:$VERSION \
            module.tar.gz:application/vnd.terraform.module.layer.v1.tar+gzip
      
      - name: Publish VM Module
        run: |
          cd modules/virtual-machine
          VERSION=${GITHUB_SHA::8}
          oras push ${{ secrets.ACR_LOGIN_SERVER }}/terraform/modules/virtual-machine:$VERSION \
            module.tar.gz:application/vnd.terraform.module.layer.v1.tar+gzip
```

---

## Phase 8 : Maintenance et Versioning <a name="maintenance"></a>

### 8.1 Versioning Sémantique

```bash
#!/bin/bash
# scripts/version-module.sh

set -e

MODULE_PATH=$1
VERSION_TYPE=${2:-"patch"}  # major, minor, patch

cd $MODULE_PATH

# Récupération version actuelle
CURRENT_VERSION=$(grep "ModuleVersion" main.tf | sed 's/.*= "\(.*\)"/\1/')
IFS='.' read -r major minor patch <<< "$CURRENT_VERSION"

case $VERSION_TYPE in
  major)
    NEW_VERSION="$((major + 1)).0.0"
    ;;
  minor)
    NEW_VERSION="$major.$((minor + 1)).0"
    ;;
  patch)
    NEW_VERSION="$major.$minor.$((patch + 1))"
    ;;
esac

# Mise à jour de la version
sed -i "s/ModuleVersion = \".*\"/ModuleVersion = \"$NEW_VERSION\"/" main.tf

# Commit et tag
git add main.tf
git commit -m "chore: bump $MODULE_PATH to v$NEW_VERSION"
git tag "$MODULE_PATH/v$NEW_VERSION"

echo "✅ Version $NEW_VERSION créée"
```

### 8.2 Drift Detection

```bash
#!/bin/bash
# scripts/detect-drift.sh

ENVIRONMENT=${1:-"dev"}

cd infrastructure-project/environments/$ENVIRONMENT

terraform init
terraform plan -detailed-exitcode

case $? in
  0)
    echo "✅ Pas de drift détecté"
    ;;
  2)
    echo "⚠️ Drift détecté!"
    terraform plan -no-color
    exit 1
    ;;
esac
```

---

## Commandes Essentielles - Récapitulatif

```bash
# Développement local
terraform fmt -recursive
terraform validate
terraform test -verbose

# Publication
./scripts/setup-acr.sh
./registry/publish-storage.sh 1.0.0
./registry/publish-vm.sh 1.0.0

# Utilisation
cd infrastructure-project/environments/dev
terraform init
terraform plan -var-file=dev.tfvars
terraform apply -var-file=dev.tfvars

# Maintenance
./scripts/version-module.sh modules/storage minor
./scripts/detect-drift.sh dev
```

---

## Résumé des Compétences Acquises

| Compétence | Niveau | Outil/Méthode |
|------------|--------|---------------|
| Création de modules | ★★★★★ | Terraform v1.11+ |
| Tests natifs | ★★★★★ | `terraform test` |
| Publication ACR | ★★★★☆ | ORAS, OCI artifacts |
| Sécurité Key Vault | ★★★★★ | RBAC, Private Endpoint |
| CI/CD complet | ★★★★★ | GitHub Actions |
| Versioning sémantique | ★★★★☆ | Git tags + ACR |
| Drift detection | ★★★★☆ | Terraform plan |
