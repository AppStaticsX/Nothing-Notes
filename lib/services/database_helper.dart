import 'package:sqflite/sqflite.dart';
import '../models/note.dart';
import 'package:path/path.dart';
import 'dart:io';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('notes.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, // Incremented version for notification counter table
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    const idType = 'TEXT PRIMARY KEY';
    const textType = 'TEXT NOT NULL';
    const intType = 'INTEGER NOT NULL';

    // Create notes table
    await db.execute('''
      CREATE TABLE notes (
        id $idType,
        title $textType,
        content $textType,
        createdAt $textType,
        updatedAt $textType,
        isPinned $intType,
        category TEXT,
        tags TEXT,
        isArchived INTEGER DEFAULT 0,
        isFavorite INTEGER DEFAULT 0,
        templateType TEXT,
        formatting TEXT,
        reminderDateTime TEXT,
        hasReminder INTEGER DEFAULT 0,
        notificationId INTEGER,
        reminderRepeatType TEXT
      )
    ''');

    // Note: reminderRepeatType column is kept for backward compatibility with existing data.
    // New reminders always use 'once' since repeat functionality has been removed from UI.

    // Create notification counter table
    await db.execute('''
      CREATE TABLE notification_counter (
        id INTEGER PRIMARY KEY,
        next_id INTEGER NOT NULL
      )
    ''');

    // Initialize counter to 1
    await db.insert('notification_counter', {'id': 1, 'next_id': 1});

    // Create indexes for better query performance
    await _createIndexes(db);
  }

  Future<void> _createIndexes(Database db) async {
    // Index for sorting by updated date (most common query)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_updated_at 
      ON notes(updatedAt DESC)
    ''');

    // Composite index for pinned and favorite sorting
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_pinned_favorite_updated 
      ON notes(isPinned DESC, isFavorite DESC, updatedAt DESC)
    ''');

    // Index for category filtering
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_category 
      ON notes(category)
    ''');

    // Index for archived filtering
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_archived 
      ON notes(isArchived)
    ''');

    // Composite index for category + archived (common query)
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_category_archived 
      ON notes(category, isArchived)
    ''');

    // Index for favorite filtering
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_favorite 
      ON notes(isFavorite)
    ''');

    // Index for reminder filtering
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reminder 
      ON notes(hasReminder)
    ''');

    // Composite index for active reminders
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_reminder_datetime 
      ON notes(hasReminder, reminderDateTime)
    ''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add new columns if upgrading from version 1
      await db.execute('ALTER TABLE notes ADD COLUMN tags TEXT');
      await db.execute(
        'ALTER TABLE notes ADD COLUMN isArchived INTEGER DEFAULT 0',
      );
      await db.execute(
        'ALTER TABLE notes ADD COLUMN isFavorite INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE notes ADD COLUMN templateType TEXT');
      await db.execute('ALTER TABLE notes ADD COLUMN formatting TEXT');
    }

    if (oldVersion < 3) {
      // Add indexes for version 3
      await _createIndexes(db);
    }

    if (oldVersion < 4) {
      // Add reminder columns for version 4
      await db.execute('ALTER TABLE notes ADD COLUMN reminderDateTime TEXT');
      await db.execute(
        'ALTER TABLE notes ADD COLUMN hasReminder INTEGER DEFAULT 0',
      );
      await db.execute('ALTER TABLE notes ADD COLUMN notificationId INTEGER');

      // Add reminder indexes
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_reminder 
        ON notes(hasReminder)
      ''');
      await db.execute('''
        CREATE INDEX IF NOT EXISTS idx_reminder_datetime 
        ON notes(hasReminder, reminderDateTime)
      ''');
    }

    if (oldVersion < 5 && newVersion >= 5) {
      // Add reminderRepeatType column for version 5
      // Note: This column is kept for backward compatibility. New reminders use 'once' only.
      await db.execute('ALTER TABLE notes ADD COLUMN reminderRepeatType TEXT');
    }

    if (oldVersion < 6) {
      // Add notification counter table for version 6
      await db.execute('''
        CREATE TABLE notification_counter (
          id INTEGER PRIMARY KEY,
          next_id INTEGER NOT NULL
        )
      ''');

      // Initialize counter to 1
      await db.insert('notification_counter', {'id': 1, 'next_id': 1});
    }
  }

  // ============================================================================
  // CRUD OPERATIONS
  // ============================================================================

  Future<Note> create(Note note) async {
    final db = await instance.database;
    await db.insert('notes', note.toMap());
    return note;
  }

  Future<Note?> readNote(String id) async {
    final db = await instance.database;
    final maps = await db.query('notes', where: 'id = ?', whereArgs: [id]);

    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    } else {
      return null;
    }
  }

  Future<List<Note>> readAllNotes() async {
    final db = await instance.database;
    const orderBy = 'isPinned DESC, isFavorite DESC, updatedAt DESC';
    final result = await db.query('notes', orderBy: orderBy);
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Read notes with pagination
  Future<List<Note>> readNotesPage(int page, int pageSize) async {
    final db = await instance.database;
    const orderBy = 'isPinned DESC, isFavorite DESC, updatedAt DESC';

    final result = await db.query(
      'notes',
      orderBy: orderBy,
      limit: pageSize,
      offset: page * pageSize,
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Read notes count (for pagination)
  Future<int> getNotesCount() async {
    final db = await instance.database;
    final result = await db.rawQuery('SELECT COUNT(*) as count FROM notes');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  Future<int> update(Note note) async {
    final db = await instance.database;
    return db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  Future<int> delete(String id) async {
    final db = await instance.database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  // ============================================================================
  // BATCH OPERATIONS (OPTIMIZED)
  // ============================================================================

  /// Delete multiple notes in a batch
  Future<void> deleteMultiple(List<String> ids) async {
    if (ids.isEmpty) return;

    final db = await instance.database;
    final batch = db.batch();

    for (final id in ids) {
      batch.delete('notes', where: 'id = ?', whereArgs: [id]);
    }

    await batch.commit(noResult: true);
  }

  /// Update multiple notes in a batch
  Future<void> updateMultiple(List<Note> notes) async {
    if (notes.isEmpty) return;

    final db = await instance.database;
    final batch = db.batch();

    for (final note in notes) {
      batch.update(
        'notes',
        note.toMap(),
        where: 'id = ?',
        whereArgs: [note.id],
      );
    }

    await batch.commit(noResult: true);
  }

  // ============================================================================
  // SEARCH OPERATIONS (OPTIMIZED)
  // ============================================================================

  /// OPTIMIZED: Search with LIKE operator and proper indexing
  Future<List<Note>> searchNotes(String query) async {
    final db = await instance.database;
    final searchPattern = '%$query%';

    final result = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: [searchPattern, searchPattern, searchPattern],
      orderBy: 'isPinned DESC, isFavorite DESC, updatedAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Search with pagination
  Future<List<Note>> searchNotesPage(
    String query,
    int page,
    int pageSize,
  ) async {
    final db = await instance.database;
    final searchPattern = '%$query%';

    final result = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ? OR tags LIKE ?',
      whereArgs: [searchPattern, searchPattern, searchPattern],
      orderBy: 'isPinned DESC, isFavorite DESC, updatedAt DESC',
      limit: pageSize,
      offset: page * pageSize,
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // ============================================================================
  // CATEGORY OPERATIONS (OPTIMIZED)
  // ============================================================================

  /// Get notes by category with proper index usage
  Future<List<Note>> getNotesByCategory(String category) async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'category = ? AND isArchived = 0',
      whereArgs: [category],
      orderBy: 'isPinned DESC, isFavorite DESC, updatedAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Get all unique categories with caching consideration
  Future<List<String>> getAllCategories() async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      columns: ['category'],
      distinct: true,
      where: 'category IS NOT NULL AND category != ""',
    );

    return result
        .map((row) => row['category'] as String?)
        .where((c) => c != null && c.isNotEmpty)
        .cast<String>()
        .toList()
      ..sort();
  }

  /// OPTIMIZED: Get notes count by category (single query)
  Future<Map<String, int>> getNotesCountByCategory() async {
    final db = await instance.database;
    final result = await db.rawQuery('''
      SELECT category, COUNT(*) as count 
      FROM notes 
      WHERE category IS NOT NULL AND category != '' AND isArchived = 0
      GROUP BY category
      ORDER BY category
    ''');

    return Map.fromEntries(
      result.map(
        (row) => MapEntry(row['category'] as String, row['count'] as int),
      ),
    );
  }

  // ============================================================================
  // TAG OPERATIONS (OPTIMIZED)
  // ============================================================================

  /// Get notes by tag
  Future<List<Note>> getNotesByTag(String tag) async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'tags LIKE ? AND isArchived = 0',
      whereArgs: ['%$tag%'],
      orderBy: 'isPinned DESC, isFavorite DESC, updatedAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Get all unique tags (single query with client-side processing)
  Future<List<String>> getAllTags() async {
    final db = await instance.database;
    final result = await db.query('notes', columns: ['tags']);
    final allTags = <String>{};

    for (var row in result) {
      final tagsString = row['tags'] as String?;
      if (tagsString != null && tagsString.isNotEmpty) {
        final tags = tagsString.split(',');
        allTags.addAll(tags.where((t) => t.trim().isNotEmpty));
      }
    }

    return allTags.toList()..sort();
  }

  /// OPTIMIZED: Get tag usage count
  Future<Map<String, int>> getTagUsageCount() async {
    final db = await instance.database;
    final result = await db.query('notes', columns: ['tags']);
    final tagCounts = <String, int>{};

    for (var row in result) {
      final tagsString = row['tags'] as String?;
      if (tagsString != null && tagsString.isNotEmpty) {
        final tags = tagsString.split(',');
        for (var tag in tags) {
          final trimmedTag = tag.trim();
          if (trimmedTag.isNotEmpty) {
            tagCounts[trimmedTag] = (tagCounts[trimmedTag] ?? 0) + 1;
          }
        }
      }
    }

    return tagCounts;
  }

  // ============================================================================
  // FILTERED QUERIES (OPTIMIZED)
  // ============================================================================

  /// Get archived notes
  Future<List<Note>> getArchivedNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'isArchived = 1',
      orderBy: 'updatedAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Get favorite notes
  Future<List<Note>> getFavoriteNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'isFavorite = 1 AND isArchived = 0',
      orderBy: 'isPinned DESC, updatedAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Get pinned notes
  Future<List<Note>> getPinnedNotes() async {
    final db = await instance.database;
    final result = await db.query(
      'notes',
      where: 'isPinned = 1 AND isArchived = 0',
      orderBy: 'updatedAt DESC',
    );
    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// OPTIMIZED: Get recent notes (last N days)
  Future<List<Note>> getRecentNotes(int days) async {
    final db = await instance.database;
    final cutoffDate = DateTime.now().subtract(Duration(days: days));

    final result = await db.query(
      'notes',
      where: 'updatedAt >= ? AND isArchived = 0',
      whereArgs: [cutoffDate.toIso8601String()],
      orderBy: 'updatedAt DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Get notes with active reminders (future reminders)
  Future<List<Note>> getNotesWithActiveReminders() async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final result = await db.query(
      'notes',
      where: 'hasReminder = 1 AND reminderDateTime > ?',
      whereArgs: [now],
      orderBy: 'reminderDateTime ASC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Get notes with past reminders
  Future<List<Note>> getNotesWithPastReminders() async {
    final db = await instance.database;
    final now = DateTime.now().toIso8601String();

    final result = await db.query(
      'notes',
      where: 'hasReminder = 1 AND reminderDateTime <= ?',
      whereArgs: [now],
      orderBy: 'reminderDateTime DESC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  /// Get all notes with reminders
  Future<List<Note>> getAllNotesWithReminders() async {
    final db = await instance.database;

    final result = await db.query(
      'notes',
      where: 'hasReminder = 1',
      orderBy: 'reminderDateTime ASC',
    );

    return result.map((map) => Note.fromMap(map)).toList();
  }

  // ============================================================================
  // NOTIFICATION ID MANAGEMENT
  // ============================================================================

  /// Generate unique notification ID using sequential counter
  /// Thread-safe implementation using database transaction
  Future<int> getNextNotificationId() async {
    final db = await instance.database;

    return await db.transaction((txn) async {
      // Get current counter value
      final result = await txn.query(
        'notification_counter',
        where: 'id = ?',
        whereArgs: [1],
      );

      if (result.isEmpty) {
        // Initialize if not exists (shouldn't happen, but defensive)
        await txn.insert('notification_counter', {'id': 1, 'next_id': 1});
        return 1;
      }

      final currentId = result.first['next_id'] as int;
      final nextId = currentId + 1;

      // Update counter atomically
      await txn.update(
        'notification_counter',
        {'next_id': nextId},
        where: 'id = ?',
        whereArgs: [1],
      );

      return currentId;
    });
  }

  // ============================================================================
  // STATISTICS (OPTIMIZED)
  // ============================================================================

  /// OPTIMIZED: Get all statistics in a single batch
  Future<Map<String, int>> getStatistics() async {
    final db = await instance.database;

    // Use single transaction for all queries
    final results = await db.transaction((txn) async {
      final total = await txn.rawQuery('SELECT COUNT(*) as count FROM notes');
      final archived = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isArchived = 1',
      );
      final favorite = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isFavorite = 1',
      );
      final pinned = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isPinned = 1',
      );

      return {
        'total': Sqflite.firstIntValue(total) ?? 0,
        'archived': Sqflite.firstIntValue(archived) ?? 0,
        'favorites': Sqflite.firstIntValue(favorite) ?? 0,
        'pinned': Sqflite.firstIntValue(pinned) ?? 0,
      };
    });

    return results;
  }

  /// Get detailed statistics
  Future<Map<String, dynamic>> getDetailedStatistics() async {
    final db = await instance.database;

    final results = await db.transaction((txn) async {
      // Basic counts
      final total = await txn.rawQuery('SELECT COUNT(*) as count FROM notes');
      final archived = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isArchived = 1',
      );
      final favorite = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isFavorite = 1',
      );
      final pinned = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE isPinned = 1',
      );

      // Category count
      final categoryCount = await txn.rawQuery(
        'SELECT COUNT(DISTINCT category) as count FROM notes WHERE category IS NOT NULL AND category != ""',
      );

      // Average notes per category
      final avgNotesPerCategory = await txn.rawQuery('''
        SELECT AVG(note_count) as avg FROM (
          SELECT COUNT(*) as note_count 
          FROM notes 
          WHERE category IS NOT NULL AND category != ""
          GROUP BY category
        )
      ''');

      return {
        'total': Sqflite.firstIntValue(total) ?? 0,
        'archived': Sqflite.firstIntValue(archived) ?? 0,
        'favorites': Sqflite.firstIntValue(favorite) ?? 0,
        'pinned': Sqflite.firstIntValue(pinned) ?? 0,
        'categories': Sqflite.firstIntValue(categoryCount) ?? 0,
        'avgNotesPerCategory':
            (avgNotesPerCategory.first['avg'] as num?)?.toDouble() ?? 0.0,
      };
    });

    return results;
  }

  // ============================================================================
  // MAINTENANCE
  // ============================================================================

  /// OPTIMIZED: Vacuum database to reclaim space and optimize
  Future<void> vacuum() async {
    final db = await instance.database;
    await db.execute('VACUUM');
  }

  /// Analyze database for query optimization
  Future<void> analyze() async {
    final db = await instance.database;
    await db.execute('ANALYZE');
  }

  /// Get database size
  Future<int> getDatabaseSize() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'notes.db');
    final file = File(path);

    if (await file.exists()) {
      return await file.length();
    }
    return 0;
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}
