import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';

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

void main() {
  test('格色写入后可以撤销再重做', () {
    final g = _game()..setMarkupMode(MarkupMode.cellColor);
    g.onCellTap(1, 1);
    final key = BoardMarkup.cellKey(1, 1);
    expect(g.userMarkup.cellColors[key], MarkupPalette.colors.first);
    expect(g.canUndo, isTrue);

    g.undo();
    expect(g.userMarkup.cellColors.containsKey(key), isFalse);

    g.redo();
    expect(g.userMarkup.cellColors[key], MarkupPalette.colors.first);
  });

  test('清除标记可以整步撤销', () {
    final g = _game()..setMarkupMode(MarkupMode.cellColor);
    g.onCellTap(1, 1);
    g.onCellTap(2, 2);
    expect(g.userMarkup.cellColors, hasLength(2));

    g.clearUserMarkup();
    expect(g.userMarkup.cellColors, isEmpty);

    g.undo();
    expect(g.userMarkup.cellColors, hasLength(2));
  });

  test('候选色和自动强链也进同一套历史', () {
    final g = _game()..setMarkupMode(MarkupMode.candidateColor);
    g.toggleGlobalCandidateColor(2);
    expect(g.userMarkup.candidateColors.keys.any((r) => r.num == 2), isTrue);

    g.undo();
    expect(g.userMarkup.candidateColors, isEmpty);

    g.setMarkupMode(MarkupMode.autoStrong);
    final added = g.paintAutoStrong(5);
    expect(added, greaterThan(0));
    expect(g.userMarkup.arrows, isNotEmpty);

    g.undo();
    expect(g.userMarkup.arrows, isEmpty);
  });

  test('填数和标记穿插，各自一步撤销', () {
    final g = _game()
      ..selectCell(0, 2)
      ..handleDigitKey(1, shift: true);
    expect(g.board!.get(0, 2), 1);

    g.setMarkupMode(MarkupMode.cellColor);
    g.onCellTap(1, 1);
    expect(g.userMarkup.cellColors, isNotEmpty);
    expect(g.board!.get(0, 2), 1);

    g.undo();
    expect(g.userMarkup.cellColors, isEmpty);
    expect(g.board!.get(0, 2), 1);

    g.undo();
    expect(g.board!.get(0, 2), 0);
  });

  test('Cmd/Ctrl+Z 撤销，Cmd/Ctrl+Y 重做', () {
    final g = _game()..setMarkupMode(MarkupMode.cellColor);
    g.onCellTap(1, 1);
    final key = BoardMarkup.cellKey(1, 1);

    expect(g.handleUndoShortcut(redo: false), isTrue);
    expect(g.userMarkup.cellColors.containsKey(key), isFalse);

    expect(g.handleUndoShortcut(redo: true), isTrue);
    expect(g.userMarkup.cellColors[key], MarkupPalette.colors.first);

    expect(g.handleUndoShortcut(redo: true), isFalse);
    g.undo();
    expect(g.handleUndoShortcut(redo: true), isTrue);
    expect(g.userMarkup.cellColors[key], MarkupPalette.colors.first);
  });
}
