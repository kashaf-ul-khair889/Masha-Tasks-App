import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

/// SQLite layer: tables `tasks` and `subtasks` (1-to-many).
class DatabaseHelper {
  DatabaseHelper._();
  static final DatabaseHelper instance = DatabaseHelper._();
  Database? _db;

  Future<Database> get db async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), 'masha_tasks.db');
    return openDatabase(
      path,
      version: 1,
      onConfigure: (d) async => d.execute('PRAGMA foreign_keys = ON'),
      onCreate: (d, v) async {
        await d.execute('''
          CREATE TABLE tasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            description TEXT,
            dueDate TEXT NOT NULL,
            repeatType TEXT NOT NULL DEFAULT 'none',
            repeatDays TEXT,
            completed INTEGER NOT NULL DEFAULT 0,
            completedDate TEXT,
            lastReset TEXT,
            reminderBefore INTEGER NOT NULL DEFAULT 0
          )''');
        await d.execute('''
          CREATE TABLE subtasks(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            taskId INTEGER NOT NULL,
            title TEXT NOT NULL,
            done INTEGER NOT NULL DEFAULT 0,
            FOREIGN KEY(taskId) REFERENCES tasks(id) ON DELETE CASCADE
          )''');
      },
    );
  }

  Future<void> _insertSubs(DatabaseExecutor e, int taskId, List<SubTask> subs) async {
    for (final s in subs) {
      await e.insert('subtasks', {'taskId': taskId, 'title': s.title, 'done': s.done ? 1 : 0});
    }
  }

  Future<int> insertTask(Task t) async {
    final d = await db;
    return d.transaction((txn) async {
      final map = t.toMap()..remove('id');
      final id = await txn.insert('tasks', map);
      await _insertSubs(txn, id, t.subtasks);
      return id;
    });
  }

  Future<void> updateTask(Task t) async {
    final d = await db;
    await d.transaction((txn) async {
      await txn.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
      await txn.delete('subtasks', where: 'taskId = ?', whereArgs: [t.id]);
      await _insertSubs(txn, t.id!, t.subtasks);
    });
  }

  Future<void> deleteTask(int id) async {
    final d = await db;
    await d.delete('subtasks', where: 'taskId = ?', whereArgs: [id]);
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasks() async {
    final d = await db;
    final rows = await d.query('tasks', orderBy: 'dueDate ASC');
    final result = <Task>[];
    for (final r in rows) {
      final subRows = await d.query('subtasks', where: 'taskId = ?', whereArgs: [r['id']], orderBy: 'id ASC');
      final subs = subRows
          .map((s) => SubTask(id: s['id'] as int, title: s['title'] as String, done: (s['done'] as int) == 1))
          .toList();
      result.add(Task.fromMap(r, subs));
    }
    return result;
  }
}
