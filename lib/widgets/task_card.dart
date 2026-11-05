import 'package:flutter/material.dart';
import '../models/task.dart';
import '../providers/app_state.dart';

class TaskCard extends StatelessWidget {
  final Task task;
  final AppState state;
  final VoidCallback onEdit;
  const TaskCard({super.key, required this.task, required this.state, required this.onEdit});

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete task?'),
        content: Text('"${task.title}" will be removed.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok == true) state.deleteTask(task);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final done = task.isDoneOn(DateTime.now());
    final overdue = !task.isRepeating && !done && task.dueDate.isBefore(DateTime.now());
    final pct = (task.progress * 100).round();

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.primary.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          children: [
            ListTile(
              leading: Checkbox(
                value: done,
                shape: const CircleBorder(),
                onChanged: (_) => state.toggleComplete(task),
              ),
              title: Text(
                task.title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  decoration: done ? TextDecoration.lineThrough : null,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (task.description.isNotEmpty) Text(task.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 6,
                    children: [
                      Chip(
                        visualDensity: VisualDensity.compact,
                        avatar: Icon(task.isRepeating ? Icons.repeat : Icons.schedule, size: 16),
                        label: Text(task.whenLabel, style: const TextStyle(fontSize: 12)),
                        backgroundColor: overdue ? cs.errorContainer : null,
                      ),
                      if (task.reminderBefore > 0)
                        Chip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(Icons.notifications_active, size: 16),
                          label: Text('${task.reminderBefore} min before', style: const TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                ],
              ),
              trailing: PopupMenuButton<String>(
                onSelected: (v) => v == 'edit' ? onEdit() : _confirmDelete(context),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Edit')),
                  PopupMenuItem(value: 'delete', child: Text('Delete')),
                ],
              ),
            ),
            if (task.subtasks.isNotEmpty) ...[
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: LinearProgressIndicator(value: task.progress, minHeight: 8, color: cs.secondary),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text('$pct%', style: const TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              for (final s in task.subtasks)
                CheckboxListTile(
                  dense: true,
                  visualDensity: VisualDensity.compact,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: s.done,
                  title: Text(s.title,
                      style: TextStyle(decoration: s.done ? TextDecoration.lineThrough : null)),
                  onChanged: (_) => state.toggleSubtask(task, s),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
