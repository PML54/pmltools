/// <claude>
/// File: analyze_project.dart
/// Date: 2025-02-04
///
/// USER INFO:
/// - Main script for project analysis
/// - Uses pml.yaml for all configuration
/// - Analyzes Dart project structure
///
/// CLAUDE INFO:
/// - Entry point for project analysis
/// - Manages database lifecycle
/// - Coordinates analysis process
///
/// KEY POINTS:
/// - Centralized configuration in pml.yaml
/// - Clean error handling
/// - Proper resource cleanup
/// </claude>
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';
import 'code_analyzer.dart';
import 'pml_config.dart';

void cleanupDatabase(PMLConfig config) {
  final dbDir = Directory(config.dbDirectory);
  final dbFile = File(config.dbPath);

  if (dbFile.existsSync()) dbFile.deleteSync();
  if (!dbDir.existsSync()) dbDir.createSync(recursive: true);
}

void main() async {
  try {
    // Chargement de la configuration depuis pml.yaml
    final config = PMLConfig.load();

    // Nettoyage de la base si demandé
    if (config.cleanupOnStart) {
      cleanupDatabase(config);
    }

    // Initialisation de la base et lancement de l'analyse
    final db = sqlite3.open(config.dbPath);
    final analyzer = CodeAnalyzer(db, config);

    stderr.writeln('Starting project analysis...');
    stderr.writeln('Configuration loaded from pml.yaml');
    stderr.writeln('Database path: ${config.dbPath}');

    await analyzer.analyzeProject();

    db.dispose();
    stderr.writeln('Analysis completed successfully');
  } catch (e) {
    stderr.writeln('ERROR: $e');
    exit(1);
  }
}