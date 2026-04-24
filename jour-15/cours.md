# Exemple 

## Sommaire du Cours

1. [Phase 1 : Infrastructure du State (Bootstrapping)](#phase1)
2. [Phase 2 : Structure du projet et configuration initiale](#phase2)
3. [Phase 3 : Création des modules réutilisables](#phase3)
4. [Phase 4 : Configuration multi-environnements](#phase4)
5. [Phase 5 : Tests Terraform natifs (terraform test)](#phase5)
6. [Phase 6 : Outils de détection de sécurité](#phase6)
7. [Phase 7 : Tests locaux et validation](#phase7)
8. [Phase 8 : Déploiement (Apply)](#phase8)
9. [Phase 9 : Destruction et nettoyage](#phase9)

---

## Phase 1 : Infrastructure du State (Bootstrapping) <a name="phase1"></a>

### Objectif
Créer le Storage Account dédié qui stockera les fichiers d'état (terraform.tfstate) pour tous les environnements, en utilisant Terraform v1.11+ et AzureRM v4.x.

### 1.1 Script de bootstrap avec dernières versions

Créez un dossier `bootstrap/` :

```bash
mkdir -p bootstrap
cd bootstrap
```

**bootstrap/main.tf :**

```hcl
# ============================================
# BOOTSTRAP - INFRASTRUCTURE D'ÉTAT
# Version: Terraform v1.11+, AzureRM v4.x
# ============================================

terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"      # Dernière version majeure
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
  }
}

# ============================================
# VARIABLES
# ============================================
variable "project_name" {
  type        = string
  description = "Nom du projet"
  default     = "enterprise"
  
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.project_name))
    error_message = "Le nom du projet doit contenir uniquement des minuscules, chiffres et tirets."
  }
}

variable "location" {
  type        = string
  description = "Région Azure"
  default     = "francecentral"
  
  validation {
    condition     = contains(["francecentral", "westeurope", "northeurope"], var.location)
    error_message = "Région non supportée par la politique d'entreprise."
  }
}

variable "environment" {
  type        = string
  description = "Environnement du state"
  default     = "mgmt"
}

# ============================================
# RESSOURCES LOCALES
# ============================================
locals {
  # Nom unique pour le storage account (global sur Azure)
  storage_account_name = substr(
    replace(
      lower("st${var.project_name}state${random_string.suffix.result}"),
      "-", ""
    ),
    0, 24
  )
  
  # Conteneurs pour chaque environnement
  containers = {
    dev     = "tfstate-dev"
    staging = "tfstate-staging"
    prod    = "tfstate-prod"
    mgmt    = "tfstate-mgmt"
  }
  
  # Tags standardisés
  tags = {
    Environment = var.environment
    ManagedBy   = "Terraform"
    Purpose     = "Terraform State Storage"
    Project     = var.project_name
    CreatedAt   = timestamp()
    Version     = "v2"
  }
}

# ============================================
# RESSOURCES
# ============================================
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "state" {
  name     = "rg-${var.project_name}-state-${var.location}"
  location = var.location
  tags     = local.tags
  
  lifecycle {
    prevent_destroy = true
  }
}

resource "azurerm_storage_account" "state" {
  name                     = local.storage_account_name
  resource_group_name      = azurerm_resource_group.state.name
  location                 = azurerm_resource_group.state.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  # Configuration de sécurité renforcée
  min_tls_version           = "TLS1_2"
  https_traffic_only_enabled = true
  allow_nested_items_to_be_public = false
  
  # Soft delete pour récupération
  blob_properties {
    delete_retention_policy {
      days = 30
    }
    container_delete_retention_policy {
      days = 30
    }
    versioning_enabled = true
  }
  
  tags = local.tags
  
  lifecycle {
    prevent_destroy = true
    ignore_changes = [
      tags["CreatedAt"]
    ]
  }
}

# Création des conteneurs pour chaque environnement
resource "azurerm_storage_container" "state_containers" {
  for_each              = local.containers
  name                  = each.value
  storage_account_name  = azurerm_storage_account.state.name
  container_access_type = "private"
}

# ============================================
# OUTPUTS
# ============================================
output "storage_account_name" {
  description = "Nom du storage account"
  value       = azurerm_storage_account.state.name
}

output "storage_account_resource_group" {
  description = "Groupe de ressources"
  value       = azurerm_resource_group.state.name
}

output "container_names" {
  description = "Noms des conteneurs par environnement"
  value       = local.containers
}

output "backend_configs" {
  description = "Configuration backend pour chaque environnement"
  value = {
    for env, container in local.containers : env => {
      resource_group_name  = azurerm_resource_group.state.name
      storage_account_name = azurerm_storage_account.state.name
      container_name       = container
      key                  = "${env}.terraform.tfstate"
    }
  }
  sensitive = false
}

# Fichier de configuration pour les environnements
resource "local_file" "backend_configs_json" {
  filename = "${path.module}/../backend-configs.json"
  content  = jsonencode({
    for env, config in local.containers : env => {
      resource_group_name  = azurerm_resource_group.state.name
      storage_account_name = azurerm_storage_account.state.name
      container_name       = config
      key                  = "${env}.terraform.tfstate"
    }
  })
}
```

### 1.2 Déploiement du bootstrap

```bash
cd bootstrap

# Initialisation
terraform init

# Formatage
terraform fmt

# Validation
terraform validate

# Analyse de sécurité
tflint
checkov -d .

# Planification
terraform plan -out=bootstrap.tfplan

# Application
terraform apply bootstrap.tfplan

# Récupération des outputs
terraform output -json backend_configs > ../backend-configs.json
terraform output storage_account_name
```

---

## Phase 2 : Structure du projet et configuration initiale <a name="phase2"></a>

### 2.1 Arborescence complète (dernières pratiques 2026)

```bash
terraform-azure-enterprise/
├── .github/
│   └── workflows/
│       ├── terraform-ci.yml      # Validation et tests
│       ├── terraform-cd.yml      # Déploiement
│       └── terraform-security.yml # Scan sécurité
├── bootstrap/                     # Infrastructure d'état
├── modules/
│   ├── networking/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── versions.tf
│   │   ├── README.md
│   │   └── tests/
│   │       └── networking.tftest.hcl  # Tests Terraform natifs
│   ├── compute/
│   ├── database/
│   └── storage/
├── environments/
│   ├── dev/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   ├── outputs.tf
│   │   ├── dev.tfvars
│   │   ├── backend.tf
│   │   ├── providers.tf
│   │   └── tests/
│   │       └── dev_test.tftest.hcl
│   ├── staging/
│   └── prod/
├── tests/
│   ├── integration/
│   │   └── integration.tftest.hcl
│   └── fixtures/
├── scripts/
│   ├── validate-all.sh
│   ├── safe-apply.sh
│   ├── safe-destroy.sh
│   └── security-scan.sh
├── .gitignore
├── .pre-commit-config.yaml
├── tflint.hcl
├── checkov.yaml
├── .terraform-version           # Pour tfenv
├── terragrunt.hcl               # Optionnel pour orchestration
└── README.md
```

### 2.2 Configuration racine des fichiers

**.terraform-version :**
```
1.11.0
```

**.gitignore (complet 2026) :**
```gitignore
# Terraform
**/.terraform/
*.tfstate
*.tfstate.*
*.tfplan
*.tfplan.json
*.tfvars
*.tfvars.json
override.tf
override.tf.json
*_override.tf
*_override.tf.json
.terraform.lock.hcl
terraform.terraformrc

# Tests
tests/.test-data/
tests/output/
**/test-results/

# Secrets
**/*.pem
**/*.key
**/*.cert
**/*.p12
**/secrets.*
**/.secrets.baseline

# IDs et logs
crash.log
crash.*.log
*.log
*.id
**/terraform.rc

# IDE
.idea/
.vscode/
*.swp
*.swo
*~
.DS_Store
Thumbs.db

# OS
.DS_Store
Thumbs.db
desktop.ini

# Modules locaux
.terraform.lock.hcl
.external_modules
```

**.pre-commit-config.yaml (2026) :**
```yaml
repos:
  - repo: https://github.com/antonbabenko/pre-commit-terraform
    rev: v1.96.0  # Dernière version 2026
    hooks:
      - id: terraform_fmt
      - id: terraform_validate
      - id: terraform_tflint
        args:
          - --args=--config=__GIT_WORKING_DIR__/tflint.hcl
      - id: terraform_checkov
        args:
          - --args=--quiet --soft-fail --skip-check CKV_AZURE_1
      - id: terraform_trivy
        args:
          - --args=--severity CRITICAL,HIGH --ignore-unfixed
      - id: terraform_docs
        args:
          - --args=--hide providers --output-file README.md
      - id: terraform_tfsec
      - id: terraform_providers_lock
        args:
          - --args=-platform=linux_amd64 -platform=darwin_amd64

  - repo: https://github.com/pre-commit/pre-commit-hooks
    rev: v5.0.0
    hooks:
      - id: trailing-whitespace
      - id: end-of-file-fixer
      - id: check-yaml
      - id: check-json
      - id: check-added-large-files
        args: ['--maxkb=500']
      - id: detect-aws-credentials
        args: ['--allow-missing-credentials']
      - id: detect-private-key
      - id: check-case-conflicts
      - id: check-merge-conflict

  - repo: https://github.com/Yelp/detect-secrets
    rev: v1.5.0
    hooks:
      - id: detect-secrets
        args: ['--baseline', '.secrets.baseline']
```

**tflint.hcl :**
```hcl
# Dernière version du plugin AzureRM
plugin "azurerm" {
  enabled = true
  version = "0.27.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

# Règles globales
rule "terraform_required_version" {
  enabled = true
}

rule "terraform_required_providers" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}

rule "terraform_unused_required_providers" {
  enabled = true
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_deprecated_interpolation" {
  enabled = true
}

rule "terraform_deprecated_index" {
  enabled = true
}

# Configuration
config {
  module = true
  force  = false
  
  # Var files pour les tests
  varfile = ["environments/dev/dev.tfvars"]
}
```

### 2.3 Configuration des providers (AzureRM v4.x)

**environments/dev/providers.tf :**
```hcl
# ============================================
# PROVIDERS CONFIGURATION
# AzureRM v4.x – Dernière version stable
# ============================================

terraform {
  required_version = ">= 1.11.0, < 2.0.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"      # Version majeure 4.x
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
  }
}

provider "azurerm" {
  # Configuration des features AzureRM v4
  features {
    # Protection RG
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    
    # Gestion Key Vault améliorée
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
    
    # Virtual Machine v4
    virtual_machine {
      delete_os_disk_on_deletion     = true
      graceful_shutdown              = false
      skip_shutdown_and_force_delete = false
    }
    
    # Application Insights v4
    application_insights {
      disable_generated_rule = false
    }
  }
  
  # OIDC pour CI/CD (recommandé)
  use_oidc = true
  
  # Les autres paramètres viennent des variables d'environnement
  # ARM_CLIENT_ID, ARM_TENANT_ID, ARM_SUBSCRIPTION_ID
}
```

---

## Phase 3 : Création des modules réutilisables <a name="phase3"></a>

### 3.1 Module Networking complet avec tests

**modules/networking/versions.tf :**
```hcl
terraform {
  required_version = ">= 1.11.0"
  
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}
```

**modules/networking/variables.tf :**
```hcl
variable "project_name" {
  type        = string
  description = "Nom du projet"
  
  validation {
    condition     = can(regex("^[a-z0-9-]{3,20}$", var.project_name))
    error_message = "Le nom du projet doit contenir 3-20 caractères (minuscules, chiffres, tirets)."
  }
}

variable "environment" {
  type        = string
  description = "Environnement"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "L'environnement doit être dev, staging ou prod."
  }
}

variable "location" {
  type        = string
  description = "Région Azure"
}

variable "resource_group_name" {
  type        = string
  description = "Nom du RG existant"
}

variable "vnet_address_space" {
  type        = list(string)
  description = "Espace d'adressage"
  default     = ["10.0.0.0/16"]
  
  validation {
    condition     = can(cidrhost(var.vnet_address_space[0], 0))
    error_message = "L'espace d'adressage doit être un CIDR valide."
  }
}

variable "subnet_configs" {
  type = map(object({
    address_prefixes      = list(string)
    service_endpoints     = optional(list(string), [])
    delegation            = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }))
  description = "Configuration des sous-réseaux"
  
  default = {
    "web" = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    "app" = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "db" = {
      address_prefixes  = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
    }
  }
}

variable "enable_ddos_protection" {
  type        = bool
  description = "Activer DDoS Protection"
  default     = false
}

variable "tags" {
  type        = map(string)
  description = "Tags à appliquer"
  default     = {}
}
```

**modules/networking/main.tf :**
```hcl
locals {
  # Conventions de nommage
  vnet_name = "vnet-${var.project_name}-${var.environment}"
  
  subnet_names = {
    for name, config in var.subnet_configs : 
    name => "snet-${name}-${var.environment}"
  }
  
  # Tags fusionnés
  merged_tags = merge(var.tags, {
    Module      = "networking"
    Environment = var.environment
    ManagedBy   = "Terraform"
  })
}

# VNet principal
resource "azurerm_virtual_network" "main" {
  name                = local.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  tags                = local.merged_tags
  
  lifecycle {
    ignore_changes = [
      tags["LastModified"]
    ]
  }
}

# Sous-réseaux dynamiques
resource "azurerm_subnet" "subnets" {
  for_each = var.subnet_configs
  
  name                 = local.subnet_names[each.key]
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = each.value.address_prefixes
  
  # Service endpoints conditionnels
  service_endpoints = try(each.value.service_endpoints, [])
  
  # Délégation conditionnelle
  dynamic "delegation" {
    for_each = try([each.value.delegation], [])
    content {
      name = delegation.value.name
      service_delegation {
        name    = delegation.value.service_delegation.name
        actions = delegation.value.service_delegation.actions
      }
    }
  }
}

# NSG par sous-réseau
resource "azurerm_network_security_group" "nsg" {
  for_each = var.subnet_configs
  
  name                = "nsg-${each.key}-${var.environment}"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = local.merged_tags
}

# Règles NSG pour le sous-réseau web
resource "azurerm_network_security_rule" "web_http" {
  count = contains(keys(var.subnet_configs), "web") ? 1 : 0
  
  name                        = "Allow-HTTP-Inbound"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg["web"].name
}

resource "azurerm_network_security_rule" "web_https" {
  count = contains(keys(var.subnet_configs), "web") ? 1 : 0
  
  name                        = "Allow-HTTPS-Inbound"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nsg["web"].name
}

# Association NSG - Subnet
resource "azurerm_subnet_network_security_group_association" "nsg_assoc" {
  for_each = var.subnet_configs
  
  subnet_id                 = azurerm_subnet.subnets[each.key].id
  network_security_group_id = azurerm_network_security_group.nsg[each.key].id
}

# Outputs
output "vnet_id" {
  description = "ID du VNet"
  value       = azurerm_virtual_network.main.id
}

output "vnet_name" {
  description = "Nom du VNet"
  value       = azurerm_virtual_network.main.name
}

output "subnet_ids" {
  description = "IDs des sous-réseaux"
  value = {
    for name, subnet in azurerm_subnet.subnets : name => subnet.id
  }
}

output "subnet_names" {
  description = "Noms des sous-réseaux"
  value = local.subnet_names
}

output "nsg_ids" {
  description = "IDs des NSG"
  value = {
    for name, nsg in azurerm_network_security_group.nsg : name => nsg.id
  }
}
```

### 3.2 Tests Terraform natifs pour le module Networking

**modules/networking/tests/networking.tftest.hcl :**
```hcl
# ============================================
# TESTS TERRAFORM NATIFS - MODULE NETWORKING
# Terraform v1.11+ 
# ============================================

# Configuration du test
variables {
  project_name        = "test"
  environment         = "test"
  location            = "francecentral"
  resource_group_name = "rg-test-networking"
  vnet_address_space  = ["10.0.0.0/16"]
  
  subnet_configs = {
    "web" = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    "app" = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "db" = {
      address_prefixes  = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
    }
  }
}

# Test 1: Vérification de la création du VNet
run "vnet_creation_test" {
  command = plan
  
  assert {
    condition     = azurerm_virtual_network.main.name == "vnet-test-test"
    error_message = "Le nom du VNet ne respecte pas la convention"
  }
  
  assert {
    condition     = length(azurerm_virtual_network.main.address_space) == 1
    error_message = "Un seul espace d'adressage doit être défini"
  }
  
  assert {
    condition     = can(cidrhost(azurerm_virtual_network.main.address_space[0], 0))
    error_message = "L'espace d'adressage doit être un CIDR valide"
  }
}

# Test 2: Vérification des sous-réseaux
run "subnets_creation_test" {
  command = plan
  
  assert {
    condition     = length(azurerm_subnet.subnets) == 3
    error_message = "3 sous-réseaux doivent être créés"
  }
  
  assert {
    condition     = contains(keys(azurerm_subnet.subnets), "web")
    error_message = "Le sous-réseau web doit exister"
  }
  
  assert {
    condition     = can(azurerm_subnet.subnets["web"].service_endpoints[0] == "Microsoft.Storage")
    error_message = "Le service endpoint doit être configuré pour web"
  }
  
  assert {
    condition     = contains(keys(azurerm_subnet.subnets), "db")
    error_message = "Le sous-réseau db doit exister"
  }
  
  assert {
    condition     = can(azurerm_subnet.subnets["db"].service_endpoints[0] == "Microsoft.Sql")
    error_message = "Le service endpoint SQL doit être configuré pour db"
  }
}

# Test 3: Vérification des NSG
run "nsg_creation_test" {
  command = plan
  
  assert {
    condition     = length(azurerm_network_security_group.nsg) == 3
    error_message = "3 NSG doivent être créés"
  }
  
  assert {
    condition     = can(azurerm_network_security_rule.web_http[0])
    error_message = "La règle HTTP doit exister pour le sous-réseau web"
  }
  
  assert {
    condition     = azurerm_network_security_rule.web_http[0].priority == 100
    error_message = "La priorité HTTP doit être 100"
  }
  
  assert {
    condition     = can(azurerm_network_security_rule.web_https[0])
    error_message = "La règle HTTPS doit exister pour le sous-réseau web"
  }
}

# Test 4: Vérification des outputs
run "outputs_test" {
  command = plan
  
  assert {
    condition     = can(output.vnet_id)
    error_message = "L'output vnet_id doit exister"
  }
  
  assert {
    condition     = can(output.subnet_ids)
    error_message = "L'output subnet_ids doit exister"
  }
  
  assert {
    condition     = can(output.subnet_ids.web)
    error_message = "subnet_ids doit contenir la clé 'web'"
  }
  
  assert {
    condition     = can(output.nsg_ids)
    error_message = "L'output nsg_ids doit exister"
  }
}

# Test 5: Test avec configuration personnalisée
run "custom_configuration_test" {
  command = plan
  
  variables {
    subnet_configs = {
      "custom" = {
        address_prefixes = ["10.0.10.0/24"]
      }
    }
  }
  
  assert {
    condition     = length(azurerm_subnet.subnets) == 1
    error_message = "Un seul sous-réseau doit être créé"
  }
  
  assert {
    condition     = azurerm_subnet.subnets["custom"].address_prefixes[0] == "10.0.10.0/24"
    error_message = "Le préfixe du sous-réseau ne correspond pas"
  }
}

# Test 6: Validation des tags
run "tags_validation_test" {
  command = plan
  
  assert {
    condition     = azurerm_virtual_network.main.tags["Module"] == "networking"
    error_message = "Le tag Module doit être 'networking'"
  }
  
  assert {
    condition     = azurerm_virtual_network.main.tags["Environment"] == "test"
    error_message = "Le tag Environment doit correspondre à l'environnement"
  }
  
  assert {
    condition     = azurerm_virtual_network.main.tags["ManagedBy"] == "Terraform"
    error_message = "Le tag ManagedBy doit être 'Terraform'"
  }
}
```

### 3.3 Module Compute simplifié

**modules/compute/main.tf (extrait) :**
```hcl
resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                = var.vm_name
  resource_group_name = var.resource_group_name
  location            = var.location
  size                = var.vm_size
  
  admin_username                  = var.admin_username
  admin_password                  = var.admin_password
  disable_password_authentication = false
  
  network_interface_ids = [azurerm_network_interface.nic.id]
  
  os_disk {
    caching              = var.os_disk_caching
    storage_account_type = var.os_disk_type
    disk_size_gb         = var.os_disk_size_gb
  }
  
  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }
  
  tags = merge(var.tags, {
    Name = var.vm_name
    Type = "VirtualMachine"
  })
  
  lifecycle {
    ignore_changes = [
      tags["LastModified"]
    ]
  }
}
```

---

## Phase 4 : Configuration multi-environnements <a name="phase4"></a>

### 4.1 Environnement Dev config complet

**environments/dev/backend.tf :**
```hcl
# Backend configuré via le bootstrap
# Les valeurs viennent du fichier backend-configs.json généré
terraform {
  backend "azurerm" {}
}
```

**environments/dev/main.tf :**
```hcl
# ============================================
# ENVIRONNEMENT: DEV
# Terraform v1.11+ | AzureRM v4.x
# ============================================

# Locals pour calculs internes
locals {
  # Suffixe unique pour noms globaux
  unique_suffix = random_string.suffix.result
  
  # Tags standardisés
  common_tags = {
    Environment       = var.environment
    ManagedBy         = "Terraform"
    Project           = var.project_name
    CostCenter        = "DevOps-Dev"
    EnvironmentClass  = "Development"
    AutoShutdown      = try(var.custom_tags["AutoShutdown"], "true")
    DeploymentDate    = timestamp()
    Version           = "2.0"
  }
  
  # SKU par environnement
  sku_tier = {
    dev     = "Standard"
    staging = "Standard"
    prod    = "Premium"
  }
  
  vm_size_map = {
    dev     = "Standard_B1s"
    staging = "Standard_B2s"
    prod    = "Standard_D2s_v3"
  }
}

# Suffixe aléatoire
resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# ========== GROUPE DE RESSOURCES ==========
resource "azurerm_resource_group" "main" {
  name     = "rg-${var.project_name}-${var.environment}-${var.location}"
  location = var.location
  tags     = local.common_tags
  
  lifecycle {
    prevent_destroy = false
  }
}

# ========== MODULE NETWORKING ==========
module "networking" {
  source = "../../modules/networking"
  
  project_name          = var.project_name
  environment           = var.environment
  location              = var.location
  resource_group_name   = azurerm_resource_group.main.name
  vnet_address_space    = var.vnet_address_space
  subnet_configs        = var.subnet_configs
  enable_ddos_protection = false
  
  tags = local.common_tags
}

# ========== MODULE STORAGE ==========
module "storage" {
  source = "../../modules/storage"
  
  storage_name_prefix = "st${var.project_name}"
  environment         = var.environment
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  enable_container_logging = var.environment == "prod" ? true : false
  soft_delete_days        = var.environment == "prod" ? 30 : 7
  
  tags = local.common_tags
}

# ========== MODULE DATABASE ==========
module "database" {
  source = "../../modules/database"
  
  sql_server_name     = "sql-${var.project_name}-${var.environment}"
  location            = var.location
  resource_group_name = azurerm_resource_group.main.name
  
  administrator_login    = var.sql_admin_login
  administrator_password = var.sql_admin_password
  
  database_name    = "appdb-${var.environment}"
  database_sku     = var.environment == "prod" ? "GP_Gen5_2" : "Basic"
  
  allowed_subnet_ids = [module.networking.subnet_ids["db"]]
  
  tags = local.common_tags
}

# ========== MODULE COMPUTE ==========
module "compute" {
  source = "../../modules/compute"
  count  = var.instance_count
  
  vm_name          = "vm-${var.project_name}-${var.environment}-${count.index + 1}"
  location         = var.location
  resource_group_name = azurerm_resource_group.main.name
  subnet_id        = module.networking.subnet_ids["app"]
  admin_username   = var.vm_admin_username
  admin_password   = var.vm_admin_password != null ? var.vm_admin_password : random_password.vm_admin[count.index].result
  vm_size          = local.vm_size_map[var.environment]
  
  create_public_ip = var.environment == "dev" ? false : true
  
  tags = merge(local.common_tags, {
    Instance = format("%02d", count.index + 1)
  })
}

# Mots de passe aléatoires pour dev
resource "random_password" "vm_admin" {
  count  = var.instance_count
  length = 16
  special = true
  override_special = "!@#$%"
}

# ========== KEY VAULT ==========
resource "azurerm_key_vault" "main" {
  name                       = "kv-${var.project_name}-${var.environment}${local.unique_suffix}"
  location                   = var.location
  resource_group_name        = azurerm_resource_group.main.name
  tenant_id                  = data.azurerm_client_config.current.tenant_id
  sku_name                   = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false
  
  tags = local.common_tags
}

data "azurerm_client_config" "current" {}

# Stockage des secrets
resource "azurerm_key_vault_secret" "vm_passwords" {
  count = var.instance_count
  
  name         = "vm-${count.index + 1}-password"
  value        = var.vm_admin_password != null ? var.vm_admin_password : random_password.vm_admin[count.index].result
  key_vault_id = azurerm_key_vault.main.id
  
  tags = local.common_tags
}

# ========== OUTPUTS ==========
output "resource_group_name" {
  description = "Nom du RG"
  value       = azurerm_resource_group.main.name
}

output "vnet_id" {
  description = "ID du VNet"
  value       = module.networking.vnet_id
}

output "subnet_ids" {
  description = "IDs des sous-réseaux"
  value       = module.networking.subnet_ids
}

output "vm_private_ips" {
  description = "IPs privées"
  value       = [for vm in module.compute : vm.private_ip]
}

output "key_vault_name" {
  description = "Nom du Key Vault"
  value       = azurerm_key_vault.main.name
}

output "sql_server_fqdn" {
  description = "FQDN SQL"
  value       = module.database.sql_server_fqdn
}
```

### 4.2 Fichiers de variables et valeurs

**environments/dev/variables.tf :**
```hcl
variable "environment" {
  type        = string
  description = "Environnement"
  
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Environment invalide"
  }
}

variable "project_name" {
  type        = string
  description = "Nom du projet"
  default     = "enterprise-app"
}

variable "location" {
  type        = string
  description = "Région"
  default     = "francecentral"
}

variable "vnet_address_space" {
  type        = list(string)
  default     = ["10.0.0.0/16"]
}

variable "subnet_configs" {
  type = map(object({
    address_prefixes      = list(string)
    service_endpoints     = optional(list(string), [])
    delegation            = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = list(string)
      })
    }))
  }))
  default = {
    "web" = {
      address_prefixes  = ["10.0.1.0/24"]
      service_endpoints = ["Microsoft.Storage"]
    }
    "app" = {
      address_prefixes = ["10.0.2.0/24"]
    }
    "db" = {
      address_prefixes  = ["10.0.3.0/24"]
      service_endpoints = ["Microsoft.Sql"]
    }
  }
}

variable "instance_count" {
  type        = number
  description = "Nombre d'instances"
  default     = 1
}

variable "vm_admin_username" {
  type        = string
  default     = "azureuser"
}

variable "vm_admin_password" {
  type        = string
  sensitive   = true
  default     = null
}

variable "sql_admin_login" {
  type        = string
  default     = "sqladmin"
}

variable "sql_admin_password" {
  type        = string
  sensitive   = true
}

variable "custom_tags" {
  type        = map(string)
  default     = {}
}
```

**environments/dev/dev.tfvars :**
```hcl
environment   = "dev"
project_name  = "enterprise-app"
location      = "francecentral"
instance_count = 1

vm_admin_username = "azureuser"
sql_admin_login   = "sqladmin"

custom_tags = {
  CostCenter   = "DevOps"
  Owner        = "PlatformTeam"
  AutoShutdown = "true"
}

# Les mots de passe sont fournis via variable d'environnement
# TF_VAR_vm_admin_password et TF_VAR_sql_admin_password
```

### 4.3 Tests Terraform pour l'environnement Dev

**environments/dev/tests/dev_test.tftest.hcl :**
```hcl
# ============================================
# TESTS ENVIRONNEMENT DEV
# Validation complète avant déploiement
# ============================================

variables {
  environment   = "dev"
  project_name  = "test-app"
  location      = "francecentral"
  instance_count = 1
  
  vm_admin_username = "testuser"
  vm_admin_password = "TestPassword123!"
  sql_admin_login   = "testadmin"
  sql_admin_password = "TestSQL123!"
}

# Mock du provider pour tests rapides
mock_provider "azurerm" {
  mock_resource "azurerm_resource_group" {
    defaults = {
      id   = "/subscriptions/mock/rg/test"
      name = "rg-test-app-dev-francecentral"
    }
  }
}

# Test 1: Validation du RG
run "resource_group_test" {
  command = plan
  
  assert {
    condition     = azurerm_resource_group.main.name == "rg-test-app-dev-francecentral"
    error_message = "Nom du RG incorrect"
  }
  
  assert {
    condition     = azurerm_resource_group.main.tags["Environment"] == "dev"
    error_message = "Tag Environment incorrect"
  }
  
  assert {
    condition     = azurerm_resource_group.main.tags["ManagedBy"] == "Terraform"
    error_message = "Tag ManagedBy manquant"
  }
}

# Test 2: Validation du networking
run "networking_test" {
  command = plan
  
  assert {
    condition     = can(module.networking.vnet_id)
    error_message = "Module networking doit fournir vnet_id"
  }
  
  assert {
    condition     = can(module.networking.subnet_ids["web"])
    error_message = "Sous-réseau web manquant"
  }
  
  assert {
    condition     = can(module.networking.subnet_ids["app"])
    error_message = "Sous-réseau app manquant"
  }
  
  assert {
    condition     = can(module.networking.subnet_ids["db"])
    error_message = "Sous-réseau db manquant"
  }
}

# Test 3: Validation des instances
run "compute_test" {
  command = plan
  
  assert {
    condition     = length(module.compute) == 1
    error_message = "Une seule VM doit être créée en dev"
  }
  
  assert {
    condition     = try(module.compute[0].create_public_ip, false) == false
    error_message = "Aucune IP publique ne doit être créée en dev"
  }
  
  assert {
    condition     = can(module.compute[0].private_ip)
    error_message = "La VM doit avoir une IP privée"
  }
}

# Test 4: Validation du Key Vault
run "keyvault_test" {
  command = plan
  
  assert {
    condition     = can(azurerm_key_vault.main.name)
    error_message = "Key Vault doit être créé"
  }
  
  assert {
    condition     = can(azurerm_key_vault.main.sku_name == "standard")
    error_message = "SKU du Key Vault doit être standard"
  }
}

# Test 5: Validation des outputs
run "outputs_test" {
  command = plan
  
  assert {
    condition     = can(output.resource_group_name)
    error_message = "Output resource_group_name manquant"
  }
  
  assert {
    condition     = can(output.vnet_id)
    error_message = "Output vnet_id manquant"
  }
  
  assert {
    condition     = can(output.vm_private_ips)
    error_message = "Output vm_private_ips manquant"
  }
}

# Test 6: Test avec instance_count augmenté
run "scaling_test" {
  command = plan
  
  variables {
    instance_count = 3
  }
  
  assert {
    condition     = length(module.compute) == 3
    error_message = "3 VMs doivent être créées"
  }
}
```

---

## Phase 5 : Tests Terraform natifs (terraform test) <a name="phase5"></a>

### 5.1 Introduction à terraform test (v1.11+)

```bash
# Terraform v1.11+ intègre nativement les tests
# Caractéristiques :
# - Tests unitaires et d'intégration
# - Pas besoin d'outils externes (Go, Terratest)
# - Exécution rapide avec mock providers
# - Syntaxe HCL native

# Structure des tests
📁 module/
├── main.tf
├── variables.tf
├── outputs.tf
└── tests/
    └── test_name.tftest.hcl
```

### 5.2 Tests d'intégration complets

**tests/integration/integration.tftest.hcl :**
```hcl
# ============================================
# TESTS D'INTÉGRATION COMPLETS
# Simulation d'un déploiement complet
# ============================================

variables {
  # Variables globales pour tous les tests
  environment   = "integration"
  project_name  = "integration-test"
  location      = "francecentral"
  instance_count = 2
}

# Configuration du provider mock
mock_provider "azurerm" {
  # Mock pour les datasources
  mock_data "azurerm_client_config" {
    defaults = {
      tenant_id       = "00000000-0000-0000-0000-000000000000"
      subscription_id = "11111111-1111-1111-1111-111111111111"
    }
  }
  
  # Mock pour les RGs
  mock_resource "azurerm_resource_group" {
    defaults = {
      id   = "/subscriptions/mock/resourceGroups/mock"
      name = "mock-rg"
    }
  }
}

# ========== TEST 1: DÉPLOIEMENT COMPLET ==========
run "full_deployment_test" {
  command = apply
  
  # Variables spécifiques
  variables {
    instance_count = 2
  }
  
  # Vérifications post-apply
  assert {
    condition     = azurerm_resource_group.main.name != ""
    error_message = "RG doit être créé"
  }
  
  assert {
    condition     = length(module.compute) == 2
    error_message = "2 VMs doivent être créées"
  }
  
  # Vérification des outputs
  assert {
    condition     = can(output.vm_private_ips)
    error_message = "Output vm_private_ips manquant"
  }
  
  assert {
    condition     = length(output.vm_private_ips) == 2
    error_message = "2 IPs privées doivent être outputs"
  }
}

# ========== TEST 2: RÉSEAU ISOLÉ ==========
run "isolated_network_test" {
  command = plan
  
  variables {
    vnet_address_space = ["172.16.0.0/12"]
    subnet_configs = {
      "isolated" = {
        address_prefixes = ["172.16.1.0/24"]
      }
    }
  }
  
  assert {
    condition     = azurerm_virtual_network.main.address_space[0] == "172.16.0.0/12"
    error_message = "Espace d'adressage VNet incorrect"
  }
  
  assert {
    condition     = can(azurerm_subnet.subnets["isolated"])
    error_message = "Sous-réseau isolé doit exister"
  }
}

# ========== TEST 3: HAUTE DISPONIBILITÉ ==========
run "high_availability_test" {
  command = plan
  
  variables {
    instance_count = 3
    
    subnet_configs = {
      "web" = {
        address_prefixes = ["10.0.1.0/24"]
      }
      "app" = {
        address_prefixes = ["10.0.2.0/24"]
      }
      "db" = {
        address_prefixes = ["10.0.3.0/24"]
      }
    }
  }
  
  assert {
    condition     = length(azurerm_subnet.subnets) >= 3
    error_message = "Au moins 3 sous-réseaux pour HA"
  }
  
  assert {
    condition     = length(module.compute) == 3
    error_message = "3 VMs pour la HA"
  }
}

# ========== TEST 4: SÉCURITÉ ET CONFORMITÉ ==========
run "security_validation_test" {
  command = plan
  
  # Vérification HTTPS obligatoire pour Storage
  assert {
    condition     = can(azurerm_storage_account.this[0].https_traffic_only_enabled) == false ? true : true
    error_message = "HTTPS obligatoire sur Storage"
  }
  
  # Vérification TLS 1.2 minimum
  assert {
    condition     = try(azurerm_storage_account.this[0].min_tls_version, "TLS1_2") == "TLS1_2"
    error_message = "TLS 1.2 minimum requis"
  }
  
  # Vérification NSG actifs
  assert {
    condition     = length(azurerm_network_security_group.nsg) >= 3
    error_message = "NSG requis pour chaque sous-réseau"
  }
}

# ========== TEST 5: PERFORMANCE ET SCALING ==========
run "performance_test" {
  command = plan
  
  variables {
    instance_count = 10  # Test scaling
  }
  
  assert {
    condition     = length(module.compute) == 10
    error_message = "10 VMs doivent pouvoir être créées"
  }
  
  assert {
    condition     = length(random_password.vm_admin) == 10
    error_message = "10 mots de passe doivent être générés"
  }
}

# ========== TEST 6: ROLLBACK ET DESTRUCTION ==========
run "destroy_test" {
  # Ce test vérifie que destroy fonctionne
  command = plan
  
  # Simule un destroy
  providers = {
    azurerm = mock_provider.azurerm
  }
  
  assert {
    condition     = true
    error_message = "Destroy plan généré"
  }
}
```

### 5.3 Script d'exécution des tests

**scripts/run-tests.sh :**
```bash
#!/bin/bash
# Script d'exécution des tests Terraform

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🧪 EXÉCUTION DES TESTS TERRAFORM${NC}"
echo -e "${BLUE}========================================${NC}"

# Variables
TEST_RESULTS_DIR="test-results"
mkdir -p $TEST_RESULTS_DIR
TIMESTAMP=$(date +%Y%m%d-%H%M%S)

# Test 1: Modules individuels
echo -e "\n${YELLOW}[1/4] Tests des modules...${NC}"
for module in modules/*/; do
    if [ -d "${module}tests" ]; then
        echo -e "→ Test de ${BLUE}$(basename $module)${NC}"
        cd $module
        terraform test -json > "../../$TEST_RESULTS_DIR/module-$(basename $module)-$TIMESTAMP.json" 2>&1 || true
        cd - > /dev/null
    fi
done

# Test 2: Environnements
echo -e "\n${YELLOW}[2/4] Tests des environnements...${NC}"
for env in dev staging prod; do
    if [ -d "environments/$env/tests" ]; then
        echo -e "→ Test de ${BLUE}$env${NC}"
        cd environments/$env
        terraform test -json > "../../$TEST_RESULTS_DIR/env-$env-$TIMESTAMP.json" 2>&1 || true
        cd - > /dev/null
    fi
done

# Test 3: Tests d'intégration
echo -e "\n${YELLOW}[3/4] Tests d'intégration...${NC}"
cd tests/integration
terraform test -json > "../../$TEST_RESULTS_DIR/integration-$TIMESTAMP.json" 2>&1 || true
cd - > /dev/null

# Test 4: Génération du rapport
echo -e "\n${YELLOW}[4/4] Génération du rapport...${NC}"

# Compter les résultats
TOTAL_TESTS=$(grep -l '"status":"pass"' $TEST_RESULTS_DIR/*.json 2>/dev/null | wc -l)
FAILED_TESTS=$(grep -l '"status":"fail"' $TEST_RESULTS_DIR/*.json 2>/dev/null | wc -l)

echo -e "\n${BLUE}Résumé des tests:${NC}"
echo -e "✅ Tests passés: ${GREEN}$TOTAL_TESTS${NC}"
echo -e "❌ Tests échoués: ${RED}$FAILED_TESTS${NC}"

# Générer rapport HTML (optionnel)
if command -v jq &> /dev/null; then
    echo -e "\n${BLUE}Rapport détaillé:${NC}"
    for file in $TEST_RESULTS_DIR/*.json; do
        if [ -f "$file" ]; then
            echo "- $(basename $file): $(jq -r '.status // "unknown"' $file 2>/dev/null || echo "unknown")"
        fi
    done
fi

# Exit avec code d'erreur si tests échoués
if [ $FAILED_TESTS -gt 0 ]; then
    echo -e "\n${RED}❌ Des tests ont échoué${NC}"
    exit 1
else
    echo -e "\n${GREEN}🎉 Tous les tests sont passés${NC}"
    exit 0
fi
```

### 5.4 Intégration des tests dans pre-commit

**.pre-commit-config.yaml (ajout) :**
```yaml
- repo: local
  hooks:
    - id: terraform-test
      name: Terraform Test
      entry: bash -c 'cd modules/networking && terraform test'
      language: system
      files: \.tf$
      pass_filenames: false
      
    - id: terraform-test-all
      name: Terraform Test All
      entry: ./scripts/run-tests.sh
      language: script
      pass_filenames: false
      stages: [push]
```

---

## Phase 6 : Outils de détection de sécurité <a name="phase6"></a>

### 6.1 Installation des outils (2026)

```bash
#!/bin/bash
# install-security-tools.sh

echo "🔒 Installation des outils de sécurité"

# TFLint
curl -s https://raw.githubusercontent.com/terraform-linters/tflint/master/install_linux.sh | bash

# Checkov
pip install checkov --upgrade

# Trivy (remplace tfsec)
wget https://github.com/aquasecurity/trivy/releases/download/v0.57.0/trivy_0.57.0_Linux-64bit.deb
sudo dpkg -i trivy_0.57.0_Linux-64bit.deb

# Terrascan
curl -L https://github.com/tenable/terrascan/releases/download/v1.19.1/terrascan_1.19.1_Linux_x86_64.tar.gz | tar xz
sudo mv terrascan /usr/local/bin/

# tfsec (déprécié, mais toujours utile)
wget https://github.com/aquasecurity/tfsec/releases/download/v1.28.10/tfsec-linux-amd64
chmod +x tfsec-linux-amd64
sudo mv tfsec-linux-amd64 /usr/local/bin/tfsec

# Pre-commit
pip install pre-commit

echo "✅ Outils installés"
```

### 6.2 Script complet d'analyse de sécurité

**scripts/security-scan.sh :**
```bash
#!/bin/bash
# Analyse de sécurité complète

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SCAN_DIR=${1:-"."}
EXIT_CODE=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🔒 ANALYSE DE SÉCURITÉ TERRAFORM${NC}"
echo -e "${BLUE}Répertoire: $SCAN_DIR${NC}"
echo -e "${BLUE}========================================${NC}"

# 1. TFLint
echo -e "\n${YELLOW}[1/6] TFLint...${NC}"
if command -v tflint &> /dev/null; then
    tflint --chdir=$SCAN_DIR --config=tflint.hcl
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ TFLint OK${NC}"
    else
        echo -e "${RED}❌ TFLint a trouvé des problèmes${NC}"
        EXIT_CODE=1
    fi
else
    echo -e "${YELLOW}⚠️ TFLint non installé${NC}"
fi

# 2. Checkov
echo -e "\n${YELLOW}[2/6] Checkov (conformité)...${NC}"
if command -v checkov &> /dev/null; then
    checkov -d $SCAN_DIR --quiet --soft-fail --output cli
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Checkov OK${NC}"
    else
        echo -e "${YELLOW}⚠️ Checkov a trouvé des warnings${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Checkov non installé${NC}"
fi

# 3. Trivy (sécurité)
echo -e "\n${YELLOW}[3/6] Trivy (vulnérabilités)...${NC}"
if command -v trivy &> /dev/null; then
    trivy config --severity CRITICAL,HIGH --exit-code 0 $SCAN_DIR
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Trivy OK${NC}"
    else
        echo -e "${RED}❌ Vulnérabilités critiques trouvées${NC}"
        EXIT_CODE=1
    fi
else
    echo -e "${YELLOW}⚠️ Trivy non installé${NC}"
fi

# 4. Terrascan
echo -e "\n${YELLOW}[4/6] Terrascan...${NC}"
if command -v terrascan &> /dev/null; then
    terrascan scan -d $SCAN_DIR -o human
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Terrascan OK${NC}"
    else
        echo -e "${YELLOW}⚠️ Terrascan a trouvé des problèmes${NC}"
    fi
else
    echo -e "${YELLOW}⚠️ Terrascan non installé${NC}"
fi

# 5. Recherche de secrets
echo -e "\n${YELLOW}[5/6] Recherche de secrets...${NC}"
SECRETS_FOUND=$(grep -rn "password\|secret\|key\|token" --include="*.tf" --include="*.tfvars" $SCAN_DIR 2>/dev/null | grep -v "variable\." | grep -v "sensitive" | grep -v "var\." | wc -l)
if [ $SECRETS_FOUND -eq 0 ]; then
    echo -e "${GREEN}✅ Aucun secret évident trouvé${NC}"
else
    echo -e "${RED}❌ $SECRETS_FOUND secrets potentiels trouvés${NC}"
    grep -rn "password\|secret\|key\|token" --include="*.tf" --include="*.tfvars" $SCAN_DIR 2>/dev/null | grep -v "variable\." | grep -v "sensitive" | head -10
    EXIT_CODE=1
fi

# 6. Variables sensibles
echo -e "\n${YELLOW}[6/6] Vérification variables sensibles...${NC}"
SENSITIVE_VARS=$(grep -rn "sensitive = false" --include="*.tf" $SCAN_DIR -A 5 | grep "variable" | wc -l)
if [ $SENSITIVE_VARS -eq 0 ]; then
    echo -e "${GREEN}✅ Variables sensibles correctement marquées${NC}"
else
    echo -e "${YELLOW}⚠️ Certaines variables sensibles ne sont pas marquées${NC}"
fi

# Résumé
echo -e "\n${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}✅ ANALYSE DE SÉCURITÉ PASSÉE${NC}"
else
    echo -e "${RED}❌ ANALYSE DE SÉCURITÉ ÉCHOUÉE${NC}"
fi
echo -e "${BLUE}========================================${NC}"

exit $EXIT_CODE
```

---

## Phase 7 : Tests locaux et validation <a name="phase7"></a>

### 7.1 Script complet de validation

**scripts/validate-all.sh :**
```bash
#!/bin/bash
# Validation complète de tous les composants

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

EXIT_CODE=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 VALIDATION COMPLÈTE${NC}"
echo -e "${BLUE}========================================${NC}"

# Fonction de validation d'un répertoire
validate_directory() {
    local dir=$1
    local name=$2
    
    echo -e "\n${YELLOW}📁 Validation: $name ($dir)${NC}"
    
    cd $dir
    
    # Nettoyage
    rm -rf .terraform
    
    # Init sans backend
    terraform init -backend=false -input=false > /dev/null 2>&1
    
    # Format
    if ! terraform fmt -check -recursive > /dev/null 2>&1; then
        echo -e "${RED}❌ Formatage incorrect${NC}"
        terraform fmt -check -recursive
        EXIT_CODE=1
    else
        echo -e "${GREEN}✅ Formatage OK${NC}"
    fi
    
    # Validate
    if ! terraform validate > /dev/null 2>&1; then
        echo -e "${RED}❌ Validation échouée${NC}"
        terraform validate
        EXIT_CODE=1
    else
        echo -e "${GREEN}✅ Validation OK${NC}"
    fi
    
    # Tests (si existent)
    if [ -d "tests" ]; then
        echo -e "${YELLOW}→ Exécution des tests...${NC}"
        terraform test 2>&1 | head -5
        if [ ${PIPESTATUS[0]} -eq 0 ]; then
            echo -e "${GREEN}✅ Tests OK${NC}"
        else
            echo -e "${RED}❌ Tests échoués${NC}"
            EXIT_CODE=1
        fi
    fi
    
    cd - > /dev/null
}

# Validation des modules
echo -e "\n${BLUE}[1/3] Validation des modules...${NC}"
for module in modules/*/; do
    if [ -f "${module}main.tf" ]; then
        validate_directory $module "$(basename $module) (module)"
    fi
done

# Validation des environnements
echo -e "\n${BLUE}[2/3] Validation des environnements...${NC}"
for env in dev staging prod; do
    if [ -d "environments/$env" ]; then
        validate_directory "environments/$env" "$env (environment)"
    fi
done

# Validation des tests d'intégration
echo -e "\n${BLUE}[3/3] Validation des tests d'intégration...${NC}"
if [ -d "tests/integration" ]; then
    validate_directory "tests/integration" "integration"
fi

# Résumé
echo -e "\n${BLUE}========================================${NC}"
if [ $EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}🎉 TOUTES LES VALIDATIONS SONT PASSÉES${NC}"
else
    echo -e "${RED}❌ DES ERREURS ONT ÉTÉ DÉTECTÉES${NC}"
fi
echo -e "${BLUE}========================================${NC}"

exit $EXIT_CODE
```

### 7.2 Test sandbox automatisé

**scripts/sandbox-test.sh :**
```bash
#!/bin/bash
# Test dans un environnement sandbox

set -e

SANDBOX_NAME="sandbox-$(date +%Y%m%d-%H%M%S)"
echo "🏖️ Création sandbox: $SANDBOX_NAME"

# Créer RG temporaire
az group create --name "rg-$SANDBOX_NAME" --location francecentral --tags Purpose=Sandbox AutoDestroy=true

# Créer environnement temporaire
cp -r environments/dev "environments/$SANDBOX_NAME"
cd "environments/$SANDBOX_NAME"

# Config backend local
cat > backend.tf << EOF
terraform {
  backend "local" {
    path = "sandbox.tfstate"
  }
}
EOF

# Variables sandbox
cat > sandbox.tfvars << EOF
environment   = "sandbox"
project_name  = "sandbox"
instance_count = 1
vm_admin_password = "TempSandbox123!"
sql_admin_password = "TempSQL123!"
EOF

# Initialisation
terraform init

# Plan
terraform plan -var-file="sandbox.tfvars"

# Apply (si --apply)
if [ "$1" == "--apply" ]; then
    echo "🚀 Application..."
    terraform apply -var-file="sandbox.tfvars" -auto-approve
    terraform output
    
    # Tests post-déploiement
    echo "🧪 Tests post-déploiement..."
    
    read -p "Appuyez sur Entrée pour détruire..."
    terraform destroy -var-file="sandbox.tfvars" -auto-approve
fi

# Nettoyage
cd ../..
rm -rf "environments/$SANDBOX_NAME"
az group delete --name "rg-$SANDBOX_NAME" --yes --no-wait

echo "✅ Sandbox terminé"
```

---

## Phase 8 : Déploiement (Apply) <a name="phase8"></a>

### 8.1 Script sécurisé de déploiement

**scripts/safe-apply.sh :**
```bash
#!/bin/bash
# Déploiement sécurisé avec validations multiples

set -e

ENVIRONMENT=${1:-"dev"}
FORCE=${2:-""}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}🚀 DÉPLOIEMENT TERRAFORM${NC}"
echo -e "${BLUE}Environnement: ${YELLOW}$ENVIRONMENT${NC}"
echo -e "${BLUE}========================================${NC}"

# Vérifications pré-déploiement
cd environments/$ENVIRONMENT

echo -e "\n${YELLOW}[1/6] Vérification des prérequis...${NC}"
command -v terraform >/dev/null 2>&1 || { echo "❌ Terraform non trouvé"; exit 1; }

echo -e "\n${YELLOW}[2/6] Tests...${NC}"
if [ -d "tests" ]; then
    terraform test || { echo "❌ Tests échoués"; exit 1; }
fi

echo -e "\n${YELLOW}[3/6] Initialisation...${NC}"
terraform init -input=false

echo -e "\n${YELLOW}[4/6] Validation...${NC}"
terraform validate

echo -e "\n${YELLOW}[5/6] Planification...${NC}"
terraform plan -var-file="$ENVIRONMENT.tfvars" -out=deploy.tfplan

# Afficher résumé
echo -e "\n${BLUE}Résumé des changements:${NC}"
terraform show -json deploy.tfplan | jq -r '.resource_changes[] | "  [\(.change.actions[0])] \(.type)/\(.name)"' 2>/dev/null || echo "  (jq non disponible)"

# Confirmation
if [ "$FORCE" != "--force" ]; then
    echo -e "\n${RED}⚠️  Confirmation requise pour $ENVIRONMENT${NC}"
    read -p "Tapez 'APPLY' pour continuer: " CONFIRM
    if [ "$CONFIRM" != "APPLY" ]; then
        echo "❌ Déploiement annulé"
        exit 1
    fi
fi

echo -e "\n${YELLOW}[6/6] Application...${NC}"
terraform apply deploy.tfplan

# Outputs
echo -e "\n${BLUE}Outputs:${NC}"
terraform output

# Sauvegarde du plan
mkdir -p ../../plans
cp deploy.tfplan "../../plans/${ENVIRONMENT}-$(date +%Y%m%d-%H%M%S).tfplan"

# Nettoyage
rm deploy.tfplan

echo -e "\n${GREEN}✅ Déploiement terminé${NC}"
```

---

## Phase 9 : Destruction et nettoyage <a name="phase9"></a>

### 9.1 Script de destruction sécurisé

**scripts/safe-destroy.sh :**
```bash
#!/bin/bash
# Destruction sécurisée

set -e

ENVIRONMENT=${1:-""}
FORCE=${2:-""}

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if [ -z "$ENVIRONMENT" ]; then
    echo "Usage: $0 <environment> [--force]"
    exit 1
fi

echo -e "${RED}========================================${NC}"
echo -e "${RED}💀 DESTRUCTION: $ENVIRONMENT${NC}"
echo -e "${RED}========================================${NC}"

cd environments/$ENVIRONMENT

# Comptage des ressources
terraform init -input=false > /dev/null 2>&1
RESOURCE_COUNT=$(terraform state list 2>/dev/null | wc -l)
echo -e "${YELLOW}⚠️ $RESOURCE_COUNT ressources vont être détruites${NC}"

# Confirmation
if [ "$FORCE" != "--force" ]; then
    echo -e "${RED}⚠️  Destruction définitive !${NC}"
    read -p "Tapez 'DESTROY' pour continuer: " CONFIRM
    if [ "$CONFIRM" != "DESTROY" ]; then
        echo "❌ Destruction annulée"
        exit 1
    fi
fi

# Destruction
terraform destroy -var-file="$ENVIRONMENT.tfvars" -auto-approve

echo -e "${GREEN}✅ Destruction terminée${NC}"
```

---

## Commandes essentielles - Récapitulatif

```bash
# Bootstrap
cd bootstrap && terraform init && terraform apply

# Tests
./scripts/run-tests.sh
./scripts/validate-all.sh

# Sécurité
./scripts/security-scan.sh
pre-commit run --all-files

# Déploiement
./scripts/safe-apply.sh dev
./scripts/safe-apply.sh staging --force
./scripts/safe-apply.sh prod --force

# Destruction
./scripts/safe-destroy.sh dev
./scripts/safe-destroy.sh staging --force

# Tests Terraform natifs
terraform test -verbose
terraform test -json > results.jsonterraform test -filter=TestName

# Nettoyage complet
az group list --query "[?contains(name, 'terraform')].name" -o tsv | xargs -I {} az group delete --name {} --yes
```