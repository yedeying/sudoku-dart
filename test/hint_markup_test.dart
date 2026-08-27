import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/game_state.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

void main() {
  test('getHint 不选中格子，也不打开行列宫或同数字高亮', () {
    final g = GameState()
      ..loadCustomGame(
        '530070000'
        '600195000'
        '098000060'
        '800060003'
        '400803001'
        '700020006'
        '060000280'
        '000419005'
        '000080079',
      );
    g.selectCell(0, 0);
    expect(g.selectedRow, 0);

    final hint = g.getHint();
    expect(hint, isNotNull);
    expect(g.hintSession?.phase, HintPhase.ready);
    expect(g.displaySelectedRow, isNull);
    expect(g.displaySelectedCol, isNull);
    expect(g.sameDigitHighlightCells(), isEmpty);
    expect(g.sameDigitHighlightCandidates(), isEmpty);
  });

  test('markupFromHint 按角色给格底、候选圆圈和箭头上色', () {
    final hint = SudokuHint.elimination(
      technique: '双线风筝',
      explanation: 'test',
      eliminations: [CandidateElim(8, 7, 5)],
      patternCells: const [
        HintCell(0, 1, HintRole.link),
        HintCell(0, 7, HintRole.link),
        HintCell(8, 7, HintRole.target),
      ],
      patternCandidates: const [
        HintCandidate(CandidateRef(0, 1, 5), HintRole.link),
        HintCandidate(CandidateRef(8, 7, 5), HintRole.target),
      ],
      links: const [
        MarkupArrow(
          from: CandidateRef(0, 1, 5),
          to: CandidateRef(0, 7, 5),
          kind: ArrowKind.strong,
        ),
      ],
    );

    final m = GameState.markupFromHint(hint);
    expect(m.cellColors[BoardMarkup.cellKey(0, 1)], isNotNull);
    expect(
      m.cellColors[BoardMarkup.cellKey(8, 7)],
      const Color(0xFFFFCDD2),
    );
    expect(
      m.candidateColors[const CandidateRef(0, 1, 5)],
      MarkupPalette.green,
    );
    expect(m.struck, contains(const CandidateRef(8, 7, 5)));
    expect(m.arrows, hasLength(1));
    expect(m.arrows.first.kind, ArrowKind.strong);
  });

  test('行向鱼把定义行整行淡亮，鱼身格仍用结构色', () {
    final hint = SudokuHint.elimination(
      technique: 'X-Wing',
      explanation: 'test',
      eliminations: [CandidateElim(0, 4, 6)],
      patternCells: const [
        HintCell(2, 4, HintRole.pattern),
        HintCell(2, 7, HintRole.pattern),
        HintCell(6, 4, HintRole.pattern),
        HintCell(6, 7, HintRole.pattern),
      ],
      highlightRows: const [2, 6],
    );

    final m = GameState.markupFromHint(hint);
    expect(m.cellColors[BoardMarkup.cellKey(2, 0)], MarkupPalette.house);
    expect(m.cellColors[BoardMarkup.cellKey(6, 3)], MarkupPalette.house);
    expect(m.cellColors[BoardMarkup.cellKey(2, 4)], const Color(0xFFBBDEFB));
    expect(m.cellColors[BoardMarkup.cellKey(0, 4)], const Color(0xFFFFCDD2));
    expect(m.cellColors.containsKey(BoardMarkup.cellKey(0, 0)), isFalse);
  });

  test('列向鱼把定义列整列淡亮', () {
    final hint = SudokuHint.elimination(
      technique: 'X-Wing',
      explanation: 'test',
      eliminations: [CandidateElim(1, 0, 4)],
      patternCells: const [
        HintCell(1, 2, HintRole.pattern),
        HintCell(5, 2, HintRole.pattern),
        HintCell(1, 7, HintRole.pattern),
        HintCell(5, 7, HintRole.pattern),
      ],
      highlightCols: const [2, 7],
    );

    final m = GameState.markupFromHint(hint);
    expect(m.cellColors[BoardMarkup.cellKey(0, 2)], MarkupPalette.house);
    expect(m.cellColors[BoardMarkup.cellKey(8, 7)], MarkupPalette.house);
    expect(m.cellColors[BoardMarkup.cellKey(1, 2)], const Color(0xFFBBDEFB));
    expect(m.cellColors.containsKey(BoardMarkup.cellKey(0, 0)), isFalse);
  });

  test('锁在宫里的一手把整个宫淡亮，宫外不受影响', () {
    final hint = SudokuHint.elimination(
      technique: '扩展矩形 Type 3',
      explanation: 'test',
      eliminations: [CandidateElim(4, 5, 7)],
      patternCells: const [
        HintCell(3, 3, HintRole.pattern),
        HintCell(3, 4, HintRole.extra),
      ],
      highlightBoxes: const [4],
    );

    final m = GameState.markupFromHint(hint);
    for (var r = 3; r < 6; r++) {
      for (var c = 3; c < 6; c++) {
        if (r == 3 && (c == 3 || c == 4)) continue;
        if (r == 4 && c == 5) continue;
        expect(
          m.cellColors[BoardMarkup.cellKey(r, c)],
          MarkupPalette.house,
          reason: 'r${r + 1}c${c + 1} 在 b5 里，应当被淡亮',
        );
      }
    }
    expect(m.cellColors[BoardMarkup.cellKey(3, 3)], const Color(0xFFBBDEFB));
    expect(m.cellColors.containsKey(BoardMarkup.cellKey(0, 0)), isFalse);
    expect(m.cellColors.containsKey(BoardMarkup.cellKey(3, 6)), isFalse);
    expect(m.cellColors.containsKey(BoardMarkup.cellKey(6, 3)), isFalse);
  });
}
