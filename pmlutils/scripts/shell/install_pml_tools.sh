RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

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

# Fonction pour vérifier les dépendances dans pubspec.yaml
check_dependencies() {
    local pubspec_file="$1"
    local missing_deps=()

    if [ ! -f "$pubspec_file" ]; then
        error "pubspec.yaml non trouvé dans le projet cible"
        exit 1
    fi

    # Vérification de sqlite3
    if ! grep -q "sqlite3:" "$pubspec_file"; then
        missing_deps+=("sqlite3")
    fi

    # Vérification de analyzer
    if ! grep -q "analyzer:" "$pubspec_file"; then
        missing_deps+=("analyzer")
    fi

    # Si des dépendances sont manquantes
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Dépendances manquantes dans pubspec.yaml:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        echo
        error "Veuillez ajouter les dépendances manquantes avant l'installation"
        exit 1
    fi

    log "✅ Toutes les dépendances requises sont présentes"
}

# Fonction pour vérifier les dépendances système
check_system_dependencies() {
    local missing_deps=()

    # Vérification de Python
    if ! command -v python3 &> /dev/null; then
        if ! command -v python &> /dev/null; then
            missing_deps+=("python")
        fi
    fi

    # Vérification de SQLite
    if ! command -v sqlite3 &> /dev/null; then
        missing_deps+=("sqlite3")
    fi

    # Si des dépendances sont manquantes
    if [ ${#missing_deps[@]} -ne 0 ]; then
        error "Dépendances système manquantes:"
        for dep in "${missing_deps[@]}"; do
            echo "  - $dep"
        done
        error "Veuillez installer les dépendances manquantes avant de continuer"
        exit 1
    fi

    log "✅ Toutes les dépendances système sont présentes"
}

# Vérifie les paramètres
if [ "$#" -ne 1 ]; then
    error "Usage: $0 <destination_dir>"
    echo "Example: $0 /path/to/target/flutter/project"
    exit 1
fi

SOURCE_DIR="$(pwd)"
DEST_DIR="$1"

# Vérifie les dépendances système
check_system_dependencies

# Vérifie les répertoires source
if [ ! -d "$SOURCE_DIR" ]; then
    error "Répertoire source non trouvé: $SOURCE_DIR"
    exit 1
fi

# Vérifie les dépendances dans le projet cible
check_dependencies "$DEST_DIR/pubspec.yaml"

if [ ! -f "$SOURCE_DIR/pml.yaml" ]; then
    error "pml.yaml non trouvé dans le répertoire source"
    exit 1
fi

log "Création de la structure pml_tools..."

# Création de la structure de répertoires
mkdir -p "$DEST_DIR"/{lib/pmlcore/analyzer,pmlutils/python/analyzer,pmlutils/scripts/{automation,shell}}
mkdir -p "$DEST_DIR"/pmlutils/{output/{doc,reports,temp},logs}

# Copie des fichiers Dart
log "Copie des fichiers Dart..."
if [ -d "$SOURCE_DIR/lib/pmlcore/analyzer" ]; then
    cp -r "$SOURCE_DIR/lib/pmlcore/analyzer/"* "$DEST_DIR/lib/pmlcore/analyzer/"
else
    warn "Répertoire source des analyseurs Dart non trouvé"
fi

# Copie des fichiers Python
log "Copie des fichiers Python..."
if [ -d "$SOURCE_DIR/pmlutils/python/analyzer" ]; then
    cp -r "$SOURCE_DIR/pmlutils/python/analyzer/"* "$DEST_DIR/pmlutils/python/analyzer/"

    # Copie requirements.txt s'il existe
    if [ -f "$SOURCE_DIR/pmlutils/python/requirements.txt" ]; then
        cp "$SOURCE_DIR/pmlutils/python/requirements.txt" "$DEST_DIR/pmlutils/python/"
    fi
else
    warn "Répertoire source des analyseurs Python non trouvé"
fi

# Copie des scripts
log "Copie des scripts..."
if [ -d "$SOURCE_DIR/pmlutils/scripts" ]; then
    # Copie des scripts d'automation
    if [ -d "$SOURCE_DIR/pmlutils/scripts/automation" ]; then
        cp -r "$SOURCE_DIR/pmlutils/scripts/automation/"* "$DEST_DIR/pmlutils/scripts/automation/"
    fi

    # Copie des scripts shell
    if [ -d "$SOURCE_DIR/pmlutils/scripts/shell" ]; then
        cp -r "$SOURCE_DIR/pmlutils/scripts/shell/"* "$DEST_DIR/pmlutils/scripts/shell/"
    fi

    # Copie du script clean.sh
    if [ -f "$SOURCE_DIR/pmlutils/scripts/clean.sh" ]; then
        cp "$SOURCE_DIR/pmlutils/scripts/clean.sh" "$DEST_DIR/pmlutils/scripts/"
    fi
else
    warn "Répertoire source des scripts non trouvé"
fi

# Copie des fichiers de configuration
log "Copie des fichiers de configuration..."
cp "$SOURCE_DIR/pml.yaml" "$DEST_DIR/"
if [ -f "$SOURCE_DIR/run_analysis.sh" ]; then
    cp "$SOURCE_DIR/run_analysis.sh" "$DEST_DIR/"
fi

# Création du README.md
log "Création du README.md..."


# Configuration des permissions
log "Configuration des permissions..."
find "$DEST_DIR" -type f -name "*.sh" -exec chmod +x {} \;

log "Migration terminée!"
log "Structure créée dans: $DEST_DIR"
echo "Installation OK "
 echo  "-->configuration  pml.yaml : "
  echo "---->remplacer  appspml par le nom de votre appli"
  echo "----->à 2 endroits"



echo  "-->Lancer run_analysis.sh pour   analyser  votre projet  "
echo  "---->Dans la fenetre Terminal de votre apps , taper run_analysis.sh"
echo "---->Resultats seront  dans les repertoires database et output"


