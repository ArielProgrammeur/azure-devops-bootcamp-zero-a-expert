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

# Vérification de la structure
if [ ! -d "modules/storage" ]; then
    echo -e "${RED}❌ Dossier modules/storage non trouvé${NC}"
    echo "   Position actuelle: $(pwd)"
    echo "   Contenu du dossier courant:"
    ls -la
    exit 1
fi

# Test du module Storage
echo -e "\n${YELLOW}📦 Test du module Storage...${NC}"

# Sauvegarder la position actuelle
CURRENT_DIR=$(pwd)

cd modules/storage

# Vérifier la présence des fichiers Terraform
if [ ! -f "main.tf" ]; then
    echo -e "${RED}❌ main.tf manquant dans modules/storage${NC}"
    exit 1
fi

# Exécuter le test (d'abord en mode verbose pour voir l'erreur)
echo "   Exécution de terraform test..."

# Option A: Si `terraform test` existe
if terraform test --help > /dev/null 2>&1; then
    if terraform test -json > "../../$TEST_RESULTS_DIR/storage-$TIMESTAMP.json" 2>&1; then
        echo -e "${GREEN}✅ Tests Storage OK${NC}"
        TEST_SUCCESS="true"
    else
        echo -e "${RED}❌ Tests Storage échoués${NC}"
        TEST_SUCCESS="false"
        # Afficher les dernières lignes du fichier JSON pour le débogage
        echo "   Dernières lignes du résultat:"
        tail -5 "../../$TEST_RESULTS_DIR/storage-$TIMESTAMP.json" 2>/dev/null || echo "   Fichier JSON vide ou inexistant"
    fi
else
    # Option B: Fallback sur validate + plan
    echo -e "${YELLOW}⚠️  terraform test non disponible, fallback sur validate/plan${NC}"
    
    echo "   Validation... "
    if terraform validate; then
        echo -e "   ${GREEN}✅ Validation OK${NC}"
    else
        echo -e "   ${RED}❌ Validation échouée${NC}"
        TEST_SUCCESS="false"
    fi
    
    echo "   Plan... "
    if terraform plan -out=tfplan > /dev/null 2>&1; then
        echo -e "   ${GREEN}✅ Plan OK${NC}"
        rm -f tfplan
    else
        echo -e "   ${RED}❌ Plan échoué${NC}"
        TEST_SUCCESS="false"
    fi
    
    # Créer un faux résultat JSON
    cat > "../../$TEST_RESULTS_DIR/storage-$TIMESTAMP.json" << EOF
{
  "status": "${TEST_SUCCESS:-true}",
  "timestamp": "$TIMESTAMP",
  "message": "Test via validate/plan fallback"
}
EOF
fi

cd "$CURRENT_DIR"

# Rapport final
echo -e "\n${YELLOW}📊 Résumé des tests:${NC}"

# Compter les résultats
PASSED=0
FAILED=0

for file in $TEST_RESULTS_DIR/*.json; do
    if [ -f "$file" ]; then
        if grep -q '"status":"pass"' "$file" 2>/dev/null || grep -q '"status": true' "$file" 2>/dev/null; then
            echo -e "${GREEN}✅ $(basename $file)${NC}"
            PASSED=$((PASSED + 1))
        else
            echo -e "${RED}❌ $(basename $file)${NC}"
            FAILED=$((FAILED + 1))
            # Afficher l'erreur si disponible
            if grep -q "error" "$file" 2>/dev/null; then
                echo "   ---"
                grep -A2 "error" "$file" | head -5
            fi
        fi
    fi
done

echo -e "\n${YELLOW}📈 Résultats: $PASSED succès, $FAILED échecs${NC}"

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}🎯 Tous les tests sont passés !${NC}"
else
    echo -e "${RED}🎯 Certains tests ont échoué${NC}"
    exit 1
fi