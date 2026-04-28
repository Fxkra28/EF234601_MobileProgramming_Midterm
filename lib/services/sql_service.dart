import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import '../models/category_model.dart';
import '../models/task_model.dart';

class SqlService {
  static final SqlService instance = SqlService._();
  SqlService._();

  Database? _db;

  Future<Database> get db async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final path = p.join(await getDatabasesPath(), 'ets1.db');
    return openDatabase(
      path,
      version: 2,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tasks ADD COLUMN locationName TEXT');
    }
  }

  Future<void> _onCreate(Database db, int version) async {
    final batch = db.batch();
    batch.execute('''
      CREATE TABLE categories (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        remoteId   TEXT,
        userId     TEXT NOT NULL,
        name       TEXT NOT NULL,
        colorHex   INTEGER NOT NULL,
        createdAt  INTEGER NOT NULL,
        updatedAt  INTEGER NOT NULL
      )
    ''');
    batch.execute('''
      CREATE TABLE tasks (
        id              INTEGER PRIMARY KEY AUTOINCREMENT,
        remoteId        TEXT,
        userId          TEXT NOT NULL,
        categoryId      INTEGER NOT NULL,
        title           TEXT NOT NULL,
        description     TEXT NOT NULL DEFAULT '',
        date            INTEGER NOT NULL,
        startTime       INTEGER,
        endTime         INTEGER,
        isCompleted     INTEGER NOT NULL DEFAULT 0,
        localImagePath  TEXT,
        remoteImageUrl  TEXT,
        imageStoragePath TEXT,
        latitude        REAL,
        longitude       REAL,
        locationName    TEXT,
        reminderEnabled INTEGER NOT NULL DEFAULT 0,
        notificationId  INTEGER,
        syncStatus      TEXT NOT NULL DEFAULT 'pending',
        createdAt       INTEGER NOT NULL,
        updatedAt       INTEGER NOT NULL,
        FOREIGN KEY (categoryId) REFERENCES categories(id) ON DELETE RESTRICT
      )
    ''');
    batch.execute('''
      CREATE TABLE messages (
        id          INTEGER PRIMARY KEY AUTOINCREMENT,
        userId      TEXT NOT NULL,
        title       TEXT NOT NULL,
        body        TEXT NOT NULL DEFAULT '',
        payload     TEXT,
        source      TEXT NOT NULL,
        receivedAt  INTEGER NOT NULL,
        readAt      INTEGER
      )
    ''');
    batch.execute(
        'CREATE UNIQUE INDEX idx_categories_remote ON categories(remoteId) WHERE remoteId IS NOT NULL');
    batch.execute(
        'CREATE UNIQUE INDEX idx_tasks_remote ON tasks(remoteId) WHERE remoteId IS NOT NULL');
    batch.execute('CREATE INDEX idx_tasks_user_date ON tasks(userId, date)');
    batch.execute('CREATE INDEX idx_tasks_category ON tasks(categoryId)');
    batch.execute(
        'CREATE INDEX idx_categories_user ON categories(userId)');
    batch.execute(
        'CREATE INDEX idx_messages_user_read ON messages(userId, readAt)');
    await batch.commit(noResult: true);
  }

  // ─── Categories ────────────────────────────────────────────────

  Future<int> insertCategory(Category c) async {
    final database = await db;
    return database.insert('categories', c.toMap()..remove('id'));
  }

  Future<int> updateCategory(Category c) async {
    final database = await db;
    return database.update(
      'categories',
      c.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [c.id],
    );
  }

  /// Throws [StateError] if any task references the category.
  Future<int> deleteCategory(int id) async {
    final database = await db;
    final inUse = Sqflite.firstIntValue(await database.rawQuery(
      'SELECT COUNT(*) FROM tasks WHERE categoryId = ?',
      [id],
    ));
    if ((inUse ?? 0) > 0) {
      throw StateError(
          'Cannot delete category: $inUse task(s) still reference it.');
    }
    return database.delete('categories', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Category>> categoriesForUser(String userId) async {
    final database = await db;
    final rows = await database.query(
      'categories',
      where: 'userId = ?',
      whereArgs: [userId],
      orderBy: 'name ASC',
    );
    return rows.map(Category.fromMap).toList();
  }

  Future<List<Map<String, Object?>>> categoriesWithCount(String userId) async {
    final database = await db;
    return database.rawQuery('''
      SELECT c.id, c.name, c.colorHex, COUNT(t.id) AS taskCount
      FROM categories c
      LEFT JOIN tasks t ON t.categoryId = c.id
      WHERE c.userId = ?
      GROUP BY c.id, c.name, c.colorHex
      ORDER BY c.name
    ''', [userId]);
  }

  Future<Category?> categoryById(int id) async {
    final database = await db;
    final rows =
        await database.query('categories', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<Category?> categoryByRemoteId(String remoteId) async {
    final database = await db;
    final rows = await database
        .query('categories', where: 'remoteId = ?', whereArgs: [remoteId]);
    if (rows.isEmpty) return null;
    return Category.fromMap(rows.first);
  }

  Future<void> seedCategoriesIfEmpty(String userId) async {
    final existing = await categoriesForUser(userId);
    if (existing.isNotEmpty) return;
    final now = DateTime.now();
    await insertCategory(Category(
      userId: userId,
      name: 'Work',
      colorHex: 0xFF4A90E2,
      createdAt: now,
      updatedAt: now,
    ));
    await insertCategory(Category(
      userId: userId,
      name: 'Personal',
      colorHex: 0xFF50C878,
      createdAt: now,
      updatedAt: now,
    ));
    await insertCategory(Category(
      userId: userId,
      name: 'Errands',
      colorHex: 0xFFFF8C42,
      createdAt: now,
      updatedAt: now,
    ));
  }

  // ─── Tasks ─────────────────────────────────────────────────────

  Future<int> insertTask(Task t) async {
    final database = await db;
    return database.insert('tasks', t.toMap()..remove('id'));
  }

  Future<int> updateTask(Task t) async {
    final database = await db;
    return database.update(
      'tasks',
      t.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [t.id],
    );
  }

  Future<int> deleteTask(int id) async {
    final database = await db;
    return database.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  /// JOIN proof — pulls tasks for a single date with their category info.
  Future<List<Map<String, Object?>>> tasksByDate(
      String userId, DateTime date) async {
    final database = await db;
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));
    return database.rawQuery('''
      SELECT t.*, c.name AS categoryName, c.colorHex AS categoryColor
      FROM tasks t
      INNER JOIN categories c ON t.categoryId = c.id
      WHERE t.userId = ?
        AND t.date >= ?
        AND t.date <  ?
      ORDER BY COALESCE(t.startTime, t.date) ASC
    ''', [userId, start.millisecondsSinceEpoch, end.millisecondsSinceEpoch]);
  }

  Future<List<Task>> allTasksForUser(String userId) async {
    final database = await db;
    final rows = await database
        .query('tasks', where: 'userId = ?', whereArgs: [userId]);
    return rows.map(Task.fromMap).toList();
  }

  Future<Set<DateTime>> datesWithTasks(String userId) async {
    final database = await db;
    final rows = await database.rawQuery(
      'SELECT DISTINCT date FROM tasks WHERE userId = ?',
      [userId],
    );
    return rows.map((r) {
      final ms = r['date'] as int;
      final d = DateTime.fromMillisecondsSinceEpoch(ms);
      return DateTime(d.year, d.month, d.day);
    }).toSet();
  }

  Future<List<Task>> pendingSyncTasks(String userId) async {
    final database = await db;
    final rows = await database.query('tasks',
        where: 'userId = ? AND syncStatus = ?',
        whereArgs: [userId, 'pending']);
    return rows.map(Task.fromMap).toList();
  }

  Future<Task?> taskById(int id) async {
    final database = await db;
    final rows =
        await database.query('tasks', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<Task?> taskByRemoteId(String remoteId) async {
    final database = await db;
    final rows = await database
        .query('tasks', where: 'remoteId = ?', whereArgs: [remoteId]);
    if (rows.isEmpty) return null;
    return Task.fromMap(rows.first);
  }

  Future<List<Task>> tasksWithReminders(String userId) async {
    final database = await db;
    final rows = await database.query(
      'tasks',
      where: 'userId = ? AND reminderEnabled = 1 AND startTime IS NOT NULL',
      whereArgs: [userId],
    );
    return rows.map(Task.fromMap).toList();
  }

  // ─── Messages (notification inbox) ─────────────────────────────

  Future<int> insertMessage({
    required String userId,
    required String title,
    required String body,
    String? payload,
    required String source,
  }) async {
    final database = await db;
    return database.insert('messages', {
      'userId': userId,
      'title': title,
      'body': body,
      'payload': payload,
      'source': source,
      'receivedAt': DateTime.now().millisecondsSinceEpoch,
      'readAt': null,
    });
  }

  Future<List<Map<String, Object?>>> messagesForUser(String userId) async {
    final database = await db;
    return database.query('messages',
        where: 'userId = ?',
        whereArgs: [userId],
        orderBy: 'receivedAt DESC');
  }

  Future<int> markMessageRead(int id) async {
    final database = await db;
    return database.update(
      'messages',
      {'readAt': DateTime.now().millisecondsSinceEpoch},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> unreadMessageCount(String userId) async {
    final database = await db;
    return Sqflite.firstIntValue(await database.rawQuery(
          'SELECT COUNT(*) FROM messages WHERE userId = ? AND readAt IS NULL',
          [userId],
        )) ??
        0;
  }

  // ─── Lifecycle ─────────────────────────────────────────────────

  Future<void> wipeUser(String userId) async {
    final database = await db;
    await database
        .delete('tasks', where: 'userId = ?', whereArgs: [userId]);
    await database
        .delete('categories', where: 'userId = ?', whereArgs: [userId]);
    await database
        .delete('messages', where: 'userId = ?', whereArgs: [userId]);
  }
}
