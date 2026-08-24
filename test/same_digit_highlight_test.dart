import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

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

  test('同数字强调是带色浅底，不是中性灰字色', () {
    expect(
      BoardPalette.lightPalette.sameDigit,
      const Color(0xFFD6E3F5),
    );
    expect(
      BoardPalette.lightPalette.sameDigit,
      isNot(const Color(0xFFE2E2E2)),
    );
  });

  testWidgets('同数字成数整格铺强调底，候选铺小格底', (tester) async {
    final board = SudokuBoard.fromString(
      '500000000050000000000000000000000000000000000000000000000000000000000000000000000',
    );
    board.candidates[2][2] = {5, 6};
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: SizedBox(
          width: 360,
          child: SudokuGrid(
            board: board,
            selectedRow: 0,
            selectedCol: 0,
            onCellTap: (_, __) {},
            showCandidates: true,
            sameDigitCells: {BoardMarkup.cellKey(1, 1)},
            sameDigitCandidates: {const CandidateRef(2, 2, 5)},
          ),
        ),
      ),
    ));

    final palette = AppTheme.light().extension<BoardPalette>()!;
    final cell = tester.widget<Container>(
      find.byKey(const ValueKey('cell-1-1')),
    );
    final cellDeco = cell.decoration as BoxDecoration;
    expect(cellDeco.color, palette.sameDigit);

    final filledDigit = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('cell-1-1')),
        matching: find.text('5'),
      ),
    );
    expect(filledDigit.style?.color, palette.givenDigit);
    expect(filledDigit.style?.color, isNot(palette.sameDigit));

    final chip = tester.widget<Container>(
      find.descendant(
        of: find.byKey(const ValueKey('cand-2-2-5')),
        matching: find.byType(Container),
      ),
    );
    final chipDeco = chip.decoration as BoxDecoration;
    expect(chipDeco.color, palette.sameDigit);

    final candDigit = tester.widget<Text>(
      find.descendant(
        of: find.byKey(const ValueKey('cand-2-2-5')),
        matching: find.text('5'),
      ),
    );
    final washFg = palette.sameDigit.computeLuminance() > 0.5
        ? Colors.black87
        : Colors.white;
    expect(candDigit.style?.color, washFg);
    expect(candDigit.style?.color, isNot(palette.sameDigit));
  });
}
