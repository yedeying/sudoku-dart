import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/widgets/hint_panel.dart';

void main() {
  testWidgets('HintPanel 显示技巧名和应用按钮', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HintPanel(
          title: '显性数对（行）',
          body: '可删除候选',
          actionLabel: '应用删除',
          onCancel: () {},
          onApply: () {},
        ),
      ),
    ));
    expect(find.text('显性数对（行）'), findsOneWidget);
    expect(find.text('应用删除'), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
  });

  test('getHint 写入 hintSession 而不依赖对话框', () {
    final g = GameState()
      ..loadCustomGame(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079',
      );
    final h = g.getHint();
    expect(h, isNotNull);
    expect(g.hintSession, isNotNull);
    expect(g.hintSession!.phase, HintPhase.ready);
    expect(g.hintSession!.hint, same(h));
  });

  test('getHint 找不到时进入 offerDeep', () {
    final g = GameState()..loadCustomGame(List.filled(81, '0').join());
    final h = g.getHint();
    expect(h, isNull);
    expect(g.hintSession?.phase, HintPhase.offerDeep);
  });

  test('session 非 none 时再次 getHint 忽略', () {
    final g = GameState()
      ..loadCustomGame(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079',
      );
    final first = g.getHint();
    expect(first, isNotNull);
    final second = g.getHint();
    expect(second, isNull);
    expect(g.hintSession!.hint, same(first));
  });

  test('requestDeepSearch 写入 ready 或 failed', () {
    final g = GameState()..loadCustomGame(List.filled(81, '0').join());
    g.getHint();
    expect(g.hintSession?.phase, HintPhase.offerDeep);
    g.requestDeepSearch();
    expect(
      g.hintSession?.phase,
      anyOf(HintPhase.ready, HintPhase.failed),
    );
  });
}
