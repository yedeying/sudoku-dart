import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/screens/game_screen.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
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
  testWidgets('提示面板打开后控制键变成应用，可连续点击继续应用', (tester) async {
    tester.view.physicalSize = const Size(1200, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = GameState()..loadCustomGame(_classic);
    await _pumpGame(tester, state);

    expect(find.byIcon(Icons.lightbulb), findsOneWidget);
    expect(find.byIcon(Icons.check), findsNothing);

    await tester.tap(find.byIcon(Icons.lightbulb));
    await tester.pump();

    expect(state.hintSession?.phase, HintPhase.ready);
    expect(find.byIcon(Icons.check), findsOneWidget);
    expect(find.byIcon(Icons.lightbulb), findsNothing);
    expect(find.text('应用'), findsOneWidget);

    Finder drawerApply() {
      final byLabel = find.text('应用本步').evaluate().isNotEmpty
          ? find.text('应用本步')
          : find.text('应用删除');
      return find.ancestor(of: byLabel, matching: find.byType(FilledButton));
    }

    final before = state.hintsUsed;
    await tester.tap(drawerApply());
    await tester.pump();

    expect(state.hintsUsed, before + 1);
    // 应用后立刻给出下一步，抽屉按钮保持可连点。
    expect(state.hintSession?.phase, HintPhase.ready);

    await tester.tap(drawerApply());
    await tester.pump();

    expect(state.hintsUsed, before + 2);
    expect(state.hintSession?.phase, HintPhase.ready);
    expect(find.text('应用'), findsOneWidget);
  });

  testWidgets('被删候选用圆圈底色高亮，数字取对照色且不再靠删除线', (tester) async {
    final board = SudokuBoard.fromString(_classic);
    const ref = CandidateRef(0, 2, 1);
    final markup = BoardMarkup(struck: {ref});

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SizedBox(
            width: 450,
            child: SudokuGrid(
              board: board,
              selectedRow: null,
              selectedCol: null,
              onCellTap: (_, __) {},
              showCandidates: true,
              markup: markup,
            ),
          ),
        ),
      ),
    );

    const palette = BoardPalette.lightPalette;
    final chip = tester.widgetList<Container>(find.byType(Container)).where((c) {
      final decoration = c.decoration;
      return decoration is BoxDecoration &&
          decoration.shape == BoxShape.circle &&
          decoration.color == palette.candidateStruck;
    });
    expect(chip, isNotEmpty, reason: '被删候选应有圆圈背景');

    final digits = tester
        .widgetList<Text>(find.text('1'))
        .where((t) => t.style?.decoration == TextDecoration.lineThrough);
    expect(digits, isEmpty, reason: '不再用删除线表示删除');
  });
}
