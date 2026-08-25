import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/screens/home_screen.dart';
import 'package:sudoku_app/theme/theme_controller.dart';

Future<void> _pumpHome(WidgetTester tester, ThemeController theme) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<ThemeController>.value(
      value: theme,
      child: MaterialApp(
        theme: theme.light,
        home: const HomeScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _pumpGame(WidgetTester tester, ThemeController theme) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<GameState>(create: (_) => GameState()),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
      ],
      child: MaterialApp(
        theme: theme.light,
        home: const GameScreen(),
      ),
    ),
  );
  await tester.pump();
}

Future<void> _openAccentPicker(WidgetTester tester) async {
  await tester.tap(find.byTooltip('强调色'));
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('从首页打开强调色选择器后可以看到蓝', (tester) async {
    await _pumpHome(tester, ThemeController());

    await _openAccentPicker(tester);

    expect(find.text('蓝'), findsOneWidget);
    expect(find.text('红'), findsOneWidget);
    expect(find.text('绿'), findsOneWidget);
    expect(find.text('紫'), findsOneWidget);
    expect(find.text('青绿'), findsOneWidget);
    expect(find.text('橙'), findsOneWidget);
    expect(find.text('玫红'), findsOneWidget);
    expect(find.text('靛'), findsOneWidget);
    expect(find.text('天蓝'), findsOneWidget);
    expect(find.text('金'), findsOneWidget);
  });

  testWidgets('点选色块会调用 setAccent', (tester) async {
    final theme = ThemeController();
    await _pumpHome(tester, theme);
    await _openAccentPicker(tester);

    await tester.tap(find.text('玫红'));
    await tester.pumpAndSettle();

    expect(theme.accentId, AccentId.rose);
  });

  testWidgets('对局页 AppBar 也能打开同一选择器', (tester) async {
    await _pumpGame(tester, ThemeController());

    await _openAccentPicker(tester);

    expect(find.text('蓝'), findsOneWidget);
  });
}
