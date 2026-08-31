import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sudoku_app/models/board_markup.dart';
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

GameState _game() => GameState()..loadCustomGame(_classic);

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
  test('空格数字键 toggle 候选，不依赖笔记模式', () {
    final g = _game()..selectCell(0, 2);
    expect(g.candidateMode, isFalse);
    expect(g.board!.visibleCandidates(0, 2), contains(2));

    expect(g.handleDigitKey(2, shift: false), isTrue);
    expect(g.board!.get(0, 2), 0);
    expect(g.board!.visibleCandidates(0, 2), isNot(contains(2)));

    g.handleDigitKey(2, shift: false);
    expect(g.board!.visibleCandidates(0, 2), contains(2));
  });

  test('Shift+数字在空格上直接填成数', () {
    final g = _game()..selectCell(0, 2);
    expect(g.handleDigitKey(2, shift: true), isTrue);
    expect(g.board!.get(0, 2), 2);
  });

  test('已有成数时数字键不改盘，Backspace 清手填并重算候选', () {
    final g = _game()
      ..selectCell(0, 2)
      ..handleDigitKey(2, shift: true);
    expect(g.board!.get(0, 2), 2);
    expect(g.handleDigitKey(4, shift: false), isFalse);
    expect(g.handleDigitKey(4, shift: true), isFalse);
    expect(g.board!.get(0, 2), 2);

    expect(g.handleBackspace(), isTrue);
    expect(g.board!.get(0, 2), 0);
    expect(g.board!.visibleCandidates(0, 2), isNotEmpty);
    expect(g.showCandidates, isTrue);
  });

  test('题目已知数不能 Backspace', () {
    final g = _game()..selectCell(0, 0);
    expect(g.board!.isInitial(0, 0), isTrue);
    expect(g.handleBackspace(), isFalse);
    expect(g.board!.get(0, 0), 5);
  });

  test('方向键和 hjkl 移动高亮，到边绕回', () {
    final g = _game()..selectCell(0, 0);
    expect(g.moveSelection(-1, 0), isTrue);
    expect(g.selectedRow, 8);
    expect(g.selectedCol, 0);
    g.moveSelection(0, -1);
    expect(g.selectedRow, 8);
    expect(g.selectedCol, 8);
    g.moveSelection(1, 1);
    expect(g.selectedRow, 0);
    expect(g.selectedCol, 0);
  });

  test('无选中时方向和数字键都不做事', () {
    final g = _game();
    expect(g.moveSelection(1, 0), isFalse);
    expect(g.handleDigitKey(2, shift: false), isFalse);
  });

  test('标记态数字键不 toggle 候选、不填数', () {
    final g = _game()
      ..setMarkupMode(MarkupMode.cellColor)
      ..selectCell(0, 2);
    expect(g.handleDigitKey(2, shift: false), isFalse);
    expect(g.handleDigitKey(2, shift: true), isFalse);
    expect(g.board!.get(0, 2), 0);
  });

  test('候选色无选中：数字区全局 toggle 该数字高亮，可叠多个数字', () {
    final g = _game()..setMarkupMode(MarkupMode.candidateColor);
    expect(g.selectedRow, isNull);
    expect(g.isNumberPadEnabled(4), isTrue);

    g.onNumberPad(4);
    final fours = g.userMarkup.candidateColors.keys.where((r) => r.num == 4);
    expect(fours, isNotEmpty);
    g.onNumberPad(5);
    expect(
      g.userMarkup.candidateColors.keys.any((r) => r.num == 5),
      isTrue,
    );
    expect(
      g.userMarkup.candidateColors.keys.any((r) => r.num == 4),
      isTrue,
    );

    g.onNumberPad(4);
    expect(
      g.userMarkup.candidateColors.keys.any((r) => r.num == 4),
      isFalse,
    );
    expect(
      g.userMarkup.candidateColors.keys.any((r) => r.num == 5),
      isTrue,
    );
  });

  test('强弱链有高亮格时数字键设锚点，方向可换格', () {
    final g = _game()..setMarkupMode(MarkupMode.strong);
    g.onCellTap(0, 2);
    expect(g.selectedRow, 0);
    expect(g.selectedCol, 2);
    expect(g.board!.visibleCandidates(0, 2), contains(2));

    expect(g.handleDigitKey(2, shift: false), isTrue);
    expect(g.arrowAnchor, const CandidateRef(0, 2, 2));

    expect(g.moveSelection(0, 1), isTrue);
    expect(g.selectedRow, 0);
    expect(g.selectedCol, 3);
  });

  testWidgets('点数字键不会连带取消选中', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _game()..selectCell(0, 2);
    await _pumpGame(tester, state);
    expect(state.selectedRow, 0);

    await tester.tap(find.text('2').last);
    await tester.pump();
    expect(state.selectedRow, 0);
    expect(state.selectedCol, 2);
    expect(state.board!.get(0, 2), isNot(0));
  });

  testWidgets('点信息条空白取消格子选中', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _game()..selectCell(0, 2);
    await _pumpGame(tester, state);
    expect(state.selectedRow, 0);

    await tester.tap(find.text('用时'));
    await tester.pump();
    expect(state.selectedRow, isNull);
    expect(state.selectedCol, isNull);
  });

  testWidgets('Cmd+Z / Cmd+Y 撤销重做标记', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _game()..setMarkupMode(MarkupMode.cellColor);
    await _pumpGame(tester, state);
    state.onCellTap(1, 1);
    await tester.pump();
    final key = BoardMarkup.cellKey(1, 1);
    expect(state.userMarkup.cellColors.containsKey(key), isTrue);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.userMarkup.cellColors.containsKey(key), isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyY);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    await tester.pump();
    expect(state.userMarkup.cellColors.containsKey(key), isTrue);
  });

  testWidgets('键盘数字和方向作用在当前高亮格', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final state = _game()..selectCell(0, 2);
    await _pumpGame(tester, state);

    await tester.sendKeyEvent(LogicalKeyboardKey.digit2);
    await tester.pump();
    expect(state.board!.get(0, 2), 0);
    expect(state.board!.visibleCandidates(0, 2), isNot(contains(2)));

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(state.selectedRow, 0);
    expect(state.selectedCol, 3);
  });
}
