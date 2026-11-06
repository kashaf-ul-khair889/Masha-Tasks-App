import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path/path.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite/sqflite.dart';
import '../models/task.dart';

/// Android: SQLite (tables `tasks` + `subtasks`).
/// Chrome/Web: browser storage (same Task model), because sqflite does not run in browsers.
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

  // ---------------- web storage ----------------
  static const _kTasks = 'web_tasks';
  static const _kNext = 'web_next_id';

  Future<List<Task>> _webLoad() async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(_kTasks);
    if (raw == null) return [];
    final list = jsonDecode(raw) as List;
    return list.map((e) {
      final m = Map<String, dynamic>.from(e['task'] as Map);
      final subs = (e['subs'] as List)
          .map((s) => SubTask(id: s['id'] as int?, title: s['title'] as String, done: s['done'] as bool))
          .toList();
      return Task.fromMap(m, subs);
    }).toList();
  }

  Future<void> _webSave(List<Task> tasks) async {
    final p = await SharedPreferences.getInstance();
    final data = tasks
        .map((t) => {
              'task': t.toMap(),
              'subs': t.subtasks.map((s) => {'id': s.id, 'title': s.title, 'done': s.done}).toList(),
            })
        .toList();
    await p.setString(_kTasks, jsonEncode(data));
  }

  // ---------------- SQLite helpers ----------------
  Future<void> _insertSubs(DatabaseExecutor e, int taskId, List<SubTask> subs) async {
    for (final s in subs) {
      await e.insert('subtasks', {'taskId': taskId, 'title': s.title, 'done': s.done ? 1 : 0});
    }
  }

  // ---------------- public API ----------------
  Future<int> insertTask(Task t) async {
    if (kIsWeb) {
      final p = await SharedPreferences.getInstance();
      final id = p.getInt(_kNext) ?? 1;
      await p.setInt(_kNext, id + 1);
      t.id = id;
      final list = await _webLoad();
      list.add(t);
      await _webSave(list);
      return id;
    }
    final d = await db;
    return d.transaction((txn) async {
      final map = t.toMap()..remove('id');
      final id = await txn.insert('tasks', map);
      await _insertSubs(txn, id, t.subtasks);
      return id;
    });
  }

  Future<void> updateTask(Task t) async {
    if (kIsWeb) {
      final list = await _webLoad();
      final i = list.indexWhere((x) => x.id == t.id);
      if (i >= 0) list[i] = t;
      await _webSave(list);
      return;
    }
    final d = await db;
    await d.transaction((txn) async {
      await txn.update('tasks', t.toMap(), where: 'id = ?', whereArgs: [t.id]);
      await txn.delete('subtasks', where: 'taskId = ?', whereArgs: [t.id]);
      await _insertSubs(txn, t.id!, t.subtasks);
    });
  }

  Future<void> deleteTask(int id) async {
    if (kIsWeb) {
      final list = await _webLoad();
      list.removeWhere((x) => x.id == id);
      await _webSave(list);
      return;
    }
    final d = await db;
    await d.delete('subtasks', where: 'taskId = ?', whereArgs: [id]);
    await d.delete('tasks', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<Task>> getTasks() async {
    if (kIsWeb) {
      final list = await _webLoad();
      list.sort((a, b) => a.dueDate.compareTo(b.dueDate));
      return list;
    }
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
