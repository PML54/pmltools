# <claude>
# File: config.py
# Date: 2025-02-05
#
# USER INFO
# - Centralized configuration for Python analyzers
# - Uses pml.yaml for configuration
# - Used across all analysis modules
#
# CONTEXT
# - Global configuration settings
# - File naming conventions
# - Path management
#
# KEY FEATURES
# - pml.yaml integration
# - App name configuration
# - File path generation
# - Consistent naming patterns
# </claude>

import os
import yaml
from typing import List, Optional

class AnalyzerConfig:
    def __init__(self):
        # Initialisation des attributs par défaut
        self.app_name: str = "minssalor"
        self.lib_dir: str = "lib"
        self.excluded_dirs: List[str] = ["lib/generated"]
        self.excluded_files: List[str] = [".freezed.dart", ".g.dart", "_test.dart"]
        self.db_dir: str = "pmlutils/database"
        self.db_name: str = "analysis.db"
        self.cleanup_on_start: bool = True
        self.output_doc_dir: str = "pmlutils/output/doc"
        self.output_reports_dir: str = "pmlutils/output/reports"
        self.output_temp_dir: str = "pmlutils/output/temp"
        self.log_level: str = "info"
        self.log_file: str = "pmlutils/logs/analysis.log"
        self.log_to_console: bool = True

        # Chargement de la configuration
        self._load_pml_config()

    def _load_pml_config(self) -> None:
        """Charge la configuration depuis pml.yaml."""
        try:
            # Remonte de deux niveaux pour trouver pml.yaml à la racine
            pml_path = os.path.join(os.path.dirname(__file__), "../../..", "pml.yaml")

            with open(pml_path, 'r', encoding='utf-8') as f:
                config = yaml.safe_load(f)

            # Configuration de base de l'application
            self.app_name = config['app']['name']
            self.lib_dir = config['app']['lib_dir']

            # Configuration de l'analyseur
            analyzer_config = config['analyzer']
            self.excluded_dirs = analyzer_config['excluded']['dirs']
            self.excluded_files = analyzer_config['excluded']['files']

            # Configuration de la base de données
            db_config = analyzer_config['database']
            self.db_dir = db_config['dir']
            self.db_name = db_config['name']
            self.cleanup_on_start = db_config['cleanup_on_start']

            # Configuration des sorties
            output_config = config['output']
            self.output_doc_dir = output_config['doc_dir']
            self.output_reports_dir = output_config['reports_dir']
            self.output_temp_dir = output_config['temp_dir']

            # Configuration des logs
            log_config = config['logging']
            self.log_level = log_config['level']
            self.log_file = log_config['file']
            self.log_to_console = log_config.get('console', True)  # True par défaut

        except Exception as e:
            print(f"Erreur lors du chargement de pml.yaml: {e}")
            print("Utilisation de la configuration par défaut")

    @property
    def db_path(self) -> str:
        """Retourne le chemin complet vers la base de données."""
        return os.path.join(self.db_dir, self.db_name)

    @property
    def log_path(self) -> str:
        """Retourne le chemin complet vers le fichier de log."""
        return os.path.join(os.path.dirname(os.path.dirname(self.log_file)))

    @property
    def documentation_file(self) -> str:
        """Nom du fichier de documentation Excel."""
        return f"{self.app_name}_documentation.xlsx"

    @property
    def markdown_documentation_file(self) -> str:
        """Nom du fichier de documentation Markdown."""
        return f"{self.app_name}_documentation.md"

    @property
    def dart_analysis_file(self) -> str:
        """Nom du fichier d'analyse Dart."""
        return f"{self.app_name}_dart_analysis.xlsx"

    @property
    def audit_report_file(self) -> str:
        """Nom du fichier de rapport d'audit."""
        return f"{self.app_name}_audit.xlsx"

    def ensure_directories(self) -> None:
        """Crée tous les répertoires nécessaires."""
        directories = [
            self.db_dir,
            self.output_doc_dir,
            self.output_reports_dir,
            self.output_temp_dir,
            os.path.dirname(self.log_file)
        ]

        for directory in directories:
            os.makedirs(directory, exist_ok=True)

# Instance globale de configuration
config = AnalyzerConfig()

# Export explicite
__all__ = ['config']