import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

const _classic = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

Future<void> _pumpGame(WidgetTester tester, GameState state) async {
  await tester.pumpWidget(
    ChangeNotifierProvider<GameState>.value(
      value: state,
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const GameScreen(),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('提示出现前后棋盘高度不变', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);
    final before = tester.getSize(find.byType(SudokuGrid));
    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();
    final after = tester.getSize(find.byType(SudokuGrid));
    expect(after, before);
    expect(find.text('应用删除').evaluate().isNotEmpty || find.text('应用本步').evaluate().isNotEmpty || find.text('应用').evaluate().isNotEmpty, isTrue);
  });
}
