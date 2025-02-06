# <claude>
# File: doc_analyzer.py
# Date: 2025-02-05
#
# USER INFO
# - Extracts Claude documentation from Dart files
# - Generates Markdown documentation
# - Uses pml.yaml configuration
# - Enhanced logging support
#
# CONTEXT
# - Analyzes Dart files for documentation
# - Excludes specified directories
# - Generates structured documentation
#
# KEY FEATURES
# - Claude documentation extraction
# - Structured by directories
# - Markdown output generation
# - Configurable exclusions
# </claude>

import os
import re
from datetime import datetime
import logging
from typing import Dict, List, Optional
from .config import config

class DocAnalyzer:
    """Analyseur de documentation pour les fichiers Dart."""

    def __init__(self):
        """Initialise l'analyseur avec la configuration de pml.yaml."""
        self.lib_path = config.lib_dir
        self.output_dir = config.output_doc_dir
        self.docs = []
        self._setup_logging()

        # Assure que le répertoire de sortie existe
        os.makedirs(self.output_dir, exist_ok=True)
        self.logger.info(f"Output directory: {self.output_dir}")
        self.logger.info(f"Library path: {self.lib_path}")

    def _setup_logging(self) -> None:
        """Configure le système de logging."""
        self.logger = logging.getLogger('DocAnalyzer')

        # Configuration du niveau de log depuis pml.yaml
        self.logger.setLevel(getattr(logging, config.log_level.upper()))

        # Configuration du formateur
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )

        # Handler console
        if config.log_to_console:
            console_handler = logging.StreamHandler()
            console_handler.setFormatter(formatter)
            self.logger.addHandler(console_handler)

        # Handler fichier
        if config.log_file:
            log_dir = os.path.dirname(config.log_file)
            os.makedirs(log_dir, exist_ok=True)
            file_handler = logging.FileHandler(config.log_file)
            file_handler.setFormatter(formatter)
            self.logger.addHandler(file_handler)

    def extract_claude_doc(self, content: str) -> Optional[str]:
        """Extrait la documentation entre les balises <claude> et </claude>.

        Args:
            content: Contenu du fichier à analyser

        Returns:
            Documentation extraite ou None si non trouvée
        """
        pattern = r'///\s*<claude>(.*?)///\s*</claude>'
        match = re.search(pattern, content, re.DOTALL)
        if match:
            return match.group(1).strip()
        return None

    def process_file(self, file_path: str) -> None:
        """Traite un fichier et extrait sa documentation.

        Args:
            file_path: Chemin du fichier à traiter
        """
        try:
            with open(file_path, 'r', encoding='utf-8') as f:
                content = f.read()
                doc = self.extract_claude_doc(content)
                if doc:
                    relative_path = os.path.relpath(file_path, self.lib_path)
                    self.docs.append({
                        'path': relative_path,
                        'doc': doc
                    })
                    self.logger.debug(f"Documentation extraite de {relative_path}")
                else:
                    self.logger.debug(f"Pas de documentation trouvée dans {file_path}")
        except Exception as e:
            self.logger.error(f"Erreur lors du traitement de {file_path}: {str(e)}")

    def scan_directory(self) -> None:
        """Parcourt le répertoire lib récursivement."""
        self.logger.info(f"Scanning directory: {self.lib_path}")
        self.logger.info(f"Excluded directories: {config.excluded_dirs}")
        self.logger.info(f"Excluded files: {config.excluded_files}")

        try:
            for root, dirs, files in os.walk(self.lib_path):
                # Filtrer les répertoires exclus
                dirs[:] = [d for d in dirs if not any(
                    os.path.join(root, d).startswith(exc_dir)
                    for exc_dir in config.excluded_dirs
                )]

                for file in files:
                    if (file.endswith('.dart') and
                            not any(file.endswith(ext) for ext in config.excluded_files)):
                        full_path = os.path.join(root, file)
                        self.process_file(full_path)

            self.logger.info(f"Found documentation in {len(self.docs)} files")

        except Exception as e:
            self.logger.error(f"Error scanning directory: {str(e)}")
            raise

    def generate_summary(self) -> str:
        """Génère le document de synthèse.

        Returns:
            Contenu du document généré
        """
        summary = f"""# {config.app_name} Documentation Summary
Generated on: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}

## Project Overview
This document provides a comprehensive overview of the application structure and components.
Documentation excludes:
- Directories: {', '.join(config.excluded_dirs)}
- Files: {', '.join(config.excluded_files)}

## Components Documentation\n\n"""

        # Organiser par dossiers
        folders: Dict[str, List[Dict]] = {}
        for doc in self.docs:
            folder = os.path.dirname(doc['path'])
            if folder not in folders:
                folders[folder] = []
            folders[folder].append(doc)

        # Générer la documentation par dossier
        for folder, docs in sorted(folders.items()):
            summary += f"\n### {folder if folder else 'Root'}\n\n"
            for doc in sorted(docs, key=lambda x: x['path']):
                summary += f"#### {os.path.basename(doc['path'])}\n"
                summary += doc['doc'] + "\n\n"

        return summary

    def save_summary(self) -> str:
        """Sauvegarde le résumé dans un fichier.

        Returns:
            Chemin du fichier généré

        Raises:
            Exception: Si l'écriture du fichier échoue
        """
        try:
            summary = self.generate_summary()
            output_path = os.path.join(self.output_dir, config.markdown_documentation_file)

            with open(output_path, 'w', encoding='utf-8') as f:
                f.write(summary)

            self.logger.info(f"Documentation generated: {output_path}")
            self.logger.info(f"Files processed: {len(self.docs)}")
            return output_path

        except Exception as e:
            self.logger.error(f"Error saving documentation: {str(e)}")
            raise

    def run(self) -> None:
        """Point d'entrée principal de l'analyseur."""
        self.logger.info(f"Starting documentation analysis for {config.app_name}...")
        try:
            self.scan_directory()
            self.save_summary()
            self.logger.info("Documentation analysis completed successfully")
        except Exception as e:
            self.logger.error("Documentation analysis failed")
            raise

def main() -> None:
    """Point d'entrée pour l'exécution en tant que module."""
    try:
        analyzer = DocAnalyzer()
        analyzer.run()
    except Exception as e:
        logging.error("Documentation analysis failed", exc_info=True)
        raise

if __name__ == '__main__':
    main()