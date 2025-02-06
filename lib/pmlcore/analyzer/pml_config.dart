import 'dart:io';
import 'package:yaml/yaml.dart';

class PMLConfig {
  // App config
  final String appName;
  final String libDir;

  // Analyzer config
  final String sourceRoot;
  final List<String> excludedDirs;
  final List<String> excludedFiles;

  // Database config
  final String dbDirectory;
  final String dbName;
  final bool cleanupOnStart;
  final String dbSchemaFile;
  final String dbBackupDir;

  // Logging config
  final String logLevel;
  final String logFile;
  final bool logToConsole;

  // Output config
  final String outputDocDir;
  final String outputReportsDir;
  final String outputTempDir;

  PMLConfig._({
    required this.appName,
    required this.libDir,
    required this.sourceRoot,
    required this.excludedDirs,
    required this.excludedFiles,
    required this.dbDirectory,
    required this.dbName,
    required this.cleanupOnStart,
    required this.dbSchemaFile,
    required this.dbBackupDir,
    required this.logLevel,
    required this.logFile,
    required this.logToConsole,
    required this.outputDocDir,
    required this.outputReportsDir,
    required this.outputTempDir,
  });

  static PMLConfig load() {
    final file = File('pml.yaml');
    if (!file.existsSync()) {
      throw FileSystemException('pml.yaml not found');
    }

    final yamlString = file.readAsStringSync();
    final yamlDoc = loadYaml(yamlString);

    return PMLConfig._(
      // App config
      appName: yamlDoc['app']['name'],
      libDir: yamlDoc['app']['lib_dir'],

      // Analyzer config
      sourceRoot: yamlDoc['analyzer']['source_root'],
      excludedDirs: List<String>.from(yamlDoc['analyzer']['excluded']['dirs']),
      excludedFiles: List<String>.from(yamlDoc['analyzer']['excluded']['files']),

      // Database config
      dbDirectory: yamlDoc['analyzer']['database']['dir'],
      dbName: yamlDoc['analyzer']['database']['name'],
      cleanupOnStart: yamlDoc['analyzer']['database']['cleanup_on_start'],
      dbSchemaFile: yamlDoc['analyzer']['database']['schema_file'],
      dbBackupDir: yamlDoc['analyzer']['database']['backup_dir'],

      // Logging config
      logLevel: yamlDoc['logging']['level'],
      logFile: yamlDoc['logging']['file'],
      logToConsole: yamlDoc['logging']['console'] ?? true,

      // Output config
      outputDocDir: yamlDoc['output']['doc_dir'],
      outputReportsDir: yamlDoc['output']['reports_dir'],
      outputTempDir: yamlDoc['output']['temp_dir'],
    );
  }

  // Méthodes utilitaires
  bool shouldAnalyzeFile(String path) {
    if (!path.endsWith('.dart')) return false;
    for (final ext in excludedFiles) {
      if (path.endsWith(ext)) return false;
    }
    for (final dir in excludedDirs) {
      if (path.contains(dir)) return false;
    }
    return true;
  }

  String get dbPath => '$dbDirectory/$dbName';

  bool isAppImport(String importName) {
    if (!importName.startsWith('package:') && !importName.startsWith('dart:')) {
      return true;
    }
    if (importName.startsWith('package:$appName/')) {
      return true;
    }
    return false;
  }

  String normalizePath(String filepath) {
    if (filepath.startsWith('$sourceRoot/')) {
      return filepath.substring(sourceRoot.length + 1);
    }
    return filepath;
  }

  // Helpers pour les répertoires
  void ensureDirectoriesExist() {
    final directories = [
      dbDirectory,
      dbBackupDir,
      outputDocDir,
      outputReportsDir,
      outputTempDir,
      Directory(logFile).parent.path,
    ];

    for (final dir in directories) {
      final directory = Directory(dir);
      if (!directory.existsSync()) {
        directory.createSync(recursive: true);
      }
    }
  }
}