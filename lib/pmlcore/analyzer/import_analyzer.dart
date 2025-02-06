/// <claude>
/// File: import_analyzer.dart
/// Date: 2025-02-04
///
/// USER INFO
/// - Analyzes imports in Dart files
/// - Updates import statistics
/// - Works with recreated database each run
/// - Uses pml.yaml configuration and logging
///
/// KEY POINTS
/// - Source files are scanned for import statements
/// - Tracks app vs package imports
/// - Updates class import counts
/// - Structured logging of analysis process
/// </claude>

import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'pml_config.dart';
import 'pml_logger.dart';

class ImportAnalyzer {
  final Database db;
  final PMLConfig config;
  late final PMLLogger _logger;

  ImportAnalyzer(this.db, this.config) {
    _logger = PMLLogger('ImportAnalyzer', config);
  }

  Future<void> analyze(String content, String filepath, int fileId) async {
    _logger.debug('Analyzing imports for file: $filepath');

    final importPattern = RegExp(r'''import ['"](.+?)['"]''');
    for (var match in importPattern.allMatches(content)) {
      final importPath = match.group(1)!;

      try {
        final isAppFile = config.isAppImport(importPath);
        _logger.info('Found import: $importPath (app_file: $isAppFile)');

        // Insert import
        db.execute('''
          INSERT OR IGNORE INTO file_imports (import_path, is_app_file)
          VALUES (?, ?)
        ''', [importPath, isAppFile ? 1 : 0]);

        // Create file-import relation
        final importResult = db.select(
            'SELECT import_id FROM file_imports WHERE import_path = ?',
            [importPath]
        );
        final importId = importResult.first['import_id'];

        db.execute('''
          INSERT OR IGNORE INTO file_import_relations (file_id, import_id)
          VALUES (?, ?)
        ''', [fileId, importId]);

        _logger.debug('Import relation created for $importPath');

      } catch (e, stack) {
        _logger.error('Error processing import: $importPath', e, stack);
      }
    }
  }

  Future<void> postProcess() async {
    _logger.info('Starting import post-processing...');

    try {
      // Update package imports
      _logger.debug('Updating package imports...');
      db.execute('''
        UPDATE file_imports
        SET is_package = 1
        WHERE import_path LIKE 'package:%' 
        AND NOT import_path LIKE 'package:${config.appName}/%'
        AND is_app_file = 0
      ''');

      // Count imports per class
      _logger.debug('Updating import counts per class...');
      db.execute('''
        UPDATE classes
        SET import_count = (
          SELECT COUNT(DISTINCT i.import_id)
          FROM file_imports i
          JOIN file_import_relations r ON i.import_id = r.import_id
          WHERE r.file_id = classes.file_id
        )
      ''');

      // Statistics
      final stats = db.select('''
        SELECT 
          SUM(CASE WHEN is_app_file = 1 THEN 1 ELSE 0 END) as app_imports,
          SUM(CASE WHEN is_package = 1 THEN 1 ELSE 0 END) as package_imports,
          COUNT(*) as total_imports
        FROM file_imports
      ''').first;

      _logger.info('''Import Statistics:
        Internal imports: ${stats['app_imports']}
        Package imports: ${stats['package_imports']}
        Total imports: ${stats['total_imports']}''');

    } catch (e, stack) {
      _logger.error('Error during import post-processing', e, stack);
    }
  }
}