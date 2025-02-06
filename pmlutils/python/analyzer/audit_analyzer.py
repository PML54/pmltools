# <claude>
# File: audit_analyzer.py
# Date: 2025-02-04
#
# USER INFO
# - Analyzes dead code and usage patterns
# - Generates audit report in Excel format
# - Uses pml.yaml configuration
# - Enhanced logging support
#
# CONTEXT
# - Post-process analysis for code audit
# - Identifies unused code elements
# - Focus on maintainability issues
#
# KEY FEATURES
# - Unused methods detection
# - Unused classes detection
# - Method complexity analysis
# - Usage statistics
# </claude>

import sqlite3
import pandas as pd
import os
from typing import Dict, Optional, List, Tuple
import logging
from openpyxl.worksheet.worksheet import Worksheet
from .config import config

class AuditAnalyzer:
    """Analyseur d'audit du code pour la détection de code mort et l'analyse de complexité."""

    def __init__(self):
        """Initialise l'analyseur avec la configuration de pml.yaml."""
        self.db_path = config.db_path
        self.output_dir = config.output_reports_dir
        self._setup_logging()

        os.makedirs(self.output_dir, exist_ok=True)
        self.logger.info(f"Output directory: {self.output_dir}")
        self.logger.info(f"Database path: {self.db_path}")

    def _setup_logging(self) -> None:
        """Configure le système de logging."""
        self.logger = logging.getLogger('AuditAnalyzer')
        self.logger.setLevel(logging.INFO)

        console_handler = logging.StreamHandler()
        formatter = logging.Formatter(
            '%(asctime)s - %(name)s - %(levelname)s - %(message)s'
        )
        console_handler.setFormatter(formatter)
        self.logger.addHandler(console_handler)

    def _connect_db(self) -> sqlite3.Connection:
        """Établit une connexion à la base de données.

        Returns:
            sqlite3.Connection: Connexion à la base de données

        Raises:
            sqlite3.Error: Si la connexion échoue
        """
        try:
            return sqlite3.connect(self.db_path)
        except sqlite3.Error as e:
            self.logger.error(f"Database connection error: {str(e)}")
            raise

    def analyze_unused_methods(self) -> pd.DataFrame:
        """Analyse les méthodes non utilisées dans le code.

        Returns:
            pd.DataFrame: DataFrame contenant les méthodes non utilisées

        Raises:
            Exception: Si l'analyse échoue
        """
        self.logger.info("Analyzing unused methods...")
        query = """
        SELECT 
            sf.file_path as file_name,
            c.class_name,
            m.method_name,
            m.return_type,
            m.param_count,
            CASE WHEN m.is_async = 1 THEN 'Yes' ELSE 'No' END as is_async,
            CASE WHEN m.is_static = 1 THEN 'Yes' ELSE 'No' END as is_static,
            m.cyclomatic_complexity,
            m.cognitive_complexity
        FROM class_methods m
        JOIN classes c ON m.class_id = c.class_id
        JOIN source_files sf ON c.file_id = sf.file_id
        WHERE NOT EXISTS (
            SELECT 1 
            FROM method_usage_references mur 
            WHERE mur.referenced_method_id = m.method_id
        )
        AND m.method_name NOT IN ('build', 'initState', 'dispose', 'createState')
        AND m.has_annotation = 0
        ORDER BY m.cyclomatic_complexity DESC, sf.file_path, c.class_name, m.method_name
        """
        try:
            with self._connect_db() as conn:
                df = pd.read_sql_query(query, conn)

            # Statistiques sur la complexité
            complex_methods = len(df[df['cyclomatic_complexity'] > 10])
            cognitive_complex = len(df[df['cognitive_complexity'] > 15])

            self.logger.info(f"Found {len(df)} unused methods")
            self.logger.info(f"Complex methods: {complex_methods}, Cognitive complex: {cognitive_complex}")

            return df
        except Exception as e:
            self.logger.error(f"Error analyzing unused methods: {str(e)}")
            raise

    def analyze_unused_classes(self) -> pd.DataFrame:
        """Analyse les classes non utilisées dans le code.

        Returns:
            pd.DataFrame: DataFrame contenant les classes non utilisées

        Raises:
            Exception: Si l'analyse échoue
        """
        self.logger.info("Analyzing unused classes...")
        query = """
        SELECT 
            sf.file_path as file_name,
            c.class_name,
            c.type as class_type,
            c.widget_type,
            c.framework_type,
            (
                SELECT COUNT(*)
                FROM class_methods m
                WHERE m.class_id = c.class_id
            ) as method_count,
            (
                SELECT AVG(cyclomatic_complexity)
                FROM class_methods m
                WHERE m.class_id = c.class_id
            ) as avg_complexity
        FROM classes c
        JOIN source_files sf ON c.file_id = sf.file_id
        WHERE NOT EXISTS (
            SELECT 1 
            FROM class_usage_references cur 
            WHERE cur.referenced_class_id = c.class_id
        )
        ORDER BY sf.file_path, c.class_name
        """
        try:
            with self._connect_db() as conn:
                df = pd.read_sql_query(query, conn)

            # Statistiques par type
            type_stats = df['class_type'].value_counts()
            self.logger.info(f"Found {len(df)} unused classes")
            self.logger.info(f"Type distribution: {dict(type_stats)}")
            return df
        except Exception as e:
            self.logger.error(f"Error analyzing unused classes: {str(e)}")
            raise

    def get_usage_statistics(self) -> pd.DataFrame:
        """Génère des statistiques d'utilisation du code.

        Returns:
            pd.DataFrame: DataFrame contenant les statistiques d'utilisation

        Raises:
            Exception: Si la génération échoue
        """
        self.logger.info("Generating usage statistics...")
        query = """
        SELECT
            'Classes' as category,
            COUNT(*) as total,
            SUM(CASE WHEN EXISTS (
                SELECT 1 FROM class_usage_references cur 
                WHERE cur.referenced_class_id = c.class_id
            ) THEN 1 ELSE 0 END) as used,
            ROUND(AVG(import_count), 1) as avg_imports
        FROM classes c
        UNION ALL
        SELECT
            'Methods' as category,
            COUNT(*) as total,
            SUM(CASE WHEN EXISTS (
                SELECT 1 FROM method_usage_references mur
                WHERE mur.referenced_method_id = m.method_id
            ) THEN 1 ELSE 0 END) as used,
            ROUND(AVG(param_count), 1) as avg_params
        FROM class_methods m
        """
        try:
            with self._connect_db() as conn:
                df = pd.read_sql_query(query, conn)
            df['usage_rate'] = (df['used'] / df['total'] * 100).round(1)
            self.logger.info(f"Usage statistics generated\n{df.to_string()}")
            return df
        except Exception as e:
            self.logger.error(f"Error generating usage statistics: {str(e)}")
            raise

    def export_audit_report(self) -> None:
        """Exporte le rapport d'audit complet au format Excel.

        Raises:
            Exception: Si l'export échoue
        """
        self.logger.info("Exporting audit report...")
        try:
            dfs = {
                'unused_methods': self.analyze_unused_methods(),
                'unused_classes': self.analyze_unused_classes(),
                'usage_statistics': self.get_usage_statistics()
            }

            filepath = os.path.join(self.output_dir, config.audit_report_file)
            self.logger.info(f"Writing report to: {filepath}")

            with pd.ExcelWriter(filepath, engine='openpyxl') as writer:
                for sheet_name, df in dfs.items():
                    self.logger.debug(f"Writing sheet: {sheet_name}")
                    df.to_excel(writer, sheet_name=sheet_name, index=False)
                    self._format_excel_sheet(writer.sheets[sheet_name], df)

            self.logger.info("Audit report exported successfully")
        except Exception as e:
            self.logger.error(f"Error exporting audit report: {str(e)}")
            raise

    def _format_excel_sheet(self, worksheet: Worksheet, df: pd.DataFrame) -> None:
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

    def run(self) -> None:
        """Point d'entrée principal de l'analyseur."""
        self.logger.info("Starting audit analysis...")
        try:
            self.export_audit_report()
            self.logger.info("Audit analysis completed successfully")
        except Exception as e:
            self.logger.error("Audit analysis failed")
            raise

def main() -> None:
    """Point d'entrée pour l'exécution en tant que module."""
    try:
        analyzer = AuditAnalyzer()
        analyzer.run()
    except Exception as e:
        logging.error("Audit analysis failed", exc_info=True)
        raise

if __name__ == '__main__':
    main()