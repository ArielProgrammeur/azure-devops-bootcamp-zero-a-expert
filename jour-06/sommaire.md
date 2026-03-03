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
