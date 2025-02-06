#!/bin/bash

# Charge la configuration
source ../shell/yaml_parser.sh

echo "Mise à jour de la documentation..."

# Vérifie que l'analyse Dart a été faite
if [ ! -f "$analyzer_database_dir/$analyzer_database_name" ]; then
    echo "Erreur: Base de données non trouvée. Lancez d'abord l'analyse Dart."
    exit 1
fi

# Vérifie si le module Python est disponible
cd "$tools_utils_python_source_dir" || exit 1

# Exécute l'analyseur de documentation
echo "Génération de la documentation..."
python3 -m analyzer.schema_doc_analyzer

if [ $? -eq 0 ]; then
    echo "Documentation mise à jour avec succès"
    exit 0
else
    echo "Erreur lors de la mise à jour de la documentation"
    exit 1
fi