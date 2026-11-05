import 'package:flutter/material.dart';
import 'providers/app_state.dart';
import 'screens/home_screen.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService.init();
  final state = AppState();
  await state.init();
  runApp(MashaTasksApp(state: state));
}

class MashaTasksApp extends StatelessWidget {
  final AppState state;
  const MashaTasksApp({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => MaterialApp(
        title: "Masha's Tasks",
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: state.themeMode,
        home: HomeScreen(state: state),
      ),
    );
  }
}
