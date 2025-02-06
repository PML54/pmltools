/// <claude>
/// File: method_analyzer.dart
/// Date: 2025-02-04
///
/// USER INFO
/// - Method analysis and extraction from AST
/// - Stores results in class_methods table
/// - Calculates cyclomatic and cognitive complexity
/// - Uses PMLConfig and structured logging
///
/// KEY POINTS
/// - Detects special widget methods (build)
/// - Analyzes method properties and complexity
/// - Handles method parameters
/// - Detailed logging of complexity metrics
/// </claude>

import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:io';
import 'pml_config.dart';
import 'pml_logger.dart';

class ComplexityAnalyzer extends RecursiveAstVisitor<void> {
  // Rendre les propriétés accessibles
  int _cyclomaticComplexity = 1;  // Start at 1
  int _cognitiveComplexity = 0;
  int _nestingLevel = 0;

  // Ajouter des getters publics
  int get cyclomaticComplexity => _cyclomaticComplexity;
  int get cognitiveComplexity => _cognitiveComplexity;

  @override
  void visitIfStatement(IfStatement node) {
    _cyclomaticComplexity++;  // +1 for if
    _cognitiveComplexity += (1 + _nestingLevel);  // Base + nesting level

    if (node.elseStatement != null) {
      _cognitiveComplexity++;  // +1 for else
    }

    _nestingLevel++;
    super.visitIfStatement(node);
    _nestingLevel--;
  }

  @override
  void visitForStatement(ForStatement node) {
    _cyclomaticComplexity++;
    _cognitiveComplexity += (1 + _nestingLevel);

    _nestingLevel++;
    super.visitForStatement(node);
    _nestingLevel--;
  }

  @override
  void visitWhileStatement(WhileStatement node) {
    _cyclomaticComplexity++;
    _cognitiveComplexity += (1 + _nestingLevel);

    _nestingLevel++;
    super.visitWhileStatement(node);
    _nestingLevel--;
  }

  @override
  void visitDoStatement(DoStatement node) {
    _cyclomaticComplexity++;
    _cognitiveComplexity += (1 + _nestingLevel);

    _nestingLevel++;
    super.visitDoStatement(node);
    _nestingLevel--;
  }

  @override
  void visitSwitchStatement(SwitchStatement node) {
    _cyclomaticComplexity += node.members.length;  // +1 for each case
    _cognitiveComplexity += (1 + _nestingLevel);

    _nestingLevel++;
    super.visitSwitchStatement(node);
    _nestingLevel--;
  }

  @override
  void visitBinaryExpression(BinaryExpression node) {
    if (node.operator.type.toString() == '&&' ||
        node.operator.type.toString() == '||') {
      _cyclomaticComplexity++;
      _cognitiveComplexity++;
    }
    super.visitBinaryExpression(node);
  }

  @override
  void visitBreakStatement(BreakStatement node) {
    _cognitiveComplexity++;  // Break adds cognitive complexity
    super.visitBreakStatement(node);
  }

  @override
  void visitCatchClause(CatchClause node) {
    _cyclomaticComplexity++;
    _cognitiveComplexity += (1 + _nestingLevel);
    super.visitCatchClause(node);
  }

  @override
  void visitConditionalExpression(ConditionalExpression node) {
    _cyclomaticComplexity++;
    _cognitiveComplexity += (1 + _nestingLevel);
    super.visitConditionalExpression(node);
  }
}

class MethodAnalyzer {
  final Database db;
  final PMLConfig config;
  late final PMLLogger _logger;

  MethodAnalyzer(this.db, this.config) {
    _logger = PMLLogger('MethodAnalyzer', config);
  }

  Future<void> analyze(CompilationUnit unit, int classId) async {
    _logger.debug('Starting method analysis for classId: $classId');

    try {
      final classResult = db.select(
          'SELECT class_name FROM classes WHERE class_id = ?',
          [classId]
      ).first;

      final className = classResult['class_name'];
      _logger.debug('Found class name: $className');

      // Find the first matching class declaration
      ClassDeclaration? targetClass;
      for (var declaration in unit.declarations) {
        _logger.debug('Checking declaration: ${declaration.runtimeType}');
        if (declaration is ClassDeclaration &&
            declaration.name.lexeme == className) {
          targetClass = declaration;
          _logger.debug('Found matching class declaration');
          break;
        }
      }

      if (targetClass == null) {
        _logger.warning('No matching class found for $className');
        return;
      }

      // Identify special class types
      String? specialType;
      if (targetClass.extendsClause != null) {
        final superclass = targetClass.extendsClause!.superclass.name.name;
        if (['StatelessWidget', 'ConsumerWidget'].contains(superclass)) {
          specialType = superclass;
          _logger.info('Found special widget type: $superclass');
        }
      }

      // Process regular methods
      _logger.debug('Number of members: ${targetClass.members.length}');
      for (var member in targetClass.members) {
        if (member is MethodDeclaration) {
          final name = member.name.lexeme;
          _logger.debug('Processing method: $name');
          if (name == 'build' && specialType != null) {
            _logger.debug('Skipping build method for $specialType (will be added later)');
            continue;
          }
          _insertMethod(classId, member);
        }
      }

      // Add special methods if needed
      if (specialType != null) {
        int paramCount = specialType == 'ConsumerWidget' ? 2 : 1;
        _logger.info('Adding build method for $specialType with $paramCount parameters');
        _insertBuildMethod(classId, paramCount);
      }
    } catch (e, stack) {
      _logger.error('Error analyzing methods', e, stack);
      rethrow;
    }
  }

  void _insertMethod(int classId, MethodDeclaration method) {
    try {
      final name = method.name.lexeme;
      final returnType = method.returnType?.toString() ?? 'dynamic';

      // Calculer les complexités
      final complexityAnalyzer = ComplexityAnalyzer();
      method.accept(complexityAnalyzer);

      _logger.info('Analyzing method: $name');
      _logger.debug('''Method details:
        Return type: $returnType
        Static: ${method.isStatic}
        Async: ${method.body.isAsynchronous}
        Parameters: ${method.parameters?.parameters.length ?? 0}
        Cyclomatic complexity: ${complexityAnalyzer.cyclomaticComplexity}
        Cognitive complexity: ${complexityAnalyzer.cognitiveComplexity}''');

      db.execute('''
        INSERT INTO class_methods (
          class_id, method_name, return_type, is_async, is_static,
          param_count, cyclomatic_complexity, cognitive_complexity, has_annotation
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        classId, name, returnType,
        method.body.isAsynchronous ? 1 : 0,
        method.isStatic ? 1 : 0,
        method.parameters?.parameters.length ?? 0,
        complexityAnalyzer.cyclomaticComplexity,
        complexityAnalyzer.cognitiveComplexity,
        method.metadata.isNotEmpty ? 1 : 0
      ]);

      _logger.debug('Method $name inserted successfully');
    } catch (e, stack) {
      _logger.error('Error inserting method $method.name.lexeme', e, stack);
    }
  }

  void _insertBuildMethod(int classId, int paramCount) {
    try {
      db.execute('''
        INSERT INTO class_methods (
          class_id, method_name, return_type, is_async, is_static,
          param_count, cyclomatic_complexity, cognitive_complexity, has_annotation
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        classId, 'build', 'Widget',
        0, 0, paramCount, 1, 0, 0
      ]);
      _logger.debug('Build method inserted successfully');
    } catch (e, stack) {
      _logger.error('Error inserting build method', e, stack);
    }
  }
}