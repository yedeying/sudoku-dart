import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';

/// Empty board with only the listed digit placements in auto-candidates.
GameState _boardWithDigit7Conjugates() {
  final g = GameState()..loadCustomGame('0' * 81);
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      g.board!.candidates[r][c] = {};
      g.board!.userCandidates[r][c] = {};
    }
  }
  // Exactly two in row 0, col 1, box 8; three in col 3 (must not draw).
  for (final cell in [
    [0, 1],
    [0, 7],
    [5, 1],
    [6, 6],
    [8, 8],
    [1, 3],
    [4, 3],
    [7, 3],
  ]) {
    g.board!.candidates[cell[0]][cell[1]].add(7);
  }
  return g;
}

void main() {
  test('自动共轭画出行、列、宫，且不只扫行', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoConjugate);
    g.onNumberPad(7);
    expect(
      g.userMarkup.arrows.where((a) => a.kind == ArrowKind.conjugate).length,
      3,
    );
  });

  test('超过两个候选的单元不画共轭', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoConjugate);
    g.onNumberPad(7);
    final col3Pair = g.userMarkup.arrows.any(
      (a) =>
          a.kind == ArrowKind.conjugate &&
          {a.from.col, a.to.col}.contains(3) &&
          a.from.row != 0 &&
          a.to.row != 0,
    );
    expect(col3Pair, isFalse);
  });

  test('无共轭对时设置 conjugateNotice', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][0].add(5);
    g.setMarkupMode(MarkupMode.autoConjugate);
    g.onNumberPad(5);
    expect(g.userMarkup.arrows, isEmpty);
    expect(g.conjugateNotice, '该数字没有共轭对');
  });

  test('强链第一点留下锚点，第二点画线并清空锚点', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.strong);
    g.onCandidateMarkupTap(0, 1, 7);
    expect(g.arrowAnchor, const CandidateRef(0, 1, 7));
    g.onCandidateMarkupTap(0, 7, 7);
    expect(g.arrowAnchor, isNull);
    expect(g.userMarkup.arrows, isNotEmpty);
  });

  test('切换模式清空锚点', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.strong);
    g.onCandidateMarkupTap(0, 1, 7);
    expect(g.arrowAnchor, isNotNull);
    g.setMarkupMode(MarkupMode.weak);
    expect(g.arrowAnchor, isNull);
  });
}
