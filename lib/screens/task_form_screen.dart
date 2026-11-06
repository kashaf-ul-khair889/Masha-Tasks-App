import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

/// Add / Edit task. Pass [task] to edit.
class TaskFormScreen extends StatefulWidget {
  final AppState state;
  final Task? task;
  const TaskFormScreen({super.key, required this.state, this.task});

  @override
  State<TaskFormScreen> createState() => _TaskFormScreenState();
}

class _TaskFormScreenState extends State<TaskFormScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _desc;
  final _subCtrl = TextEditingController();
  late DateTime _due;
  String _repeat = 'none';
  Set<int> _days = {};
  int _before = 0;
  List<SubTask> _subs = [];

  bool get _editing => widget.task != null;

  @override
  void initState() {
    super.initState();
    final t = widget.task;
    _title = TextEditingController(text: t?.title ?? '');
    _desc = TextEditingController(text: t?.description ?? '');
    _due = t?.dueDate ?? DateTime.now().add(const Duration(hours: 1));
    _repeat = t?.repeatType ?? 'none';
    _days = {...?t?.repeatDays};
    _before = t?.reminderBefore ?? 0;
    _subs = t == null
        ? []
        : t.subtasks.map((s) => SubTask(title: s.title, done: s.done)).toList();
  }

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    _subCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _due,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _due = DateTime(d.year, d.month, d.day, _due.hour, _due.minute));
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_due));
    if (t != null) setState(() => _due = DateTime(_due.year, _due.month, _due.day, t.hour, t.minute));
  }

  void _addSub() {
    final txt = _subCtrl.text.trim();
    if (txt.isEmpty) return;
    setState(() {
      _subs.add(SubTask(title: txt));
      _subCtrl.clear();
    });
  }

  Future<void> _save() async {
    if (kIsWeb) NotificationService.requestPermissions(); // Chrome asks permission on click
    if (!_form.currentState!.validate()) return;
    if (_repeat == 'weekly' && _days.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Select at least one day for weekly repeat')));
      return;
    }
    _addSub(); // include text left in the subtask box
    final old = widget.task;
    final task = Task(
      id: old?.id,
      title: _title.text.trim(),
      description: _desc.text.trim(),
      dueDate: _due,
      repeatType: _repeat,
      repeatDays: _repeat == 'weekly' ? (_days.toList()..sort()) : [],
      completed: old?.completed ?? false,
      completedDate: old?.completedDate,
      lastReset: old?.lastReset,
      reminderBefore: _before,
      subtasks: _subs,
    );
    if (_editing) {
      await widget.state.updateTask(task);
    } else {
      await widget.state.addTask(task);
    }
    if (!_editing && kIsWeb && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('🍯 Task added! ${task.title} — ${task.whenLabel}')));
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Edit Task' : 'New Task')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *', prefixIcon: Icon(Icons.title)),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Title is required' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              maxLines: 3,
              decoration: const InputDecoration(labelText: 'Description', prefixIcon: Icon(Icons.notes)),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text(fmtDate(_due)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time),
                    label: Text(fmtTime(_due)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _repeat,
              decoration: const InputDecoration(labelText: 'Repeat', prefixIcon: Icon(Icons.repeat)),
              items: const [
                DropdownMenuItem(value: 'none', child: Text('Does not repeat')),
                DropdownMenuItem(value: 'daily', child: Text('Every day')),
                DropdownMenuItem(value: 'weekly', child: Text('Selected days of the week')),
              ],
              onChanged: (v) => setState(() => _repeat = v!),
            ),
            if (_repeat == 'weekly')
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Wrap(
                  spacing: 6,
                  children: [
                    for (var i = 1; i <= 7; i++)
                      FilterChip(
                        label: Text(dayNames[i - 1]),
                        selected: _days.contains(i),
                        onSelected: (sel) => setState(() => sel ? _days.add(i) : _days.remove(i)),
                      ),
                  ],
                ),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<int>(
              value: _before,
              decoration: const InputDecoration(
                  labelText: 'Extra reminder', prefixIcon: Icon(Icons.notifications_active)),
              items: const [
                DropdownMenuItem(value: 0, child: Text('Only at due time')),
                DropdownMenuItem(value: 5, child: Text('5 minutes before')),
                DropdownMenuItem(value: 10, child: Text('10 minutes before')),
                DropdownMenuItem(value: 15, child: Text('15 minutes before')),
                DropdownMenuItem(value: 30, child: Text('30 minutes before')),
                DropdownMenuItem(value: 60, child: Text('1 hour before')),
              ],
              onChanged: (v) => setState(() => _before = v!),
            ),
            const SizedBox(height: 20),
            Text('Subtasks (for progress bar)', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _subCtrl,
                    onSubmitted: (_) => _addSub(),
                    decoration: const InputDecoration(hintText: 'Add a subtask', isDense: true),
                  ),
                ),
                IconButton.filled(onPressed: _addSub, icon: const Icon(Icons.add)),
              ],
            ),
            for (var i = 0; i < _subs.length; i++)
              ListTile(
                dense: true,
                leading: const Icon(Icons.subdirectory_arrow_right),
                title: Text(_subs[i].title),
                trailing: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _subs.removeAt(i)),
                ),
              ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: Text(_editing ? 'Update Task' : 'Save Task'),
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            ),
          ],
        ),
      ),
    );
  }
}
