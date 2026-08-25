import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';
import 'package:sudoku_app/theme/app_theme.dart';

const _classic = '530070000'
    '600195000'
    '098000060'
    '800060003'
    '400803001'
    '700020006'
    '060000280'
    '000419005'
    '000080079';

void main() {
  test('提示解释使用 rXcY 而不写第x行第x列', () {
    final state = GameState()..loadCustomGame(_classic);
    final hint = SudokuSolver.getHint(state.board!);
    expect(hint, isNotNull);
    expect(hint!.explanation, isNot(contains(RegExp(r'第\s*\d+\s*行第'))));
    expect(hint.explanation, isNot(contains(RegExp(r'格子 \('))));
    expect(hint.explanation, contains(RegExp(r'r\d+c\d+')));
  });

  testWidgets('提示抽屉结论行是填/删记号', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = GameState()..loadCustomGame(_classic);
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
    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();

    final hasFill = find.textContaining('填 r').evaluate().isNotEmpty;
    final hasElim = find.textContaining('删 ').evaluate().isNotEmpty;
    expect(hasFill || hasElim, isTrue);
    expect(find.textContaining('位置：第'), findsNothing);
    expect(find.text('技巧定义'), findsOneWidget);
    expect(find.textContaining('Naked Single'), findsOneWidget);
  });
}
