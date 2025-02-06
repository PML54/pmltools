/// <claude>
/// File: class_declaration_store.dart
/// Date: 2025-01-29 16:45:00 CET (Paris) by Claude-3.5-Sonnet
///
/// USER INFO
/// - In-memory store for class declarations
/// - Maps class IDs to their AST nodes
/// - Used during analysis phase only
///
/// CONTEXT
/// - Temporary storage during AST traversal
/// - Bridges between database IDs and AST nodes
/// - Supports multi-pass analysis
///
/// KEY POINTS
/// - Maintains ordered list of class IDs
/// - Maps IDs to ClassDeclaration nodes
/// - Thread-safe single analysis session
///
/// DATA STRUCTURE
/// - ids: Ordered list of processed class IDs
/// - nodes: Map of class ID to AST node
/// - Nullability supported for partial declarations
///
/// Version History:
/// v1.0 - 2025-01-29 16:45 - Initial documentation
///   * Added comprehensive structure description
///   * Documented temporary storage nature
///   * Clarified usage context
/// </claude>

import 'package:analyzer/dart/ast/ast.dart';

class ClassDeclarationStore {
  final Map<int, ClassDeclaration?> nodes = {};
  final List<int> ids = [];

  void addClassId(int id) {
    ids.add(id);
  }

  void addNode(int id, ClassDeclaration node) {
    nodes[id] = node;
  }
}