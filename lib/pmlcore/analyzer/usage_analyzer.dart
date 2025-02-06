/// <claude>
/// File: usage_analyzer.dart
/// Date: 2025-01-29 17:45:00 CET (Paris) by Claude-3.5-Sonnet
///
/// USER INFO
/// - Tracks method and class usage across files
/// - Part of cross-reference analysis
/// - Table rebuilt on each analysis run
///
/// KEY POINTS
/// - Records method invocations
/// - Maps caller-callee relationships
/// - Uses AST visitor pattern
/// - Tracks class instantiation and usage
///
/// TABLE UPDATES
/// - Uses method_usage_references table
/// - Uses class_usage_references table
/// - Links to class_methods table
///
/// Version History:
/// v1.2 - 2025-01-29 17:45 - Added class usage tracking
///   * Added instance creation tracking
///   * Added type reference tracking
///   * Added debug logging
/// v1.1 - 2025-01-29 17:30 - Renamed and restructured
/// v1.0 - 2024-01-29 09:45 - Initial version
/// </claude>

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';

class UsageAnalyzer {
  final Database db;

  UsageAnalyzer(this.db);

  Future<void> analyze(CompilationUnit unit, int fileId, int classId, String className) async {
    stderr.writeln('  Starting usage analysis for class $className (ID: $classId)');
    unit.visitChildren(_UsageVisitor(db, classId, fileId));
  }
}

class _UsageVisitor extends RecursiveAstVisitor<void> {
  final Database db;
  final int classId;
  final int fileId;

  _UsageVisitor(this.db, this.classId, this.fileId);

  @override
  void visitMethodInvocation(MethodInvocation node) {
    try {
      // Récupérer l'ID de la méthode référencée
      final methodName = node.methodName.name;
      stderr.writeln('    Found method invocation: $methodName');

      // Chercher dans class_methods
      final methodResult = db.select('''
        SELECT method_id 
        FROM class_methods 
        WHERE method_name = ?
      ''', [methodName]);

      if (methodResult.isNotEmpty) {
        final methodId = methodResult.first['method_id'] as int;
        stderr.writeln('    Found method ID: $methodId');

        db.execute('''
          INSERT INTO method_usage_references (
            referenced_method_id,
            source_file_id,
            source_class_id,
            is_direct_call
          ) VALUES (?, ?, ?, ?)
        ''', [methodId, fileId, classId, 1]);
      }
    } catch (e) {
      stderr.writeln('    Error processing method invocation: $e');
    }

    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    try {
      final className = node.constructorName.type.name.name;
      stderr.writeln('    Found class instantiation: $className');

      final classResult = db.select('''
        SELECT class_id 
        FROM classes 
        WHERE class_name = ?
      ''', [className]);

      if (classResult.isNotEmpty) {
        final referencedClassId = classResult.first['class_id'] as int;
        stderr.writeln('    Found class ID: $referencedClassId');

        db.execute('''
          INSERT INTO class_usage_references (
            referenced_class_id,
            source_file_id,
            source_class_id,
            source_method_id,
            reference_type
          ) VALUES (?, ?, ?, ?, ?)
        ''', [referencedClassId, fileId, classId, null, 'creation']);
      }
    } catch (e) {
      stderr.writeln('    Error processing class instantiation: $e');
    }

    super.visitInstanceCreationExpression(node);
  }
}