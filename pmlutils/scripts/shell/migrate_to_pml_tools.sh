#!/bin/bash

# Configuration des couleurs pour les messages
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Chemins par défaut (peut être écrasé par les arguments)
SOURCE_DIR="/Users/pml/StudioProjects/minssalor"
DEST_DIR="/Users/pml/StudioProjects/pml_tools"

# Fonction pour les messages de log
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Gestion des paramètres
if [ "$#" -eq 2 ]; then
    SOURCE_DIR="$1"
    DEST_DIR="$2"
elif [ "$#" -ne 0 ]; then
    error "Usage: $0 [source_project_dir destination_dir]"
    echo "Si aucun paramètre n'est fourni, chemins par défaut utilisés :"
    echo "Source : $SOURCE_DIR"
    echo "Destination : $DEST_DIR"
    exit 1
fi

# Vérifie les répertoires source
if [ ! -d "$SOURCE_DIR" ]; then
    error "Répertoire source non trouvé: $SOURCE_DIR"
    exit 1
fi

log "Migration des outils PML..."

# Création de la structure de base
mkdir -p "$DEST_DIR"/{lib/pmlcore/analyzer,pmlutils/python/analyzer,pmlutils/scripts/{automation,shell}}
mkdir -p "$DEST_DIR"/pmlutils/{output/{doc,reports,temp},logs,database/{backups}}

# Fonctions de copie avec logging
copy_if_exists() {
    local src="$1"
    local dest="$2"
    local description="$3"

    if [ -d "$src" ]; then
        cp -r "$src/"* "$dest/"
        log "$description copiés"
    else
        warn "Répertoire non trouvé : $src"
    fi
}

# Copie des différents composants
copy_if_exists "$SOURCE_DIR/lib/pmlcore/analyzer" "$DEST_DIR/lib/pmlcore/analyzer" "Fichiers Dart"
copy_if_exists "$SOURCE_DIR/pmlutils/python/analyzer" "$DEST_DIR/pmlutils/python/analyzer" "Fichiers Python"
copy_if_exists "$SOURCE_DIR/pmlutils/scripts/automation" "$DEST_DIR/pmlutils/scripts/automation" "Scripts d'automatisation"
copy_if_exists "$SOURCE_DIR/pmlutils/scripts/shell" "$DEST_DIR/pmlutils/scripts/shell" "Scripts shell"

# Duplication de install_pml_tools.sh depuis pmlutils/scripts/shell vers la racine
if [ -f "$DEST_DIR/pmlutils/scripts/shell/install_pml_tools.sh" ]; then
    cp "$DEST_DIR/pmlutils/scripts/shell/install_pml_tools.sh" "$DEST_DIR/install_pml_tools.sh"
    chmod +x "$DEST_DIR/install_pml_tools.sh"
    log "Script d'installation dupliqué à la racine"
else
    warn "Script d'installation non trouvé dans pmlutils/scripts/shell"
fi

# Copie du fichier de configuration
log "Copie de pml.yaml..."
cp "$SOURCE_DIR/pml.yaml" "$DEST_DIR/pml.yaml" 2>/dev/null || {
    warn "pml.yaml non trouvé, création d'un fichier par défaut"
    cat > "$DEST_DIR/pml.yaml" << 'EOL'
# Configuration générée lors de la migration
app:
  name: "project_migrated"
  lib_dir: "lib"
EOL
}