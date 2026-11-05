import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../db/database_helper.dart';
import '../models/task.dart';
import '../services/notification_service.dart';

/// Holds tasks + settings. UI listens via ListenableBuilder.
class AppState extends ChangeNotifier {
  final _db = DatabaseHelper.instance;
  late SharedPreferences _prefs;

  List<Task> tasks = [];
  ThemeMode themeMode = ThemeMode.light;
  String sound = 'default';

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    themeMode = ThemeMode.values[_prefs.getInt('theme') ?? 1]; // 0 system,1 light,2 dark
    sound = _prefs.getString('sound') ?? 'default';
    await refresh();
  }

  /// Reload from DB and auto-reset repeating tasks on a new day.
  Future<void> refresh() async {
    final list = await _db.getTasks();
    final today = dateKey(DateTime.now());
    for (final t in list) {
      if (t.isRepeating && t.lastReset != today) {
        if (t.completedDate != today) t.completedDate = null;
        for (final s in t.subtasks) {
          s.done = false;
        }
        t.lastReset = today;
        await _db.updateTask(t);
      }
    }
    tasks = list;
    notifyListeners();
  }

  // ---- Views ----
  DateTime _sortKey(Task t) {
    if (!t.isRepeating) return t.dueDate;
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day, t.dueDate.hour, t.dueDate.minute);
  }

  List<Task> get todayTasks {
    final now = DateTime.now();
    final today = dateOnly(now);
    final l = tasks.where((t) {
      if (t.isRepeating) return t.occursOn(now) && !t.isDoneOn(now);
      return !t.completed && !dateOnly(t.dueDate).isAfter(today); // today + overdue
    }).toList();
    l.sort((a, b) => _sortKey(a).compareTo(_sortKey(b)));
    return l;
  }

  List<Task> get completedTasks {
    final now = DateTime.now();
    return tasks.where((t) => t.isDoneOn(now)).toList();
  }

  List<Task> get repeatedTasks => tasks.where((t) => t.isRepeating).toList();

  // ---- CRUD ----
  Future<void> addTask(Task t) async {
    t.lastReset = dateKey(DateTime.now());
    t.id = await _db.insertTask(t);
    await NotificationService.showAdded(t, sound); // instant "task added" notification
    await NotificationService.schedule(t, sound); // reminder(s)
    await refresh();
  }

  Future<void> updateTask(Task t) async {
    await _db.updateTask(t);
    await NotificationService.schedule(t, sound);
    await refresh();
  }

  Future<void> deleteTask(Task t) async {
    await NotificationService.cancelTask(t);
    await _db.deleteTask(t.id!);
    await refresh();
  }

  Future<void> toggleComplete(Task t) async {
    final now = DateTime.now();
    if (t.isRepeating) {
      t.completedDate = t.isDoneOn(now) ? null : dateKey(now);
    } else {
      t.completed = !t.completed;
    }
    await updateTask(t); // reschedules / cancels notifications
  }

  Future<void> toggleSubtask(Task t, SubTask s) async {
    s.done = !s.done;
    final allDone = t.subtasks.every((x) => x.done);
    if (allDone && !t.isDoneOn(DateTime.now())) {
      if (t.isRepeating) {
        t.completedDate = dateKey(DateTime.now());
      } else {
        t.completed = true;
      }
    }
    await updateTask(t);
  }

  // ---- Settings ----
  Future<void> setTheme(ThemeMode m) async {
    themeMode = m;
    await _prefs.setInt('theme', m.index);
    notifyListeners();
  }

  Future<void> setSound(String s) async {
    sound = s;
    await _prefs.setString('sound', s);
    for (final t in tasks) {
      await NotificationService.schedule(t, sound);
    }
    notifyListeners();
  }
}
