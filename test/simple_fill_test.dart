import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/screens/game_screen.dart';
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
  test('exportPuzzle 是 81 位当前盘面', () {
    final state = GameState()..loadCustomGame(_classic);
    expect(state.exportPuzzle(), _classic);
  });

  test('填写简单技巧只走唯余', () {
    final state = GameState()..loadCustomGame(_classic);
    final before = state.board!.toStringRepresentation();
    final n = state.applySimpleFills(includeHiddenSingle: false);
    expect(n, greaterThan(0));
    expect(state.hintsUsed, 0);
    expect(state.board!.toStringRepresentation(), isNot(before));
  });

  test('填写简单类不少于只填唯余', () {
    final onlyNaked = GameState()..loadCustomGame(_classic);
    final singles = GameState()..loadCustomGame(_classic);
    final n1 = onlyNaked.applySimpleFills(includeHiddenSingle: false);
    final n2 = singles.applySimpleFills(includeHiddenSingle: true);
    expect(n2, greaterThanOrEqualTo(n1));
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
    expect(find.textContaining('已用唯余/摒除填写'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('一键复制'), findsOneWidget);
    expect(find.text('重新开始'), findsOneWidget);
    expect(find.text('快速填充'), findsOneWidget);
    expect(find.text('1 唯余法'), findsNothing);
    expect(find.text('2 唯余+摒除'), findsNothing);
  });
}
