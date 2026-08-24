import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'screens/main_shell.dart';
import 'models/game_state.dart';
import 'theme/theme_controller.dart';

void main() {
  runApp(const SudokuApp());
}

class SudokuApp extends StatelessWidget {
  const SudokuApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GameState()),
        ChangeNotifierProvider(create: (_) {
          final c = ThemeController();
          c.load();
          return c;
        }),
      ],
      child: Consumer<ThemeController>(
        builder: (_, theme, __) => MaterialApp(
          title: '数独游戏',
          theme: theme.light,
          darkTheme: theme.dark,
          themeMode: ThemeMode.system,
          home: const MainShell(),
          debugShowCheckedModeBanner: false,
        ),
      ),
    );
  }
}
