#!/bin/bash

# Fonction pour lire les valeurs du pml.yaml
parse_yaml() {
   local prefix=$2
   local s='[[:space:]]*' w='[a-zA-Z0-9_]*' fs=$(echo @|tr @ '\034')
   sed -ne "s|^\($s\):|\1|" \
        -e "s|^\($s\)\($w\)$s:$s[\"']\(.*\)[\"']$s\$|\1$fs\2$fs\3|p" \
        -e "s|^\($s\)\($w\)$s:$s\(.*\)$s\$|\1$fs\2$fs\3|p"  $1 |
   awk -F$fs '{
      indent = length($1)/2;
      vname[indent] = $2;
      for (i in vname) {if (i > indent) {delete vname[i]}}
      if (length($3) > 0) {
         vn=""; for (i=0; i<indent; i++) {vn=(vn)(vname[i])("_")}
         printf("%s%s%s=\"%s\"\n", "'$prefix'",vn, $2, $3);
      }
   }'
}

# Fonction pour le log
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1"
}

# Gestion des erreurs
handle_error() {
    log "ERREUR: $1"
    exit 1
}

# Vérifier si pml.yaml existe
if [ ! -f "pml.yaml" ]; then
    handle_error "pml.yaml non trouvé"
fi

# Charger la configuration
eval $(parse_yaml pml.yaml)

# Vérifier le répertoire courant
PROJECT_DIR="$PWD"
log "Projet: $PROJECT_DIR"

# Créer les répertoires nécessaires
mkdir -p "$analyzer_database_dir" || handle_error "Impossible de créer $analyzer_database_dir"
mkdir -p "$output_doc_dir" || handle_error "Impossible de créer $output_doc_dir"
mkdir -p "$output_reports_dir" || handle_error "Impossible de créer $output_reports_dir"
mkdir -p "$output_temp_dir" || handle_error "Impossible de créer $output_temp_dir"
mkdir -p "$tools_utils_python_source_dir/analyzer" || handle_error "Impossible de créer le répertoire Python"

# Vérifier les outils requis
command -v dart >/dev/null 2>&1 || handle_error "dart n'est pas installé"
command -v flutter >/dev/null 2>&1 || handle_error "flutter n'est pas installé"
command -v python3 >/dev/null 2>&1 || handle_error "python3 n'est pas installé"
command -v pip3 >/dev/null 2>&1 || handle_error "pip3 n'est pas installé"

# 1. Build et analyse Flutter/Dart
#log "Exécution du build_runner..."
# dart run build_runner build --delete-conflicting-outputs || handle_error "Erreur lors du build_runner"

log "Analyse Flutter..."
flutter analyze || log "Des problèmes ont été détectés lors de l'analyse Flutter"

# 2. Exécution de l'analyseur Dart
log "Exécution de l'analyseur Dart..."
ANALYZE_SCRIPT="lib/pmlcore/analyzer/analyze_project.dart"
if [ -f "$ANALYZE_SCRIPT" ]; then
    dart run "$ANALYZE_SCRIPT" || handle_error "Erreur lors de l'exécution de l'analyseur Dart"
else
    handle_error "Script d'analyse Dart non trouvé: $ANALYZE_SCRIPT"
fi

# 3. Configuration Python
log "Configuration de l'environnement Python..."
PYTHON_DIR="$PROJECT_DIR/$tools_utils_python_source_dir"

# Installer ou mettre à jour les dépendances Python
if [ -f "$PYTHON_DIR/requirements.txt" ]; then
    log "Installation des dépendances Python..."
    pip3 install -r "$PYTHON_DIR/requirements.txt" || handle_error "Erreur lors de l'installation des dépendances Python"
else
    log "requirements.txt non trouvé dans $PYTHON_DIR"
fi

# Configuration du PYTHONPATH
export PYTHONPATH="$PROJECT_DIR/pmlutils/python:$PYTHONPATH"

# 4. Exécution des analyseurs Python
cd "$PROJECT_DIR" || handle_error "Impossible de retourner au répertoire du projet"

log "Exécution de l'analyse de documentation..."
python3 -m analyzer.schema_doc_analyzer || handle_error "Erreur lors de l'analyse de documentation"

log "Exécution de l'audit..."
python3 -m analyzer.audit_analyzer || handle_error "Erreur lors de l'audit"

log "Exécution de l'analyse Dart..."
python3 -m analyzer.dart_analyzer || handle_error "Erreur lors de l'analyse Dart"
log "Exécution de  Extraction Claude..."
python3 -m analyzer.doc_analyzer || handle_error "Erreur lors de l'analyse Dart"

# 5. Rapport final
log "Analyse terminée"
log "Documentation générée dans: $output_doc_dir"
log "Rapports générés dans: $output_reports_dir"

# Si nous sommes arrivés ici, tout s'est bien passé
exit 0
