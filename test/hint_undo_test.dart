import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

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
  test('撤销会清掉进行中的提示', () {
    final g = GameState()..loadCustomGame(_classic);
    g.selectCell(0, 2);
    g.placeNumber(1);
    g.getHint();
    expect(g.hintSession?.phase, HintPhase.ready);
    expect(g.hintMarkup, isNotNull);

    g.undo();

    expect(g.hintSession, isNull);
    expect(g.hintMarkup, isNull);
    expect(g.board!.get(0, 2), 0);
  });

  test('应用填数提示后可以撤销这一步，下一步提示一并收起', () {
    final g = GameState()..loadCustomGame(_classic);
    final before = g.exportPuzzle();
    final first = g.getHint();
    expect(first, isNotNull);
    expect(first!.isElimination, isFalse);

    g.applyHintAndAdvance(first);
    expect(g.board!.get(first.row, first.col), first.value);
    expect(g.hintSession?.phase, HintPhase.ready);
    expect(g.exportPuzzle(), isNot(before));

    g.undo();

    expect(g.exportPuzzle(), before);
    expect(g.hintSession, isNull);
    expect(g.hintMarkup, isNull);
    expect(g.board!.get(first.row, first.col), 0);
  });

  test('连续应用的提示可以一步步撤销', () {
    final g = GameState()..loadCustomGame(_classic);
    final start = g.exportPuzzle();
    final first = g.getHint()!;
    g.applyHintAndAdvance(first);
    final afterFirst = g.exportPuzzle();
    final second = g.hintSession!.hint!;
    g.applyHintAndAdvance(second);

    g.undo();
    expect(g.exportPuzzle(), afterFirst);
    expect(g.hintSession, isNull);

    g.undo();
    expect(g.exportPuzzle(), start);
  });

  test('删除候选的提示应用后可以整步撤销并重做', () {
    final g = GameState()..loadCustomGame(_classic);
    g.board!.setUserCandidates(0, 2, {1, 2, 4});
    final hint = SudokuHint.elimination(
      technique: '测试删除',
      explanation: '删掉 (1,3) 的 1',
      eliminations: [CandidateElim(0, 2, 1), CandidateElim(0, 2, 2)],
    );

    g.applyHint(hint);
    expect(g.canUndo, isTrue);
    expect(g.board!.eliminated[0][2], contains(1));
    expect(g.board!.visibleCandidates(0, 2), isNot(contains(1)));
    expect(g.board!.getUserCandidates(0, 2), isNot(contains(1)));

    g.undo();
    expect(g.hintSession, isNull);
    expect(g.board!.eliminated[0][2], isNot(contains(1)));
    expect(g.board!.visibleCandidates(0, 2), contains(1));
    expect(g.board!.getUserCandidates(0, 2), contains(1));

    g.redo();
    expect(g.board!.eliminated[0][2], contains(1));
    expect(g.board!.visibleCandidates(0, 2), isNot(contains(1)));
    expect(g.board!.getUserCandidates(0, 2), isNot(contains(1)));
  });
}
