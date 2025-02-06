/// <claude>
/// File: documentation_analyzer.dart
/// Date: 2024-01-29 09:25:15 CET (Paris) by Claude-3.5-Sonnet
///
/// USER INFO
/// - Generates documentation from AST analysis
/// - Stores in class_documentations table
/// - Database recreated on each run
///
/// KEY POINTS
/// - Analyses class purposes
/// - Detects responsibilities
/// - Infers method purposes
///
/// TABLE UPDATES
/// - Uses class_documentations table
/// - Updated column names (file_id, class_name, etc.)
/// - Consistent naming with other tables
/// </claude>

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:sqlite3/sqlite3.dart';
import 'dart:convert';
import 'dart:io';

class DocumentationAnalyzer {
  final Database db;

  DocumentationAnalyzer(this.db);

  void analyze(String content, int fileId) {
    try {
      final result = parseString(content: content);
      final unit = result.unit;

      final visitor = _DocumentationVisitor(db, fileId);
      unit.accept(visitor);
    } catch (e, stack) {
      stderr.writeln('Error during AST analysis: $e\n$stack');
    }
  }
}

class _DocumentationVisitor extends RecursiveAstVisitor<void> {
  final Database db;
  final int fileId;
  final Map<String, Map<String, dynamic>> classesInfo = {};
  final List<String> sharedResponsibilities = [];

  _DocumentationVisitor(this.db, this.fileId);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    final className = node.name.lexeme;
    final classInfo = _analyzeClass(node);
    classesInfo[className] = classInfo;

    _insertDocumentation(className, classInfo);

    super.visitClassDeclaration(node);
  }

  Map<String, dynamic> _analyzeClass(ClassDeclaration node) {
    final info = <String, dynamic>{
      'type': _determineClassType(node),
      'purpose': _inferClassPurpose(node),
      'responsibilities': _analyzeResponsibilities(node),
      'methods': _analyzeMethods(node)
    };

    return info;
  }

  String _determineClassType(ClassDeclaration node) {
    if (node.abstractKeyword != null) return 'abstract';

    if (node.extendsClause != null) {
      final superclass = node.extendsClause!.superclass.name.name;
      if (superclass.contains('Widget')) return 'widget';
      if (superclass.contains('State')) return 'state';
      if (superclass.contains('Bloc')) return 'bloc';
      if (superclass.contains('Cubit')) return 'cubit';
      if (superclass.contains('Repository')) return 'repository';
      if (superclass.contains('Service')) return 'service';
    }

    if (node.implementsClause != null) {
      for (var interface in node.implementsClause!.interfaces) {
        if (interface.name.name.contains('Repository')) return 'repository';
        if (interface.name.name.contains('Service')) return 'service';
      }
    }

    final className = node.name.lexeme.toLowerCase();
    if (className.endsWith('controller')) return 'controller';
    if (className.endsWith('service')) return 'service';
    if (className.endsWith('repository')) return 'repository';
    if (className.endsWith('bloc')) return 'bloc';
    if (className.endsWith('state')) return 'state';
    if (className.endsWith('event')) return 'event';

    return 'class';
  }

  String _inferClassPurpose(ClassDeclaration node) {
    final className = node.name.lexeme;
    final methods = node.members.whereType<MethodDeclaration>();
    final methodNames = methods.map((m) => m.name.lexeme).toList();

    if (methodNames.contains('build')) {
      return 'UI Component for rendering ${_humanize(className)}';
    }
    if (methods.any((m) => m.name.lexeme.startsWith('fetch') ||
        m.name.lexeme.startsWith('get'))) {
      return 'Data provider for ${_humanize(className)}';
    }
    if (methodNames.contains('call')) {
      return 'Use case implementation for ${_humanize(className)}';
    }
    if (className.endsWith('Repository')) {
      return 'Data repository managing ${_humanize(className.replaceAll('Repository', ''))}';
    }
    if (className.endsWith('Service')) {
      return 'Service providing ${_humanize(className.replaceAll('Service', ''))} functionality';
    }

    return 'Manages ${_humanize(className)} functionality';
  }

  List<String> _analyzeResponsibilities(ClassDeclaration node) {
    final responsibilities = <String>[];
    final methods = node.members.whereType<MethodDeclaration>();

    final dataManagement = methods.where((m) =>
    m.name.lexeme.startsWith('get') ||
        m.name.lexeme.startsWith('set') ||
        m.name.lexeme.startsWith('update') ||
        m.name.lexeme.startsWith('delete')
    );

    final stateManagement = methods.where((m) =>
    m.name.lexeme.contains('State') ||
        m.name.lexeme.contains('Event')
    );

    final uiMethods = methods.where((m) =>
    m.name.lexeme == 'build' ||
        m.name.lexeme.startsWith('render') ||
        m.name.lexeme.startsWith('draw')
    );

    if (dataManagement.isNotEmpty) {
      responsibilities.add('Manages data operations and persistence');
    }

    if (stateManagement.isNotEmpty) {
      responsibilities.add('Handles state management and transitions');
    }

    if (uiMethods.isNotEmpty) {
      responsibilities.add('Renders user interface components');
    }

    if (methods.any((m) => m.name.lexeme.contains('validate'))) {
      responsibilities.add('Performs data validation');
    }

    if (methods.any((m) => m.body is BlockFunctionBody &&
        (m.body as BlockFunctionBody).keyword?.lexeme == 'async')) {
      responsibilities.add('Handles asynchronous operations');
    }

    return responsibilities;
  }

  List<Map<String, String>> _analyzeMethods(ClassDeclaration node) {
    return node.members
        .whereType<MethodDeclaration>()
        .map((method) => {
      'name': method.name.lexeme,
      'purpose': _inferMethodPurpose(method),
      'type': _determineMethodType(method)
    })
        .toList();
  }

  String _determineMethodType(MethodDeclaration method) {
    if (method.isGetter) return 'getter';
    if (method.isSetter) return 'setter';
    if (method.isOperator) return 'operator';

    if (method.body is BlockFunctionBody) {
      final body = method.body as BlockFunctionBody;
      if (body.keyword?.lexeme == 'async') {
        return 'async';
      }
    }

    return 'method';
  }

  String _inferMethodPurpose(MethodDeclaration method) {
    final name = method.name.lexeme;

    if (name == 'build') return 'Builds the widget UI structure';
    if (name.startsWith('get')) return 'Retrieves ${_humanize(name.substring(3))}';
    if (name.startsWith('set')) return 'Updates ${_humanize(name.substring(3))}';
    if (name.startsWith('on')) return 'Handles ${_humanize(name.substring(2))} event';
    if (name.contains('State')) return 'Manages state transition for ${_humanize(name)}';
    if (name.startsWith('update')) return 'Updates ${_humanize(name.substring(6))}';
    if (name.startsWith('fetch')) return 'Fetches ${_humanize(name.substring(5))} data';
    if (name.startsWith('validate')) return 'Validates ${_humanize(name.substring(8))}';

    return 'Handles ${_humanize(name)} operation';
  }

  void _insertDocumentation(String className, Map<String, dynamic> classInfo) {
    try {
      db.execute('''
        INSERT INTO class_documentations (
          file_id,
          date_created,
          class_name,
          class_type,
          class_purpose,
          responsibilities,
          methods,
          shared_responsibilities
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?)
      ''', [
        fileId,
        DateTime.now().toIso8601String(),
        className,
        classInfo['type'],
        classInfo['purpose'],
        json.encode(classInfo['responsibilities']),
        json.encode(classInfo['methods']),
        json.encode(sharedResponsibilities)
      ]);
    } catch (e) {
      stderr.writeln('Error inserting documentation for $className: $e');
    }
  }

  String _humanize(String input) {
    final humanized = input
        .replaceAllMapped(RegExp(r'([A-Z])', caseSensitive: true),
            (Match m) => ' ${m[1]!.toLowerCase()}')
        .trim();
    return humanized[0].toUpperCase() + humanized.substring(1);
  }
}