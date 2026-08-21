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

const _other = '003020600'
    '900305001'
    '001806400'
    '008102900'
    '700000008'
    '006708200'
    '002609500'
    '800203009'
    '005010300';

void main() {
  test('换一局时所有开关回到初始状态', () {
    final state = GameState()..loadCustomGame(_classic);

    state.toggleShowCandidates();
    state.toggleCandidateMode();
    state.setMarkupMode(MarkupMode.strong);
    state.setMarkupColor(MarkupPalette.colors[5]);
    state.setFilterDigit(7);
    state.selectCell(0, 2);
    state.onCandidateTap(0, 2, 1);
    state.getHint();

    expect(state.showCandidates, true);
    expect(state.candidateMode, true);
    expect(state.arrowAnchor, isNotNull);

    state.loadCustomGame(_other);

    expect(state.showCandidates, false);
    expect(state.candidateMode, false);
    expect(state.markupMode, MarkupMode.off);
    expect(state.markupColor, MarkupPalette.colors.first);
    expect(state.userMarkup.filterDigit, isNull);
    expect(state.userMarkup.candidateColors, isEmpty);
    expect(state.userMarkup.arrows, isEmpty);
    expect(state.arrowAnchor, isNull);
    expect(state.hintSession, isNull);
    expect(state.hintMarkup, isNull);
    expect(state.selectedRow, isNull);
    expect(state.hintsUsed, 0);
    expect(state.canUndo, false);
  });

  test('重新开始同一局会清掉棋盘上的标记', () {
    final state = GameState()..loadCustomGame(_classic);
    state.setMarkupMode(MarkupMode.cellColor);
    state.onCellTap(0, 2);
    state.getHint();
    expect(state.userMarkup.cellColors, isNotEmpty);

    state.resetGame();

    expect(state.userMarkup.cellColors, isEmpty);
    expect(state.hintSession, isNull);
    expect(state.arrowAnchor, isNull);
  });
}
