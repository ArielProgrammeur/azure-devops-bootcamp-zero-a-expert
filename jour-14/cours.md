# Cours Complet Terraform sur Azure

## Sommaire du Cours

1. [Introduction à Terraform sur Azure](#1-introduction-à-terraform-sur-azure)
2. [Installation et configuration professionnelle](#2-installation-et-configuration-professionnelle)
3. [Syntaxe HCL – Pas à pas](#3-syntaxe-hcl--pas-à-pas)
4. [Provider AzureRM en détail](#4-provider-azurerm-en-détail)
5. [Variables, Outputs et Locals – Guide complet](#5-variables-outputs-et-locals--guide-complet)
6. [Gestion d'État (State) – Backend Azure Storage](#6-gestion-détat-state--backend-azure-storage)
7. [Méta-arguments expliqués](#7-méta-arguments-expliqués)
8. [Modules – Architecture d'entreprise](#8-modules--architecture-dentreprise)
9. [Sécurité et gestion des secrets](#9-sécurité-et-gestion-des-secrets)
10. [Terraform Test – Valider votre infrastructure](#10-terraform-test--valider-votre-infrastructure)
11. [Déploiement CI/CD avec Azure DevOps](#11-déploiement-cicd-avec-azure-devops)
12. [Exemples pratiques complets](#12-exemples-pratiques-complets)
13. [Nettoyage des ressources](#13-nettoyage-des-ressources)
14. [Dépannage et erreurs courantes](#14-dépannage-et-erreurs-courantes)

---

## 1. Introduction à Terraform sur Azure

### 1.1 Qu'est-ce que Terraform ? Explication ligne par ligne

```hcl
# Terraform est un outil d'Infrastructure as Code (IaC)
# Cela signifie que vous écrivez du code pour décrire votre infrastructure
# Au lieu de cliquer dans le portail Azure

# Voici un exemple simple qui crée un groupe de ressources Azure
resource "azurerm_resource_group" "example" {
  # "resource" = mot-clé Terraform pour créer une ressource
  # "azurerm_resource_group" = type de ressource (provider + ressource)
  # "example" = nom local (identifiant dans votre code)
  
  name     = "mon-groupe-ressources"     # Nom dans Azure
  location = "France Central"            # Région Azure
}
```

### 1.2 Comment fonctionne Terraform ? (Workflow expliqué)

```bash
# ÉTAPE 1: terraform init
# Pourquoi ? Télécharge les plugins nécessaires (comme AzureRM)
# Que se passe-t-il ? Crée un dossier .terraform avec les providers
terraform init

# ÉTAPE 2: terraform plan
# Pourquoi ? Voir ce qui va être créé/modifié/supprimé
# Que se passe-t-il ? Compare votre code avec ce qui existe dans Azure
terraform plan

# ÉTAPE 3: terraform apply
# Pourquoi ? Applique les changements dans Azure
# Que se passe-t-il ? Crée/modifie/supprime les ressources
terraform apply

# ÉTAPE 4: terraform destroy
# Pourquoi ? Supprime toutes les ressources
# Attention ! Supprime définitivement (sauf si prevent_destroy est actif)
terraform destroy
```

### 1.3 Terraform vs autres outils Azure (Tableau comparatif détaillé)

| Fonctionnalité | Terraform | Bicep | ARM JSON |
|---|---|---|---|
| **Langage** | HCL (lisible par les humains) | Langage déclaratif similaire à Terraform | JSON (très verbeux) |
| **Multi-cloud** | Oui – un code pour Azure, AWS, GCP | Non – seulement Azure | Non – seulement Azure |
| **Gestion d'état** | Fichier d'état dédié (terraform.tfstate) | Géré par Azure Resource Manager | Géré par ARM |
| **Tests intégrés** | Oui (terraform test depuis v1.6) | Non (tests externes) | Non |
| **Rollback** | Oui (via plans et state) | Non (doit refaire le déploiement) | Non |
| **Modules** | Oui – registry public et privé | Oui – registry Azure | Oui mais complexe |

---

## 2. Installation et configuration professionnelle

### 2.1 Installation détaillée (chaque commande expliquée)

```bash
# MÉTHODE 1: tfenv (RECOMMANDÉE pour les professionnels)
# Pourquoi ? Permet de changer de version facilement

# Étape 1: Cloner tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
# git clone = copie le dépôt
# ~/.tfenv = dossier caché dans votre répertoire personnel

# Étape 2: Ajouter au PATH (chemin d'exécution)
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
# echo = écrit le texte dans le fichier
# export PATH = ajoute un chemin où le système cherche les programmes
# >> = ajoute à la fin du fichier (sans écraser)

# Étape 3: Recharger la configuration
source ~/.bashrc
# source = re-exécute le fichier pour prendre en compte les modifications

# Étape 4: Installer une version spécifique
tfenv install 1.11.0
# 1.11.0 = dernière version stable avec terraform test amélioré

# Étape 5: Utiliser cette version
tfenv use 1.11.0

# Vérification
terraform --version
# Affiche: Terraform v1.11.0 (sur Linux/amd64)
```

### 2.2 Configuration VSCode étape par étape

```json
// .vscode/settings.json
{
  // Active le serveur de langage Terraform
  "terraform.languageServer": {
    "enabled": true,     // true = active l'autocomplétion
    "args": ["serve"]    // commande pour démarrer le serveur
  },
  
  // Formatage automatique quand vous sauvegardez
  "[terraform]": {
    "editor.formatOnSave": true,  // format auto à la sauvegarde
    "editor.tabSize": 2,          // indentation de 2 espaces
    "editor.insertSpaces": true   // utilise des espaces, pas des tabulations
  },
  
  // Ignore le dossier .terraform (où sont les providers)
  "terraform.format": {
    "recursive": true,              // formate aussi les sous-dossiers
    "ignore-path": ".terraform"     // ne pas toucher ce dossier
  }
}
```

### 2.3 Authentification Azure – Chaque méthode expliquée

```bash
# MÉTHODE 1: Azure CLI (POUR LE DÉVELOPPEMENT LOCAL)

# Commande pour se connecter
az login
# Ouvre votre navigateur pour vous connecter
# Une fois connecté, vous avez un token valide

# Vérifier votre abonnement actif
az account show
# Affiche: 
# {
#   "id": "xxxx-xxxx-xxxx",  ← ID de votre abonnement
#   "name": "Azure Pass",
#   "user": { "name": "votre@email.com" }
# }

# Changer d'abonnement si nécessaire
az account set --subscription "ID-DE-VOTRE-ABONNEMENT"

# Vérifier que Terraform peut utiliser Azure CLI
# Terraform utilise automatiquement vos identifiants Azure CLI
# Pas besoin de configuration supplémentaire !

# MÉTHODE 2: Service Principal (POUR CI/CD)

# Créer un Service Principal (identité non-humaine)
# Pourquoi ? Pour que GitHub Actions ou Azure DevOps puissent se connecter
az ad sp create-for-rbac \
  --name "terraform-sp-2025" \           # Nom unique
  --role Contributor \                    # Droits : peut créer des ressources
  --scopes /subscriptions/XXXXXX \        # Sur quel abonnement
  --sdk-auth                             # Format JSON pour les pipelines

# La commande retourne:
# {
#   "clientId": "xxxx",       ← = nom d'utilisateur
#   "clientSecret": "yyyy",   ← = mot de passe (À GARDER SECRET !)
#   "subscriptionId": "zzzz",
#   "tenantId": "tttt"
# }
```

---

## 3. Syntaxe HCL – Pas à pas

### 3.1 Structure d'un fichier .tf (décortiqué)

```hcl
# ==========================================
# PARTIE 1: Bloc terraform (configuration Terraform lui-même)
# ==========================================
terraform {
  # required_version = version de Terraform nécessaire
  # ~> 1.11 signifie : version 1.11.x (mais pas 1.12)
  required_version = "~> 1.11"
  
  # required_providers = quels plugins sont nécessaires
  required_providers {
    # azurerm = nom du provider (interaction avec Azure)
    azurerm = {
      source  = "hashicorp/azurerm"  # source = registry officiel HashiCorp
      version = "~> 4.0"              # version du provider Azure
    }
  }
}

# ==========================================
# PARTIE 2: Bloc provider (configuration du cloud)
# ==========================================
provider "azurerm" {
  # features = configure des comportements spécifiques Azure
  features {
    # Bloc resource_group : comment gérer les groupes
    resource_group {
      # prevent_deletion_if_contains_resources = empêche suppression
      # Si true, terraform destroy échoue si le RG contient des ressources
      prevent_deletion_if_contains_resources = true
    }
  }
}

# ==========================================
# PARTIE 3: Bloc resource (ce qu'on crée dans Azure)
# ==========================================
resource "azurerm_resource_group" "rg" {
  # "azurerm_resource_group" = type dans Azure
  # "rg" = nom que j'utilise dans mon code
  # Je peux y faire référence plus tard: azurerm_resource_group.rg
  
  name     = "rg-projet-001"        # Nom réel dans Azure
  location = "France Central"       # Où
}

# ==========================================
# PARTIE 4: Bloc output (informations après déploiement)
# ==========================================
output "resource_group_id" {
  description = "ID du groupe créé"
  # value = ce qu'on veut afficher
  value = azurerm_resource_group.rg.id
  # id = attribut de la ressource (Azure génère cet ID)
}
```

### 3.2 Types de données – Exemples concrets

```hcl
# ==========================================
# TYPE string (chaîne de caractères)
# ==========================================
variable "project_name" {
  type    = string
  default = "monprojet"
  # utilisation: "monprojet"
}

# ==========================================
# TYPE number (nombre)
# ==========================================
variable "instance_count" {
  type    = number
  default = 3
  # utilisation: 3, 42, 3.14
}

# ==========================================
# TYPE bool (booléen : vrai/faux)
# ==========================================
variable "enable_monitoring" {
  type    = bool
  default = true
  # utilisation: true (vrai) ou false (faux)
}

# ==========================================
# TYPE list (liste ordonnée)
# ==========================================
variable "allowed_ips" {
  type    = list(string)
  default = ["10.0.0.1", "10.0.0.2", "10.0.0.3"]
  # accès à l'élément 0: "10.0.0.1"
}

# ==========================================
# TYPE map (dictionnaire clé → valeur)
# ==========================================
variable "vm_sizes" {
  type    = map(string)
  default = {
    dev = "Standard_B1s"      # clé "dev" → valeur "Standard_B1s"
    prod = "Standard_D2s_v3"  # clé "prod" → valeur "Standard_D2s_v3"
  }
  # utilisation: vm_sizes["dev"] retourne "Standard_B1s"
}

# ==========================================
# TYPE object (structure complexe)
# ==========================================
variable "database_config" {
  type = object({
    name     = string
    sku      = string
    capacity = number
    geo_backup_enabled = bool
  })
  default = {
    name     = "mydb"
    sku      = "GP_Gen5"
    capacity = 2
    geo_backup_enabled = true
  }
  # accès: database_config.name, database_config.sku
}
```

### 3.3 Fonctions natives – Guide pratique

```hcl
# ==========================================
# FONCTIONS DE MANIPULATION DE CHAÎNES
# ==========================================

# upper() = met en majuscules
locals {
  env_upper = upper("dev")  # résultat: "DEV"
}

# lower() = met en minuscules
locals {
  name_lower = lower("MONPROJET")  # résultat: "monprojet"
}

# join() = colle des chaînes avec séparateur
locals {
  storage_name = join("", ["st", "projet", "dev"])
  # résultat: "stprojetdev"
}

# format() = formatage style printf
locals {
  formatted = format("rg-%s-%s", "projet", "dev")
  # %s = placeholder pour string, résultat: "rg-projet-dev"
}

# ==========================================
# FONCTIONS DE MANIPULATION DE LISTES
# ==========================================

# length() = nombre d'éléments
locals {
  my_list = ["a", "b", "c"]
  count = length(my_list)  # résultat: 3
}

# element() = élément à un index (avec sécurité)
locals {
  second = element(["a", "b", "c"], 1)  # résultat: "b"
  # Si index hors limite, prend le dernier élément
}

# concat() = fusionne plusieurs listes
locals {
  merged = concat(["a", "b"], ["c", "d"])  # résultat: ["a","b","c","d"]
}

# ==========================================
# FONCTIONS DE MANIPULATION DE MAPS
# ==========================================

# lookup() = chercher dans une map avec valeur par défaut
locals {
  sizes = {
    dev = "small"
    prod = "large"
  }
  dev_size = lookup(sizes, "dev", "medium")   # résultat: "small"
  test_size = lookup(sizes, "test", "medium") # résultat: "medium" (par défaut)
  # 1er arg: map, 2e: clé, 3e: valeur par défaut
}
```

### 3.4 Expressions conditionnelles expliquées

```hcl
# ==========================================
# CONDITION TERNAIRE (SI ALORS SINON)
# Syntaxe: condition ? valeur_si_vrai : valeur_si_faux
# ==========================================

variable "environment" {
  type = string
  default = "prod"
}

# Exemple 1: choix du SKU selon l'environnement
locals {
  # Si environment == "prod", alors sku = "Standard_GRS"
  # Sinon, sku = "Standard_LRS"
  sku = var.environment == "prod" ? "Standard_GRS" : "Standard_LRS"
}

# Exemple 2: condition pour créer ou non une ressource
resource "azurerm_resource_group" "optional_rg" {
  # Si create_rg = true, count = 1 (une instance)
  # Si create_rg = false, count = 0 (aucune instance)
  count = var.create_rg ? 1 : 0
  
  name     = "rg-optionnel"
  location = "France Central"
}
```

---

## 4. Provider AzureRM en détail

### 4.1 Configuration du provider – Ligne par ligne

```hcl
# ==========================================
# FICHIER: provider.tf
# ==========================================

# Bloc terraform : versioning et providers requis
terraform {
  required_version = "~> 1.11"  # Terraform lui-même
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"  # Source officielle
      version = "~> 4.0"              # Version majeure 4
    }
  }
}

# Bloc provider : configuration de la connexion Azure
provider "azurerm" {
  # LE BLOC features : configure le comportement d'AZURE
  # Sans ce bloc, Terraform ne peut pas fonctionner !
  features {
    
    # ===== SOUS-BLOC resource_group =====
    resource_group {
      # prevent_deletion_if_contains_resources : PROTECTION CRITIQUE
      # À true: terraform destroy échoue si le RG contient des ressources
      # À false: terraform destroy supprime TOUT (dangereux en prod)
      prevent_deletion_if_contains_resources = true
      
      # Autres options (moins utilisées):
      # recover_soft_deleted_resource_groups = true
    }
    
    # ===== SOUS-BLOC key_vault =====
    key_vault {
      # purge_soft_delete_on_destroy : Nettoyage définitif
      # Quand true : quand vous supprimez un Key Vault, il est purgé
      # Quand false : reste 7-90 jours (soft delete)
      purge_soft_delete_on_destroy = true
      
      # recover_soft_deleted_key_vaults : Réutilisation de noms
      # Quand true : si un KV supprimé existe, Terraform le récupère
      # Quand false : crée un nouveau (peut échouer si nom existe)
      recover_soft_deleted_key_vaults = true
    }
    
    # ===== SOUS-BLOC virtual_machine =====
    virtual_machine {
      # delete_os_disk_on_deletion : Nettoyage automatique
      # Quand true : supprime le disque OS quand la VM est supprimée
      delete_os_disk_on_deletion = true
      
      # graceful_shutdown : Arrêt propre
      # Quand true : envoie un signal d'arrêt avant suppression
      graceful_shutdown = false
    }
  }
  
  # ===== AUTHENTIFICATION =====
  # Ces variables sont optionnelles si vous avez fait "az login"
  
  # Pour CI/CD (GitHub Actions, Azure DevOps)
  # DÉCOMMENTEZ POUR PRODUCTION
  /*
  client_id       = var.azure_client_id    # Service Principal client ID
  client_secret   = var.azure_client_secret # Service Principal secret
  tenant_id       = var.azure_tenant_id     # Votre tenant Azure AD
  subscription_id = var.azure_subscription_id # Abonnement Azure
  use_oidc        = true                    # Utiliser OpenID Connect
  */
}
```

### 4.2 Comprendre le bloc features – Tableau détaillé

| Feature | Description | Quand l'activer | Risques si désactivé |
|---------|-------------|----------------|----------------------|
| `prevent_deletion_if_contains_resources` | Empêche suppression RG non vide | TOUJOURS en prod, recommandé en dev | Destruction accidentelle de TOUTES les ressources |
| `purge_soft_delete_on_destroy` | Supprime définitivement les KV | En dev/test (évite frais) | Le KV reste dans soft delete (facturation possible) |
| `recover_soft_deleted_key_vaults` | Réutilise KV supprimés | Quand vous voulez garder le même nom | Peut échouer si le nom existe encore |
| `delete_os_disk_on_deletion` | Nettoie les disques | Toujours true (évite frais inutiles) | Disques orphelins (facturés) |
| `skip_shutdown_and_force_delete` | Force suppression sans arrêt | Jamais (sauf contraintes techniques) | Corruption de données possible |

---

## 5. Variables, Outputs et Locals – Guide complet

### 5.1 Variables – Déclaration complète

```hcl
# ==========================================
# FICHIER: variables.tf
# ==========================================

# Variable simple avec description
variable "project_name" {
  description = "Nom du projet (utilisé pour nommer toutes les ressources)"
  type        = string
  default     = "myproject"
}

# Variable avec validation (CRITIQUE en entreprise)
variable "environment" {
  description = "Environnement cible"
  type        = string
  
  # VALIDATION : empêche les valeurs incorrectes
  validation {
    # condition = règle de validation
    condition     = contains(["dev", "staging", "prod"], var.environment)
    # contains(vérifie si la valeur est dans la liste)
    # [var.environment] est une liste de valeurs autorisées
    
    # error_message = message affiché si la condition échoue
    error_message = "L'environnement doit être dev, staging ou prod."
  }
  
  # Deuxième validation : format
  validation {
    condition     = can(regex("^(dev|staging|prod)$", var.environment))
    # regex = expression régulière (pattern matching)
    # ^ = début, $ = fin, | = ou
    error_message = "Format d'environnement invalide."
  }
}

# Variable sensible (ne sera JAMAIS affichée)
variable "admin_password" {
  description = "Mot de passe administrateur"
  type        = string
  sensitive   = true  # Masqué dans les logs et les outputs
  # Default n'est PAS défini pour forcer l'utilisateur à fournir
}

# Variable object (structure complexe)
variable "network_config" {
  description = "Configuration réseau complète"
  type = object({
    vnet_address_space = list(string)      # Liste de CIDRs
    subnets = map(object({                 # Map de sous-réseaux
      cidr              = string
      service_endpoints = list(string)
      delegations = optional(list(object({ # Optionnel (peut être null)
        name = string
        service_delegation = object({
          name    = string
          actions = list(string)
        })
      })))
    }))
  })
  
  # Valeur par défaut complète
  default = {
    vnet_address_space = ["10.0.0.0/16"]
    subnets = {
      web = {
        cidr              = "10.0.1.0/24"
        service_endpoints = ["Microsoft.Storage"]
        delegations       = null
      }
      app = {
        cidr              = "10.0.2.0/24"
        service_endpoints = []
        delegations       = null
      }
    }
  }
}
```

### 5.2 Variables via fichiers .tfvars

```hcl
# ==========================================
# FICHIER: dev.tfvars (NON versionné pour secrets)
# ==========================================

# Ce fichier contient les valeurs pour l'environnement DEV
environment     = "dev"
project_name    = "demo"
admin_password  = "TempP@ssw0rd123!"  # ← Secret, ne pas versionner

# ==========================================
# FICHIER: prod.tfvars (versionné, sans secrets)
# ==========================================

environment     = "prod"
project_name    = "demo"
# admin_password PAS DÉFINI ici (doit venir du pipeline)
```

**Utilisation des fichiers .tfvars :**

```bash
# Pour utiliser un fichier .tfvars
terraform plan -var-file="dev.tfvars"

# Pour plusieurs fichiers (le dernier écrase les précédents)
terraform plan -var-file="common.tfvars" -var-file="dev.tfvars"

# Pour une variable individuelle
terraform plan -var="environment=dev"

# Mélange des trois méthodes (ordre de priorité)
# 1. -var (priorité maximale)
# 2. -var-file (priorité moyenne)
# 3. variables.tf default (priorité minimale)
```

### 5.3 Locals – Calculs intelligents

```hcl
# ==========================================
# FICHIER: locals.tf
# ==========================================

locals {
  # ===== TAGS STANDARDISÉS =====
  common_tags = {
    # Mélange de variables et de valeurs fixes
    Environment   = var.environment
    ManagedBy     = "Terraform"
    Project       = var.project_name
    CostCenter    = "IT-Ops"
    DeploymentDate = timestamp()  # timestamp() = date/heure actuelle
  }
  
  # ===== NOMS DYNAMIQUES =====
  # Pour éviter les collisions dans Azure Storage (noms uniques globaux)
  storage_name = lower(join("", [
    "st",                      # préfixe pour storage
    var.project_name,          # nom du projet
    var.environment,           # environnement
    random_string.suffix.result # suffixe aléatoire unique
  ]))
  # Exemple: "stmyprojectdevabc123"
  
  # ===== LOGIQUE MÉTIER =====
  # Carte de correspondance env → SKU
  sku_map = {
    dev     = "Standard_LRS"
    staging = "Standard_GRS"
    prod    = "Standard_GRS"
  }
  
  # Lookup avec valeur par défaut
  sku = lookup(local.sku_map, var.environment, "Standard_LRS")
  
  # ===== CONDITIONS COMPLEXES =====
  # Exemple: nombre d'instances selon l'environnement
  instance_count = var.environment == "prod" ? 3 : (
    var.environment == "staging" ? 2 : 1
  )
  # Signification:
  # Si environment = prod → 3 instances
  # Sinon si environment = staging → 2 instances
  # Sinon → 1 instance
  
  # ===== CONCATÉNATION AVEC FORMATAGE =====
  resource_group_name = format("rg-%s-%s-%s",
    var.project_name,
    var.environment,
    random_string.suffix.result
  )
}
```

### 5.4 Outputs – Récupérer les informations

```hcl
# ==========================================
# FICHIER: outputs.tf
# ==========================================

# Output simple
output "resource_group_name" {
  description = "Nom du groupe de ressources"
  value       = azurerm_resource_group.rg.name
}

# Output sensible (masqué)
output "admin_password" {
  description = "Mot de passe administrateur"
  value       = var.admin_password
  sensitive   = true  # N'apparaît pas dans les logs
}

# Output avec conditions
output "public_ip" {
  description = "IP publique (si créée)"
  # Si la ressource existe, affiche son IP
  # Sinon, affiche "Not created"
  value       = var.create_public_ip ? azurerm_public_ip.pip[0].ip_address : "Not created"
}

# Output pour lien dans d'autres stacks
output "vnet_id" {
  description = "ID du VNET pour l'import"
  value       = azurerm_virtual_network.vnet.id
  # Exported value: /subscriptions/xxx/resourceGroups/yyy/providers/Microsoft.Network/virtualNetworks/zzz
}
```

**Utiliser les outputs :**

```bash
# Afficher tous les outputs après terraform apply
terraform output

# Afficher un output spécifique
terraform output resource_group_name

# Afficher en format JSON (pour scripts)
terraform output -json
```

---

## 6. Gestion d'État (State) – Backend Azure Storage

### 6.1 Pourquoi un backend distant ? Explication détaillée

```hcl
# ==========================================
# PROBLÈME: terraform.tfstate local
# ==========================================

# Sans backend distant, Terraform crée un fichier local:
# terraform.tfstate

# PROBLÈMES avec le state local:
# 1. Travail en équipe: Impossible
#    - Alice crée un RG
#    - Bob crée une VM
#    - Leurs states sont différents → conflits

# 2. Perte de données
#    - Vous supprimez terraform.tfstate
#    - Terraform ne sait plus ce qui existe → crée des doublons

# 3. Sécurité
#    - terraform.tfstate contient des secrets en clair
#    - Local = accessible par tous les processus

# 4. Locking
#    - Deux personnes peuvent faire apply en même temps
#    - Résultat: state corrompu

# ==========================================
# SOLUTION: Backend distant Azure Storage
# ==========================================

# Avec Azure Storage:
# - State stocké dans un blob Azure (sécurisé, accessible à tous)
# - Locking automatique (blob lease)
# - Versioning history (rétention)
```

### 6.2 Configuration backend – Pas à pas

```bash
# ==========================================
# ÉTAPE 1: Créer le Storage Account du state (UNE SEULE FOIS)
# ==========================================

# Variables
RESOURCE_GROUP="rg-terraform-state"
STORAGE_ACCOUNT="stterraformstate$(openssl rand -hex 4)"  # Nom unique
CONTAINER_NAME="tfstate"

# Créer le groupe de ressources
az group create \
  --name $RESOURCE_GROUP \
  --location "France Central"
# --name = nom du RG
# --location = région

# Créer le storage account
az storage account create \
  --name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --sku Standard_LRS \
  --encryption-services blob
# --sku Standard_LRS = localement redondant (pas cher)
# --encryption-services blob = chiffrement activé

# Créer le conteneur pour les states
az storage container create \
  --name $CONTAINER_NAME \
  --account-name $STORAGE_ACCOUNT \
  --public-access off
# --public-access off = privé (recommandé)

# Récupérer la clé d'accès
az storage account keys list \
  --account-name $STORAGE_ACCOUNT \
  --resource-group $RESOURCE_GROUP \
  --query "[0].value" -o tsv
# Cette clé servira pour l'authentification du backend

# ==========================================
# ÉTAPE 2: Configurer le backend dans Terraform
# ==========================================
```

```hcl
# FICHIER: backend.tf
terraform {
  backend "azurerm" {
    # Le backend AZURE STORAGE
    # Toutes ces valeurs sont OBLIGATOIRES
    
    resource_group_name  = "rg-terraform-state"  # RG contenant le storage
    storage_account_name = "stterraformstatea1b2c3d4"  # Nom de votre storage
    container_name       = "tfstate"              # Conteneur pour le state
    key                  = "prod.terraform.tfstate"  # Nom du fichier state
    
    # AUTHENTIFICATION (choisir une méthode)
    
    # Méthode 1: Access Key (simple)
    access_key = "votre-clé-stockée-dans-un-secret"
    
    # Méthode 2: SAS Token (plus sécurisé)
    # sas_token = "?sv=2022-11-02&ss=b..."
    
    # Méthode 3: Managed Identity (CI/CD Azure)
    # use_azuread_auth = true
    # use_azuread_auth = "true"
    
    # ACTIVITÉS DE LOCK
    # Azure bloque automatiquement le blob pendant apply
    # Pas besoin de configuration spéciale
  }
}
```

**ATTENTION IMPORTANTE:** Le backend ne peut PAS utiliser de variables !

```hcl
# CECI NE FONCTIONNE PAS:
terraform {
  backend "azurerm" {
    key = var.environment  # ERREUR: les variables ne sont pas autorisées
  }
}

# SOLUTION: utiliser -backend-config
```

### 6.3 Utilisation du backend avec configuration externe

```bash
# ==========================================
# MÉTHODE: backend-config
# ==========================================

# Créer un fichier backend.conf (non versionné)
cat > backend.conf <<EOF
resource_group_name  = "rg-terraform-state"
storage_account_name = "stterraformstateabc123"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
access_key           = "$(az storage account keys list --account-name stterraformstateabc123 --resource-group rg-terraform-state --query "[0].value" -o tsv)"
EOF

# Initialiser avec ce fichier
terraform init -backend-config=backend.conf

# Pour changer d'environnement (ex: production)
terraform init -reconfigure -backend-config=backend-prod.conf
# -reconfigure = ignore l'état existant et reconfigure
```

### 6.4 Structure d'état professionnelle

```
📁 projet-terraform/
├── 📁 environments/
│   ├── 📁 dev/
│   │   ├── main.tf
│   │   ├── dev.tfvars
│   │   └── backend.conf   # key = "dev.tfstate"
│   ├── 📁 staging/
│   │   ├── main.tf
│   │   ├── staging.tfvars
│   │   └── backend.conf   # key = "staging.tfstate"
│   └── 📁 prod/
│       ├── main.tf
│       ├── prod.tfvars
│       └── backend.conf   # key = "prod.tfstate"
```

**Fichier backend.conf pour DEV:**
```hcl
resource_group_name  = "rg-terraform-state"
storage_account_name = "stterraformstateabc"
container_name       = "tfstate"
key                  = "dev.terraform.tfstate"
```

**Résultat dans Azure Storage:**
```
Conteneur: tfstate
├── dev.terraform.tfstate    (locké pendant apply)
├── staging.terraform.tfstate
└── prod.terraform.tfstate
```

---

## 7. Méta-arguments expliqués

### 7.1 `count` – Création multiple ou conditionnelle

```hcl
# ==========================================
# EXEMPLE 1: Création conditionnelle
# ==========================================

variable "create_storage" {
  type    = bool
  default = true
}

# Si create_storage = true → une instance
# Si create_storage = false → zéro instance
resource "azurerm_storage_account" "optional" {
  count = var.create_storage ? 1 : 0
  # count = 0 ou 1
  
  name                     = "stoptional${count.index}"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Pour accéder à cette ressource conditionnelle:
# Si elle existe: azurerm_storage_account.optional[0].name
# Si elle n'existe pas: l'accès échoue

# ==========================================
# EXEMPLE 2: Création multiple (identique)
# ==========================================

variable "subnet_count" {
  type    = number
  default = 3
}

# Crée 3 sous-réseaux identiques
resource "azurerm_subnet" "subnet" {
  count = var.subnet_count  # count = 3
  
  name                 = "subnet-${count.index}"
  # count.index = 0 pour le premier, 1 pour le second, etc.
  
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.${count.index}.0/24"]
  # 0 → 10.0.0.0/24
  # 1 → 10.0.1.0/24
  # 2 → 10.0.2.0/24
}

# ==========================================
# ACCÈS AUX RESSOURCES AVEC COUNT
# ==========================================

# Accéder à la première ressource
output "first_subnet" {
  value = azurerm_subnet.subnet[0].name
}

# Accéder à toutes (pour for_each ou dynamic)
output "all_subnets" {
  value = azurerm_subnet.subnet[*].name
  # Le [*] = splat expression, retourne toutes les valeurs
}
```

### 7.2 `for_each` – Création multiple avec configuration distincte

```hcl
# ==========================================
# EXEMPLE: Sous-réseaux avec configurations différentes
# ==========================================

variable "subnets" {
  description = "Configuration des sous-réseaux"
  type = map(object({
    cidr               = string
    service_endpoints  = list(string)
    delegation_name    = optional(string)  # optionnel
  }))
  
  default = {
    # Clé = nom du sous-réseau
    "web" = {                    # subnet.name = "web"
      cidr              = "10.0.1.0/24"
      service_endpoints = ["Microsoft.Storage"]
      delegation_name   = null
    }
    "app" = {                    # subnet.name = "app"
      cidr              = "10.0.2.0/24"
      service_endpoints = []
      delegation_name   = null
    }
    "db" = {                    # subnet.name = "db"
      cidr              = "10.0.3.0/24"
      service_endpoints = ["Microsoft.Sql"]
      delegation_name   = "sql-delegation"  # délégation spécifique
    }
  }
}

resource "azurerm_subnet" "subnet" {
  # for_each parcourt la map var.subnets
  for_each = var.subnets
  
  # each.key = la clé de la map ("web", "app", "db")
  name = each.key
  
  # each.value = l'objet correspondant
  # each.value.cidr, each.value.service_endpoints, etc.
  cidr = each.value.cidr
  
  # Accès aux propriétés avec coalesce (si null, utiliser liste vide)
  service_endpoints = each.value.service_endpoints
  
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  
  # Bloc dynamic : créé seulement si delegation_name n'est pas null
  dynamic "delegation" {
    # for_each = liste d'un élément si condition, sinon liste vide
    for_each = each.value.delegation_name != null ? [1] : []
    # [1] = un élément pour créer le bloc
    # [] = aucun élément pour ne pas créer le bloc
    
    content {
      name = each.value.delegation_name
      service_delegation {
        name = "Microsoft.Sql/managedInstances"
        actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
      }
    }
  }
}

# ==========================================
# ACCÈS AUX RESSOURCES AVEC FOR_EACH
# ==========================================

# Accéder à un sous-réseau spécifique
output "web_subnet_id" {
  value = azurerm_subnet.subnet["web"].id
}

# Afficher toutes les valeurs
output "all_subnet_ids" {
  value = {
    for k, subnet in azurerm_subnet.subnet : k => subnet.id
  }
  # Résultat: {"web": "/subscriptions/...", "app": "/subscriptions/...", "db": "/subscriptions/..."}
}
```

### 7.3 `depends_on` – Dépendance explicite

```hcl
# ==========================================
# QUAND UTILISER depends_on ?
# ==========================================

# Terraform détecte AUTOMATIQUEMENT les dépendances via les références:
resource "azurerm_resource_group" "rg" {
  # Cette ressource sera créée APRÈS la ressource A
  # parce que j'utilise azurerm_resource_group.rg.name
  name     = "rg-depends"
  location = "France Central"
  
  depends_on = [
    azurerm_resource_group.other_rg  # Force la création dans l'ordre
  ]
}

# EXEMPLE RÉEL: dépendance explicite nécessaire
resource "azurerm_app_service_plan" "asp" {
  name                = "asp-monapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  sku {
    tier = "Standard"
    size = "S1"
  }
}

resource "azurerm_app_service" "app" {
  name                = "monapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  # Dépendance explicite (optionnel car Terraform voit la référence)
  depends_on = [azurerm_app_service_plan.asp]
  
  # Terraform DÉDUIT déjà la dépendance via app_service_plan_id
  app_service_plan_id = azurerm_app_service_plan.asp.id
}

# ❌ Mauvais usage: PAS BESOIN de depends_on dans 99% des cas
# ✅ Bon usage: dépendances entre providers, appels API externes
# ✅ Bon usage: ressources sans références directes (ex: logs, policies)
```

### 7.4 `lifecycle` – Contrôle du cycle de vie

```hcl
# ==========================================
# lifecycle - Prévenir la suppression (PROTECTION CRITIQUE)
# ==========================================

resource "azurerm_resource_group" "production_rg" {
  name     = "rg-production"
  location = "France Central"
  
  lifecycle {
    # prevent_destroy = empêche terraform destroy
    prevent_destroy = true
    
    # Si vous exécutez "terraform destroy" avec cette ressource:
    # ERROR: cannot destroy resource without setting count=0
  }
}

# ==========================================
# lifecycle - Ignorer les changements externes
# ==========================================

resource "azurerm_app_service" "webapp" {
  name                = "myapp"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  
  site_config {
    dotnet_framework_version = "v8.0"
  }
  
  tags = {
    Environment = "prod"
    ManagedBy   = "Terraform"
  }
  
  lifecycle {
    # ignore_changes = ignore les modifications faites hors Terraform
    ignore_changes = [
      tags["LastDeployedBy"],  # Ignore ce tag spécifique
      site_config[0].always_on # Ignore ce paramètre
    ]
    
    # Exemple: Un pipeline ajoute un tag "LastDeployedBy=2025-01-01"
    # Terraform ne va PAS supprimer ce tag quand il recrée la ressource
  }
}

# ==========================================
# lifecycle - Zero-downtime deployment
# ==========================================

resource "azurerm_storage_account" "sa" {
  name                     = "mystorageaccount"
  resource_group_name      = azurerm_resource_group.rg.name
  location                 = azurerm_resource_group.rg.location
  account_tier             = "Standard"
  account_replication_type = "LRS"
  
  lifecycle {
    # create_before_destroy = créer la nouvelle avant détruire l'ancienne
    create_before_destroy = true
    
    # Scénario: vous changez account_replication_type de LRS à GRS
    # Sans create_before_destroy: détruit LRS, puis crée GRS (temps mort)
    # Avec create_before_destroy: crée GRS, puis supprime LRS (zero downtime)
  }
}
```

---

## 8. Modules – Architecture d'entreprise

### 8.1 Structure d'un module professionnel

```
📁 modules/
└── 📁 azure_virtual_machine/
    ├── main.tf          # Ressources du module
    ├── variables.tf     # Paramètres d'entrée
    ├── outputs.tf       # Valeurs de sortie
    ├── versions.tf      # Versions requises
    ├── README.md        # Documentation
    ├── locals.tf        # Calculs internes
    └── tests/           # Tests du module
        └── main.tftest.hcl
```

### 8.2 Module complet – Azure Virtual Machine

**FICHIER: modules/azure_virtual_machine/variables.tf**

```hcl
# ==========================================
# VARIABLES OBLIGATOIRES
# ==========================================

variable "vm_name" {
  description = "Nom de la machine virtuelle"
  type        = string
  
  validation {
    condition     = can(regex("^[a-z0-9]([-a-z0-9]*[a-z0-9])?$", var.vm_name))
    error_message = "Le nom doit être en minuscules, chiffres, et tirets."
  }
}

variable "location" {
  description = "Région Azure"
  type        = string
}

variable "resource_group_name" {
  description = "Nom du groupe de ressources existant"
  type        = string
}

variable "subnet_id" {
  description = "ID du sous-réseau"
  type        = string
}

# ==========================================
# VARIABLES AVEC VALEURS PAR DÉFAUT
# ==========================================

variable "vm_size" {
  description = "Taille de la VM"
  type        = string
  default     = "Standard_B1s"
  
  validation {
    condition     = can(regex("^(Standard_|Basic_)", var.vm_size))
    error_message = "La taille doit commencer par Standard_ ou Basic_"
  }
}

variable "admin_username" {
  description = "Nom d'utilisateur admin"
  type        = string
  default     = "azureuser"
}

# ==========================================
# VARIABLES SENSIBLES
# ==========================================

variable "admin_password" {
  description = "Mot de passe admin"
  type        = string
  sensitive   = true
  # PAS DE DEFAULT - doit être fourni
}

variable "source_image" {
  description = "Image source pour la VM"
  type = object({
    publisher = string
    offer     = string
    sku       = string
    version   = string
  })
  default = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "22.04-LTS"
    version   = "latest"
  }
}

variable "tags" {
  description = "Tags à appliquer"
  type        = map(string)
  default     = {}
}
```

**FICHIER: modules/azure_virtual_machine/main.tf**

```hcl
# ==========================================
# RESSOURCES ALÉATOIRES POUR UNICITÉ
# ==========================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
  numeric = true
}

# ==========================================
# IP PUBLIQUE (OPTIONNELLE)
# ==========================================

resource "azurerm_public_ip" "pip" {
  # count = 0 ou 1 selon var.create_public_ip
  count = var.create_public_ip ? 1 : 0
  
  name                = "${var.vm_name}-pip"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Dynamic"
  sku                 = "Basic"
  tags                = var.tags
}

# ==========================================
# INTERFACE RÉSEAU
# ==========================================

resource "azurerm_network_interface" "nic" {
  name                = "${var.vm_name}-nic"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags

  ip_configuration {
    name                          = "ipconfig1"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = try(azurerm_public_ip.pip[0].id, null)
    # try(..., null) = si la ressource existe, prend son ID, sinon null
  }
}

# ==========================================
# MACHINE VIRTUELLE LINUX
# ==========================================

resource "random_string" "suffix" {
  length  = 6
  special = false
  upper   = false
}

resource "azurerm_linux_virtual_machine" "vm" {
  name                  = var.vm_name
  location              = var.location
  resource_group_name   = var.resource_group_name
  network_interface_ids = [azurerm_network_interface.nic.id]
  size                  = var.vm_size
  
  admin_username        = var.admin_username
  admin_password        = var.admin_password
  disable_password_authentication = false
  
  # DISQUE OS
  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
    disk_size_gb         = 30
  }
  
  # IMAGE SOURCE
  source_image_reference {
    publisher = var.source_image.publisher
    offer     = var.source_image.offer
    sku       = var.source_image.sku
    version   = var.source_image.version
  }
  
  tags = merge(var.tags, {
    "OS" = var.source_image.offer
  })
  
  # DONNÉES DE BOOT (script d'initialisation)
  custom_data = base64encode(templatefile("${path.module}/cloud_init.tftpl", {
    hostname = var.vm_name
  }))
}

# ==========================================
# BLOCKER POUR DISQUE MANAGÉ (optionnel)
# ==========================================

resource "azurerm_managed_disk" "data_disk" {
  count = var.data_disk_size_gb != null ? 1 : 0
  
  name                 = "${var.vm_name}-datadisk"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = "Standard_LRS"
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  
  tags = var.tags
}

resource "azurerm_virtual_machine_data_disk_attachment" "attach" {
  count = var.data_disk_size_gb != null ? 1 : 0
  
  managed_disk_id    = azurerm_managed_disk.data_disk[0].id
  virtual_machine_id = azurerm_linux_virtual_machine.vm.id
  lun                = 0
  caching            = "ReadWrite"
}
```

**FICHIER: modules/azure_virtual_machine/cloud_init.tftpl** (template cloud-init)

```bash
#!/bin/bash
# cloud-init script template
# Variables disponibles: ${hostname}

# Configure hostname
hostnamectl set-hostname ${hostname}

# Install Docker (exemple)
apt-get update
apt-get install -y docker.io docker-compose

# Enable Docker
systemctl enable docker
systemctl start docker

echo "VM ${hostname} initialized at $(date)" > /var/log/cloud-init-output.log
```

**FICHIER: modules/azure_virtual_machine/outputs.tf**

```hcl
# ==========================================
# SORTIES DU MODULE
# ==========================================

output "vm_id" {
  description = "ID de la VM"
  value       = azurerm_linux_virtual_machine.vm.id
}

output "vm_private_ip" {
  description = "IP privée de la VM"
  value       = azurerm_network_interface.nic.private_ip_address
}

output "vm_public_ip" {
  description = "IP publique (si créée)"
  value       = try(azurerm_public_ip.pip[0].ip_address, null)
}

output "vm_username" {
  description = "Nom d'utilisateur admin"
  value       = var.admin_username
  # Non-sensitive pour faciliter la connexion SSH
}

output "connection_info" {
  description = "Information de connexion SSH"
  value       = var.create_public_ip ? "ssh ${var.admin_username}@${azurerm_public_ip.pip[0].ip_address}" : "No public IP: utilisez Azure Bastion"
}
```

### 8.3 Utilisation du module dans un projet

**environments/dev/main.tf**

```hcl
# ==========================================
# APPEL DU MODULE AVEC CONFIGURATION
# ==========================================

module "app_vm" {
  source = "../../modules/azure_virtual_machine"
  # source CHEMIN LOCAL
  # Pour module public: "Azure/aks/azurerm"
  # Version: version = "8.0.0"
  
  # PARAMÈTRES OBLIGATOIRES
  vm_name             = "app-vm-dev"
  location            = var.location
  resource_group_name = azurerm_resource_group.rg.name
  subnet_id           = azurerm_subnet.app.id
  admin_password      = var.vm_admin_password  # Récupéré de dev.tfvars ou Key Vault
  
  # PARAMÈTRES OPTIONNELS (override des defaults)
  vm_size    = "Standard_B1s"
  admin_username = "devuser"
  
  create_public_ip = true
  # data_disk_size_gb = 100  # DÉCOMMENTER pour ajouter un disque
  
  source_image = {
    publisher = "Canonical"
    offer     = "UbuntuServer"
    sku       = "20.04-LTS"  # Override: utilise Ubuntu 20.04 au lieu de 22.04
    version   = "latest"
  }
  
  # TAGS HÉRITÉS
  tags = merge(local.common_tags, {
    "Purpose" = "Development"
    "CostCenter" = "DevTeam"
  })
}

# ==========================================
# UTILISATION DES OUTPUTS DU MODULE
# ==========================================

output "app_vm_ip" {
  value = module.app_vm.vm_public_ip
}

output "ssh_command" {
  value = module.app_vm.connection_info
}
```

---

## 9. Sécurité et gestion des secrets

### 9.1 Azure Key Vault – Intégration complète

```hcl
# ==========================================
# RÉCUPÉRATION DE SECRETS DEPUIS KEY VAULT
# ==========================================

# 1. Data source pour récupérer des secrets
data "azurerm_key_vault" "shared" {
  name                = "kv-shared-prod"
  resource_group_name = "rg-security-prod"
}

data "azurerm_key_vault_secret" "sql_admin_password" {
  name         = "sql-admin-password"
  key_vault_id = data.azurerm_key_vault.shared.id
}

data "azurerm_key_vault_secret" "api_keys" {
  name         = "api-keys"
  key_vault_id = data.azurerm_key_vault.shared.id
}

# 2. Utilisation dans une ressource (pas de secret en clair !)
resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${var.environment}"
  location                     = var.location
  resource_group_name          = azurerm_resource_group.rg.name
  version                      = "12.0"
  administrator_login          = "sqladmin"
  
  # Valeur récupérée de Key Vault
  administrator_login_password = data.azurerm_key_vault_secret.sql_admin_password.value
  # Terraform ne montre JAMAIS cette valeur dans les logs
}

# 3. Créer des secrets dans Key Vault (BEST PRACTICE)
resource "random_password" "app_secret" {
  length  = 24
  special = true
  # Génère un mot de passe aléatoire sécurisé
}

resource "azurerm_key_vault_secret" "app_secret" {
  name         = "${var.environment}-app-secret"
  value        = random_password.app_secret.result
  key_vault_id = data.azurerm_key_vault.shared.id
  
  tags = local.common_tags
}

# 4. Politique d'accès pour Terraform lui-même
resource "azurerm_key_vault_access_policy" "terraform" {
  key_vault_id = data.azurerm_key_vault.shared.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = data.azurerm_client_config.current.object_id
  # L'object_id est l'identité qui exécute Terraform (votre SP ou Managed Identity)
  
  secret_permissions = [
    "Get",      # Lire des secrets
    "List",     # Lister les secrets
    "Set",      # Créer/modifier des secrets
    "Delete",   # Supprimer
    "Purge"     # Nettoyage définitif
  ]
}
```

### 9.2 Protection du fichier d'état

```hcl
# ==========================================
# .gitignore – Ne jamais versionner les states
# ==========================================

cat > .gitignore <<'EOF'
# Terraform state files
*.tfstate
*.tfstate.*
terraform.tfstate.backup

# Sensitive variable files
terraform.tfvars
*.tfvars
*.tfvars.json

# Local overrides
override.tf
override.tf.json
*_override.tf
*_override.tf.json

# CLI configuration files
.terraformrc
terraform.rc

# Crash log files
crash.log
crash.*.log

# Local .terraform directories
.terraform/
EOF

# ==========================================
# Variable sensitive – Masquage automatique
# ==========================================

variable "client_secret" {
  type      = string
  sensitive = true  # Ne jamais apparaître dans les logs
  # Terraform output: <sensitive>
}

# ==========================================
# Vérification des secrets en clair
# ==========================================

# Outil tflint avec détection de secrets
cat > .tflint.hcl <<EOF
plugin "azurerm" {
  enabled = true
  version = "0.20.0"
  source  = "github.com/terraform-linters/tflint-ruleset-azurerm"
}

rule "terraform_unused_declarations" {
  enabled = true
}

rule "terraform_comment_syntax" {
  enabled = true
}

rule "terraform_typed_variables" {
  enabled = true
}
EOF
```

---

## 10. Terraform Test – Valider votre infrastructure

### 10.1 Introduction à `terraform test`

```hcl
# Terraform v1.6+ intègre nativement le test unitaire
# Les tests permettent de valider que votre code fonctionne AVANT déploiement

# ==========================================
# STRUCTURE DES TESTS
# ==========================================

📁 terraform-project/
├── main.tf
├── variables.tf
├── outputs.tf
└── 📁 tests/
    ├── 📁 network/
    │   └── main.tftest.hcl
    └── 📁 security/
        └── main.tftest.hcl

# ==========================================
# EXÉCUTION DES TESTS
# ==========================================

# Exécuter tous les tests
terraform test

# Exécuter un sous-ensemble
terraform test -test-directory=tests/network

# Verbose pour debug
terraform test -verbose

# Générer un rapport JUnit (pour CI/CD)
terraform test -junit-xml=test-results.xml
```

### 10.2 Exemple complet de test

**FICHIER: tests/basic/main.tftest.hcl**

```hcl
# ==========================================
# CONFIGURATION DU TEST
# ==========================================

# 1. Variables mockées (simulent les variables réelles)
variables {
  environment = "test"
  location    = "France Central"
  project_name = "testproject"
}

# 2. Providers mockés (optionnel)
# mock_provider "azurerm" { ... }

# ==========================================
# RUN BLOC 1: Validation du groupe de ressources
# ==========================================

run "resource_group_creation" {
  # command = plan (par défaut) ou apply
  
  # Vérification 1: Le RG doit exister
  assert {
    condition     = azurerm_resource_group.rg.name == "rg-testproject-test"
    error_message = "Le nom du RG ne correspond pas à la convention"
  }
  
  # Vérification 2: La location doit être correcte
  assert {
    condition     = azurerm_resource_group.rg.location == "France Central"
    error_message = "La location n'est pas France Central"
  }
  
  # Vérification 3: Les tags doivent être présents
  assert {
    condition     = azurerm_resource_group.rg.tags["ManagedBy"] == "Terraform"
    error_message = "Le tag ManagedBy est manquant ou incorrect"
  }
  
  # Vérification 4: Les outputs doivent fonctionner
  assert {
    condition     = output.resource_group_name == azurerm_resource_group.rg.name
    error_message = "L'output resource_group_name ne correspond pas"
  }
}

# ==========================================
# RUN BLOC 2: Validation du stockage
# ==========================================

run "storage_account_validation" {
  # Dépend des ressources créées dans le run précédent
  # (exécuté après resource_group_creation)
  
  # Créer une ressource de test (n'existe pas dans le vrai code)
  command = apply  # Simule le déploiement
  
  # Mock d'une variable pour le test
  variables {
    storage_tier = "Standard"
  }
  
  assert {
    condition     = azurerm_storage_account.sa.account_tier == "Standard"
    error_message = "Le Storage Account n'est pas Standard"
  }
  
  assert {
    condition     = azurerm_storage_account.sa.https_traffic_only_enabled == true
    error_message = "HTTPS obligatoire non activé"
  }
  
  # Vérifier que le nom est uniq et respecte les règles
  assert {
    condition     = can(regex("^st[a-z0-9]{3,24}$", azurerm_storage_account.sa.name))
    error_message = "Le nom du Storage Account ne respecte pas les règles Azure"
  }
}

# ==========================================
# RUN BLOC 3: Tests conditionnels
# ==========================================

run "conditional_resources" {
  # Tester comportement selon configuration
  
  # Simulation: environment = prod
  variables {
    environment = "prod"
  }
  
  # En prod, doit avoir le bon SKU
  assert {
    condition     = local.sku == "Standard_GRS"
    error_message = "La production doit utiliser Standard_GRS"
  }
}

# ==========================================
# RUN BLOC 4: Validation des outputs
# ==========================================

run "output_validation" {
  # Vérifie tous les outputs avec des conditions
  
  # Outputs doivent être définis
  assert {
    condition     = can(output.resource_group_name)
    error_message = "L'output resource_group_name doit exister"
  }
  
  # Output non-sensitive doit avoir une valeur
  assert {
    condition     = output.resource_group_name != ""
    error_message = "L'output resource_group_name est vide"
  }
  
  # Output sensitive ne doit pas être exposé
  run "check_sensitive_output" {
    # Ce block lance une sous-exécution de test
    variables {
      test_sensitive = true
    }
    
    assert {
      condition     = output.admin_password != null
      error_message = "Le password admin doit être défini"
    }
  }
}
```

### 10.3 Tests avancés avec mocks

**FICHIER: tests/advanced/mocking.tftest.hcl**

```hcl
# ==========================================
# MOCK DE PROVIDER POUR ISOLATION
# ==========================================

# Mock du provider Azure pour ne pas appeler l'API
mock_provider "azurerm" {
  # Mock complet du resource group
  mock_resource "azurerm_resource_group" {
    defaults = {
      id       = "/subscriptions/mock/resourceGroups/mock"
      name     = "mock-rg"
      location = "France Central"
    }
  }
  
  # Mock dynamique du storage account
  mock_data "azurerm_storage_account" {
    defaults = {
      name                = "mockstorage"
      primary_blob_endpoint = "https://mock.blob.core.windows.net/"
    }
  }
}

# Test avec mocks
run "with_mocks" {
  # Utilise les mocks, pas d'appel réel à Azure
  # Exécution ultra-rapide !
  
  command = apply
  
  assert {
    condition     = azurerm_resource_group.rg.location == "France Central"
    error_message = "Mock n'a pas fonctionné"
  }
  
  assert {
    condition     = azurerm_storage_account.sa.primary_blob_endpoint != null
    error_message = "Storage mock n'est pas défini"
  }
}
```

---

## 11. Déploiement CI/CD avec Azure DevOps

### 11.1 Pipeline complet Azure DevOps

**FICHIER: azure-pipelines.yml**

```yaml
# ==========================================
# DÉCLENCHEURS
# ==========================================

trigger:
  branches:
    include:
    - main
    - develop
  paths:
    include:
    - 'environments/*'  # Seulement si code Terraform modifié

# ==========================================
# VARIABLES
# ==========================================

variables:
  # Configuration globale
  TF_ROOT: 'environments/prod'
  TF_VERSION: '1.11.0'
  
  # Service connection Azure (définie dans Azure DevOps)
  ARM_SERVICE_CONNECTION: 'azure-terraform-prod'
  
  # Groupe de variables (secrets)
  - group: 'terraform-secrets'

# ==========================================
# STAGE 1: VALIDATION (toujours exécuté)
# ==========================================

stages:
  - stage: Validate
    displayName: 'Validation Terraform'
    jobs:
      - job: TerraformChecks
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          # 1. Installer Terraform
          - task: TerraformInstaller@1
            displayName: 'Install Terraform'
            inputs:
              terraformVersion: $(TF_VERSION)
          
          # 2. Vérifier formatage
          - script: |
              cd $(TF_ROOT)
              terraform fmt -check -recursive
            displayName: 'Check formatting'
            continueOnError: false
          
          # 3. Initialisation (sans backend pour validation)
          - script: |
              cd $(TF_ROOT)
              terraform init -backend=false
            displayName: 'Init without backend'
          
          # 4. Validation syntaxique
          - script: |
              cd $(TF_ROOT)
              terraform validate
            displayName: 'Validate syntax'
          
          # 5. Exécuter tests
          - script: |
              cd $(TF_ROOT)
              terraform test -verbose
            displayName: 'Run tests'
          
          # 6. Analyse de sécurité (Checkov)
          - script: |
              pip install checkov
              cd $(TF_ROOT)
              checkov -f main.tf --soft-fail
            displayName: 'Security scanning'

# ==========================================
# STAGE 2: PLAN (sur main branch)
# ==========================================

  - stage: Plan
    displayName: 'Terraform Plan'
    dependsOn: Validate
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - job: PlanJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - checkout: self
            persistCredentials: true
          
          - task: TerraformInstaller@1
            inputs:
              terraformVersion: $(TF_VERSION)
          
          # Login Azure
          - task: AzureCLI@2
            inputs:
              azureSubscription: $(ARM_SERVICE_CONNECTION)
              scriptType: 'bash'
              scriptLocation: 'inlineScript'
              inlineScript: |
                # Récupérer l'access key depuis Key Vault
                az keyvault secret show --name tfstate-key --vault-name kv-terraform --query value -o tsv
              # Stocker la clé dans une variable d'environnement
          
          - script: |
              cd $(TF_ROOT)
              terraform init -backend-config="../../config/backend-prod.conf"
              terraform plan -var-file="prod.tfvars" -out=tfplan
              terraform show -json tfplan > tfplan.json
            displayName: 'Terraform Plan'
          
          # Publier l'artefact plan
          - publish: $(TF_ROOT)/tfplan.json
            artifact: terraform-plan
            displayName: 'Publish plan artifact'

# ==========================================
# STAGE 3: APPLY (avec approval manuelle)
# ==========================================

  - stage: Apply
    displayName: 'Terraform Apply'
    dependsOn: Plan
    condition: and(succeeded(), eq(variables['Build.SourceBranch'], 'refs/heads/main'))
    jobs:
      - deployment: ApplyJob
        environment: 'AzureProduction'
        strategy:
          runOnce:
            deploy:
              steps:
                - task: TerraformInstaller@1
                  inputs:
                    terraformVersion: $(TF_VERSION)
                
                # Récupérer le plan depuis l'artefact
                - download: current
                  artifact: terraform-plan
                
                - script: |
                    cd $(TF_ROOT)
                    terraform init -backend-config="../../config/backend-prod.conf"
                    terraform apply tfplan.json
                  displayName: 'Apply infrastructure'
                
                # Sauvegarder l'état dans Azure Storage (automatique)
                - script: |
                    cd $(TF_ROOT)
                    echo "Deployment complete at $(date)" >> deployment.log
                  displayName: 'Post-deploy tasks'

# ==========================================
# STAGE 4: DESTROY (environnements temporaires)
# ==========================================

  - stage: Destroy
    displayName: 'Destroy Infrastructure'
    condition: and(failed(), eq(variables['Build.SourceBranch'], 'refs/heads/feature/*'))
    # Détruit automatiquement si le déploiement échoue (pour feature branches)
    jobs:
      - job: DestroyJob
        pool:
          vmImage: 'ubuntu-latest'
        steps:
          - script: |
              cd $(TF_ROOT)
              terraform init -backend-config="../../config/dev-backend.conf"
              terraform destroy -auto-approve -var-file="dev.tfvars"
            displayName: 'Destroy all resources'
```

### 11.2 GitHub Actions workflow

**FICHIER: .github/workflows/terraform.yml**

```yaml
name: 'Terraform CI/CD on Azure'

on:
  push:
    branches: [ main, develop ]
  pull_request:
    branches: [ main ]

# Permissions pour OIDC
permissions:
  id-token: write
  contents: read
  pull-requests: write

# Variables d'environnement
env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_USE_OIDC: true
  TF_VERSION: '1.11.0'
  TF_ROOT: 'environments/prod'

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    
    steps:
    # Checkout code
    - name: Checkout
      uses: actions/checkout@v4
    
    # Setup Terraform
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v3
      with:
        terraform_version: ${{ env.TF_VERSION }}
    
    # Login to Azure (OIDC)
    - name: Login to Azure
      uses: azure/login@v1
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
    
    # Terraform Init
    - name: Terraform Init
      run: |
        cd ${{ env.TF_ROOT }}
        terraform init -backend-config="backend.conf"
    
    # Terraform Format Check
    - name: Terraform Format
      run: |
        cd ${{ env.TF_ROOT }}
        terraform fmt -check -recursive
    
    # Terraform Validate
    - name: Terraform Validate
      run: |
        cd ${{ env.TF_ROOT }}
        terraform validate
    
    # Terraform Test
    - name: Terraform Test
      run: |
        cd ${{ env.TF_ROOT }}
        terraform test -verbose
    
    # Terraform Plan (and PR comment)
    - name: Terraform Plan
      id: plan
      run: |
        cd ${{ env.TF_ROOT }}
        terraform plan -var-file="prod.tfvars" -out=tfplan
        terraform show -no-color tfplan > plan.txt
        echo "plan_output=$(cat plan.txt)" >> $GITHUB_ENV
    
    - name: Comment PR
      uses: actions/github-script@v6
      if: github.event_name == 'pull_request'
      with:
        script: |
          const output = `#### Terraform Plan
          \`\`\`
          ${{ env.plan_output }}
          \`\`\`
          `;
          github.rest.issues.createComment({
            issue_number: context.issue.number,
            owner: context.repo.owner,
            repo: context.repo.repo,
            body: output
          })
    
    # Terraform Apply (only on main)
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: |
        cd ${{ env.TF_ROOT }}
        terraform apply -auto-approve tfplan
```

---

## 12. Exemples pratiques complets

### 12.1 Application web 3-tiers complète

**FICHIER: main.tf** (Version production)

```hcl
# ==========================================
# PROJET: Infrastructure 3-tiers pour WebApp
# ==========================================

terraform {
  required_version = "~> 1.11"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.6"
    }
  }
  
  backend "azurerm" {
    # Configuration via backend.conf
  }
}

provider "azurerm" {
  features {
    resource_group {
      prevent_deletion_if_contains_resources = true
    }
    key_vault {
      purge_soft_delete_on_destroy    = true
      recover_soft_deleted_key_vaults = true
    }
  }
}

# ==========================================
# LOCALS (calculs et constantes)
# ==========================================

locals {
  # Nommage standardisé
  name_prefix = "${var.project_name}-${var.environment}"
  
  # Tags systématiques
  default_tags = {
    Environment   = var.environment
    ManagedBy     = "Terraform"
    Project       = var.project_name
    DeployedBy    = var.deployed_by
    CostCenter    = "FinOps-${upper(var.environment)}"
    Compliance    = "ISO27001"
  }
  
  # SKU par environnement
  app_service_sku = {
    dev     = "B1"
    staging = "S1"
    prod    = "P1V2"
  }
  
  # Capacité DB par environnement
  db_capacity = {
    dev     = 1
    staging = 2
    prod    = 4
  }
}

# ==========================================
# GROUPE DE RESSOURCES
# ==========================================

resource "random_string" "suffix" {
  length  = 4
  special = false
  upper   = false
  numeric = true
}

resource "azurerm_resource_group" "rg" {
  name     = "rg-${local.name_prefix}"
  location = var.location
  tags     = local.default_tags
}

# ==========================================
# RÉSEAU (VNET + SUBNETS)
# ==========================================

resource "azurerm_virtual_network" "vnet" {
  name                = "vnet-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  address_space       = ["10.0.0.0/16"]
  tags                = local.default_tags
}

resource "azurerm_subnet" "web" {
  name                 = "snet-web"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.1.0/24"]
  
  # Délégation pour App Service
  delegation {
    name = "webapp-delegation"
    service_delegation {
      name    = "Microsoft.Web/serverFarms"
      actions = ["Microsoft.Network/virtualNetworks/subnets/action"]
    }
  }
}

resource "azurerm_subnet" "db" {
  name                 = "snet-db"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  
  # Service endpoint pour Azure SQL
  service_endpoints = ["Microsoft.Sql"]
}

# ==========================================
# BASE DE DONNÉES SQL
# ==========================================

resource "azurerm_mssql_server" "sql" {
  name                         = "sql-${local.name_prefix}${random_string.suffix.result}"
  resource_group_name          = azurerm_resource_group.rg.name
  location                     = azurerm_resource_group.rg.location
  version                      = "12.0"
  administrator_login          = var.sql_admin_username
  administrator_login_password = var.sql_admin_password  # Sensitive
  
  tags = local.default_tags
}

# Règle firewall pour permettre accès depuis les services Azure
resource "azurerm_mssql_firewall_rule" "allow_azure" {
  name             = "AllowAzureServices"
  server_id        = azurerm_mssql_server.sql.id
  start_ip_address = "0.0.0.0"
  end_ip_address   = "0.0.0.0"
}

# Base de données
resource "azurerm_mssql_database" "appdb" {
  name           = "appdb"
  server_id      = azurerm_mssql_server.sql.id
  sku_name       = "GP_Gen5_${local.db_capacity[var.environment]}"
  max_size_gb    = 32
  
  # Configuration avancée
  threat_detection_policy {
    state                = "Enabled"
    retention_days       = 30
    email_addresses      = ["security@company.com"]
    email_account_admins = true
  }
  
  tags = local.default_tags
}

# ==========================================
# APPLICATION WEB (APP SERVICE)
# ==========================================

resource "azurerm_service_plan" "asp" {
  name                = "asp-${local.name_prefix}"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  os_type             = "Linux"
  sku_name            = local.app_service_sku[var.environment]
  
  tags = local.default_tags
}

resource "azurerm_linux_web_app" "webapp" {
  name                = "app-${local.name_prefix}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  service_plan_id     = azurerm_service_plan.asp.id
  https_only          = true
  
  # Configuration du site
  site_config {
    application_stack {
      dotnet_version = "8.0"
    }
    
    # Always on pour production
    always_on = var.environment == "prod" ? true : false
    
    # 32-bit en dev, 64-bit en prod
    use_32_bit_worker = var.environment == "dev" ? true : false
    
    # Min TLS 1.2
    minimum_tls_version = "1.2"
  }
  
  # Application settings (secrets)
  app_settings = {
    "ConnectionStrings:DefaultConnection" = "Server=${azurerm_mssql_server.sql.fully_qualified_domain_name};Database=${azurerm_mssql_database.appdb.name};User Id=${azurerm_mssql_server.sql.administrator_login};Password=${azurerm_mssql_server.sql.administrator_login_password};"
    "ASPNETCORE_ENVIRONMENT" = var.environment
  }
  
  # Identité managée (pour accès aux secrets)
  identity {
    type = "SystemAssigned"
  }
  
  tags = local.default_tags
}

# ==========================================
# KEY VAULT POUR SECRETS D'APP
# ==========================================

resource "azurerm_key_vault" "kv" {
  name                = "kv-${local.name_prefix}${random_string.suffix.result}"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  
  soft_delete_retention_days = 7
  purge_protection_enabled   = false  # Dev only, true pour prod
  
  tags = local.default_tags
}

# Politique d'accès pour App Service
resource "azurerm_key_vault_access_policy" "webapp" {
  key_vault_id = azurerm_key_vault.kv.id
  tenant_id    = data.azurerm_client_config.current.tenant_id
  object_id    = azurerm_linux_web_app.webapp.identity[0].principal_id
  
  secret_permissions = ["Get", "List"]
}

# Secret stocké dans Key Vault
resource "azurerm_key_vault_secret" "api_key" {
  name         = "APIKey"
  value        = random_password.api_key.result
  key_vault_id = azurerm_key_vault.kv.id
  
  tags = local.default_tags
}

resource "random_password" "api_key" {
  length  = 32
  special = true
  min_special = 2
}

# ==========================================
# OUTPUTS (Informations de déploiement)
# ==========================================

output "webapp_url" {
  description = "URL de l'application web"
  value       = "https://${azurerm_linux_web_app.webapp.default_hostname}"
}

output "sql_server_fqdn" {
  description = "Nom complet du serveur SQL"
  value       = azurerm_mssql_server.sql.fully_qualified_domain_name
}

output "key_vault_id" {
  description = "ID du Key Vault"
  value       = azurerm_key_vault.kv.id
}
```

### 12.2 Déploiement étape par étape

```bash
# ==========================================
# 1. INITIALISATION (une seule fois)
# ==========================================

# Installer Azure CLI
az login

# Configurer le storage backend (une seule fois par projet)
./scripts/setup-backend.sh

# Initialiser Terraform avec le backend
terraform init -backend-config="environments/dev/backend.conf"

# ==========================================
# 2. DÉVELOPPEMENT LOCAL
# ==========================================

# Télécharger les dépendances
terraform get -update

# Formater le code
terraform fmt -recursive

# Valider la syntaxe
terraform validate

# Exécuter les tests
terraform test -verbose

# ==========================================
# 3. DÉPLOIEMENT DEV
# ==========================================

# Planifier
terraform plan -var-file="environments/dev/dev.tfvars" -out=dev-plan

# Afficher le plan
terraform show dev-plan

# Appliquer
terraform apply dev-plan

# ==========================================
# 4. DÉPLOIEMENT PRODUCTION
# ==========================================

# Depuis le pipeline CI/CD (ne pas faire en local)
# Mais pour démonstration:
terraform workspace new prod
terraform plan -var-file="environments/prod/prod.tfvars" -out=prod-plan
terraform apply prod-plan

# ==========================================
# 5. VÉRIFICATIONS POST-DÉPLOIEMENT
# ==========================================

# Tester l'application
curl https://app-myproject-prod.azurewebsites.net

# Vérifier les outputs
terraform output webapp_url

# Lister les ressources
terraform state list

# ==========================================
# 6. MAINTENANCE
# ==========================================

# Importer une ressource existante (créée manuellement)
terraform import azurerm_resource_group.existing /subscriptions/xxx/resourceGroups/old-rg

# Supprimer une ressource du state (sans la détruire)
terraform state rm azurerm_storage_account.sa

# Déplacer une ressource entre modules
terraform state mv azurerm_resource_group.rg module.rg.azurerm_resource_group.rg
```

---

## 13. Nettoyage des ressources

### 13.1 Destruction contrôlée

```bash
# ==========================================
# NETTOYAGE PAR ENVIRONNEMENT
# ==========================================

# Dev : destruction complète
cd environments/dev
terraform destroy -auto-approve -var-file="dev.tfvars"

# Staging : destruction partielle (garder le RG)
terraform destroy -target=azurerm_linux_web_app.webapp -auto-approve

# Production : aucune destruction automatique
# Nettoyage manuel via Azure Portal (avec validation)

# ==========================================
# NETTOYAGE FORCÉ (MÊME AVEC PREVENT_DESTROY)
# ==========================================

# Option 1: Supprimer le flag prevent_destroy temporairement
# Modifier main.tf: prevent_destroy = false

# Option 2: Supprimer la ressource du state puis supprimer manuellement
terraform state rm azurerm_resource_group.rg
az group delete --name rg-production --yes --no-wait

# Option 3: Script de force-destruction
#!/bin/bash
# cleanup_all.sh
for rg in $(az group list --query "[?contains(name, 'terraform')].name" -o tsv); do
  echo "Deleting RG: $rg"
  az group delete --name "$rg" --yes --no-wait &
done
wait
echo "All RG deleted"
```

### 13.2 Nettoyage du state

```bash
# ==========================================
# NETTOYAGE DES STATES DANS AZURE STORAGE
# ==========================================

# Lire l'état actuel
terraform show

# Nettoyer les états orphelins
az storage blob list \
  --account-name stterraformstateabc \
  --container-name tfstate \
  --query "[?starts_with(name, 'old-')].name" -o tsv | \
  xargs -I {} az storage blob delete --account-name stterraformstateabc --container-name tfstate --name {}

# Sauvegarder l'état avant nettoyage
az storage blob download \
  --account-name stterraformstateabc \
  --container-name tfstate \
  --name prod.terraform.tfstate \
  --file backup-$(date +%Y%m%d).tfstate
```

---

## 14. Dépannage et erreurs courantes

### 14.1 Tableau des erreurs fréquentes

| Erreur | Cause probable | Solution | Commandes de diagnostic |
|--------|---------------|----------|------------------------|
| `Error: Failed to get existing workspaces` | Backend Azure Storage inaccessible | Vérifier les permissions du SP | `az storage account show-connection-string` |
| `Error: Acquiring state lock` | Un autre utilisateur a le lock | Attendre ou forcer (déconseillé) | `terraform force-unlock LOCK_ID` |
| `Error: 409 Conflict (Storage Account name taken)` | Nom globalement non unique | Ajouter suffixe aléatoire | `random_string` dans le nom |
| `Error: AuthorizationFailed` | Pas les droits RBAC | Ajouter rôle Contributor | `az role assignment list --assignee SP_ID` |
| `Error: creating Virtual Network: InvalidAddressPrefix` | CIDR invalide ou chevauchement | Vérifier la plage d'adresses | `cidrsubnet` pour calculer |
| `Error: 400 Bad Request: "Invalid location"` | Région non supportée | Utiliser région supportée | `az account list-locations` |
| `Error: Provider produced inconsistent final plan` | State drift (modification manuelle) | Rafraîchir l'état | `terraform refresh` puis `terraform plan` |

### 14.2 Procédure de debug complète

```bash
# ==========================================
# DIAGNOSTIC PAS À PAS
# ==========================================

# 1. Vérifier la version et configuration
terraform version
terraform providers

# 2. Activer les logs détaillés
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform-debug.log
terraform apply

# 3. Vérifier les permissions Azure
az account show
az role assignment list --assignee "votre-email@company.com" --output table

# 4. Vérifier le backend et l'état
terraform state list
terraform state show <resource_name>

# 5. Comparer avec la réalité Azure
az resource list --resource-group "rg-name" --output table

# 6. Forcer la rafraîchissement
terraform refresh

# 7. Replanifier avec graph de dépendances
terraform graph | dot -Tpng > graph.png

# 8. Debug d'une ressource spécifique
terraform plan -target=azurerm_resource_group.rg

# 9. Simulation en mode "what-if" (via plan)
terraform plan -detailed-exitcode
# Exit 0 = no changes, 1 = error, 2 = changes

# 10. Restaurer depuis backup
az storage blob download \
  --account-name stterraformstateabc \
  --container-name tfstate \
  --name backup.tfstate \
  --file terraform.tfstate
```

---

## Conclusion et Prochaines Étapes

### Résumé des compétences acquises

✅ **Fondamentaux** : HCL, providers, ressources  
✅ **Gestion d'état** : Backend Azure Storage, locking, remote state  
✅ **Modularité** : Création et utilisation de modules  
✅ **Sécurité** : Key Vault, variables sensibles, RBAC  
✅ **Tests** : Terraform test, mocks, validation  
✅ **CI/CD** : Pipelines Azure DevOps et GitHub Actions  
✅ **Bonnes pratiques** : Nommage, tagging, versioning  

### Prochaines certifications

1. **HashiCorp Certified: Terraform Associate** (002)
   - Durée : 60 min, 57 questions
   - Prix : $70.50 USD
   - [https://www.hashicorp.com/certification/terraform-associate](https://www.hashicorp.com/certification/terraform-associate)

2. **Microsoft Certified: Azure Solutions Architect Expert**
   - Nécessite deux examens (AZ-305 et AZ-104)

### Ressources complémentaires

```bash
# Documentation officielle
https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs
https://developer.hashicorp.com/terraform/tutorials/azure-get-started

# Communauté
https://github.com/terraform-azure-modules

# Exemples complets (notre repository)
git clone https://github.com/company/terraform-azure-examples.git
cd terraform-azure-examples
make setup
make test
make deploy-dev
```

### Scripts utiles (Makefile)

```makefile
# Makefile pour automatiser le workflow
.PHONY: init plan apply destroy test clean

init:
	terraform init -backend-config=environments/$(ENV)/backend.conf

plan:
	terraform plan -var-file=environments/$(ENV)/$(ENV).tfvars -out=tfplan-$(ENV)

apply:
	terraform apply tfplan-$(ENV)

destroy:
	terraform destroy -auto-approve -var-file=environments/$(ENV)/$(ENV).tfvars

test:
	terraform test -verbose

fmt:
	terraform fmt -recursive

validate:
	terraform validate

clean:
	rm -rf .terraform terraform.tfstate* tfplan-*
```
