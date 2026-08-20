import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';

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
}
