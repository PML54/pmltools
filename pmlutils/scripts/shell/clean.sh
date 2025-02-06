#!/bin/bash

# Configuration des couleurs
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Fonction de log
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Nettoyage des fichiers générés dans l'application
clean_app_files() {
    local app_root="$1"

    # Vérification du répertoire
    if [ ! -d "$app_root" ]; then
        error "Répertoire de l'application non trouvé : $app_root"
        return 1
    fi

    # Se déplacer dans le répertoire de l'application
    cd "$app_root" || return 1

    # Confirmation avant nettoyage
    read -p "Voulez-vous vraiment nettoyer tous les fichiers générés dans $app_root ? (o/N) " confirmation
    if [[ ! "$confirmation" =~ ^[oO]$ ]]; then
        log "Nettoyage annulé."
        return 0
    fi

    # Nettoyage des fichiers générés
    log "🧹 Début du nettoyage..."

    # Suppression des fichiers .g.dart et .freezed.dart
    log "Suppression des fichiers de génération Dart..."
    find . -type f \( -name "*.g.dart" -o -name "*.freezed.dart" \) -delete

    # Nettoyage du répertoire output
    log "Nettoyage complet du répertoire de sortie..."
    if [ -d "pmlutils/output" ]; then
        # Suppression de tous les fichiers et sous-répertoires
        rm -rf pmlutils/output/doc/*
        rm -rf pmlutils/output/reports/*
        rm -rf pmlutils/output/temp/*

        # Recréation des répertoires vides si nécessaire
        mkdir -p pmlutils/output/doc
        mkdir -p pmlutils/output/reports
        mkdir -p pmlutils/output/temp
    fi

    # Nettoyage du répertoire build
    if [ -d "build" ]; then
        log "Suppression du répertoire build..."
        rm -rf build
    fi

    # Nettoyage des fichiers .log
    log "Suppression des fichiers logs..."
    find . -type f -name "*.log" -delete

    # Nettoyage de la base de données locale si elle existe
    if [ -d "pmlutils/database" ]; then
        log "Nettoyage de la base de données..."
        rm -f pmlutils/database/*.db
        rm -rf pmlutils/database/backups/*
    fi

    # Nettoyage des fichiers temporaires
    log "Suppression des fichiers temporaires..."
    find . -type f \( -name "*.tmp" -o -name "*.temp" \) -delete

# Nettoyage des caches Python
find . -type d -name "__pycache__" -exec rm -rf {} +
find . -type f -name "*.pyc" -delete
    # Nettoyage des caches
    log "Nettoyage des caches..."
    flutter clean
    dart pub get

    # Régénération des fichiers
    log "Régénération des fichiers générés..."
    dart run build_runner build --delete-conflicting-outputs

    # Vérification de la configuration
    log "Vérification de la configuration Flutter..."
    flutter doctor

    # Mise à jour des dépendances
    log "Mise à jour des dépendances..."
    flutter pub upgrade

    log "🎉 Nettoyage et restauration terminés !"

    # Proposition de relancer l'application
    read -p "Voulez-vous lancer l'application ? (o/N) " launch_app
    if [[ "$launch_app" =~ ^[oO]$ ]]; then
        flutter run
    fi
}

# Utilisation du script
if [ $# -eq 0 ]; then
    # Utilisation du répertoire courant si aucun argument n'est passé
    clean_app_files "."
else
    # Utilisation du répertoire spécifié
    clean_app_files "$1"
fi