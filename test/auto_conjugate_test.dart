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
  test('自动强链画出行、列、宫，且不只扫行', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(7);
    expect(
      g.userMarkup.arrows.where((a) => a.kind == ArrowKind.strong).length,
      3,
    );
  });

  test('超过两个候选的单元不画强链', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(7);
    final col3Pair = g.userMarkup.arrows.any(
      (a) =>
          a.kind == ArrowKind.strong &&
          {a.from.col, a.to.col}.contains(3) &&
          a.from.row != 0 &&
          a.to.row != 0,
    );
    expect(col3Pair, isFalse);
  });

  test('无双值单元时设置 autoStrongNotice', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][0].add(5);
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(5);
    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, '该数字没有强链');
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

  test('宫内双值强链：同行另有同数字时仍合法', () {
    final cands = List.generate(9, (_) => List.generate(9, (_) => <int>{}));
    // Box 8 pair (6,6)-(6,7); third 5 on same row outside the box
    cands[6][6].add(5);
    cands[6][7].add(5);
    cands[6][0].add(5);
    expect(
      BoardMarkup.isLegalConjugate(
        const CandidateRef(6, 6, 5),
        const CandidateRef(6, 7, 5),
        cands,
      ),
      isTrue,
    );
  });

  test('自动强链不带箭头', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(7);
    expect(g.userMarkup.arrows, isNotEmpty);
    expect(
      g.userMarkup.arrows.where((a) => a.kind == ArrowKind.strong),
      isNotEmpty,
    );
    expect(g.userMarkup.arrows.every((a) => a.directed == false), isTrue);
  });

  test('两条不同强链的端点互相看得见时补一条无向弱链', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    // 两行各一条强链；近端同列但该列还有第三处，所以近端之间只能是弱链。
    for (final cell in [
      [0, 1],
      [0, 6],
      [3, 1],
      [3, 8],
      [7, 1],
    ]) {
      g.board!.candidates[cell[0]][cell[1]].add(5);
    }
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(5);

    final weaks = g.userMarkup.arrows.where((a) => a.kind == ArrowKind.weak);
    expect(weaks.length, 1);
    final weak = weaks.single;
    final ends = {weak.from, weak.to};
    expect(ends, {
      const CandidateRef(0, 1, 5),
      const CandidateRef(3, 1, 5),
    });
    expect(weak.directed, isFalse);
    expect(
      g.userMarkup.arrows.any((a) =>
          a.kind == ArrowKind.weak &&
          {a.from, a.to}.contains(const CandidateRef(0, 6, 5)) &&
          {a.from, a.to}.contains(const CandidateRef(0, 1, 5))),
      isFalse,
    );
  });

  test('两端已有强链时不再画弱链', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(7);
    expect(
      g.userMarkup.arrows.any((a) =>
          a.kind == ArrowKind.weak &&
          {a.from, a.to}.contains(const CandidateRef(0, 1, 7)) &&
          {a.from, a.to}.contains(const CandidateRef(0, 7, 7))),
      isFalse,
    );
  });

  test('手动画的强链仍带箭头', () {
    final g = GameState()..loadCustomGame('0' * 81);
    g.setMarkupMode(MarkupMode.strong);
    g.onCandidateMarkupTap(0, 0, 1);
    g.onCandidateMarkupTap(0, 1, 1);
    expect(g.userMarkup.arrows.single.directed, isTrue);
  });

  test('自动强弱链下点候选只展开从它出发的交替链', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    for (final cell in [
      [0, 1],
      [0, 6],
      [3, 1],
      [3, 8],
      [7, 1],
      [8, 0],
      [8, 2],
    ]) {
      g.board!.candidates[cell[0]][cell[1]].add(5);
    }
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 6, 5);

    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(0, 1, 5)) &&
          {a.from, a.to}.contains(const CandidateRef(0, 6, 5)) &&
          a.kind == ArrowKind.strong),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          a.kind == ArrowKind.weak &&
          a.color == null &&
          {a.from, a.to}.contains(const CandidateRef(0, 1, 5)) &&
          {a.from, a.to}.contains(const CandidateRef(3, 1, 5))),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          a.kind == ArrowKind.strong &&
          {a.from, a.to}.contains(const CandidateRef(3, 1, 5)) &&
          {a.from, a.to}.contains(const CandidateRef(3, 8, 5))),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(8, 0, 5))),
      isFalse,
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(0, 6, 5)],
      MarkupPalette.contrast(MarkupPalette.colors.first),
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(3, 8, 5)],
      MarkupPalette.contrast(MarkupPalette.colors.first),
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(0, 1, 5)],
      MarkupPalette.colors.first,
    );
  });

  test('两端共见的同数字候选标成红色', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    for (final cell in [
      [0, 1],
      [0, 6],
      [3, 1],
      [3, 8],
      [4, 6],
      [5, 7],
      [7, 1],
      [8, 6],
    ]) {
      g.board!.candidates[cell[0]][cell[1]].add(5);
    }
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 6, 5);
    expect(
      g.userMarkup.candidateColors[const CandidateRef(4, 6, 5)],
      MarkupPalette.red,
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(0, 6, 5)],
      isNot(MarkupPalette.red),
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(8, 6, 5)],
      isNot(MarkupPalette.red),
    );
  });

  test('预选色是红色时共见删除改标蓝色', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    for (final cell in [
      [0, 1],
      [0, 6],
      [3, 1],
      [3, 8],
      [4, 6],
      [5, 7],
      [7, 1],
      [8, 6],
    ]) {
      g.board!.candidates[cell[0]][cell[1]].add(5);
    }
    g.setMarkupMode(MarkupMode.autoStrong);
    g.setMarkupColor(MarkupPalette.red);
    g.onCandidateTap(0, 6, 5);
    expect(
      g.userMarkup.candidateColors[const CandidateRef(4, 6, 5)],
      MarkupPalette.blue,
    );
  });

  test('只保留两端之间的最短 AIC，不画绕路', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][6].add(5);
    g.board!.candidates[0][1].addAll({5, 2});
    g.board!.candidates[3][1].add(5);
    g.board!.candidates[3][8].add(5);
    g.board!.candidates[7][1].add(5);
    g.board!.candidates[8][1].add(2);
    g.board!.candidates[8][4].addAll({2, 5});
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 6, 5);

    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(3, 8, 5))),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(8, 1, 2)) &&
          {a.from, a.to}.contains(const CandidateRef(8, 4, 2))),
      isTrue,
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(3, 8, 5)],
      MarkupPalette.contrast(MarkupPalette.colors.first),
    );
    expect(
      g.userMarkup.candidateColors[const CandidateRef(8, 4, 5)],
      MarkupPalette.contrast(MarkupPalette.colors.first),
    );
  });

  test('通往同一端点的绕路不画', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][6].add(5);
    g.board!.candidates[0][1].addAll({5, 2});
    g.board!.candidates[3][1].addAll({5, 2});
    g.board!.candidates[3][8].add(5);
    g.board!.candidates[7][1].add(5);
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 6, 5);

    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(3, 8, 5))),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(0, 1, 2)) ||
          {a.from, a.to}.contains(const CandidateRef(3, 1, 2))),
      isFalse,
    );
  });

  test('点不在强链端点的候选时不展开', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    for (final cell in [
      [0, 1],
      [0, 6],
      [3, 1],
      [3, 8],
      [6, 1],
      [8, 5],
      [8, 7],
    ]) {
      g.board!.candidates[cell[0]][cell[1]].add(5);
    }
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(6, 1, 5);

    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, isNotNull);
  });

  test('孤立双值格另一端不是同数字则不画', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[2][3].addAll({4, 7});
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(2, 3, 4);
    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, isNotNull);
  });

  test('数字键自动强弱链不画同格双值链', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[2][3].addAll({4, 7});
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(4);
    expect(g.userMarkup.arrows, isEmpty);
  });

  test('点候选展开 XY-Chain：房屋共轭可当弱链跳过', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][7].addAll({4, 5});
    g.board!.candidates[0][2].addAll({4, 6});
    g.board!.candidates[1][0].addAll({1, 4});
    g.board!.candidates[7][0].addAll({1, 5});
    g.board!.candidates[7][6].addAll({1, 6});
    g.board!.candidates[8][6].addAll({1, 4});
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 7, 4);

    bool linked(ArrowKind kind, CandidateRef a, CandidateRef b) =>
        g.userMarkup.arrows.any((arrow) =>
            arrow.kind == kind &&
            {arrow.from, arrow.to}.contains(a) &&
            {arrow.from, arrow.to}.contains(b));

    expect(
      linked(
        ArrowKind.strong,
        const CandidateRef(0, 7, 4),
        const CandidateRef(0, 2, 4),
      ),
      isTrue,
    );
    expect(
      g.userMarkup.arrows.any((a) => a.from.row == a.to.row && a.from.col == a.to.col),
      isFalse,
    );
    expect(
      g.userMarkup.arrows.any((a) =>
          {a.from, a.to}.contains(const CandidateRef(7, 0, 1)) &&
          {a.from, a.to}.contains(const CandidateRef(7, 6, 1))),
      isTrue,
    );
    expect(
      g.userMarkup.candidateColors.containsKey(const CandidateRef(8, 6, 4)),
      isTrue,
    );
    expect(g.autoStrongNotice, isNull);
  });

  test('点候选展开跨数字 AIC：另一端不是同数字则不画', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][0].addAll({1, 2});
    g.board!.candidates[0][5].addAll({2, 3});
    g.board!.candidates[0][8].add(2);
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 0, 1);

    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, isNotNull);
  });

  test('点候选展开跨数字 AIC：同格铰链但另一端不同数字则不画', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][0].addAll({1, 2, 3});
    g.board!.candidates[0][8].add(1);
    g.board!.candidates[8][0].add(2);
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 8, 1);

    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, isNotNull);
  });

  test('点没有强链的候选时不画链', () {
    final g = GameState()..loadCustomGame('0' * 81);
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        g.board!.candidates[r][c] = {};
        g.board!.userCandidates[r][c] = {};
      }
    }
    g.board!.candidates[0][0].add(5);
    g.board!.candidates[8][8].add(5);
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onCandidateTap(0, 0, 5);
    expect(g.userMarkup.arrows, isEmpty);
    expect(g.autoStrongNotice, isNotNull);
  });

  test('已有强链再画时不设 autoStrongNotice', () {
    final g = _boardWithDigit7Conjugates();
    g.setMarkupMode(MarkupMode.autoStrong);
    g.onNumberPad(7);
    expect(g.autoStrongNotice, isNull);
    expect(
      g.userMarkup.arrows.where((a) => a.kind == ArrowKind.strong).length,
      3,
    );
    g.onNumberPad(7);
    expect(g.autoStrongNotice, isNull);
    expect(
      g.userMarkup.arrows.where((a) => a.kind == ArrowKind.strong).length,
      3,
    );
  });
}
