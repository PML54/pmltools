/// <claude>
/// File: class_relations_analyzer.dart
/// Date: 2024-01-29 09:35:15 CET (Paris) by Claude-3.5-Sonnet
///
/// USER INFO
/// - Analyzes relationships between classes
/// - Detects inheritance, implementations, mixins
/// - Database recreated on each run
///
/// KEY POINTS
/// - Tracks extends, implements, with relationships
/// - Filters generated code (Freezed, etc.)
/// - Uses class_relations table
///
/// TABLE UPDATES
/// - Uses renamed classes table
/// - Updated column names for consistency
/// - Relations table updated
/// </claude>

import 'package:sqlite3/sqlite3.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'dart:io';

class ClassRelationAnalyzer {
  final Database db;

  ClassRelationAnalyzer(this.db);

  Future<void> analyze(CompilationUnit unit, int classId) async {
    // Get source class info
    final sourceClassResult = db.select(
        'SELECT class_name, file_path FROM classes JOIN source_files ON classes.file_id = source_files.file_id WHERE class_id = ?',
        [classId]
    ).first;

    final sourceClass = sourceClassResult['class_name'] as String;
    final sourceFile = sourceClassResult['file_path'] as String;

    stderr.writeln('\nAnalyzing relations in $sourceFile for class: $sourceClass');

    // Find corresponding declaration
    final declarations = unit.declarations.whereType<ClassDeclaration>()
        .where((d) => d.name.lexeme == sourceClass);

    if (declarations.isNotEmpty) {
      final declaration = declarations.first;

      // Process inheritance
      if (declaration.extendsClause != null) {
        final superclass = declaration.extendsClause!.superclass.toString();
        stderr.writeln('  extends: $superclass');
        _insertRelation(classId, superclass, 'extends');
      }

      // Process interfaces
      if (declaration.implementsClause != null) {
        for (var interface in declaration.implementsClause!.interfaces) {
          final interfaceName = interface.toString();
          stderr.writeln('  implements: $interfaceName');
          _insertRelation(classId, interfaceName, 'implements');
        }
      }

      // Process mixins
      if (declaration.withClause != null) {
        for (var mixin in declaration.withClause!.mixinTypes) {
          final mixinName = mixin.toString();
          // Skip generated mixins
          if (!mixinName.startsWith('_\$')) {
            stderr.writeln('  with: $mixinName');
            _insertRelation(classId, mixinName, 'with');
          }
        }
      }
    } else {
      stderr.writeln('  Warning: Class declaration not found in AST');
    }
  }

  void _insertRelation(int classId, String targetClass, String relationType) {
    // Check for existing relation
    final existingCount = db.select('''
      SELECT COUNT(*) as count 
      FROM class_relations 
      WHERE source_class_id = ? 
        AND target_class_name = ? 
        AND relation_type = ?
    ''', [classId, targetClass, relationType]).first['count'] as int;

    if (existingCount == 0) {
      db.execute('''
        INSERT INTO class_relations (
          source_class_id, 
          target_class_name, 
          relation_type
        ) VALUES (?, ?, ?)
      ''', [classId, targetClass, relationType]);
    }
  }
}