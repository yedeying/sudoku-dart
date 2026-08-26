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

  testWidgets('HintPanel 在解法后面展示技巧定义', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: HintPanel(
          title: '唯余法',
          body: 'r1c3 只能填 4',
          definition: '唯余法（Naked Single）指某个空格只剩下一个候选数字。',
          actionLabel: '应用本步',
          onCancel: () {},
          onApply: () {},
        ),
      ),
    ));
    expect(find.text('技巧定义'), findsOneWidget);
    expect(find.textContaining('Naked Single'), findsOneWidget);
    expect(
      tester.getTopLeft(find.textContaining('Naked Single')).dy,
      greaterThan(tester.getTopLeft(find.textContaining('只能填 4')).dy),
    );
  });

  testWidgets('长正文超过高度上限时卡片本身不溢出，内容改为内部滚动', (tester) async {
    final longBody = List.generate(60, (i) => '第 $i 行很长的提示说明文字').join('\n');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: HintPanel(
            title: '一个很长的提示',
            body: longBody,
            actionLabel: '应用删除',
            onCancel: () {},
            onApply: () {},
            maxHeight: 200,
          ),
        ),
      ),
    ));

    expect(tester.takeException(), isNull);
    final cardHeight = tester.getSize(find.byType(Card)).height;
    expect(cardHeight, lessThanOrEqualTo(200.5));
    // 标题和按钮始终可见，正文被裁切在可滚动区域内。
    expect(find.text('一个很长的提示'), findsOneWidget);
    expect(find.text('应用删除'), findsOneWidget);
  });

  testWidgets('短提示按内容收高，不把上限高度撑满', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Align(
          alignment: Alignment.bottomCenter,
          child: HintPanel(
            title: '唯余法',
            body: 'r1c3 只能填 4',
            actionLabel: '应用本步',
            onCancel: () {},
            onApply: () {},
            maxHeight: 400,
          ),
        ),
      ),
    ));
    expect(tester.getSize(find.byType(Card)).height, lessThan(280));
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

  test('应用填数提示后 hintSession 为 null 且通知发生在清除之后', () {
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
    final hint = g.getHint();
    expect(hint, isNotNull);
    expect(hint!.isElimination, isFalse);
    expect(g.hintSession, isNotNull);

    HintSession? lastSeenSession;
    g.addListener(() {
      lastSeenSession = g.hintSession;
    });

    g.applyHint(hint);

    expect(g.hintSession, isNull);
    expect(lastSeenSession, isNull);
  });

  test('笔记模式应用填数提示后最后一次通知仍保持 candidateMode', () {
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
    g.toggleCandidateMode();
    expect(g.candidateMode, isTrue);

    final hint = g.getHint();
    expect(hint, isNotNull);
    expect(hint!.isElimination, isFalse);

    bool? lastCandidateMode;
    HintSession? lastSession;
    g.addListener(() {
      lastCandidateMode = g.candidateMode;
      lastSession = g.hintSession;
    });

    g.applyHint(hint);

    expect(g.candidateMode, isTrue);
    expect(g.hintSession, isNull);
    expect(lastCandidateMode, isTrue);
    expect(lastSession, isNull);
  });
}
