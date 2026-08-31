import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app_orientation.dart';
import 'screens/main_shell.dart';
import 'models/game_state.dart';
import 'theme/theme_controller.dart';
import 'widgets/phone_frame.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppOrientation.lockPortrait();
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final game = GameState();
          game.restoreCurrent();
          return game;
        }),
        ChangeNotifierProvider(create: (_) {
          final c = ThemeController();
          c.load();
          return c;
        }),
      ],
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          title: '我的数独',
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: ThemeMode.system,
          builder: (context, child) => PhoneFrame(
            child: child ?? const SizedBox.shrink(),
          ),
          home: const MainShell(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
