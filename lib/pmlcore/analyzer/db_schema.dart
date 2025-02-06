/// <claude>
/// File: db_schema.dart
/// Date: 2025-01-29 15:15:00 CET (Paris) by Claude-3.5-Sonnet
///
/// USER INFO
/// - Database is RECREATED on each analysis
/// - SQLite schema follows standard naming conventions
/// - All tables use consistent naming patterns
/// - Foreign keys are enforced
/// - Usage tracking tables added for dead code detection
///
/// CONTEXT
/// - SQLite schema for Dart code analysis
/// - Stores source files, classes, and methods data
/// - Generates documentation from AST analysis
/// - Tracks class and method usage for dead code detection
///
/// DATABASE STRUCTURE
/// Source Files Layer:
/// - source_files: Dart source files
/// - file_imports: Import declarations
/// - file_import_relations: N-N file-import mapping
///
/// Code Analysis Layer:
/// - classes: Class definitions and metadata
/// - class_methods: Method definitions and metrics
/// - class_documentations: Generated documentation
///
/// Usage Tracking Layer:
/// - class_usage_references: Tracks where classes are used
/// - method_usage_references: Tracks method calls
///
/// CLAUDE MODIFICATION HISTORY
/// v1.6 - 2025-01-29 15:15 - Added usage tracking tables
///   * Added class_usage_references table
///   * Added method_usage_references table
///   * Updated documentation for usage tracking
/// v1.5 - 2024-01-29 08:20 - English documentation
/// v1.4 - 2024-01-29 08:10 - Consistent table naming
/// v1.3 - 2024-01-29 07:40 - Removed unused tables
/// v1.2 - 2024-01-29 07:20 - Removed class_interactions
/// v1.1 - 2024-01-29 06:55 - Index improvements
/// v1.0 - 2024-01-29 06:33 - Initial version
///
/// KEY POINTS
/// - Tables follow naming convention: plural nouns
/// - IDs include table name (file_id, class_id)
/// - Foreign keys use consistent naming
/// - Indexes named with idx_ prefix
/// - Usage tracking enables dead code detection
///
/// EXTENSION POINTS
/// - Add support for code metrics tables
/// - Add version control integration
/// - Add custom annotation support
/// - Add code quality metrics
/// - Add usage statistics and metrics
/// </claude>sqlite3/sqlite3.dart';
import 'package:sqlite3/sqlite3.dart';
void initializeTables(Database db) {
  try {
    db.execute('BEGIN TRANSACTION');

    // Core structure
    _initCoreStructure(db);

    // Classes et méthodes
    _initClassStructure(db);

    // Index
    _createAllIndexes(db);

    db.execute('COMMIT');
  } catch (e) {
    db.execute('ROLLBACK');
    print('Erreur lors de l\'initialisation de la base : $e');
    rethrow;
  }
}

void _initCoreStructure(Database db) {
  db.execute('''
    CREATE TABLE source_files (
      file_id INTEGER PRIMARY KEY,
      file_path TEXT NOT NULL,
      size_bytes INTEGER,
      last_modified DATETIME
    )
  ''');

  db.execute('''
    CREATE TABLE file_imports (
      import_id INTEGER PRIMARY KEY,
      import_path TEXT NOT NULL UNIQUE,
      is_app_file BOOLEAN NOT NULL DEFAULT 0,
      is_package BOOLEAN DEFAULT FALSE
    )
  ''');

  db.execute('''
    CREATE TABLE file_import_relations (
      relation_id INTEGER PRIMARY KEY,
      file_id INTEGER NOT NULL,
      import_id INTEGER NOT NULL,
      FOREIGN KEY (file_id) REFERENCES source_files(file_id),
      FOREIGN KEY (import_id) REFERENCES file_imports(import_id),
      UNIQUE(file_id, import_id)
    )
  ''');

  db.execute('''
    CREATE TABLE class_documentations (
      doc_id INTEGER PRIMARY KEY,
      file_id INTEGER NOT NULL,
      date_created TEXT NOT NULL,
      class_name TEXT NOT NULL,
      class_type TEXT,
      class_purpose TEXT,
      responsibilities TEXT,
      methods TEXT,
      shared_responsibilities TEXT,
      FOREIGN KEY (file_id) REFERENCES source_files(file_id)
    )
  ''');

  db.execute('CREATE INDEX idx_documentation_file ON class_documentations(file_id)');

  // Nouvelles tables pour le suivi des utilisations
  db.execute('''
    CREATE TABLE class_usage_references (
      reference_id INTEGER PRIMARY KEY,
      referenced_class_id INTEGER NOT NULL,
      source_file_id INTEGER NOT NULL,
      source_class_id INTEGER,
      source_method_id INTEGER,
      reference_type TEXT CHECK(reference_type IN ('creation', 'extension', 'implementation', 'usage')) NOT NULL,
      FOREIGN KEY (referenced_class_id) REFERENCES classes (class_id),
      FOREIGN KEY (source_file_id) REFERENCES source_files (file_id),
      FOREIGN KEY (source_class_id) REFERENCES classes (class_id),
      FOREIGN KEY (source_method_id) REFERENCES class_methods (method_id)
    )
  ''');

  db.execute('''
    CREATE TABLE method_usage_references (
      reference_id INTEGER PRIMARY KEY,
      referenced_method_id INTEGER NOT NULL,
      source_file_id INTEGER NOT NULL,
      source_class_id INTEGER,
      source_method_id INTEGER,
      is_direct_call BOOLEAN NOT NULL DEFAULT TRUE,
      FOREIGN KEY (referenced_method_id) REFERENCES class_methods (method_id),
      FOREIGN KEY (source_file_id) REFERENCES source_files (file_id),
      FOREIGN KEY (source_class_id) REFERENCES classes (class_id),
      FOREIGN KEY (source_method_id) REFERENCES class_methods (method_id)
    )
  ''');
}

void _initClassStructure(Database db) {
  db.execute('''
    CREATE TABLE classes (
      class_id INTEGER PRIMARY KEY,
      file_id INTEGER NOT NULL,
      class_name TEXT NOT NULL,
      type TEXT CHECK(type IN ('class', 'abstract', 'mixin', 'interface', 'enum')) DEFAULT 'class',
      description TEXT,
      import_count INTEGER NOT NULL,
      is_used BOOLEAN NOT NULL,
      widget_type TEXT DEFAULT NULL,
      framework_type TEXT DEFAULT NULL,
      FOREIGN KEY (file_id) REFERENCES source_files(file_id)
    )
  ''');

  db.execute('''
    CREATE TABLE class_methods (
      method_id INTEGER PRIMARY KEY,
      class_id INTEGER NOT NULL,
      method_name TEXT NOT NULL,
      return_type TEXT,
      is_async BOOLEAN DEFAULT FALSE,
      is_static BOOLEAN DEFAULT FALSE,
      cyclomatic_complexity INTEGER DEFAULT 1,
      cognitive_complexity INTEGER DEFAULT 1,
      param_count INTEGER DEFAULT 0,
      has_annotation BOOLEAN DEFAULT FALSE,
      FOREIGN KEY (class_id) REFERENCES classes(class_id),
      UNIQUE(class_id, method_name)
    )
  ''');
}

void _createAllIndexes(Database db) {
  final indexDefinitions = [
    'CREATE INDEX idx_files_path ON source_files(file_path)',
    'CREATE INDEX idx_imports_path ON file_imports(import_path)',
    'CREATE INDEX idx_import_relations_file ON file_import_relations(file_id)',
    'CREATE INDEX idx_import_relations_import ON file_import_relations(import_id)',
    'CREATE INDEX idx_class_file ON classes(file_id)',
    'CREATE INDEX idx_class_name ON classes(class_name)',
    'CREATE INDEX idx_methods_class ON class_methods(class_id)',
    'CREATE INDEX idx_methods_name ON class_methods(method_name)',
    'CREATE INDEX idx_class_usage_referenced ON class_usage_references(referenced_class_id)',
    'CREATE INDEX idx_class_usage_source ON class_usage_references(source_file_id, source_class_id)',
    'CREATE INDEX idx_method_usage_referenced ON method_usage_references(referenced_method_id)',
    'CREATE INDEX idx_method_usage_source ON method_usage_references(source_file_id, source_class_id)'

  ];

  for (final indexDef in indexDefinitions) {
    db.execute(indexDef);
  }
}