const _months = ['Jan','Feb','Mar','Apr','May','Jun','Jul','Aug','Sep','Oct','Nov','Dec'];
const dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']; // weekday 1..7

String _two(int n) => n.toString().padLeft(2, '0');
String dateKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';
DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
String fmtDate(DateTime d) => '${d.day} ${_months[d.month - 1]} ${d.year}';
String fmtTime(DateTime d) {
  final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$h:${_two(d.minute)} ${d.hour >= 12 ? 'PM' : 'AM'}';
}

class SubTask {
  int? id;
  String title;
  bool done;
  SubTask({this.id, required this.title, this.done = false});
}

class Task {
  int? id;
  String title;
  String description;
  DateTime dueDate; // date + time
  String repeatType; // none | daily | weekly
  List<int> repeatDays; // 1=Mon .. 7=Sun (weekly)
  bool completed; // used by non-repeating tasks
  String? completedDate; // used by repeating tasks (done for that day)
  String? lastReset;
  int reminderBefore; // minutes before due time (0 = none)
  List<SubTask> subtasks;

  Task({
    this.id,
    required this.title,
    this.description = '',
    required this.dueDate,
    this.repeatType = 'none',
    List<int>? repeatDays,
    this.completed = false,
    this.completedDate,
    this.lastReset,
    this.reminderBefore = 0,
    List<SubTask>? subtasks,
  })  : repeatDays = repeatDays ?? [],
        subtasks = subtasks ?? [];

  bool get isRepeating => repeatType != 'none';

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'title': title,
        'description': description,
        'dueDate': dueDate.toIso8601String(),
        'repeatType': repeatType,
        'repeatDays': repeatDays.join(','),
        'completed': completed ? 1 : 0,
        'completedDate': completedDate,
        'lastReset': lastReset,
        'reminderBefore': reminderBefore,
      };

  factory Task.fromMap(Map<String, dynamic> m, List<SubTask> subs) {
    final days = (m['repeatDays'] as String? ?? '');
    return Task(
      id: m['id'] as int,
      title: m['title'] as String,
      description: m['description'] as String? ?? '',
      dueDate: DateTime.parse(m['dueDate'] as String),
      repeatType: m['repeatType'] as String? ?? 'none',
      repeatDays: days.isEmpty ? [] : days.split(',').map(int.parse).toList(),
      completed: (m['completed'] as int? ?? 0) == 1,
      completedDate: m['completedDate'] as String?,
      lastReset: m['lastReset'] as String?,
      reminderBefore: m['reminderBefore'] as int? ?? 0,
      subtasks: subs,
    );
  }

  bool isDoneOn(DateTime day) =>
      isRepeating ? completedDate == dateKey(day) : completed;

  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final start = dateOnly(dueDate);
    if (!isRepeating) return d == start;
    if (d.isBefore(start)) return false;
    if (repeatType == 'daily') return true;
    return repeatDays.contains(d.weekday);
  }

  double get progress {
    if (subtasks.isNotEmpty) {
      return subtasks.where((s) => s.done).length / subtasks.length;
    }
    return isDoneOn(DateTime.now()) ? 1.0 : 0.0;
  }

  String get repeatLabel {
    if (repeatType == 'daily') return 'Every day';
    if (repeatType == 'weekly') {
      final d = [...repeatDays]..sort();
      return d.map((e) => dayNames[e - 1]).join(', ');
    }
    return 'Once';
  }

  String get whenLabel => isRepeating
      ? '$repeatLabel • ${fmtTime(dueDate)}'
      : '${fmtDate(dueDate)} • ${fmtTime(dueDate)}';
}
