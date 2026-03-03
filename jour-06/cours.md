# Cours Avancé sur le Réseau Azure

## Sommaire

1. [Introduction : l’analogie de la société d’habitation](#1-introduction--lanalogie-de-la-société-dhabitation)
2. [Rappel des fondamentaux : VNet, CIDR et subnets](#2-rappel-des-fondamentaux--vnet-cidr-et-subnets)
3. [Les composants de sécurité réseau](#3-les-composants-de-sécurité-réseau)
   - 3.1 Network Security Group (NSG)
   - 3.2 Application Security Group (ASG)
   - 3.3 Azure Firewall
   - 3.4 Web Application Firewall (WAF)
   - 3.5 Network Access Control List (NACL) – clarification
4. [Routage et connectivité](#4-routage-et-connectivité)
   - 4.1 Tables de routage (Route Tables) et routes système
   - 4.2 NAT Gateway
   - 4.3 Azure DNS
5. [Équilibrage de charge](#5-équilibrage-de-charge)
   - 5.1 Azure Load Balancer (L4)
   - 5.2 Application Gateway (L7)
6. [Architecture complète d’une application multi‑niveaux](#6-architecture-complète-dune-application-multi-niveaux)
   - 6.1 Conception du VNet et des subnets
   - 6.2 Déploiement sur deux zones de disponibilité
   - 6.3 Pare-feu et WAF en périphérie
   - 6.4 Équilibrage de charge externe et interne
   - 6.5 Règles de sécurité (NSG, ASG)
   - 6.6 Schéma détaillé du flux réseau
7. [Connecter plusieurs VNets : Peering et VPN Gateway](#7-connecter-plusieurs-vnets--peering-et-vpn-gateway)
   - 7.1 VNet Peering
   - 7.2 VPN Gateway (connexion site‑à‑site)
8. [Bonnes pratiques avancées](#8-bonnes-pratiques-avancées)
9. [Conclusion](#9-conclusion)

---

## 1. Introduction : l’analogie de la société d’habitation

Pour bien comprendre le réseau Azure, prenons l’image d’une **société d’habitation** (residential society) :

- **Le terrain entier** représente votre abonnement Azure.
- **Le portail d’entrée** (gate) est le point d’accès depuis l’extérieur.
- **Les différents compounds** (enclos) correspondent aux **Availability Zones** – des zones physiquement séparées.
- **Chaque maison** dans un compound est un **subnet** (par exemple, le subnet des bases de données, le subnet des applications, le subnet web).
- **Les portes individuelles** des maisons sont les **Network Security Groups (NSG)** qui filtrent qui peut entrer dans chaque maison.
- **Le gardien à l’entrée du compound** est le **firewall** (Azure Firewall) qui inspecte tout le trafic avant qu’il n’atteigne les maisons.
- **Le routeur principal** qui dirige les visiteurs vers le bon compound est l’**Application Gateway** (ou Load Balancer).
- **Le système de numérotation des maisons** est le **CIDR** qui définit l’espace d’adressage.

Cette analogie nous suivra tout au long du cours.

---

## 2. Rappel des fondamentaux : VNet, CIDR et subnets

Un **Virtual Network (VNet)** est un réseau privé virtuel dans Azure. On définit sa taille avec une notation **CIDR** (par exemple `10.0.0.0/16`). Ce VNet est découpé en **subnets** pour organiser les ressources :

- **Subnet public** : contient des ressources accessibles depuis Internet (ex : serveurs web).
- **Subnet privé** : contient des ressources internes (bases de données, middle‑tier).

Dans notre analogie, le VNet est le terrain clôturé, et les subnets sont les différentes zones (résidentielle, commerciale, etc.).

---

## 3. Les composants de sécurité réseau

### 3.1 Network Security Group (NSG)

Un **NSG** est un pare‑feu distribué **stateful** qui filtre le trafic à destination et en provenance des ressources Azure. On peut l’associer à un subnet ou à une carte réseau (NIC). Il contient des règles de priorité.

- **Rôle** : comme le digicode à l’entrée de chaque maison.
- **Règles** : on définit qui (source IP, service tag, ASG) peut accéder à quelle destination, sur quel port, avec quel protocole.

### 3.2 Application Security Group (ASG)

Un **ASG** permet de regrouper logiquement des machines virtuelles (ou autres ressources) et de les référencer dans les règles NSG par leur nom, sans utiliser d’adresses IP. C’est très utile quand les IP changent (auto‑scaling).

- **Rôle** : comme une liste blanche nominative (“les livreurs”) plutôt qu’une adresse postale fixe.

### 3.3 Azure Firewall

**Azure Firewall** est un pare‑feu managé, centralisé, avec état (stateful). Il inspecte le trafic à la périphérie du VNet et peut appliquer des politiques de filtrage FQDN (noms de domaine), du TLS inspection, et de la traduction d’adresses (DNAT/SNAT).

- **Rôle** : le gardien à l’entrée du compound, qui vérifie l’identité de chaque visiteur avant de l’autoriser à entrer dans la zone.

### 3.4 Web Application Firewall (WAF)

Le **WAF** est une couche supplémentaire qui protège les applications web contre les attaques courantes (SQL injection, XSS, etc.). Il est intégré à **Application Gateway** (ou Azure Front Door).

- **Rôle** : un détecteur de faux billets à l’entrée du bâtiment principal.

### 3.5 Network Access Control List (NACL) – clarification

Le terme **NACL** est souvent utilisé chez AWS pour un filtrage **stateless** au niveau du subnet. **Azure n’a pas d’équivalent direct** ; le filtrage au niveau subnet est assuré par les NSG (stateful). On peut mentionner que dans Azure, on utilise les NSG pour ce rôle, et qu’ils sont plus simples à gérer car stateful.

---

## 4. Routage et connectivité

### 4.1 Tables de routage (Route Tables) et routes système

Azure crée automatiquement des **routes système** pour permettre la communication interne au VNet, avec Internet, et avec les réseaux connectés (peering, VPN). Vous pouvez ajouter des **routes personnalisées** dans une table de routage et l’associer à un subnet pour forcer le trafic à passer par une appliance virtuelle (ex : firewall).

- **Rôle** : les panneaux indicateurs dans la ville, qui dirigent le trafic vers la bonne sortie.

### 4.2 NAT Gateway

**NAT Gateway** permet aux ressources d’un subnet privé d’accéder à Internet (pour les mises à jour par exemple) tout en masquant leurs adresses IP privées derrière une IP publique statique. C’est une forme de SNAT (Source Network Address Translation).

- **Rôle** : une ligne téléphonique partagée dans un immeuble : plusieurs appartements peuvent appeler à l’extérieur, mais le numéro affiché est celui de l’immeuble.

### 4.3 Azure DNS

**Azure DNS** est un service d’hébergement de domaines. Vous pouvez y gérer vos enregistrements DNS (A, CNAME, etc.) et les associer à vos ressources Azure (load balancer, application gateway, etc.).

- **Rôle** : l’annuaire téléphonique de la ville, qui traduit un nom (ex: www.monsite.com) en adresse (IP).

---

## 5. Équilibrage de charge

### 5.1 Azure Load Balancer (L4)

**Azure Load Balancer** opère au niveau **couche 4** (transport). Il répartit le trafic TCP/UDP entrant entre plusieurs VM (backend pool) selon des règles et des sondes de santé. Il peut être public (entrée depuis Internet) ou interne (trafic entre VM).

- **Rôle** : un répartiteur de colis qui envoie chaque paquet à un employé disponible, sans regarder le contenu.

### 5.2 Application Gateway (L7)

**Application Gateway** est un load balancer de **couche 7** (application). Il peut router le trafic en fonction de l’URL, des en‑têtes HTTP, des cookies, etc. Il intègre nativement le **WAF** et peut faire de la terminaison SSL.

- **Rôle** : un standardiste qui écoute le nom du service demandé (ex: /api ou /images) et transfère l’appel à l’équipe compétente.

---

## 6. Architecture complète d’une application multi‑niveaux

### 6.1 Conception du VNet et des subnets

Prenons un projet typique : une application web avec frontend, backend API et base de données. Nous allons déployer sur **deux Availability Zones** pour la haute disponibilité.

**VNet :** `10.0.0.0/16`

| Subnet | Plage CIDR | Rôle |
|--------|------------|------|
| `snet-web` | `10.0.1.0/24` | Serveurs web (frontend) |
| `snet-app` | `10.0.2.0/24` | Serveurs d’application (API) |
| `snet-data` | `10.0.3.0/24` | Bases de données |
| `snet-gw` | `10.0.254.0/27` | Sous‑réseau pour la passerelle VPN (si besoin) |
| `snet-fw` | `10.0.253.0/27` | Sous‑réseau pour Azure Firewall (AzureFirewallSubnet obligatoire) |

### 6.2 Déploiement sur deux zones de disponibilité

Pour chaque niveau, on déploie des VM dans les deux zones (par exemple VM web en Zone 1 et Zone 2). Les sous‑réseaux s’étendent sur l’ensemble des zones (un subnet peut contenir des ressources de différentes zones).

### 6.3 Pare-feu et WAF en périphérie

- **Azure Firewall** est placé dans son propre subnet (`AzureFirewallSubnet`). Tous les flux entrants depuis Internet passent par lui (via une table de routage qui force le trafic Internet vers le firewall). Il applique des règles de filtrage et DNAT pour exposer certains services.
- **Application Gateway** avec **WAF** est déployée en frontend. Elle reçoit les requêtes HTTP/HTTPS des utilisateurs, les inspecte (WAF) et les route vers les VM web.

### 6.4 Équilibrage de charge externe et interne

- **Externe** : Application Gateway distribue le trafic vers les VM web dans les deux zones.
- **Interne** : Un **Azure Load Balancer interne** (ILB) répartit les appels des VM web vers les VM d’application (API) dans les subnets `snet-app`. Les VM d’application sont dans un backend pool, avec une sonde de santé.
- Pour les bases de données, on peut utiliser un autre ILB ou un cluster avec Always On (mais cela dépasse le cadre réseau).

### 6.5 Règles de sécurité (NSG, ASG)

- **NSG sur `snet-web`** :
  - Autoriser HTTP/HTTPS depuis Internet (ou depuis Application Gateway uniquement).
  - Autoriser SSH/RDP depuis une plage d’administration (ex: IP du bureau).
  - Refuser tout autre trafic entrant.
- **NSG sur `snet-app`** :
  - Autoriser le trafic depuis `snet-web` sur le port de l’API (ex: 8080).
  - Autoriser SSH depuis la plage d’admin.
  - Refuser Internet direct.
- **NSG sur `snet-data`** :
  - Autoriser SQL (1433) depuis `snet-app` (ou via un ASG).
  - Refuser tout autre trafic.
- **ASG** : on peut créer `ASG_Web`, `ASG_App`, `ASG_DB` et référencer ces groupes dans les règles NSG, simplifiant la maintenance.

### 6.6 Schéma détaillé du flux réseau

Voici le parcours d’une requête utilisateur :

```
Utilisateur → Internet → Azure DNS (résolution du nom)
              ↓
          Application Gateway (avec WAF) – L7
              ↓
          Azure Firewall (règles DNAT/filtrage)
              ↓
          Table de routage (force le retour par le firewall si nécessaire)
              ↓
          VM Web (snet-web) – après vérification NSG
              ↓
          (Appel API) → Azure Load Balancer interne (L4)
              ↓
          VM App (snet-app) – après vérification NSG
              ↓
          (Requête SQL) → (via ASG/NSG) → VM DB (snet-data)
              ↓
          Réponse suivie du chemin inverse
```

**Détails supplémentaires :**
- Les VM web peuvent avoir besoin d’accéder à Internet pour des mises à jour. On utilise une **NAT Gateway** attachée au subnet `snet-web` pour leur fournir une IP publique de sortie.
- Toutes les communications entre subnets sont contrôlées par NSG et éventuellement par les règles du Firewall si on a forcé le routage via lui.
- Le trafic entre zones de disponibilité reste dans le VNet et est à faible latence.

---

## 7. Connecter plusieurs VNets : Peering et VPN Gateway

### 7.1 VNet Peering

Le **VNet Peering** permet de connecter deux VNets (dans la même région ou des régions différentes) comme s’ils n’en formaient qu’un. Le trajet est privé, passe par le backbone Microsoft, sans passer par Internet.

**Exemple** : Projet 1 (VNet1) et Projet 2 (VNet2) ont besoin de communiquer. On établit un peering dans les deux sens. Les routes système assurent la connectivité.

- **Cas d’usage** : partage de ressources (bases de données, services) entre équipes, sans exposition publique.

### 7.2 VPN Gateway (connexion site‑à‑site)

**VPN Gateway** permet de connecter votre VNet à un réseau sur‑premise via un tunnel VPN sécurisé (IPsec). On crée une passerelle dans un subnet dédié (`GatewaySubnet`), et on la configure avec une adresse IP publique.

- **Cas d’usage** : architecture hybride, où des serveurs locaux accèdent aux ressources Azure de manière privée.

---

## 8. Bonnes pratiques avancées

- **Toujours segmenter** les fonctions dans des subnets distincts avec des NSG dédiés.
- **Utiliser les ASG** pour éviter de coder en dur des adresses IP dans les règles NSG.
- **Centraliser la sortie Internet** avec NAT Gateway ou Azure Firewall pour un contrôle et une journalisation unifiés.
- **Forcer le trafic Internet via Azure Firewall** en créant une route 0.0.0.0/0 vers l’IP du firewall dans la table de routage des subnets.
- **Déployer les ressources critiques sur au moins deux zones de disponibilité**.
- **Utiliser Application Gateway avec WAF** pour protéger les applications web exposées.
- **Surveiller les logs** (NSG flow logs, Azure Firewall logs) avec Azure Monitor.
- **Planifier l’adressage CIDR** pour éviter les chevauchements lors de peering ou de connexions VPN.

---

## 9. Conclusion

Azure offre un éventail complet de services réseau pour construire des architectures robustes, sécurisées et évolutives. De la simple VM isolée à l’application mondiale répartie sur plusieurs régions, en passant par les connexions hybrides, vous disposez de tous les outils nécessaires. La clé est de bien comprendre le rôle de chaque composant – VNet, subnets, NSG, ASG, Azure Firewall, load balancers, passerelles – et de les assembler selon les principes de défense en profondeur.

> **Ce qu’il faut retenir** :  
> - **VNet** = votre réseau privé.  
> - **Subnets** = zones fonctionnelles.  
> - **NSG/ASG** = sécurité fine.  
> - **Azure Firewall** = gardien central.  
> - **Load Balancer / App Gateway** = répartition de charge (L4/L7).  
> - **Peering / VPN** = connectivité étendue.  

Avec ces concepts, vous êtes prêt à concevoir des infrastructures réseau professionnelles sur Azure.