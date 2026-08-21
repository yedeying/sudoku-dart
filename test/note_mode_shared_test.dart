import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/theme/app_theme.dart';
import 'package:sudoku_app/theme/board_palette.dart';
import 'package:sudoku_app/widgets/sudoku_grid.dart';

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
  group('笔记模式与自动候选共享同一个集合', () {
    test('笔记点已有的自动候选会把它去掉，而不是无效叠加', () {
      final board = SudokuBoard.fromString(_classic);
      expect(board.visibleCandidates(0, 2), {1, 2, 4});

      board.toggleUserCandidate(0, 2, 2);
      expect(board.visibleCandidates(0, 2), {1, 4});

      board.toggleUserCandidate(0, 2, 5);
      expect(board.visibleCandidates(0, 2), {1, 4, 5});

      // 再点一次回到有 2 的状态，可见集合可反复切换。
      board.toggleUserCandidate(0, 2, 2);
      expect(board.visibleCandidates(0, 2), {1, 2, 4, 5});
    });

    test('手动去掉的自动候选在重算后仍然不出现', () {
      final board = SudokuBoard.fromString(_classic);
      board.toggleUserCandidate(0, 2, 2);
      board.refreshCandidates();
      expect(board.visibleCandidates(0, 2), {1, 4});
    });

    test('撤销/重做能还原可见候选', () {
      final state = GameState()..loadCustomGame(_classic);
      state.toggleCandidateMode();
      state.selectCell(0, 2);

      state.placeNumber(2);
      expect(state.board!.visibleCandidates(0, 2), {1, 4});
      state.placeNumber(5);
      expect(state.board!.visibleCandidates(0, 2), {1, 4, 5});

      state.undo();
      expect(state.board!.visibleCandidates(0, 2), {1, 4});
      state.undo();
      expect(state.board!.visibleCandidates(0, 2), {1, 2, 4});

      state.redo();
      expect(state.board!.visibleCandidates(0, 2), {1, 4});
      state.redo();
      expect(state.board!.visibleCandidates(0, 2), {1, 4, 5});
    });

    testWidgets('自动候选和手写候选长得一样，不再单独着色', (tester) async {
      final board = SudokuBoard.fromString(_classic);
      board.toggleUserCandidate(0, 2, 5);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SizedBox(
              width: 450,
              child: SudokuGrid(
                board: board,
                selectedRow: null,
                selectedCol: null,
                onCellTap: (_, __) {},
                showCandidates: true,
              ),
            ),
          ),
        ),
      );

      const palette = BoardPalette.lightPalette;
      // 候选数字号远小于填入的数字，用它把两者区分开。
      Text smallDigit(String d) => tester
          .widgetList<Text>(find.text(d))
          .firstWhere((t) => (t.style?.fontSize ?? 0) < 20);
      final auto = smallDigit('1');
      final manual = smallDigit('5');
      expect(auto.style?.color, palette.candidate);
      expect(manual.style?.color, palette.candidate);
      expect(manual.style?.fontWeight, auto.style?.fontWeight);
    });
  });
}
