import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';

GameState _boardWithFives() {
  final g = GameState();
  // (0,0)=5, (1,1)=5 given; (2,2) empty — force visible candidate 5
  g.loadCustomGame(
    '500000000'
    '050000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000'
    '000000000',
  );
  g.board!.candidates[2][2] = {5};
  g.board!.userCandidates[2][2] = {};
  return g;
}

void main() {
  test('标记关闭时选中成数 5 弱高亮其它 5 和候选 5', () {
    final g = _boardWithFives();
    g.selectCell(0, 0);
    expect(g.sameDigitHighlightCells(), contains(BoardMarkup.cellKey(1, 1)));
    expect(
      g.sameDigitHighlightCandidates(),
      contains(const CandidateRef(2, 2, 5)),
    );
  });

  test('标记开启后同数字高亮为空', () {
    final g = _boardWithFives();
    g.setMarkupMode(MarkupMode.cellColor);
    g.selectCell(0, 0);
    expect(g.sameDigitHighlightCells(), isEmpty);
    expect(g.sameDigitHighlightCandidates(), isEmpty);
  });
}
