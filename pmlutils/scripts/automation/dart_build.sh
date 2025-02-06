#!/bin/bash

# Charge la configuration
source ../shell/yaml_parser.sh

echo "Lancement du build_runner..."

# Force la suppression des fichiers générés existants
echo "Suppression des fichiers générés..."
find . -name "*.g.dart" -delete
find . -name "*.freezed.dart" -delete

# Lance le build_runner
echo "Génération des fichiers..."
dart run build_runner build --delete-conflicting-outputs

if [ $? -eq 0 ]; then
    echo "Build terminé avec succès"
    exit 0
else
    echo "Erreur lors du build"
    exit 1
fi