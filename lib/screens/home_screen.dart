import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../models/task.dart';
import '../providers/app_state.dart';
import '../services/export_service.dart';
import '../services/notification_service.dart';
import '../services/download_stub.dart' if (dart.library.js_interop) '../services/download_web.dart';
import '../widgets/masha_header.dart';
import '../widgets/task_card.dart';
import 'settings_screen.dart';
import 'task_form_screen.dart';

class HomeScreen extends StatefulWidget {
  final AppState state;
  const HomeScreen({super.key, required this.state});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  int _tab = 0;
  Timer? _timer;
  final Set<String> _fired = {};
  AppState get s => widget.state;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => NotificationService.requestPermissions());
    if (kIsWeb) _timer = Timer.periodic(const Duration(seconds: 15), (_) => _checkDue());
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState st) {
    if (st == AppLifecycleState.resumed) s.refresh(); // handles midnight reset
  }

  /// Chrome has no background notifications, so due tasks pop up as an in-app alert.
  void _checkDue() {
    final now = DateTime.now();
    for (final t in s.tasks) {
      if (t.isDoneOn(now) || !t.occursOn(now)) continue;
      final due = DateTime(now.year, now.month, now.day, t.dueDate.hour, t.dueDate.minute);
      final events = <String, DateTime>{'due': due};
      if (t.reminderBefore > 0) events['pre'] = due.subtract(Duration(minutes: t.reminderBefore));
      events.forEach((kind, at) {
        final diff = now.difference(at);
        final key = '${t.id}-${dateKey(now)}-$kind';
        if (!diff.isNegative && diff.inSeconds < 120 && _fired.add(key)) {
          final title = kind == 'due' ? '⏰ Task time!' : '🔔 Reminder: ${t.reminderBefore} min left';
          webNotify(title, '${t.title} - ${t.whenLabel}');
          playWebSound(s.sound);
          showDialog(
            context: context,
            builder: (_) => AlertDialog(
              title: Text(title),
              content: Text('${t.title}\n${t.whenLabel}'),
              actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
            ),
          );
        }
      });
    }
  }

  void _openForm([Task? t]) => Navigator.push(
      context, MaterialPageRoute(builder: (_) => TaskFormScreen(state: s, task: t)));

  Future<void> _export(String type) async {
    if (s.tasks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No tasks to export yet!')));
      return;
    }
    try {
      if (type == 'csv') await ExportService.shareCsv(s.tasks);
      if (type == 'pdf') await ExportService.sharePdf(s.tasks);
      if (type == 'email') await ExportService.shareEmail(s.tasks);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: s,
      builder: (context, _) {
        final lists = [s.todayTasks, s.completedTasks, s.repeatedTasks];
        final titles = ['Today Tasks', 'Completed Tasks', 'Repeated Tasks'];
        final empties = [
          'No tasks for today!\nGo play with the Bear 🐻',
          'Nothing completed yet.\nMasha believes in you!',
          'No repeating tasks.\nAdd one with a repeat setting.',
        ];
        final subs = [
          '${lists[0].length} task(s) to do today',
          '${lists[1].length} task(s) done — well done!',
          '${lists[2].length} repeating task(s)',
        ];
        final list = lists[_tab];
        return Scaffold(
          appBar: AppBar(
            title: Text(titles[_tab]),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.ios_share),
                tooltip: 'Export',
                onSelected: _export,
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'csv', child: Text('Export CSV')),
                  PopupMenuItem(value: 'pdf', child: Text('Export PDF')),
                  PopupMenuItem(value: 'email', child: Text('Send by Email')),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.settings),
                onPressed: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => SettingsScreen(state: s))),
              ),
            ],
          ),
          body: Stack(
            children: [
              Positioned.fill(
                child: Opacity(
                  opacity: 0.16,
                  child: Image.asset('assets/images/bg_forest.jpg',
                      fit: BoxFit.cover, errorBuilder: (_, __, ___) => const SizedBox()),
                ),
              ),
              Column(
                children: [
                  MashaHeader(subtitle: subs[_tab]),
                  Expanded(
                    child: list.isEmpty
                        ? EmptyState(text: empties[_tab])
                        : ListView.builder(
                            padding: const EdgeInsets.only(top: 6, bottom: 90),
                            itemCount: list.length,
                            itemBuilder: (_, i) => TaskCard(
                                task: list[i], state: s, onEdit: () => _openForm(list[i])),
                          ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _openForm(),
            icon: const Icon(Icons.add),
            label: const Text('Add Task'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.today), label: 'Today'),
              NavigationDestination(icon: Icon(Icons.check_circle), label: 'Completed'),
              NavigationDestination(icon: Icon(Icons.repeat), label: 'Repeated'),
            ],
          ),
        );
      },
    );
  }
}
