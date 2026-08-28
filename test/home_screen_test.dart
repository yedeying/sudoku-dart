import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/home_screen.dart';
import 'package:sudoku_app/theme/theme_controller.dart';

const _classic =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('首页六级只有名称，没有过时的技巧说明', (tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => GameState()),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('入门'), findsOneWidget);
    expect(find.text('普通'), findsOneWidget);
    expect(find.text('进阶'), findsOneWidget);
    expect(find.text('专业'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('地狱'), 80);
    expect(find.text('大师'), findsOneWidget);
    expect(find.text('地狱'), findsOneWidget);
    expect(find.textContaining('XY-Wing'), findsNothing);
    expect(find.textContaining('只需基础'), findsNothing);
    expect(find.text('继续题目'), findsNothing);
  });

  testWidgets('有未完成的当前题时显示继续', (tester) async {
    final game = GameState()..loadCustomGame(_classic);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: game),
          ChangeNotifierProvider(create: (_) => ThemeController()),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pump();

    expect(find.text('继续题目'), findsOneWidget);
    expect(find.text('自定义'), findsWidgets);
  });
}
