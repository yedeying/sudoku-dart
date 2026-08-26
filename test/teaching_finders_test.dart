import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_catalog.dart';
import 'package:sudoku_app/services/advanced_techniques.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

TechniqueInfo _tech(String id) =>
    TechniqueCatalog.all.firstWhere((t) => t.id == id);

SudokuBoard _board(String id) =>
    SudokuBoard.fromString(_tech(id).examplePuzzle);

Set<String> _elimKeys(SudokuHint hint) => {
      for (final e in hint.eliminations) '${e.row},${e.col},${e.num}',
    };

Set<String> _teachingElims(String id) => {
      for (final ref in _tech(id).exampleMarkup.candidateColors.keys)
        '${ref.row},${ref.col},${ref.num}',
    };

void _expectFinder(
  String id,
  String name,
  SudokuHint? Function(SudokuBoard) find, {
  bool fill = false,
}) {
  final hint = find(_board(id));
  expect(hint, isNotNull, reason: '$name 应在教学盘面上找得到');
  expect(hint!.technique, name);
  if (fill) {
    expect(hint.isElimination, isFalse);
    return;
  }
  expect(hint.isElimination, isTrue);
  expect(hint.eliminations, isNotEmpty);
}

void _expectFishHouse(SudokuHint hint) {
  expect(
    hint.highlightRows.isNotEmpty || hint.highlightCols.isNotEmpty,
    isTrue,
    reason: '${hint.technique} 应标出定义行或定义列',
  );
  for (final r in hint.highlightRows) {
    expect(
      hint.patternCells.any((c) => c.role == HintRole.pattern && c.row == r),
      isTrue,
      reason: '${hint.technique} 淡亮行 r${r + 1} 应穿过鱼身',
    );
  }
  for (final c in hint.highlightCols) {
    expect(
      hint.patternCells.any((c0) => c0.role == HintRole.pattern && c0.col == c),
      isTrue,
      reason: '${hint.technique} 淡亮列 c${c + 1} 应穿过鱼身',
    );
  }
}

void main() {
  test('带鳍 X-Wing 教学盘面', () {
    _expectFinder(
        'finned_xwing', '带鳍 X-Wing', AdvancedTechniques.findFinnedXWing);
  });

  test('带鳍 Swordfish 教学盘面', () {
    _expectFinder('finned_swordfish', '带鳍 Swordfish',
        AdvancedTechniques.findFinnedSwordfish);
  });

  test('带鳍 Jellyfish 教学盘面', () {
    _expectFinder('finned_jellyfish', '带鳍 Jellyfish',
        AdvancedTechniques.findFinnedJellyfish);
  });

  test('Franken 鱼教学盘面', () {
    _expectFinder(
        'franken_fish', 'Franken 鱼', AdvancedTechniques.findFrankenFish);
  });

  test('鱼类教学盘面标出定义行或列', () {
    final cases = <(String, String, SudokuHint? Function(SudokuBoard))>[
      ('finned_xwing', '带鳍 X-Wing', AdvancedTechniques.findFinnedXWing),
      (
        'finned_swordfish',
        '带鳍 Swordfish',
        AdvancedTechniques.findFinnedSwordfish
      ),
      (
        'finned_jellyfish',
        '带鳍 Jellyfish',
        AdvancedTechniques.findFinnedJellyfish
      ),
      ('franken_fish', 'Franken 鱼', AdvancedTechniques.findFrankenFish),
      ('jellyfish', 'Jellyfish', AdvancedTechniques.findJellyfish),
    ];
    for (final item in cases) {
      final hint = item.$3(_board(item.$1));
      expect(hint, isNotNull, reason: '${item.$2} 应找得到');
      expect(hint!.technique, item.$2);
      _expectFishHouse(hint);
    }
  });

  test('X-Wing 教学图淡亮定义行', () {
    final markup = _tech('xwing').exampleMarkup;
    expect(markup.cellColors[BoardMarkup.cellKey(2, 0)], isNotNull);
    expect(markup.cellColors[BoardMarkup.cellKey(6, 1)], isNotNull);
    expect(
      markup.cellColors[BoardMarkup.cellKey(2, 4)],
      isNot(markup.cellColors[BoardMarkup.cellKey(2, 0)]),
    );
  });

  test('X-Wing / Swordfish 提示带上定义线', () {
    SudokuHint? walkTo(String id, String name) {
      final puzzle =
          TechniqueCatalog.practicePuzzles[id] ?? _tech(id).examplePuzzle;
      final board = SudokuBoard.fromString(puzzle);
      for (var i = 0; i < 80; i++) {
        final hint = SudokuSolver.getHint(board);
        if (hint == null) return null;
        if (hint.technique == name) return hint;
        if (hint.isElimination) {
          for (final e in hint.eliminations) {
            board.eliminateCandidate(e.row, e.col, e.num);
          }
        } else {
          board.set(hint.row, hint.col, hint.value);
        }
      }
      return null;
    }

    for (final item in [('xwing', 'X-Wing'), ('swordfish', 'Swordfish')]) {
      final hint = walkTo(item.$1, item.$2);
      expect(hint, isNotNull, reason: '${item.$2} 应走得到');
      _expectFishHouse(hint!);
    }
  });

  test('WXYZ-Wing 教学盘面', () {
    _expectFinder('wxyz_wing', 'WXYZ-Wing', AdvancedTechniques.findWxyzWing);
  });

  test('BUG+1 教学盘面填入奇数次候选', () {
    final hint = AdvancedTechniques.findBugPlusOne(_board('bug1'));
    expect(hint, isNotNull);
    expect(hint!.technique, 'BUG+1');
    expect(hint.isElimination, isFalse);
    expect(hint.row, 3);
    expect(hint.col, 7);
    expect(hint.value, 5);
  });

  test('getHint 搜索顺序遵循评审难度和语义约束', () {
    final order = SudokuSolver.hintSearchOrder;
    const expected = [
      '唯余法',
      '摒除法（行/列/宫）',
      '显性数对',
      '显性三数组',
      '隐性数对',
      '宫区块',
      '行/列区块',
      '隐性三数组',
      '显性四数组',
      'X-Wing',
      '隐性四数组',
      '摩天楼',
      '双线风筝',
      'Swordfish',
      '多宝鱼',
      '带鳍 X-Wing',
      '刺身鱼',
      '空矩形',
      'Jellyfish',
      'XY-Wing',
      '唯一矩形 1',
      '不完整唯一矩形',
      '唯一矩形 2',
      'BUG+1',
      '可规避矩形',
      '带鳍 Swordfish',
      '唯一矩形 4',
      '隐性唯一矩形',
      'BUG 类型 2',
      '扩展矩形 1',
      'XYZ-Wing',
      '带鳍 Jellyfish',
      '扩展矩形 2',
      '唯一矩形 3',
      'BUG 类型 4',
      '扩展矩形 4',
      '扩展矩形 3',
      '唯一环 1',
      'BUG 类型 3',
      '唯一环 2',
      'Franken 鱼',
      '唯一环 4',
      'Simple Coloring',
      '唯一环 3',
      '探长',
      'W-Wing',
      'XY-Chain',
      'WXYZ-Wing',
      'AIC 开链',
      'Sue de Coq',
      'Nice Loop / AIC 环',
      'Grouped AIC',
      '死环',
      '毛刺数组',
      'ALS-XZ',
      'Death Blossom',
      'Kraken Fish',
      'Forcing Chain',
      'ALS-XY-Wing',
      'Nishio',
      'Forcing Net',
    ];

    for (final name in expected) {
      expect(order, contains(name), reason: '$name 必须存在，不能用 -1 参与顺序比较');
    }
    expect(order, expected);
  });

  test('XY-Chain 教学盘面', () {
    _expectFinder('xy_chain', 'XY-Chain', AdvancedTechniques.findXyChain);
  });

  test('AIC 开链教学盘面', () {
    _expectFinder('aic', 'AIC 开链', AdvancedTechniques.findAic);
  });

  test('Nice Loop 教学盘面', () {
    _expectFinder(
        'nice_loop', 'Nice Loop / AIC 环', AdvancedTechniques.findNiceLoop);
  });

  test('XY-Chain / AIC 开链 / Nice Loop 标出整条强弱链', () {
    final cases = <(String, String, SudokuHint? Function(SudokuBoard))>[
      ('xy_chain', 'XY-Chain', AdvancedTechniques.findXyChain),
      ('aic', 'AIC 开链', AdvancedTechniques.findAic),
      ('nice_loop', 'Nice Loop / AIC 环', AdvancedTechniques.findNiceLoop),
    ];
    for (final (id, name, find) in cases) {
      final hint = find(_board(id));
      expect(hint, isNotNull, reason: '$name 应找得到');
      expect(
        hint!.links.where((a) => a.kind == ArrowKind.strong),
        isNotEmpty,
        reason: '$name 应标出强链箭头，不能只洗格子',
      );
      expect(
        hint.links.where((a) => a.kind == ArrowKind.weak),
        isNotEmpty,
        reason: '$name 应标出弱链箭头',
      );
      expect(
        hint.patternCandidates.where((c) => c.role == HintRole.link),
        isNotEmpty,
        reason: '$name 中继候选应标在数字上',
      );
      expect(hint.explanation, contains('='));
      expect(hint.explanation, contains(' - '));
    }
  });

  test('教学里带箭头的链/翼技巧，提示也要带链', () {
    final finders = <String, SudokuHint? Function(SudokuBoard)>{
      'xy_chain': AdvancedTechniques.findXyChain,
      'aic': AdvancedTechniques.findAic,
      'nice_loop': AdvancedTechniques.findNiceLoop,
      'grouped_aic': AdvancedTechniques.findGroupedAic,
      'als_xz': AdvancedTechniques.findAlsXz,
      'als_xy': AdvancedTechniques.findAlsXyWing,
      'death_blossom': AdvancedTechniques.findDeathBlossom,
      'wxyz_wing': AdvancedTechniques.findWxyzWing,
    };
    for (final entry in finders.entries) {
      final tech = _tech(entry.key);
      if (tech.exampleMarkup.arrows.isEmpty) continue;
      final hint = entry.value(_board(entry.key));
      expect(hint, isNotNull, reason: '${tech.name} 应找得到');
      expect(
        hint!.links,
        isNotEmpty,
        reason: '${tech.name} 教学有链示意，提示却没有箭头',
      );
    }
  });

  test('Sue de Coq 标出交接格和两堆锁定集的候选', () {
    final hint = AdvancedTechniques.findSueDeCoq(_board('sue_de_coq'));
    expect(hint, isNotNull);
    expect(
      hint!.patternCandidates.where((c) => c.role != HintRole.target),
      isNotEmpty,
      reason: '不能只把要删的标红',
    );
  });

  test('Death Blossom 标出花心到花瓣的箭头', () {
    final hint = AdvancedTechniques.findDeathBlossom(_board('death_blossom'));
    expect(hint, isNotNull);
    expect(hint!.links, isNotEmpty);
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.pattern),
      isNotEmpty,
    );
  });

  test('Sue de Coq 教学盘面', () {
    _expectFinder('sue_de_coq', 'Sue de Coq', AdvancedTechniques.findSueDeCoq);
  });

  test('Death Blossom 教学盘面', () {
    _expectFinder(
        'death_blossom', 'Death Blossom', AdvancedTechniques.findDeathBlossom);
  });

  test('Kraken Fish 教学盘面', () {
    _expectFinder('kraken', 'Kraken Fish', AdvancedTechniques.findKrakenFish);
  });

  test('Kraken 标出假设推导链上的候选和箭头', () {
    const puzzle =
        '024610007006070402003824560000200800301060024002001000069002100240130600130006240';
    final board = SudokuBoard.fromString(puzzle);
    SudokuHint? hint;
    for (var i = 0; i < 80; i++) {
      hint = SudokuSolver.getHint(board);
      if (hint == null) break;
      if (hint.technique == 'Kraken Fish') break;
      if (hint.isElimination) {
        for (final e in hint.eliminations) {
          board.eliminateCandidate(e.row, e.col, e.num);
        }
      } else {
        board.set(hint.row, hint.col, hint.value);
      }
    }
    expect(hint, isNotNull);
    expect(hint!.technique, 'Kraken Fish');
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.link),
      isNotEmpty,
      reason: '推导过程应标在候选上，不能只洗格子',
    );
    expect(
      hint.links.where((a) => a.kind == ArrowKind.weak),
      isNotEmpty,
      reason: '假设推出的每一步应有箭头',
    );
    expect(hint.explanation, contains('→'));
  });

  test('Nishio 标出假设后推出的候选链', () {
    final hint = AdvancedTechniques.findNishio(_board('nishio'));
    expect(hint, isNotNull);
    expect(
      hint!.patternCandidates.where((c) => c.role == HintRole.link),
      isNotEmpty,
    );
    expect(hint.links, isNotEmpty);
  });

  test('Forcing Chain 教学盘面推出公共填数', () {
    final hint = AdvancedTechniques.findForcingChain(_board('forcing_chain'));
    expect(hint, isNotNull);
    expect(hint!.technique, 'Forcing Chain');
    expect(hint.isElimination, isFalse);
    expect(hint.value, inInclusiveRange(1, 9));
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.link),
      isNotEmpty,
    );
    expect(hint.links, isNotEmpty);
  });

  test('Forcing Net 教学盘面推出公共填数', () {
    final hint = AdvancedTechniques.findForcingNet(_board('forcing_net'));
    expect(hint, isNotNull);
    expect(hint!.technique, 'Forcing Net');
    expect(hint.row, 4);
    expect(hint.col, 2);
    expect(hint.value, 1);
    expect(
      hint.patternCandidates.where((c) => c.role == HintRole.link),
      isNotEmpty,
    );
    expect(hint.links, isNotEmpty);
  });

  test('有 XY-Chain 时 getHint 不先报 Grouped AIC / ALS', () {
    final board = _board('xy_chain');
    final hint = AdvancedTechniques.findXyChain(board);
    expect(hint, isNotNull);
    final fromHint = SudokuSolver.getHint(board);
    expect(fromHint, isNotNull);
    expect(
      const {'Grouped AIC', 'ALS-XZ', 'ALS-XY-Wing', 'Nishio'}
          .contains(fromHint!.technique),
      isFalse,
      reason: '已有更浅的链/基础技巧时不该先甩重器，实际是 ${fromHint.technique}',
    );
    if (fromHint.technique == 'XY-Chain') {
      expect(
          _elimKeys(fromHint).containsAll(_teachingElims('xy_chain')), isTrue);
    }
  });
}
