/// <claude>
/// File: pml_logger.dart
/// Date: 2025-02-04
///
/// USER INFO
/// - Logger pour les outils d'analyse PML
/// - Configuration via pml.yaml
/// - Support de différents niveaux de log
///
/// KEY POINTS
/// - Logs vers fichier et console
/// - Niveaux : debug, info, warning, error
/// - Format structuré des messages
/// </claude>

import 'dart:io';
import 'pml_config.dart';

class PMLLogger {
  final String className;
  final PMLConfig config;
  late final IOSink _logFile;

  PMLLogger(this.className, this.config) {
    final logDir = Directory(config.logFile).parent;
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }
    _logFile = File(config.logFile).openWrite(mode: FileMode.append);
  }

  void _log(String level, String message, [Object? error, StackTrace? stackTrace]) {
    final timestamp = DateTime.now().toIso8601String();
    final logMessage = '[$timestamp] $level [$className] $message';

    // Écriture dans le fichier
    _logFile.writeln(logMessage);
    if (error != null) {
      _logFile.writeln('Error: $error');
      if (stackTrace != null) {
        _logFile.writeln('Stack trace:\n$stackTrace');
      }
    }

    // Affichage console si activé
    if (config.logToConsole) {
      if (level == 'ERROR') {
        stderr.writeln(logMessage);
      } else {
        print(logMessage);
      }
    }
  }

  void debug(String message) {
    if (_shouldLog('debug')) {
      _log('DEBUG', message);
    }
  }

  void info(String message) {
    if (_shouldLog('info')) {
      _log('INFO', message);
    }
  }

  void warning(String message) {
    if (_shouldLog('warning')) {
      _log('WARNING', message);
    }
  }

  void error(String message, [Object? error, StackTrace? stackTrace]) {
    // Les erreurs sont toujours loguées quel que soit le niveau
    _log('ERROR', message, error, stackTrace);
  }

  bool _shouldLog(String level) {
    final levels = ['debug', 'info', 'warning', 'error'];
    final configLevelIndex = levels.indexOf(config.logLevel.toLowerCase());
    final messageLevelIndex = levels.indexOf(level.toLowerCase());
    return messageLevelIndex >= configLevelIndex;
  }

  Future<void> dispose() async {
    await _logFile.close();
  }
}