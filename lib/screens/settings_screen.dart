import 'package:flutter/material.dart';
import '../providers/app_state.dart';
import '../services/notification_service.dart';

class SettingsScreen extends StatelessWidget {
  final AppState state;
  const SettingsScreen({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: state,
        builder: (context, _) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Theme', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            SegmentedButton<ThemeMode>(
              segments: const [
                ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Light')),
                ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Dark')),
                ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.phone_android), label: Text('System')),
              ],
              selected: {state.themeMode},
              onSelectionChanged: (s) => state.setTheme(s.first),
            ),
            const SizedBox(height: 24),
            Text('Notification sound', style: Theme.of(context).textTheme.titleLarge),
            RadioGroup<String>(
              groupValue: state.sound,
              onChanged: (v) => state.setSound(v!),
              child: Column(
                children: [
                  for (final e in NotificationService.soundOptions.entries)
                    RadioListTile<String>(
                      value: e.key,
                      title: Text(e.value),
                      secondary: IconButton(
                        icon: const Icon(Icons.play_circle),
                        tooltip: 'Test sound',
                        onPressed: () => NotificationService.showNow(
                            999999, '🔊 Test', 'This is the "${e.value}" sound', e.key),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: NotificationService.requestPermissions,
              icon: const Icon(Icons.notifications),
              label: const Text('Allow notifications / alarms'),
            ),
          ],
        ),
      ),
    );
  }
}
