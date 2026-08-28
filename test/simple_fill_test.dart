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

const _nakedPair =
    '006005009328009700700208010000000002030500090200090000070000001000000008000000000';

void main() {
  test('exportPuzzle 是 81 位当前盘面', () {
    final state = GameState()..loadCustomGame(_classic);
    expect(state.exportPuzzle(), _classic);
  });

  test('填写简单技巧只走唯余', () {
    final state = GameState()..loadCustomGame(_classic, difficulty: 'advanced');
    final before = state.board!.toStringRepresentation();
    final n = state.applySimpleFills(includeHiddenSingle: false);
    expect(n.filled, greaterThan(0));
    expect(state.hintsUsed, 0);
    expect(state.board!.toStringRepresentation(), isNot(before));
  });

  test('填写简单类不少于只填唯余', () {
    final onlyNaked = GameState()
      ..loadCustomGame(_classic, difficulty: 'advanced');
    final singles = GameState()
      ..loadCustomGame(_classic, difficulty: 'advanced');
    final n1 = onlyNaked.applySimpleFills(includeHiddenSingle: false);
    final n2 = singles.applySimpleFills(includeHiddenSingle: true);
    expect(n2.filled, greaterThanOrEqualTo(n1.filled));
  });

  test('进阶档碰到数对就停，不删候选', () {
    final state = GameState()
      ..loadCustomGame(_nakedPair, difficulty: 'advanced');
    state.applySimpleFills(includeHiddenSingle: true);
    final next = SudokuSolver.getHint(state.board!);
    expect(next, isNotNull);
    expect(next!.technique, '显性数对');
  });

  test('自定义档会连走数对删除', () {
    final state = GameState()..loadCustomGame(_nakedPair);
    expect(state.difficulty, 'custom');
    final result = state.applySimpleFills(includeHiddenSingle: true);
    expect(result.eliminated, greaterThan(0));
    expect(state.hintsUsed, 0);
    final next = SudokuSolver.getHint(state.board!);
    expect(next?.technique, isNot('显性数对'));
  });

  testWidgets('对局页右上角有复制残局', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => GameState()..loadCustomGame(_classic),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const GameScreen(),
        ),
      ),
    );
    await tester.pump();
    expect(find.text('一键复制'), findsNothing);
    expect(find.text('快速填充'), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('快速填充')).dx,
      greaterThan(tester.getTopLeft(find.text('标记')).dx),
    );
    await tester.tap(find.byIcon(Icons.flash_on_outlined));
    await tester.pump();
    expect(find.textContaining('已填写'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('一键复制'), findsOneWidget);
    expect(find.text('重新开始'), findsOneWidget);
    expect(find.text('快速填充'), findsOneWidget);
    expect(find.text('1 唯余法'), findsNothing);
    expect(find.text('2 唯余+摒除'), findsNothing);
  });
}
