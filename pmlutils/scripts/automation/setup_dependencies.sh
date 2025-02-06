#!/bin/bash

# Couleurs pour les messages
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

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

# Vérification de l'environnement
check_flutter() {
    if ! command -v flutter &> /dev/null; then
        error "Flutter n'est pas installé. Veuillez installer Flutter avant de continuer."
        exit 1
    fi
}

# Vérification du pubspec.yaml
check_pubspec() {
    if [ ! -f "pubspec.yaml" ]; then
        error "Fichier pubspec.yaml non trouvé. Assurez-vous d'être dans un projet Flutter/Dart."
        exit 1
    fi
}

# Fonction pour ajouter une dépendance
add_dependency() {
    local package=$1
    local version=$2

    if ! grep -q "$package:" pubspec.yaml; then
        log "Installation de $package:$version"
        flutter pub add "$package:$version"
    else
        log "✅ $package déjà présent"
    fi
}

# Fonction principale
main() {
    # Vérifications préalables
    check_flutter
    check_pubspec

    # Dépendances essentielles pour les outils
    log "Vérification et installation des dépendances..."

    # Dépendances de base
    add_dependency "sqlite3" "1.5.0"
    add_dependency "analyzer" "5.0.0"

    # Dépendances optionnelles mais recommandées
    add_dependency "path" "1.8.3"
    add_dependency "collection" "1.17.2"

    # Mise à jour finale des dépendances
    log "Synchronisation des dépendances..."
    flutter pub get

    # Vérification
    flutter pub outdated

    echo
    log "🚀 Configuration des dépendances terminée !"
    log "N'oubliez pas de consulter README.md pour plus d'informations."
}

# Exécution du script
main