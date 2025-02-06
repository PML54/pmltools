# <claude>
# File: dart_analyzer.py
# Date: 2025-02-04
#
# USER INFO
# - Post-processes SQLite database content
# - Generates Excel reports for analysis
# - Uses pml.yaml configuration
# - Enhanced logging support
#
# CONTEXT
# - Analyzes method complexity
# - Generates class hierarchy
# - Produces documentation
# - Runs audit checks
#
# KEY FEATURES
# - Method complexity analysis
# - Class hierarchy generation
# - Structured logging
# - Configurable outputs
#
# CLAUDE MODIFICATION HISTORY
# v1.6 - 2025-02-04 - Enhanced configuration and logging
#   * Added structured logging
#   * Improved error handling
#   * Added comprehensive docstrings
# v1.5 - 2025-01-30 13:00 - Integrated audit analyzer
# </claude>

import sqlite3
import pandas as pd
import os
import logging
from typing import List, Dict, Any, Optional
from .schema_doc_analyzer import SchemaDocAnalyzer
from .audit_analyzer import AuditAnalyzer
from .config import config

class DartCodeAnalyzer:
    """Analyseur principal de code Dart avec génération de rapports."""

    def __init__(self):
        """Initialise l'analyseur avec la configuration de pml.yaml."""
        self.db_path = config.db_path
        self.output_dir = config.output_reports_dir
        self._setup_logging()

        # Création du répertoire de sortie
        os.makedirs(self.output_dir, exist_ok=True)
        self.logger.info(f"Output directory: {self.output_dir}")
        self.logger.info(f"Database path: {self.db_path}")

        # Test de la connexion à la base de données
        self._test_db_connection()

    def _setup_logging(self) -> None:
        """Configure le système de logging."""
        self.logger = logging.getLogger('DartCodeAnalyzer')
        self.logger.setLevel(logging.INFO)

        console_handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)

    def _test_db_connection(self) -> None:
        """Teste la connexion à la base de données.

        Raises:
            Exception: Si la connexion échoue
        """
        try:
            with self.connect() as conn:
                conn.execute("SELECT 1 FROM source_files LIMIT 1")
                self.logger.debug("Database connection test successful")
        except sqlite3.Error as e:
            self.logger.error(f"Database connection error: {str(e)}")
            raise Exception(f"Database connection error: {str(e)}")

    def connect(self) -> sqlite3.Connection:
        """Établit une connexion à la base de données.

        Returns:
            sqlite3.Connection: Connexion à la base de données

        Raises:
            sqlite3.Error: Si la connexion échoue
        """
        return sqlite3.connect(self.db_path)

    def analyze_methods(self) -> pd.DataFrame:
        """Analyse la complexité et les caractéristiques des méthodes.

        Returns:
            pd.DataFrame: DataFrame contenant l'analyse des méthodes

        Raises:
            Exception: Si l'analyse échoue
        """
        self.logger.info("Analyzing methods...")
        query = """
        SELECT 
            sf.file_path as file_name,
            c.class_name,
            m.method_name,
            m.return_type,
            m.param_count,
            m.cyclomatic_complexity,
            m.cognitive_complexity,
            m.is_async,
            m.is_static
        FROM 
            class_methods m
            INNER JOIN classes c ON m.class_id = c.class_id
            INNER JOIN source_files sf ON c.file_id = sf.file_id
        WHERE 
            m.method_name NOT IN ('build', 'initState', 'dispose', 'createState')
            AND m.has_annotation = 0
        ORDER BY 
            m.cyclomatic_complexity DESC,
            m.cognitive_complexity DESC,
            sf.file_path,
            c.class_name,
            m.method_name
        """
        try:
            with self.connect() as conn:
                df = pd.read_sql_query(query, conn)
            self.logger.info(f"Analyzed {len(df)} methods")
            self.logger.debug(f"Found {len(df[df['cyclomatic_complexity'] > 10])} complex methods")
            return df
        except Exception as e:
            self.logger.error(f"Error analyzing methods: {str(e)}")
            raise

    def analyze_class_hierarchy(self) -> pd.DataFrame:
        """Analyse la hiérarchie des classes et leurs méthodes.

        Returns:
            pd.DataFrame: DataFrame contenant la hiérarchie des classes

        Raises:
            Exception: Si l'analyse échoue
        """
        self.logger.info("Analyzing class hierarchy...")
        query = """
        SELECT 
            sf.file_path as file_name,
            c.class_name,
            c.type as class_type,
            c.widget_type,
            c.framework_type,
            m.method_name,
            m.return_type,
            CASE WHEN m.is_async = 1 THEN 'async' ELSE '' END as is_async,
            CASE WHEN m.is_static = 1 THEN 'static' ELSE '' END as is_static,
            m.param_count,
            m.cyclomatic_complexity,
            m.cognitive_complexity
        FROM 
            source_files sf
            INNER JOIN classes c ON sf.file_id = c.file_id
            INNER JOIN class_methods m ON c.class_id = m.class_id
        ORDER BY 
            sf.file_path,
            c.class_name,
            m.method_name
        """
        try:
            with self.connect() as conn:
                df = pd.read_sql_query(query, conn)

            stats = {
                'total_classes': len(df['class_name'].unique()),
                'widget_classes': len(df[df['widget_type'].notna()]),
                'framework_classes': len(df[df['framework_type'].notna()])
            }
            self.logger.info(
                f"Class statistics - Total: {stats['total_classes']}, "
                f"Widgets: {stats['widget_classes']}, "
                f"Framework: {stats['framework_classes']}"
            )

            return df
        except Exception as e:
            self.logger.error(f"Error analyzing class hierarchy: {str(e)}")
            raise

    def get_file_contents(self) -> pd.DataFrame:
        """Récupère un résumé du contenu de chaque fichier.

        Returns:
            pd.DataFrame: DataFrame contenant le résumé des fichiers

        Raises:
            Exception: Si la récupération échoue
        """
        self.logger.info("Getting file contents...")
        query = """
        SELECT
            sf.file_path as file_name,
            GROUP_CONCAT(DISTINCT 
                c.class_name || ' (' || c.type || ') -> ' || 
                GROUP_CONCAT(m.method_name)
            ) as content
        FROM source_files sf
        LEFT JOIN classes c ON sf.file_id = c.file_id
        LEFT JOIN class_methods m ON c.class_id = m.class_id
        GROUP BY sf.file_path
        ORDER BY sf.file_path
        """
        try:
            with self.connect() as conn:
                df = pd.read_sql_query(query, conn)
            self.logger.info(f"Got contents for {len(df)} files")
            return df
        except Exception as e:
            self.logger.error(f"Error getting file contents: {str(e)}")
            raise

    def export_to_excel(self, dataframes: Dict[str, pd.DataFrame]) -> None:
        """Exporte les données dans un fichier Excel.

        Args:
            dataframes: Dictionnaire de DataFrames à exporter

        Raises:
            Exception: Si l'export échoue
        """
        self.logger.info("Exporting to Excel...")
        filepath = os.path.join(self.output_dir, config.dart_analysis_file)
        self.logger.info(f"Writing to: {filepath}")

        try:
            # Prétraitement des données
            processed_dfs = {}
            for name, df in dataframes.items():
                df = df.fillna('')
                for col in df.select_dtypes(include=['bool']).columns:
                    df[col] = df[col].map({True: 'Yes', False: 'No'})
                processed_dfs[name] = df

            # Export vers Excel
            with pd.ExcelWriter(filepath, engine='openpyxl') as writer:
                for sheet_name, df in processed_dfs.items():
                    self.logger.debug(f"Writing sheet: {sheet_name}")
                    safe_sheet_name = sheet_name[:31]  # Limite Excel
                    df.to_excel(writer, sheet_name=safe_sheet_name, index=False)

                    # Formatage des colonnes
                    self._format_excel_sheet(writer.sheets[safe_sheet_name], df)

            self.logger.info("Excel export completed successfully")
        except Exception as e:
            self.logger.error(f"Error exporting to Excel: {str(e)}")
            raise

    def _format_excel_sheet(self, worksheet: Any, df: pd.DataFrame) -> None:
        """Formate une feuille Excel pour une meilleure lisibilité.

        Args:
            worksheet: Feuille Excel à formater
            df: DataFrame source des données
        """
        for idx, col in enumerate(df):
            max_length = max(
                df[col].astype(str).apply(len).max(),
                len(str(col))
            )
            worksheet.column_dimensions[chr(65 + idx)].width = min(max_length + 2, 50)

    def run_all_analyses(self) -> None:
        """Exécute toutes les analyses disponibles."""
        self.logger.info("Starting comprehensive analysis")
        try:
            # Analyses principales
            exports = {
                "Methods": self.analyze_methods(),
                "Hierarchy": self.analyze_class_hierarchy()
            }

            # Export Excel
            self.logger.info("Exporting main analysis results...")
            self.export_to_excel(exports)

            # Documentation
            self.logger.info("Starting documentation analysis...")
            doc_analyzer = SchemaDocAnalyzer()
            doc_analyzer.run()

            # Audit
            self.logger.info("Starting audit analysis...")
            audit_analyzer = AuditAnalyzer()
            audit_analyzer.run()

            self.logger.info("All analyses completed successfully")
        except Exception as e:
            self.logger.error("Analysis failed", exc_info=True)
            raise

def main() -> None:
    """Point d'entrée pour l'exécution en tant que module."""
    try:
        analyzer = DartCodeAnalyzer()
        analyzer.run_all_analyses()
    except Exception as e:
        logging.error("Dart code analysis failed", exc_info=True)
        raise

if __name__ == '__main__':
    main()