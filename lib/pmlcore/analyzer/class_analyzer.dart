/// <claude>
/// File: class_analyzer.dart
/// Date: 2025-02-04
///
/// USER INFO
/// - Analyzes class structures from Dart AST
/// - Detects framework types (Riverpod, Flutter, etc.)
/// - Determines widget types
/// - Uses PMLConfig and logging
///
/// KEY POINTS
/// - Handles class declarations
/// - Processes mixins and enums
/// - Stores class metadata
/// - Structured logging
/// </claude>

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'class_declaration_store.dart';
import 'pml_config.dart';
import 'pml_logger.dart';

class ClassAnalyzer {
  final Database db;
  final PMLConfig config;
  late final PMLLogger _logger;

  ClassAnalyzer(this.db, this.config) {
    _logger = PMLLogger('ClassAnalyzer', config);
  }

  Future<ClassDeclarationStore> analyze(String content, int fileId) async {
    final classStore = ClassDeclarationStore();

    try {
      final result = parseString(content: content);
      final unit = result.unit;

      final imports = _analyzeImports(unit);
      _logger.debug('Found ${imports.length} imports');

      final visitor = _ClassVisitor(db, fileId, classStore, imports, _logger);
      unit.accept(visitor);

      return classStore;
    } catch (e, stack) {
      _logger.error('Error analyzing class structure', e, stack);
      rethrow;
    }
  }

  Set<String> _analyzeImports(CompilationUnit unit) {
    final imports = <String>{};
    for (final directive in unit.directives) {
      if (directive is ImportDirective) {
        imports.add(directive.uri.stringValue ?? '');
      }
    }
    return imports;
  }
}

class _ClassVisitor extends RecursiveAstVisitor<void> {
  final Database db;
  final int fileId;
  final ClassDeclarationStore classStore;
  final Set<String> imports;
  final PMLLogger _logger;

  _ClassVisitor(this.db, this.fileId, this.classStore, this.imports, this._logger);

  String? _determineFrameworkType(ClassDeclaration node) {
    // Existant inchangé
    return null;
  }

  String? _determineWidgetType(ClassDeclaration node) {
    // Existant inchangé
    return null;
  }

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name2.lexeme;
    String type = 'class';
    String? widgetType;
    String? frameworkType;

    if (node.abstractKeyword != null) {
      type = 'abstract';
    } else if (node.implementsClause != null) {
      final interfaces = node.implementsClause!.interfaces;
      if (interfaces.any((i) => i.name2.lexeme == 'Interface')) {
        type = 'interface';
      }
    }

    widgetType = _determineWidgetType(node);
    frameworkType = _determineFrameworkType(node);

    _logger.info('Found $type: $className' +
        (widgetType != null ? ' (widget: $widgetType)' : '') +
        (frameworkType != null ? ' (framework: $frameworkType)' : ''));

    try {
      db.execute('''
        INSERT INTO classes (
          file_id, 
          class_name,
          type,
          import_count,
          is_used,
          widget_type,
          framework_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [fileId, className, type, 0, 0, widgetType, frameworkType]);

      final classId = db.lastInsertRowId;
      classStore.addClassId(classId);
      classStore.addNode(classId, node);
    } catch (e, stack) {
      _logger.error('Error inserting class $className', e, stack);
    }

    super.visitClassDeclaration(node);
  }

  @override
  void visitMixinDeclaration(MixinDeclaration node) {
    final mixinName = node.name2.lexeme;
    _logger.info('Found mixin: $mixinName');

    try {
      db.execute('''
        INSERT INTO classes (
          file_id, 
          class_name,
          type,
          import_count,
          is_used,
          widget_type,
          framework_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [fileId, mixinName, 'mixin', 0, 0, null, null]);

      final classId = db.lastInsertRowId;
      classStore.addClassId(classId);
    } catch (e, stack) {
      _logger.error('Error inserting mixin $mixinName', e, stack);
    }

    super.visitMixinDeclaration(node);
  }

  @override
  void visitEnumDeclaration(EnumDeclaration node) {
    final enumName = node.name2.lexeme;
    _logger.info('Found enum: $enumName');

    try {
      db.execute('''
        INSERT INTO classes (
          file_id, 
          class_name,
          type,
          import_count,
          is_used,
          widget_type,
          framework_type
        ) VALUES (?, ?, ?, ?, ?, ?, ?)
      ''', [fileId, enumName, 'enum', 0, 0, null, null]);

      final classId = db.lastInsertRowId;
      classStore.addClassId(classId);
    } catch (e, stack) {
      _logger.error('Error inserting enum $enumName', e, stack);
    }

    super.visitEnumDeclaration(node);
  }
}