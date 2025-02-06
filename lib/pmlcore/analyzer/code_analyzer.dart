/// <claude>
/// File: code_analyzer.dart
/// Date: 2025-02-04
///
/// USER INFO
/// - Database is RECREATED on each analysis
/// - Analysis without diagram generation for now
/// - Flow: files -> classes -> methods -> documentation -> usages
/// - Dead code detection through usage tracking
/// - Configuration now from pml.yaml
///
/// CONTEXT
/// - Main Dart code analyzer
/// - Structure extraction via AST
/// - SQLite storage with renamed tables
/// - Usage tracking for classes and methods
///
/// ANALYSIS LAYERS
/// - File Structure: source files and imports
/// - Code Structure: classes and methods
/// - Documentation: automated documentation generation
/// - Usage Tracking: class and method references
///
/// CLAUDE MODIFICATION HISTORY
/// v1.6 - 2025-02-04 - Migration to pml.yaml
///   * Replaced AnalyzerConfig with PMLConfig
///   * Updated configuration handling
///   * Removed old config dependencies
/// v1.5 - 2025-01-29 15:35 - Added usage tracking
/// </claude>

import 'dart:io';
import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:sqlite3/sqlite3.dart';

import 'class_analyzer.dart';
import 'documentation_analyzer.dart';
import './db_schema.dart';
import 'import_analyzer.dart';
import 'method_analyzer.dart';
import 'usage_analyzer.dart';
import 'pml_config.dart';

class CodeAnalyzer {
  final Database db;
  final PMLConfig config;

  CodeAnalyzer(this.db, this.config) {
    initializeTables(db);
  }

  Future<void> analyzeProject() async {
    try {
      await _analyzeDartFiles();

      stderr.writeln('\nStarting post-processing...');
      final importAnalyzer = ImportAnalyzer(db, config);
      await importAnalyzer.postProcess();

      stderr.writeln('\nAnalysis complete');
    } catch (e, stack) {
      stderr.writeln('Error: $e\n$stack');
    }
  }

  Future<void> _analyzeDartFiles() async {
    stderr.writeln('\nDirectory: ${Directory.current.path}');

    final libDir = Directory(config.sourceRoot);
    await for (final entity in libDir.list(recursive: true)) {
      if (_shouldAnalyzeFile(entity)) {
        await _analyzeFile(entity as File);
      }
    }
  }

  Future<void> _analyzeFile(File file) async {
    String filePath = file.path;
    filePath = _normalizePath(filePath);
    stderr.writeln('\nAnalyzing: $filePath');

    try {
      final content = await file.readAsString();
      final result = parseString(content: content);
      final CompilationUnit unit = result.unit;

      final fileId = _insertFileInfo(filePath, file);

      final context = _AnalysisContext(
          fileId: fileId,
          filePath: filePath,
          content: content,
          unit: unit,
          db: db
      );

      await _runStructureAnalyzers(context);

      stderr.writeln('  Analyzing documentation...');
      final docAnalyzer = DocumentationAnalyzer(db);
      docAnalyzer.analyze(content, fileId);

    } catch (e) {
      stderr.writeln('Error analyzing $filePath: $e');
      stderr.writeln(StackTrace.current);
    }
  }

  Future<void> _runStructureAnalyzers(_AnalysisContext context) async {
    stderr.writeln('  Processing imports...');
    final importAnalyzer = ImportAnalyzer(db, config);
    await importAnalyzer.analyze(context.content, context.filePath, context.fileId);

    stderr.writeln('  Processing classes...');
    final classAnalyzer = ClassAnalyzer(db, config);  // Ajout de config
    final classStore = await classAnalyzer.analyze(context.content, context.fileId);

    final methodAnalyzer = MethodAnalyzer(db, config);  // Ajout de config
    final usageAnalyzer = UsageAnalyzer(db);
    final processedDeclarations = <String>{};

    for (var declaration in context.unit.declarations) {
      if (declaration is ClassDeclaration) {
        final className = declaration.name2.lexeme;

        if (processedDeclarations.contains(className)) {
          stderr.writeln('  Skipping already processed class: $className');
          continue;
        }
        processedDeclarations.add(className);

        stderr.writeln('  Processing class: $className');
        final classId = classStore.ids[processedDeclarations.length - 1];

        stderr.writeln('    Processing methods...');
        await methodAnalyzer.analyze(context.unit, classId);

        stderr.writeln('    Analyzing usages...');
        await usageAnalyzer.analyze(
            context.unit,
            context.fileId,
            classId,
            className
        );
      }
    }
  }

  int _insertFileInfo(String filepath, File file) {
    final stats = file.statSync();
    final filePath = _normalizePath(filepath);

    db.execute('''
      INSERT INTO source_files (
        file_path,
        size_bytes,
        last_modified
      ) VALUES (?, ?, ?)
    ''', [filePath, stats.size, stats.modified.toIso8601String()]);

    return db.lastInsertRowId;
  }

  String _normalizePath(String filepath) {
    return config.normalizePath(filepath);
  }

  bool _shouldAnalyzeFile(FileSystemEntity entity) {
    return entity is File && config.shouldAnalyzeFile(entity.path);
  }
}

class _AnalysisContext {
  final int fileId;
  final String filePath;
  final String content;
  final CompilationUnit unit;
  final Database db;

  _AnalysisContext({
    required this.fileId,
    required this.filePath,
    required this.content,
    required this.unit,
    required this.db
  });
}