# <claude>
# File: schema_doc_analyzer.py
# Date: 2025-02-05
#
# USER INFO
# - Analyzes SQLite schema structure
# - Generates Excel documentation
# - Database is recreated on each Dart analysis
#
# CONTEXT
# - Documents database structure
# - Describes tables and relationships
# - Provides AST analysis insights
#
# KEY FEATURES
# - Table descriptions
# - Schema relationships
# - Index information
# - AST analysis documentation
# </claude>

import sqlite3
import pandas as pd
import os
import logging
from typing import Dict, List, Optional
from .config import config

class SchemaDocAnalyzer:
    """Analyseur de la structure de la base de données SQLite."""

    def __init__(self):
        """Initialise l'analyseur avec la configuration de pml.yaml."""
        self.db_path = config.db_path
        self.output_dir = config.output_doc_dir
        self._setup_logging()

        # Création du répertoire de sortie
        os.makedirs(self.output_dir, exist_ok=True)
        self.logger.info(f"Output directory: {self.output_dir}")
        self.logger.info(f"Database path: {self.db_path}")

    def _setup_logging(self) -> None:
        """Configure le système de logging."""
        self.logger = logging.getLogger('SchemaDocAnalyzer')

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

    def _connect_db(self) -> sqlite3.Connection:
        """Établit une connexion à la base de données.

        Returns:
            sqlite3.Connection: Connexion à la base

        Raises:
            sqlite3.Error: Si la connexion échoue
        """
        try:
            return sqlite3.connect(self.db_path)
        except sqlite3.Error as e:
            self.logger.error(f"Database connection error: {str(e)}")
            raise

    def get_tables_info(self) -> pd.DataFrame:
        """Récupère les informations sur toutes les tables.

        Returns:
            pd.DataFrame: Informations sur les tables
        """
        self.logger.info("Getting tables information...")
        query = """
        SELECT 
            name as table_name,
            sql as create_statement
        FROM 
            sqlite_master
        WHERE 
            type='table'
            AND name NOT LIKE 'sqlite_%'
        """

        try:
            with self._connect_db() as conn:
                df = pd.read_sql_query(query, conn)

            descriptions = {
                'source_files': 'Stores Dart source file information',
                'file_imports': 'Records import statements used in files',
                'file_import_relations': 'Maps files to their imports',
                'classes': 'Defines classes, interfaces, and mixins',
                'class_methods': 'Contains methods and their metrics',
                'class_documentations': 'Auto-generated class documentation',
                'class_usage_references': 'Track class usage and references',
                'method_usage_references': 'Track method calls and usage'
            }
            df['description'] = df['table_name'].map(descriptions)

            self.logger.debug(f"Found {len(df)} tables")
            return df

        except Exception as e:
            self.logger.error(f"Error getting tables info: {str(e)}")
            raise

    def get_relations_info(self) -> pd.DataFrame:
        """Récupère les informations sur les relations entre tables.

        Returns:
            pd.DataFrame: Informations sur les relations
        """
        self.logger.info("Getting relations information...")
        try:
            relations = [
                {
                    'source_table': 'file_imports',
                    'target_table': 'source_files',
                    'source_column': 'file_id',
                    'target_column': 'file_id',
                    'type': '1:N',
                    'description': 'File imports relationship'
                },
                {
                    'source_table': 'file_imports',
                    'target_table': 'file_imports',
                    'source_column': 'import_id',
                    'target_column': 'import_path',
                    'type': 'UNIQUE',
                    'description': 'Unique import identifier'
                },
                {
                    'source_table': 'classes',
                    'target_table': 'source_files',
                    'source_column': 'file_id',
                    'target_column': 'file_id',
                    'type': '1:N',
                    'description': 'Classes defined in file'
                },
                {
                    'source_table': 'class_methods',
                    'target_table': 'classes',
                    'source_column': 'class_id',
                    'target_column': 'class_id',
                    'type': '1:N',
                    'description': 'Methods belonging to class'
                },
                {
                    'source_table': 'class_usage_references',
                    'target_table': 'classes',
                    'source_column': 'referenced_class_id',
                    'target_column': 'class_id',
                    'type': 'N:1',
                    'description': 'Class usage tracking'
                },
                {
                    'source_table': 'method_usage_references',
                    'target_table': 'class_methods',
                    'source_column': 'referenced_method_id',
                    'target_column': 'method_id',
                    'type': 'N:1',
                    'description': 'Method usage tracking'
                }
            ]
            return pd.DataFrame(relations)

        except Exception as e:
            self.logger.error(f"Error getting relations info: {str(e)}")
            raise

    def get_ast_insights(self) -> pd.DataFrame:
        """Récupère les insights sur l'analyse AST.

        Returns:
            pd.DataFrame: Informations sur l'analyse AST
        """
        self.logger.info("Getting AST insights...")
        try:
            ast_info = [
                {
                    'concept': 'AST Analysis',
                    'description': 'Parses Dart source into Abstract Syntax Tree',
                    'usage': 'Classes and methods extraction'
                },
                {
                    'concept': 'AST Visitors',
                    'description': 'Tree traversal for information extraction',
                    'usage': 'Definition and usage analysis'
                },
                {
                    'concept': 'Code Metrics',
                    'description': 'Complexity and maintainability metrics',
                    'usage': 'Code quality assessment'
                },
                {
                    'concept': 'Usage Analysis',
                    'description': 'Tracks class and method usage',
                    'usage': 'Dead code detection'
                }
            ]
            return pd.DataFrame(ast_info)
        except Exception as e:
            self.logger.error(f"Error getting AST insights: {str(e)}")
            raise

    def get_file_contents(self) -> pd.DataFrame:
        """Récupère un résumé du contenu des fichiers.

        Returns:
            pd.DataFrame: Résumé du contenu des fichiers
        """
        self.logger.info("Getting file contents...")
        query = """
        SELECT
            sf.file_path as "File",
            c.class_name as "Class",
            c.type as "Type",
            GROUP_CONCAT(m.method_name) as "Methods"
        FROM source_files sf
        LEFT JOIN classes c ON sf.file_id = c.file_id
        LEFT JOIN class_methods m ON c.class_id = m.class_id
        GROUP BY sf.file_path, c.class_name, c.type
        ORDER BY sf.file_path, c.class_name
        """
        try:
            with self._connect_db() as conn:
                df = pd.read_sql_query(query, conn)
            self.logger.debug(f"Found {len(df)} file entries")
            return df
        except Exception as e:
            self.logger.error(f"Error getting file contents: {str(e)}")
            raise

    def export_documentation(self) -> None:
        """Exporte la documentation au format Excel."""
        self.logger.info("Starting documentation export...")
        try:
            dfs = {
                'Schema_Tables': self.get_tables_info(),
                'Schema_Relations': self.get_relations_info(),
                'AST_Analysis': self.get_ast_insights(),
                'Code_Structure': self.get_file_contents()
            }

            filepath = os.path.join(self.output_dir, config.documentation_file)
            self.logger.info(f"Exporting to: {filepath}")

            with pd.ExcelWriter(filepath, engine='openpyxl') as writer:
                for sheet_name, df in dfs.items():
                    self.logger.debug(f"Writing sheet: {sheet_name}")
                    df.to_excel(writer, sheet_name=sheet_name, index=False)

                    # Format des colonnes
                    worksheet = writer.sheets[sheet_name]
                    for idx, col in enumerate(df):
                        max_length = max(
                            df[col].astype(str).apply(len).max(),
                            len(str(col))
                        )
                        worksheet.column_dimensions[chr(65 + idx)].width = min(max_length + 2, 50)

            self.logger.info("Documentation export completed successfully")

        except Exception as e:
            self.logger.error("Error exporting documentation", exc_info=True)
            raise

    def run(self) -> None:
        """Point d'entrée principal de l'analyseur."""
        self.logger.info("Starting schema documentation generation...")
        try:
            self.export_documentation()
            self.logger.info("Schema documentation completed successfully")
        except Exception as e:
            self.logger.error("Schema documentation generation failed")
            raise

def main() -> None:
    """Point d'entrée pour l'exécution en tant que module."""
    try:
        analyzer = SchemaDocAnalyzer()
        analyzer.run()
    except Exception as e:
        logging.error("Schema documentation analysis failed", exc_info=True)
        raise

if __name__ == '__main__':
    main()