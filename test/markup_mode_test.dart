import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';

const classic =
    '530070000600195000098000060800060003400803001700020006060000280000419005000080079';

GameState _classicWithVisible8() {
  final g = GameState()..loadCustomGame(classic);
  // (0,2) empty; force auto set to {8}
  g.board!.candidates[0][2] = {8};
  g.board!.userCandidates[0][2] = {};
  return g;
}

void main() {
  test('未进格色模式时选格不上色', () {
    final g = GameState()..loadExampleGame('easy');
    g.setMarkupMode(MarkupMode.off);
    g.onCellTap(0, 0);
    expect(g.userMarkup.cellColors, isEmpty);
  });

  test('格色模式点格写入当前色，同色再点取消', () {
    final g = GameState()..loadExampleGame('easy');
    g.setMarkupColor(MarkupPalette.colors.first);
    g.setMarkupMode(MarkupMode.cellColor);
    g.onCellTap(1, 1);
    expect(g.userMarkup.cellColors[BoardMarkup.cellKey(1, 1)],
        MarkupPalette.colors.first);
    g.onCellTap(1, 1);
    expect(g.userMarkup.cellColors.containsKey(BoardMarkup.cellKey(1, 1)),
        isFalse);
  });

  test('候选色：选色选格点数字键给该候选上色，不改笔记集合', () {
    final g = _classicWithVisible8();
    g.setMarkupColor(MarkupPalette.colors[1]);
    g.setMarkupMode(MarkupMode.candidateColor);
    g.selectCell(0, 2);
    g.onNumberPad(8);
    expect(g.userMarkup.candidateColors[const CandidateRef(0, 2, 8)],
        MarkupPalette.colors[1]);
    expect(g.board!.getUserCandidates(0, 2).contains(8), isFalse);
  });

  test('候选色：同色再点数字键取消上色', () {
    final g = _classicWithVisible8();
    g.setMarkupColor(MarkupPalette.colors[1]);
    g.setMarkupMode(MarkupMode.candidateColor);
    g.selectCell(0, 2);
    g.onNumberPad(8);
    g.onNumberPad(8);
    expect(
      g.userMarkup.candidateColors.containsKey(const CandidateRef(0, 2, 8)),
      isFalse,
    );
    expect(g.board!.getUserCandidates(0, 2), isEmpty);
  });

  test('格色模式数字键无效', () {
    final g = _classicWithVisible8();
    g.setMarkupMode(MarkupMode.cellColor);
    g.selectCell(0, 2);
    g.onNumberPad(8);
    expect(g.board!.get(0, 2), 0);
    expect(g.userMarkup.candidateColors, isEmpty);
  });
}
