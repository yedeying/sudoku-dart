import '../models/board_markup.dart';
import '../models/notation.dart';
import '../models/sudoku_board.dart';
import 'advanced_techniques.dart';

enum HintRole { pattern, cover, extra, link, target }

class HintCell {
  final int row;
  final int col;
  final HintRole role;

  const HintCell(this.row, this.col, this.role);
}

class HintCandidate {
  final CandidateRef ref;
  final HintRole role;

  const HintCandidate(this.ref, this.role);
}

/// 一组格子（每个元素是 [row, col]）按同一角色标记。
List<HintCell> hintCells(HintRole role, Iterable<List<int>> cells) =>
    [for (final c in cells) HintCell(c[0], c[1], role)];

/// 一组格子上的同一个数字按同一角色标记。
List<HintCandidate> hintCands(
  HintRole role,
  int digit,
  Iterable<List<int>> cells,
) =>
    [
      for (final c in cells)
        HintCandidate(CandidateRef(c[0], c[1], digit), role)
    ];

/// 鱼身：基线与覆盖线交点上真正带该候选的格子。
List<List<int>> fishBody(
  SudokuBoard board,
  Iterable<int> rows,
  Iterable<int> cols,
  int num,
) =>
    [
      for (final r in rows)
        for (final c in cols)
          if (board.get(r, c) == 0 && board.getCandidates(r, c).contains(num))
            [r, c],
    ];

/// 单个格子上的多个数字按同一角色标记。
List<HintCandidate> hintDigits(
  HintRole role,
  List<int> cell,
  Iterable<int> digits,
) =>
    [
      for (final d in digits)
        HintCandidate(CandidateRef(cell[0], cell[1], d), role)
    ];

/// 表示一个可以在某格子上被删除的候选数字
class CandidateElim {
  final int row;
  final int col;
  final int num;

  CandidateElim(this.row, this.col, this.num);

  @override
  String toString() => '(${row + 1},${col + 1})≠$num';
}

/// 数独求解器，包含多种解题技巧
class SudokuSolver {
  /// 使用回溯法求解数独
  static bool solve(SudokuBoard board) {
    return _backtrack(board.board, 0, 0);
  }

  static bool _backtrack(List<List<int>> board, int row, int col) {
    // 找到下一个空格
    while (row < 9) {
      while (col < 9 && board[row][col] != 0) {
        col++;
      }
      if (col < 9) break;
      col = 0;
      row++;
    }

    // 如果没有空格了，说明已经解决
    if (row == 9) return true;

    // 尝试填入 1-9
    for (int num = 1; num <= 9; num++) {
      if (_isValid(board, row, col, num)) {
        board[row][col] = num;

        if (_backtrack(board, row, col)) {
          return true;
        }

        board[row][col] = 0;
      }
    }

    return false;
  }

  static bool _isValid(List<List<int>> board, int row, int col, int num) {
    // 检查行
    for (int j = 0; j < 9; j++) {
      if (board[row][j] == num) return false;
    }

    // 检查列
    for (int i = 0; i < 9; i++) {
      if (board[i][col] == num) return false;
    }

    // 检查 3x3 宫格
    int boxRow = (row ~/ 3) * 3;
    int boxCol = (col ~/ 3) * 3;
    for (int i = boxRow; i < boxRow + 3; i++) {
      for (int j = boxCol; j < boxCol + 3; j++) {
        if (board[i][j] == num) return false;
      }
    }

    return true;
  }

  /// 获取解题提示
  ///
  /// 优先返回可以直接填入数字的技巧（Naked/Hidden Single），
  /// 然后是能够删除候选数字的逻辑技巧（返回 isElimination=true）。
  /// 找不到已实现的逻辑技巧时返回 null，绝不以回溯结果冒充提示。
  static final List<(String, SudokuHint? Function(SudokuBoard))> _hintFinders =
      [
    ('唯余法', _findNakedSingle),
    ('摒除法（行/列/宫）', _findHiddenSingle),
    ('显性数对', _findNakedPair),
    ('显性三数组', _findNakedTriple),
    ('隐性数对', AdvancedTechniques.findHiddenPair),
    ('宫区块', _findPointingPair),
    ('行/列区块', _findBoxLineReduction),
    ('隐性三数组', AdvancedTechniques.findHiddenTriple),
    ('显性四数组', AdvancedTechniques.findNakedQuad),
    ('X-Wing', _findXWing),
    ('隐性四数组', AdvancedTechniques.findHiddenQuad),
    ('摩天楼', AdvancedTechniques.findSkyscraper),
    ('双线风筝', AdvancedTechniques.findTwoStringKite),
    ('Swordfish', _findSwordfish),
    ('多宝鱼', AdvancedTechniques.findTurbotFish),
    ('带鳍 X-Wing', AdvancedTechniques.findFinnedXWing),
    ('刺身鱼', AdvancedTechniques.findSashimiFish),
    ('空矩形', AdvancedTechniques.findEmptyRectangle),
    ('Jellyfish', AdvancedTechniques.findJellyfish),
    ('XY-Wing', _findXYWing),
    ('唯一矩形 1', AdvancedTechniques.findUniqueRectangleType1),
    ('不完整唯一矩形', AdvancedTechniques.findIncompleteUniqueRectangle),
    ('唯一矩形 2', AdvancedTechniques.findUniqueRectangleType2),
    ('BUG+1', AdvancedTechniques.findBugPlusOne),
    ('可规避矩形', AdvancedTechniques.findAvoidableRectangle),
    ('带鳍 Swordfish', AdvancedTechniques.findFinnedSwordfish),
    ('唯一矩形 4', AdvancedTechniques.findUniqueRectangleType4),
    ('隐性唯一矩形', AdvancedTechniques.findHiddenUniqueRectangle),
    ('BUG 类型 2', AdvancedTechniques.findBugType2),
    ('扩展矩形 1', AdvancedTechniques.findExtendedRectType1),
    ('XYZ-Wing', _findXYZWing),
    ('带鳍 Jellyfish', AdvancedTechniques.findFinnedJellyfish),
    ('扩展矩形 2', AdvancedTechniques.findExtendedRectType2),
    ('唯一矩形 3', AdvancedTechniques.findUniqueRectangleType3),
    ('BUG 类型 4', AdvancedTechniques.findBugType4),
    ('扩展矩形 4', AdvancedTechniques.findExtendedRectType4),
    ('扩展矩形 3', AdvancedTechniques.findExtendedRectType3),
    ('唯一环 1', AdvancedTechniques.findUniqueLoopType1),
    ('BUG 类型 3', AdvancedTechniques.findBugType3),
    ('唯一环 2', AdvancedTechniques.findUniqueLoopType2),
    ('Franken 鱼', AdvancedTechniques.findFrankenFish),
    ('唯一环 4', AdvancedTechniques.findUniqueLoopType4),
    ('Simple Coloring', AdvancedTechniques.findSimpleColoring),
    // 唯一环 3 是这一族里最重的一手（7.2），比 Simple Coloring（7.0）还深，
    // 所以排在它后面；顺序必须跟难度分同向，见 hint_order_monotonic_test。
    ('唯一环 3', AdvancedTechniques.findUniqueLoopType3),
    ('探长', AdvancedTechniques.findBorescoper),
    ('淑芬', AdvancedTechniques.findQiu),
    ('W-Wing', AdvancedTechniques.findWWing),
    ('XY-Chain', AdvancedTechniques.findXyChain),
    ('WXYZ-Wing', AdvancedTechniques.findWxyzWing),
    ('AIC 开链', AdvancedTechniques.findAic),
    ('Sue de Coq', AdvancedTechniques.findSueDeCoq),
    ('Nice Loop / AIC 环', AdvancedTechniques.findNiceLoop),
    ('Grouped AIC', AdvancedTechniques.findGroupedAic),
    ('死环', AdvancedTechniques.findDeadLoop),
    ('ALS-XZ', AdvancedTechniques.findAlsXz),
    ('DDS', AdvancedTechniques.findDds),
    ('Death Blossom', AdvancedTechniques.findDeathBlossom),
    ('WALS', AdvancedTechniques.findWals),
    ('Kraken Fish', AdvancedTechniques.findKrakenFish),
    // 毛刺数组「毛刺为真」那一支是把唯余摒除推到推不动为止，力度和强制链
    // 同级，不是 9.4 那一档的认形。排在 ALS-XZ 之前时它会把 ALS-XZ、
    // Death Blossom、Kraken 该出面的局面全抢走——题库 160 题里 Sue de Coq
    // 与 Death Blossom 一次都露不了面。所以按实际力度排在 Kraken 之后。
    ('毛刺数组', AdvancedTechniques.findBurredSubset),
    ('飞鱼导弹', AdvancedTechniques.findExocet),
    ('Forcing Chain', AdvancedTechniques.findForcingChain),
    ('ALS-XY-Wing', AdvancedTechniques.findAlsXyWing),
    ('Nishio', AdvancedTechniques.findNishio),
    ('Forcing Net', AdvancedTechniques.findForcingNet),
  ];

  /// 提示搜索的实际顺序，供顺序约束测试与诊断使用。
  static List<String> get hintSearchOrder =>
      List.unmodifiable(_hintFinders.map((entry) => entry.$1));

  static SudokuHint? getHint(SudokuBoard board) {
    for (final entry in _hintFinders) {
      final hint = entry.$2(board);
      if (hint != null) return hint;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 单元定义辅助
  // ---------------------------------------------------------------------------

  /// 返回所有 27 个单元（9 行 + 9 列 + 9 宫格）
  static List<_Unit> _allUnits() {
    List<_Unit> units = [];
    for (int r = 0; r < 9; r++) {
      units.add(_Unit('行', rowRef(r), [
        for (int c = 0; c < 9; c++) [r, c]
      ]));
    }
    for (int c = 0; c < 9; c++) {
      units.add(_Unit('列', colRef(c), [
        for (int r = 0; r < 9; r++) [r, c]
      ]));
    }
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        units.add(_Unit('宫', boxRef(br, bc), [
          for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++) [br * 3 + i, bc * 3 + j]
        ]));
      }
    }
    return units;
  }

  static bool _setEq(Set<int> a, Set<int> b) =>
      a.length == b.length && a.containsAll(b);

  // ---------------------------------------------------------------------------
  // 填数技巧
  // ---------------------------------------------------------------------------

  /// 唯一候选数：某个格子只有一个候选数字
  static SudokuHint? _findNakedSingle(SudokuBoard board) {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board.get(i, j) == 0) {
          var candidates = board.getCandidates(i, j);
          if (candidates.length == 1) {
            return SudokuHint(
              row: i,
              col: j,
              value: candidates.first,
              technique: '唯余法',
              explanation: '${cellRef(i, j)} 只能填 ${candidates.first}，'
                  '同行、同列、同宫已占满其它数字。',
              patternCells: [
                HintCell(i, j, HintRole.pattern),
                ...hintCells(
                  HintRole.link,
                  _blockingPeers(board, i, j, candidates.first),
                ),
              ],
              patternCandidates: [
                HintCandidate(
                  CandidateRef(i, j, candidates.first),
                  HintRole.pattern,
                ),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  /// 宫的说法：「宫格 1-2」这种编号没人看得懂，直接说它占哪几行哪几列。
  static String _boxLabel(int boxRow, int boxCol) => boxRef(boxRow, boxCol);

  /// 唯一候选数的依据：每个被排除的数字，各找一个已填的同行/列/宫格子作为见证。
  static List<List<int>> _blockingPeers(
    SudokuBoard board,
    int row,
    int col,
    int keep,
  ) {
    final peers = <List<int>>[
      for (int c = 0; c < 9; c++)
        if (c != col) [row, c],
      for (int r = 0; r < 9; r++)
        if (r != row) [r, col],
      for (int i = 0; i < 3; i++)
        for (int j = 0; j < 3; j++)
          if ((row ~/ 3) * 3 + i != row || (col ~/ 3) * 3 + j != col)
            [(row ~/ 3) * 3 + i, (col ~/ 3) * 3 + j],
    ];
    final witnesses = <int, List<int>>{};
    for (final p in peers) {
      final v = board.get(p[0], p[1]);
      if (v == 0 || v == keep) continue;
      witnesses.putIfAbsent(v, () => p);
    }
    return witnesses.values.toList();
  }

  /// 隐藏单元：某个数字在某行/列/宫格中只能放在一个位置
  static SudokuHint? _findHiddenSingle(SudokuBoard board) {
    for (int row = 0; row < 9; row++) {
      var hint = _findHiddenSingleInRow(board, row);
      if (hint != null) return hint;
    }
    for (int col = 0; col < 9; col++) {
      var hint = _findHiddenSingleInColumn(board, col);
      if (hint != null) return hint;
    }
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        var hint = _findHiddenSingleInBox(board, boxRow, boxCol);
        if (hint != null) return hint;
      }
    }
    return null;
  }

  static SudokuHint? _findHiddenSingleInRow(SudokuBoard board, int row) {
    for (int num = 1; num <= 9; num++) {
      List<int> possibleCols = [];
      for (int col = 0; col < 9; col++) {
        if (board.get(row, col) == 0 &&
            board.getCandidates(row, col).contains(num)) {
          possibleCols.add(col);
        }
      }
      if (possibleCols.length == 1) {
        return SudokuHint(
          row: row,
          col: possibleCols[0],
          value: num,
          technique: '摒除法（行/列/宫）',
          explanation:
              '${rowRef(row)} 上数字 $num 只能放在 ${cellRef(row, possibleCols[0])}。',
          patternCells: [
            HintCell(row, possibleCols[0], HintRole.pattern),
            ...hintCells(HintRole.link, [
              for (int c = 0; c < 9; c++)
                if (c != possibleCols[0]) [row, c],
            ]),
          ],
          patternCandidates: [
            HintCandidate(
              CandidateRef(row, possibleCols[0], num),
              HintRole.pattern,
            ),
          ],
        );
      }
    }
    return null;
  }

  static SudokuHint? _findHiddenSingleInColumn(SudokuBoard board, int col) {
    for (int num = 1; num <= 9; num++) {
      List<int> possibleRows = [];
      for (int row = 0; row < 9; row++) {
        if (board.get(row, col) == 0 &&
            board.getCandidates(row, col).contains(num)) {
          possibleRows.add(row);
        }
      }
      if (possibleRows.length == 1) {
        return SudokuHint(
          row: possibleRows[0],
          col: col,
          value: num,
          technique: '摒除法（行/列/宫）',
          explanation:
              '${colRef(col)} 上数字 $num 只能放在 ${cellRef(possibleRows[0], col)}。',
          patternCells: [
            HintCell(possibleRows[0], col, HintRole.pattern),
            ...hintCells(HintRole.link, [
              for (int r = 0; r < 9; r++)
                if (r != possibleRows[0]) [r, col],
            ]),
          ],
          patternCandidates: [
            HintCandidate(
              CandidateRef(possibleRows[0], col, num),
              HintRole.pattern,
            ),
          ],
        );
      }
    }
    return null;
  }

  static SudokuHint? _findHiddenSingleInBox(
      SudokuBoard board, int boxRow, int boxCol) {
    int startRow = boxRow * 3;
    int startCol = boxCol * 3;
    for (int num = 1; num <= 9; num++) {
      List<List<int>> possibleCells = [];
      for (int i = startRow; i < startRow + 3; i++) {
        for (int j = startCol; j < startCol + 3; j++) {
          if (board.get(i, j) == 0 && board.getCandidates(i, j).contains(num)) {
            possibleCells.add([i, j]);
          }
        }
      }
      if (possibleCells.length == 1) {
        return SudokuHint(
          row: possibleCells[0][0],
          col: possibleCells[0][1],
          value: num,
          technique: '摒除法（行/列/宫）',
          explanation: '${_boxLabel(boxRow, boxCol)} 上数字 $num 只能放在 '
              '${cellRef(possibleCells[0][0], possibleCells[0][1])}。',
          patternCells: [
            HintCell(
                possibleCells[0][0], possibleCells[0][1], HintRole.pattern),
            ...hintCells(HintRole.link, [
              for (int i = startRow; i < startRow + 3; i++)
                for (int j = startCol; j < startCol + 3; j++)
                  if (i != possibleCells[0][0] || j != possibleCells[0][1])
                    [i, j],
            ]),
          ],
          patternCandidates: [
            HintCandidate(
              CandidateRef(possibleCells[0][0], possibleCells[0][1], num),
              HintRole.pattern,
            ),
          ],
        );
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Naked Subsets（删除候选数）
  // ---------------------------------------------------------------------------

  /// 数字对（Naked Pair）：单元中两个格子只有相同的两个候选数字，
  /// 则可以从单元内其他格子删除这两个数字。
  static SudokuHint? _findNakedPair(SudokuBoard board) {
    for (final u in _allUnits()) {
      var cells = u.cells.where((c) => board.get(c[0], c[1]) == 0).toList();
      for (int i = 0; i < cells.length; i++) {
        var ci = board.getCandidates(cells[i][0], cells[i][1]);
        if (ci.length != 2) continue;
        for (int j = i + 1; j < cells.length; j++) {
          var cj = board.getCandidates(cells[j][0], cells[j][1]);
          if (cj.length != 2) continue;
          if (!_setEq(ci, cj)) continue;

          List<CandidateElim> elims = [];
          for (final c in cells) {
            if ((c[0] == cells[i][0] && c[1] == cells[i][1]) ||
                (c[0] == cells[j][0] && c[1] == cells[j][1])) {
              continue;
            }
            var cand = board.getCandidates(c[0], c[1]);
            for (final n in ci) {
              if (cand.contains(n)) elims.add(CandidateElim(c[0], c[1], n));
            }
          }
          if (elims.isNotEmpty) {
            return SudokuHint.elimination(
              technique: '显性数对',
              explanation:
                  '${u.label} 中 ${cellRef(cells[i][0], cells[i][1])} 和 '
                  '${cellRef(cells[j][0], cells[j][1])} 形成数对 '
                  '${ci.toList()..sort()}，可从该单元其它格删除这两个数字。',
              eliminations: elims,
              patternCells: hintCells(HintRole.pattern, [cells[i], cells[j]]),
              patternCandidates: [
                ...hintDigits(HintRole.pattern, cells[i], ci),
                ...hintDigits(HintRole.pattern, cells[j], cj),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  /// 数字三元组（Naked Triple）：单元中三个格子候选数的并集恰好只有三个数字。
  static SudokuHint? _findNakedTriple(SudokuBoard board) {
    for (final u in _allUnits()) {
      var cells = u.cells
          .where((c) =>
              board.get(c[0], c[1]) == 0 &&
              board.getCandidates(c[0], c[1]).length >= 2 &&
              board.getCandidates(c[0], c[1]).length <= 3)
          .toList();
      for (int i = 0; i < cells.length; i++) {
        for (int j = i + 1; j < cells.length; j++) {
          for (int k = j + 1; k < cells.length; k++) {
            var union = board
                .getCandidates(cells[i][0], cells[i][1])
                .union(board.getCandidates(cells[j][0], cells[j][1]))
                .union(board.getCandidates(cells[k][0], cells[k][1]));
            if (union.length != 3) continue;

            // 从单元内所有非三元组成员的空格中删除三元组数字
            List<CandidateElim> elims = [];
            for (final c in u.cells) {
              if (board.get(c[0], c[1]) != 0) continue;
              bool isMember = (c[0] == cells[i][0] && c[1] == cells[i][1]) ||
                  (c[0] == cells[j][0] && c[1] == cells[j][1]) ||
                  (c[0] == cells[k][0] && c[1] == cells[k][1]);
              if (isMember) continue;
              var cand = board.getCandidates(c[0], c[1]);
              for (final n in union) {
                if (cand.contains(n)) elims.add(CandidateElim(c[0], c[1], n));
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '显性三数组',
                explanation: '${u.label} 中 '
                    '${cellRef(cells[i][0], cells[i][1])}、'
                    '${cellRef(cells[j][0], cells[j][1])}、'
                    '${cellRef(cells[k][0], cells[k][1])} '
                    '形成三数组 ${union.toList()..sort()}，'
                    '可从该单元其它格删除这些数字。',
                eliminations: elims,
                patternCells: hintCells(
                  HintRole.pattern,
                  [cells[i], cells[j], cells[k]],
                ),
                patternCandidates: [
                  for (final c in [cells[i], cells[j], cells[k]])
                    ...hintDigits(
                      HintRole.pattern,
                      c,
                      board.getCandidates(c[0], c[1]),
                    ),
                ],
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 区块删减
  // ---------------------------------------------------------------------------

  /// 指向对（Pointing）：宫格内某数字只在同一行/列，可从该行/列其他位置删除
  static SudokuHint? _findPointingPair(SudokuBoard board) {
    for (int boxRow = 0; boxRow < 3; boxRow++) {
      for (int boxCol = 0; boxCol < 3; boxCol++) {
        int startRow = boxRow * 3;
        int startCol = boxCol * 3;
        for (int num = 1; num <= 9; num++) {
          List<List<int>> positions = [];
          for (int i = startRow; i < startRow + 3; i++) {
            for (int j = startCol; j < startCol + 3; j++) {
              if (board.get(i, j) == 0 &&
                  board.getCandidates(i, j).contains(num)) {
                positions.add([i, j]);
              }
            }
          }
          if (positions.length < 2 || positions.length > 3) continue;

          // 同一行
          if (positions.every((p) => p[0] == positions[0][0])) {
            int row = positions[0][0];
            List<CandidateElim> elims = [];
            for (int col = 0; col < 9; col++) {
              if (col >= startCol && col < startCol + 3) continue;
              if (board.get(row, col) == 0 &&
                  board.getCandidates(row, col).contains(num)) {
                elims.add(CandidateElim(row, col, num));
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '宫区块',
                explanation: '${_boxLabel(boxRow, boxCol)} 里数字 $num 只落在 '
                    '${rowRef(row)} 的 ${cellsList(positions)}。'
                    '该宫的 $num 必在 ${rowRef(row)}，故 ${rowRef(row)} 宫外的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(HintRole.pattern, positions),
                patternCandidates: hintCands(
                  HintRole.pattern,
                  num,
                  positions,
                ),
              );
            }
          }

          // 同一列
          if (positions.every((p) => p[1] == positions[0][1])) {
            int col = positions[0][1];
            List<CandidateElim> elims = [];
            for (int row = 0; row < 9; row++) {
              if (row >= startRow && row < startRow + 3) continue;
              if (board.get(row, col) == 0 &&
                  board.getCandidates(row, col).contains(num)) {
                elims.add(CandidateElim(row, col, num));
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '宫区块',
                explanation: '${_boxLabel(boxRow, boxCol)} 里数字 $num 只落在 '
                    '${colRef(col)} 的 ${cellsList(positions)}。'
                    '该宫的 $num 必在 ${colRef(col)}，故 ${colRef(col)} 宫外的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(HintRole.pattern, positions),
                patternCandidates: hintCands(
                  HintRole.pattern,
                  num,
                  positions,
                ),
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// 盒线削减（Box/Line Reduction）：某数字在行/列中只出现在一个宫格，
  /// 可从该宫格的其他位置删除。
  static SudokuHint? _findBoxLineReduction(SudokuBoard board) {
    // 行
    for (int row = 0; row < 9; row++) {
      for (int num = 1; num <= 9; num++) {
        List<int> cols = [];
        for (int col = 0; col < 9; col++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            cols.add(col);
          }
        }
        if (cols.length < 2 || cols.length > 3) continue;
        int boxCol = cols[0] ~/ 3;
        if (!cols.every((c) => c ~/ 3 == boxCol)) continue;

        int boxRow = row ~/ 3;
        int startRow = boxRow * 3;
        int startCol = boxCol * 3;
        List<CandidateElim> elims = [];
        for (int i = startRow; i < startRow + 3; i++) {
          if (i == row) continue;
          for (int j = startCol; j < startCol + 3; j++) {
            if (board.get(i, j) == 0 &&
                board.getCandidates(i, j).contains(num)) {
              elims.add(CandidateElim(i, j, num));
            }
          }
        }
        if (elims.isNotEmpty) {
          return SudokuHint.elimination(
            technique: '行/列区块',
            explanation: '${rowRef(row)} 的数字 $num 只落在 '
                '${_boxLabel(boxRow, boxCol)} 的 '
                '${cols.map((c) => cellRef(row, c)).join(', ')}。'
                '该行 $num 必在此宫，故宫内其它行的 $num 可删。',
            eliminations: elims,
            patternCells: hintCells(HintRole.pattern, [
              for (final c in cols) [row, c],
            ]),
            patternCandidates: hintCands(HintRole.pattern, num, [
              for (final c in cols) [row, c],
            ]),
          );
        }
      }
    }

    // 列
    for (int col = 0; col < 9; col++) {
      for (int num = 1; num <= 9; num++) {
        List<int> rows = [];
        for (int row = 0; row < 9; row++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            rows.add(row);
          }
        }
        if (rows.length < 2 || rows.length > 3) continue;
        int boxRow = rows[0] ~/ 3;
        if (!rows.every((r) => r ~/ 3 == boxRow)) continue;

        int boxCol = col ~/ 3;
        int startRow = boxRow * 3;
        int startCol = boxCol * 3;
        List<CandidateElim> elims = [];
        for (int i = startRow; i < startRow + 3; i++) {
          for (int j = startCol; j < startCol + 3; j++) {
            if (j == col) continue;
            if (board.get(i, j) == 0 &&
                board.getCandidates(i, j).contains(num)) {
              elims.add(CandidateElim(i, j, num));
            }
          }
        }
        if (elims.isNotEmpty) {
          return SudokuHint.elimination(
            technique: '行/列区块',
            explanation: '${colRef(col)} 的数字 $num 只落在 '
                '${_boxLabel(boxRow, boxCol)} 的 '
                '${rows.map((r) => cellRef(r, col)).join(', ')}。'
                '该列 $num 必在此宫，故宫内其它列的 $num 可删。',
            eliminations: elims,
            patternCells: hintCells(HintRole.pattern, [
              for (final r in rows) [r, col],
            ]),
            patternCandidates: hintCands(HintRole.pattern, num, [
              for (final r in rows) [r, col],
            ]),
          );
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 鱼类技巧
  // ---------------------------------------------------------------------------

  /// X-Wing
  static SudokuHint? _findXWing(SudokuBoard board) {
    for (int num = 1; num <= 9; num++) {
      // 基于行
      List<MapEntry<int, List<int>>> rowsWithTwo = [];
      for (int row = 0; row < 9; row++) {
        List<int> cols = [];
        for (int col = 0; col < 9; col++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            cols.add(col);
          }
        }
        if (cols.length == 2) rowsWithTwo.add(MapEntry(row, cols));
      }
      for (int i = 0; i < rowsWithTwo.length; i++) {
        for (int j = i + 1; j < rowsWithTwo.length; j++) {
          if (rowsWithTwo[i].value[0] == rowsWithTwo[j].value[0] &&
              rowsWithTwo[i].value[1] == rowsWithTwo[j].value[1]) {
            int col1 = rowsWithTwo[i].value[0];
            int col2 = rowsWithTwo[i].value[1];
            int row1 = rowsWithTwo[i].key;
            int row2 = rowsWithTwo[j].key;
            List<CandidateElim> elims = [];
            for (int row = 0; row < 9; row++) {
              if (row == row1 || row == row2) continue;
              for (final col in [col1, col2]) {
                if (board.get(row, col) == 0 &&
                    board.getCandidates(row, col).contains(num)) {
                  elims.add(CandidateElim(row, col, num));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: 'X-Wing',
                explanation: '数字 $num 在 ${rowRef(row1)},${rowRef(row2)} '
                    '只出现于 ${colRef(col1)},${colRef(col2)}，形成 X-Wing，'
                    '这两列其它位置的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(HintRole.pattern, [
                  [row1, col1],
                  [row1, col2],
                  [row2, col1],
                  [row2, col2],
                ]),
                patternCandidates: hintCands(HintRole.pattern, num, [
                  [row1, col1],
                  [row1, col2],
                  [row2, col1],
                  [row2, col2],
                ]),
                links: [
                  _strong(row1, col1, row1, col2, num),
                  _strong(row2, col1, row2, col2, num),
                ],
                highlightRows: [row1, row2],
              );
            }
          }
        }
      }

      // 基于列
      List<MapEntry<int, List<int>>> colsWithTwo = [];
      for (int col = 0; col < 9; col++) {
        List<int> rows = [];
        for (int row = 0; row < 9; row++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            rows.add(row);
          }
        }
        if (rows.length == 2) colsWithTwo.add(MapEntry(col, rows));
      }
      for (int i = 0; i < colsWithTwo.length; i++) {
        for (int j = i + 1; j < colsWithTwo.length; j++) {
          if (colsWithTwo[i].value[0] == colsWithTwo[j].value[0] &&
              colsWithTwo[i].value[1] == colsWithTwo[j].value[1]) {
            int row1 = colsWithTwo[i].value[0];
            int row2 = colsWithTwo[i].value[1];
            int col1 = colsWithTwo[i].key;
            int col2 = colsWithTwo[j].key;
            List<CandidateElim> elims = [];
            for (int col = 0; col < 9; col++) {
              if (col == col1 || col == col2) continue;
              for (final row in [row1, row2]) {
                if (board.get(row, col) == 0 &&
                    board.getCandidates(row, col).contains(num)) {
                  elims.add(CandidateElim(row, col, num));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: 'X-Wing',
                explanation: '数字 $num 在 ${colRef(col1)},${colRef(col2)} '
                    '只出现于 ${rowRef(row1)},${rowRef(row2)}，形成 X-Wing，'
                    '这两行其它位置的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(HintRole.pattern, [
                  [row1, col1],
                  [row2, col1],
                  [row1, col2],
                  [row2, col2],
                ]),
                patternCandidates: hintCands(HintRole.pattern, num, [
                  [row1, col1],
                  [row2, col1],
                  [row1, col2],
                  [row2, col2],
                ]),
                links: [
                  _strong(row1, col1, row2, col1, num),
                  _strong(row1, col2, row2, col2, num),
                ],
                highlightCols: [col1, col2],
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// 基线上的强链：这一行/列里该数字只剩这两格，必有其一。
  static MarkupArrow _strong(int r1, int c1, int r2, int c2, int num) =>
      MarkupArrow(
        from: CandidateRef(r1, c1, num),
        to: CandidateRef(r2, c2, num),
        kind: ArrowKind.strong,
      );

  /// Swordfish
  static SudokuHint? _findSwordfish(SudokuBoard board) {
    for (int num = 1; num <= 9; num++) {
      // 基于行
      List<MapEntry<int, List<int>>> rowsWith = [];
      for (int row = 0; row < 9; row++) {
        List<int> cols = [];
        for (int col = 0; col < 9; col++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            cols.add(col);
          }
        }
        if (cols.length == 2 || cols.length == 3) {
          rowsWith.add(MapEntry(row, cols));
        }
      }
      for (int i = 0; i < rowsWith.length; i++) {
        for (int j = i + 1; j < rowsWith.length; j++) {
          for (int k = j + 1; k < rowsWith.length; k++) {
            var allCols = rowsWith[i]
                .value
                .toSet()
                .union(rowsWith[j].value.toSet())
                .union(rowsWith[k].value.toSet());
            if (allCols.length != 3) continue;
            var rows = [rowsWith[i].key, rowsWith[j].key, rowsWith[k].key];
            List<CandidateElim> elims = [];
            for (int row = 0; row < 9; row++) {
              if (rows.contains(row)) continue;
              for (final col in allCols) {
                if (board.get(row, col) == 0 &&
                    board.getCandidates(row, col).contains(num)) {
                  elims.add(CandidateElim(row, col, num));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: 'Swordfish',
                explanation: '数字 $num 在 ${rowsList(rows)} 形成 Swordfish'
                    '（列 ${colsList(allCols)}），这些列其它位置的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(
                  HintRole.pattern,
                  fishBody(board, rows, allCols, num),
                ),
                patternCandidates: hintCands(
                  HintRole.pattern,
                  num,
                  fishBody(board, rows, allCols, num),
                ),
                highlightRows: rows,
              );
            }
          }
        }
      }

      // 基于列
      List<MapEntry<int, List<int>>> colsWith = [];
      for (int col = 0; col < 9; col++) {
        List<int> rows = [];
        for (int row = 0; row < 9; row++) {
          if (board.get(row, col) == 0 &&
              board.getCandidates(row, col).contains(num)) {
            rows.add(row);
          }
        }
        if (rows.length == 2 || rows.length == 3) {
          colsWith.add(MapEntry(col, rows));
        }
      }
      for (int i = 0; i < colsWith.length; i++) {
        for (int j = i + 1; j < colsWith.length; j++) {
          for (int k = j + 1; k < colsWith.length; k++) {
            var allRows = colsWith[i]
                .value
                .toSet()
                .union(colsWith[j].value.toSet())
                .union(colsWith[k].value.toSet());
            if (allRows.length != 3) continue;
            var cols = [colsWith[i].key, colsWith[j].key, colsWith[k].key];
            List<CandidateElim> elims = [];
            for (int col = 0; col < 9; col++) {
              if (cols.contains(col)) continue;
              for (final row in allRows) {
                if (board.get(row, col) == 0 &&
                    board.getCandidates(row, col).contains(num)) {
                  elims.add(CandidateElim(row, col, num));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: 'Swordfish',
                explanation: '数字 $num 在 ${colsList(cols)} 形成 Swordfish'
                    '（行 ${rowsList(allRows)}），这些行其它位置的 $num 可删。',
                eliminations: elims,
                patternCells: hintCells(
                  HintRole.pattern,
                  fishBody(board, allRows, cols, num),
                ),
                patternCandidates: hintCands(
                  HintRole.pattern,
                  num,
                  fishBody(board, allRows, cols, num),
                ),
                highlightCols: cols,
              );
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Wing 技巧
  // ---------------------------------------------------------------------------

  /// XY-Wing
  static SudokuHint? _findXYWing(SudokuBoard board) {
    List<Map<String, dynamic>> biValueCells = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board.get(i, j) == 0) {
          var candidates = board.getCandidates(i, j);
          if (candidates.length == 2) {
            biValueCells.add({
              'row': i,
              'col': j,
              'candidates': candidates.toList()..sort(),
            });
          }
        }
      }
    }

    for (int p = 0; p < biValueCells.length; p++) {
      var pivot = biValueCells[p];
      int pRow = pivot['row'];
      int pCol = pivot['col'];
      List<int> pCands = pivot['candidates'];

      for (int w1 = 0; w1 < biValueCells.length; w1++) {
        if (w1 == p) continue;
        var wing1 = biValueCells[w1];
        int w1Row = wing1['row'];
        int w1Col = wing1['col'];
        List<int> w1Cands = wing1['candidates'];

        if (!_canSee(pRow, pCol, w1Row, w1Col)) continue;
        var common1 = pCands.toSet().intersection(w1Cands.toSet());
        if (common1.length != 1) continue;

        for (int w2 = w1 + 1; w2 < biValueCells.length; w2++) {
          if (w2 == p) continue;
          var wing2 = biValueCells[w2];
          int w2Row = wing2['row'];
          int w2Col = wing2['col'];
          List<int> w2Cands = wing2['candidates'];

          if (!_canSee(pRow, pCol, w2Row, w2Col)) continue;
          var common2 = pCands.toSet().intersection(w2Cands.toSet());
          if (common2.length != 1) continue;
          if (common1.first == common2.first) continue;

          var z1 = w1Cands.toSet().difference(pCands.toSet());
          var z2 = w2Cands.toSet().difference(pCands.toSet());
          if (z1.length != 1 || z2.length != 1) continue;
          if (z1.first != z2.first) continue;

          int z = z1.first;
          List<CandidateElim> elims = [];
          for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
              if (board.get(i, j) != 0) continue;
              if (i == pRow && j == pCol) continue;
              if (i == w1Row && j == w1Col) continue;
              if (i == w2Row && j == w2Col) continue;
              if (_canSee(i, j, w1Row, w1Col) &&
                  _canSee(i, j, w2Row, w2Col) &&
                  board.getCandidates(i, j).contains(z)) {
                elims.add(CandidateElim(i, j, z));
              }
            }
          }
          if (elims.isNotEmpty) {
            return SudokuHint.elimination(
              technique: 'XY-Wing',
              explanation: '${cellRef(pRow, pCol)} 是支点（候选 '
                  '${pCands.join('、')}），两翼 ${cellRef(w1Row, w1Col)} 和 '
                  '${cellRef(w2Row, w2Col)} 各带一个 $z。'
                  '支点填哪个数都会逼出一翼的 $z，'
                  '同时看见两翼处的 $z 可删。',
              eliminations: elims,
              patternCells: [
                HintCell(pRow, pCol, HintRole.extra),
                ...hintCells(HintRole.pattern, [
                  [w1Row, w1Col],
                  [w2Row, w2Col],
                ]),
              ],
              patternCandidates: [
                ...hintDigits(HintRole.extra, [pRow, pCol], pCands),
                ...hintCands(HintRole.pattern, z, [
                  [w1Row, w1Col],
                  [w2Row, w2Col],
                ]),
              ],
              links: [
                _weak(pRow, pCol, common1.first, w1Row, w1Col, common1.first),
                _weak(pRow, pCol, common2.first, w2Row, w2Col, common2.first),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  /// XYZ-Wing
  static SudokuHint? _findXYZWing(SudokuBoard board) {
    for (int pRow = 0; pRow < 9; pRow++) {
      for (int pCol = 0; pCol < 9; pCol++) {
        if (board.get(pRow, pCol) != 0) continue;
        var pCands = board.getCandidates(pRow, pCol);
        if (pCands.length != 3) continue;

        List<Map<String, dynamic>> wings = [];
        for (int i = 0; i < 9; i++) {
          for (int j = 0; j < 9; j++) {
            if (board.get(i, j) == 0 && (i != pRow || j != pCol)) {
              var candidates = board.getCandidates(i, j);
              if (candidates.length == 2 &&
                  candidates.difference(pCands).isEmpty &&
                  _canSee(pRow, pCol, i, j)) {
                wings.add({'row': i, 'col': j, 'candidates': candidates});
              }
            }
          }
        }

        for (int w1 = 0; w1 < wings.length; w1++) {
          for (int w2 = w1 + 1; w2 < wings.length; w2++) {
            var wing1 = wings[w1];
            var wing2 = wings[w2];
            Set<int> w1Cands = Set<int>.from(wing1['candidates']);
            Set<int> w2Cands = Set<int>.from(wing2['candidates']);

            var union = Set<int>.from(pCands).union(w1Cands).union(w2Cands);
            if (union.length != 3) continue;
            var common = pCands.intersection(w1Cands).intersection(w2Cands);
            if (common.length != 1) continue;
            int z = common.first;

            int w1Row = wing1['row'];
            int w1Col = wing1['col'];
            int w2Row = wing2['row'];
            int w2Col = wing2['col'];

            List<CandidateElim> elims = [];
            for (int i = 0; i < 9; i++) {
              for (int j = 0; j < 9; j++) {
                if (board.get(i, j) != 0) continue;
                if (i == pRow && j == pCol) continue;
                if (i == w1Row && j == w1Col) continue;
                if (i == w2Row && j == w2Col) continue;
                if (_canSee(i, j, pRow, pCol) &&
                    _canSee(i, j, w1Row, w1Col) &&
                    _canSee(i, j, w2Row, w2Col) &&
                    board.getCandidates(i, j).contains(z)) {
                  elims.add(CandidateElim(i, j, z));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: 'XYZ-Wing',
                explanation: '${cellRef(pRow, pCol)} 是支点（候选 '
                    '${(pCands.toList()..sort()).join('、')}），两翼 '
                    '${cellRef(w1Row, w1Col)} 和 ${cellRef(w2Row, w2Col)} '
                    '都带 $z。三格中 $z 必有其一，'
                    '同时看见这三格处的 $z 可删。',
                eliminations: elims,
                patternCells: [
                  HintCell(pRow, pCol, HintRole.extra),
                  ...hintCells(HintRole.pattern, [
                    [w1Row, w1Col],
                    [w2Row, w2Col],
                  ]),
                ],
                patternCandidates: [
                  ...hintDigits(HintRole.extra, [pRow, pCol], pCands),
                  ...hintCands(HintRole.pattern, z, [
                    [w1Row, w1Col],
                    [w2Row, w2Col],
                  ]),
                ],
                links: [
                  _weak(pRow, pCol, z, w1Row, w1Col, z),
                  _weak(pRow, pCol, z, w2Row, w2Col, z),
                ],
              );
            }
          }
        }
      }
    }
    return null;
  }

  /// 弱链：两个位置互相可见，同一个数字不能同时成立。
  static MarkupArrow _weak(
    int r1,
    int c1,
    int n1,
    int r2,
    int c2,
    int n2,
  ) =>
      MarkupArrow(
        from: CandidateRef(r1, c1, n1),
        to: CandidateRef(r2, c2, n2),
        kind: ArrowKind.weak,
      );

  /// 检查两个格子是否互相可见（同行、同列或同宫格）
  static bool _canSee(int r1, int c1, int r2, int c2) {
    if (r1 == r2 && c1 == c2) return false;
    if (r1 == r2 || c1 == c2) return true;
    return (r1 ~/ 3 == r2 ~/ 3) && (c1 ~/ 3 == c2 ~/ 3);
  }

  // ---------------------------------------------------------------------------
  // 唯一解判定
  // ---------------------------------------------------------------------------

  /// 检查数独是否有唯一解
  static bool hasUniqueSolution(SudokuBoard board) {
    return countSolutions(board, limit: 2) == 1;
  }

  /// 计算数独的解的数量（找到 [limit] 个后提前退出）
  static int countSolutions(SudokuBoard board, {int limit = 2}) {
    var grid = board.board.map((r) => List<int>.from(r)).toList();
    int count = 0;

    void recurse() {
      if (count >= limit) return;

      // 找到下一个空格
      int row = -1;
      int col = -1;
      for (int i = 0; i < 9 && row == -1; i++) {
        for (int j = 0; j < 9; j++) {
          if (grid[i][j] == 0) {
            row = i;
            col = j;
            break;
          }
        }
      }

      // 没有空格了，找到一个完整解
      if (row == -1) {
        count++;
        return;
      }

      for (int num = 1; num <= 9; num++) {
        if (_isValid(grid, row, col, num)) {
          grid[row][col] = num;
          recurse();
          grid[row][col] = 0;
          if (count >= limit) return;
        }
      }
    }

    recurse();
    return count;
  }

  // ---------------------------------------------------------------------------
  // 逐步解题
  // ---------------------------------------------------------------------------

  /// 获取解题过程（逐步演示）
  static List<SudokuStep> getSolutionSteps(SudokuBoard board) {
    return getLogicalSolveTrace(board).steps;
  }

  /// 运行当前已实现的逻辑技巧，并同时报告是否完整解出。
  static LogicalSolveTrace getLogicalSolveTrace(SudokuBoard board) {
    List<SudokuStep> steps = [];
    var tempBoard = board.copy();

    int guard = 0;
    while (!tempBoard.isComplete() && guard < 200) {
      guard++;
      var hint = getHint(tempBoard);
      if (hint == null) break;

      steps.add(SudokuStep(
        row: hint.row,
        col: hint.col,
        value: hint.value,
        technique: hint.technique,
        explanation: hint.explanation,
        boardState: tempBoard.toStringRepresentation(),
        isElimination: hint.isElimination,
      ));

      if (hint.isElimination) {
        bool changed = false;
        for (final e in hint.eliminations) {
          if (tempBoard.eliminateCandidate(e.row, e.col, e.num)) {
            changed = true;
          }
        }
        // 如果没有任何候选数被真正删除，说明陷入停滞，退出以防死循环
        if (!changed) break;
      } else {
        tempBoard.set(hint.row, hint.col, hint.value);
      }
    }

    return LogicalSolveTrace(
      steps: steps,
      completed: tempBoard.isComplete(),
    );
  }
}

/// 单元（行/列/宫格）
class _Unit {
  final String type; // '行' / '列' / '宫格'
  final String label; // 用于说明文本
  final List<List<int>> cells;

  _Unit(this.type, this.label, this.cells);
}

/// 解题提示
///
/// 兼容两类提示：
/// - 填数提示（isElimination == false）：在 (row, col) 填入 value。
/// - 删除候选提示（isElimination == true）：删除 [eliminations] 中列出的候选数字，
///   此时 row/col/value 指向第一个被删除的候选，仅用于界面定位展示。
class SudokuHint {
  final int row;
  final int col;
  final int value;
  final String technique;
  final String explanation;
  final bool isElimination;
  final List<CandidateElim> eliminations;
  final List<HintCell> patternCells;
  final List<HintCandidate> patternCandidates;
  final List<MarkupArrow> links;
  final List<int> highlightRows;
  final List<int> highlightCols;

  /// 要淡亮的宫，编号 0–8，按行优先。
  ///
  /// 有些技巧的关键房屋就是一个宫——虚拟格数组配在宫里、底数被锁在宫里，
  /// 只标行列就把这一手最要紧的那块地方漏掉了。
  final List<int> highlightBoxes;

  SudokuHint({
    required this.row,
    required this.col,
    required this.value,
    required this.technique,
    required this.explanation,
    this.isElimination = false,
    this.eliminations = const [],
    this.patternCells = const [],
    this.patternCandidates = const [],
    this.links = const [],
    this.highlightRows = const [],
    this.highlightCols = const [],
    this.highlightBoxes = const [],
  });

  /// 构造一个删除候选数字的提示
  factory SudokuHint.elimination({
    required String technique,
    required String explanation,
    required List<CandidateElim> eliminations,
    List<HintCell> patternCells = const [],
    List<HintCandidate> patternCandidates = const [],
    List<MarkupArrow> links = const [],
    List<int> highlightRows = const [],
    List<int> highlightCols = const [],
    List<int> highlightBoxes = const [],
  }) {
    final first = eliminations.first;
    return SudokuHint(
      row: first.row,
      col: first.col,
      value: first.num,
      technique: technique,
      explanation: explanation,
      isElimination: true,
      eliminations: eliminations,
      patternCells: patternCells,
      patternCandidates: patternCandidates,
      links: links,
      highlightRows: highlightRows,
      highlightCols: highlightCols,
      highlightBoxes: highlightBoxes,
    );
  }
}

/// 解题步骤（用于演示）
class SudokuStep {
  final int row;
  final int col;
  final int value;
  final String technique;
  final String explanation;
  final String boardState;
  final bool isElimination;

  SudokuStep({
    required this.row,
    required this.col,
    required this.value,
    required this.technique,
    required this.explanation,
    required this.boardState,
    this.isElimination = false,
  });
}

class LogicalSolveTrace {
  final List<SudokuStep> steps;
  final bool completed;

  const LogicalSolveTrace({
    required this.steps,
    required this.completed,
  });
}
