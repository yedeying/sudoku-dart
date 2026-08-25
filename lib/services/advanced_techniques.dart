import '../models/board_markup.dart';
import '../models/notation.dart';
import '../models/sudoku_board.dart';
import 'sudoku_solver.dart';

/// 高级数独解题技巧扩展
class AdvancedTechniques {
  // ---------------------------------------------------------------------------
  // 通用辅助
  // ---------------------------------------------------------------------------

  /// 两个格子是否互相可见（同行、同列或同宫格）
  static bool _canSee(int r1, int c1, int r2, int c2) {
    if (r1 == r2 && c1 == c2) return false;
    if (r1 == r2 || c1 == c2) return true;
    return (r1 ~/ 3 == r2 ~/ 3) && (c1 ~/ 3 == c2 ~/ 3);
  }

  static List<HintCell> _targetCells(List<CandidateElim> elims) =>
      [for (final e in elims) HintCell(e.row, e.col, HintRole.target)];

  static List<HintCandidate> _targetCands(List<CandidateElim> elims) => [
        for (final e in elims)
          HintCandidate(CandidateRef(e.row, e.col, e.num), HintRole.target)
      ];

  /// 返回所有 27 个单元（行/列/宫格）
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

  static Iterable<List<T>> _combinations<T>(List<T> items, int size) sync* {
    if (size == 0) {
      yield <T>[];
      return;
    }
    for (var i = 0; i <= items.length - size; i++) {
      for (final tail in _combinations(items.sublist(i + 1), size - 1)) {
        yield [items[i], ...tail];
      }
    }
  }

  // ---------------------------------------------------------------------------
  // Naked Quad - 显性四元组
  // ---------------------------------------------------------------------------

  static SudokuHint? findNakedQuad(SudokuBoard board) {
    for (final unit in _allUnits()) {
      final cells = unit.cells.where((cell) {
        if (board.get(cell[0], cell[1]) != 0) return false;
        final count = board.getCandidates(cell[0], cell[1]).length;
        return count >= 2 && count <= 4;
      }).toList();

      for (final quad in _combinations(cells, 4)) {
        final digits = <int>{};
        for (final cell in quad) {
          digits.addAll(board.getCandidates(cell[0], cell[1]));
        }
        if (digits.length != 4) continue;

        final quadKeys = {
          for (final cell in quad) '${cell[0]},${cell[1]}',
        };
        final eliminations = <CandidateElim>[];
        for (final cell in unit.cells) {
          if (quadKeys.contains('${cell[0]},${cell[1]}') ||
              board.get(cell[0], cell[1]) != 0) {
            continue;
          }
          for (final digit in digits) {
            if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
              eliminations.add(CandidateElim(cell[0], cell[1], digit));
            }
          }
        }
        if (eliminations.isNotEmpty) {
          final sortedDigits = digits.toList()..sort();
          return SudokuHint.elimination(
            technique: '显性四数组',
            explanation: '${unit.label} 中 ${cellsList(quad)} '
                '候选并集只有 ${sortedDigits.join('、')}，'
                '这四个数字占满这些格，可从该单元其它格删除它们。',
            eliminations: eliminations,
            patternCells: hintCells(HintRole.pattern, quad),
            patternCandidates: [
              for (final cell in quad)
                ...hintDigits(
                  HintRole.pattern,
                  cell,
                  board.getCandidates(cell[0], cell[1]),
                ),
            ],
          );
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Hidden Pair - 隐藏数字对
  // ---------------------------------------------------------------------------

  /// 如果两个数字在某单元中只能出现在相同的两个格子里，
  /// 则这两个格子的其他候选数字都可以被删除。
  static SudokuHint? findHiddenPair(SudokuBoard board) {
    for (final u in _allUnits()) {
      // 统计每个数字在单元中的候选位置
      Map<int, List<List<int>>> numPositions = {};
      for (int num = 1; num <= 9; num++) {
        List<List<int>> positions = [];
        for (final c in u.cells) {
          if (board.get(c[0], c[1]) == 0 &&
              board.getCandidates(c[0], c[1]).contains(num)) {
            positions.add(c);
          }
        }
        if (positions.length == 2) numPositions[num] = positions;
      }

      var nums = numPositions.keys.toList();
      for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          var p1 = numPositions[nums[i]]!;
          var p2 = numPositions[nums[j]]!;
          if (p1[0][0] == p2[0][0] &&
              p1[0][1] == p2[0][1] &&
              p1[1][0] == p2[1][0] &&
              p1[1][1] == p2[1][1]) {
            var pairNums = {nums[i], nums[j]};
            List<CandidateElim> elims = [];
            for (final cell in p1) {
              var cand = board.getCandidates(cell[0], cell[1]);
              for (final n in cand) {
                if (!pairNums.contains(n)) {
                  elims.add(CandidateElim(cell[0], cell[1], n));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '隐性数对',
                explanation: '${u.label} 中数字 ${nums[i]} 和 ${nums[j]} 只能出现在 '
                    '${cellRef(p1[0][0], p1[0][1])} 和 '
                    '${cellRef(p1[1][0], p1[1][1])}，'
                    '这两格只能是这两个数字，其它候选可删。',
                eliminations: elims,
                patternCells: hintCells(HintRole.pattern, p1),
                patternCandidates: [
                  for (final cell in p1)
                    ...hintDigits(HintRole.pattern, cell, pairNums),
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
  // Hidden Triple - 隐藏数字三元组
  // ---------------------------------------------------------------------------

  static SudokuHint? findHiddenTriple(SudokuBoard board) {
    for (final u in _allUnits()) {
      // 数字 -> 候选位置（以字符串键表示格子坐标）
      Map<int, Set<String>> numPositions = {};
      Map<String, List<int>> keyToCell = {};
      for (int num = 1; num <= 9; num++) {
        Set<String> positions = {};
        for (final c in u.cells) {
          if (board.get(c[0], c[1]) == 0 &&
              board.getCandidates(c[0], c[1]).contains(num)) {
            var key = '${c[0]},${c[1]}';
            positions.add(key);
            keyToCell[key] = c;
          }
        }
        if (positions.length >= 2 && positions.length <= 3) {
          numPositions[num] = positions;
        }
      }

      var nums = numPositions.keys.toList();
      for (int i = 0; i < nums.length; i++) {
        for (int j = i + 1; j < nums.length; j++) {
          for (int k = j + 1; k < nums.length; k++) {
            var union = numPositions[nums[i]]!
                .union(numPositions[nums[j]]!)
                .union(numPositions[nums[k]]!);
            if (union.length != 3) continue;

            var tripleNums = {nums[i], nums[j], nums[k]};
            List<CandidateElim> elims = [];
            for (final key in union) {
              var cell = keyToCell[key]!;
              var cand = board.getCandidates(cell[0], cell[1]);
              for (final n in cand) {
                if (!tripleNums.contains(n)) {
                  elims.add(CandidateElim(cell[0], cell[1], n));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '隐性三数组',
                explanation: '${u.label} 中数字 ${nums[i]}、${nums[j]}、${nums[k]} '
                    '只能出现在 '
                    '${union.map((k) => cellRef(keyToCell[k]![0], keyToCell[k]![1])).join(', ')}，'
                    '这三格被这三个数字占满，其它候选可删。',
                eliminations: elims,
                patternCells: hintCells(
                  HintRole.pattern,
                  [for (final key in union) keyToCell[key]!],
                ),
                patternCandidates: [
                  for (final key in union)
                    ...hintDigits(
                      HintRole.pattern,
                      keyToCell[key]!,
                      tripleNums.where((n) => board
                          .getCandidates(keyToCell[key]![0], keyToCell[key]![1])
                          .contains(n)),
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
  // Hidden Quad - 隐性四元组
  // ---------------------------------------------------------------------------

  static SudokuHint? findHiddenQuad(SudokuBoard board) {
    for (final unit in _allUnits()) {
      final positionsByDigit = <int, Set<String>>{};
      final cellsByKey = <String, List<int>>{};
      for (var digit = 1; digit <= 9; digit++) {
        final positions = <String>{};
        for (final cell in unit.cells) {
          if (board.get(cell[0], cell[1]) == 0 &&
              board.getCandidates(cell[0], cell[1]).contains(digit)) {
            final key = '${cell[0]},${cell[1]}';
            positions.add(key);
            cellsByKey[key] = cell;
          }
        }
        if (positions.isNotEmpty && positions.length <= 4) {
          positionsByDigit[digit] = positions;
        }
      }

      for (final digits in _combinations(positionsByDigit.keys.toList(), 4)) {
        final positions = <String>{};
        for (final digit in digits) {
          positions.addAll(positionsByDigit[digit]!);
        }
        if (positions.length != 4) continue;

        final digitSet = digits.toSet();
        final eliminations = <CandidateElim>[];
        for (final key in positions) {
          final cell = cellsByKey[key]!;
          for (final candidate in board.getCandidates(cell[0], cell[1])) {
            if (!digitSet.contains(candidate)) {
              eliminations.add(
                CandidateElim(cell[0], cell[1], candidate),
              );
            }
          }
        }
        if (eliminations.isNotEmpty) {
          final sortedDigits = digits.toList()..sort();
          return SudokuHint.elimination(
            technique: '隐性四数组',
            explanation: '${unit.label} 中数字 ${sortedDigits.join('、')} '
                '只可能出现在 '
                '${positions.map((k) => cellRef(cellsByKey[k]![0], cellsByKey[k]![1])).join(', ')}，'
                '这四格被这四个数字占满，其它候选可删。',
            eliminations: eliminations,
            patternCells: hintCells(
              HintRole.pattern,
              [for (final key in positions) cellsByKey[key]!],
            ),
            patternCandidates: [
              for (final key in positions)
                ...hintDigits(
                  HintRole.pattern,
                  cellsByKey[key]!,
                  digitSet.where((d) => board
                      .getCandidates(cellsByKey[key]![0], cellsByKey[key]![1])
                      .contains(d)),
                ),
            ],
          );
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Jellyfish - 水母（4 行 4 列的鱼）
  // ---------------------------------------------------------------------------

  static SudokuHint? findJellyfish(SudokuBoard board) {
    for (int num = 1; num <= 9; num++) {
      var hint = _findJellyfishInRows(board, num);
      if (hint != null) return hint;
      var hint2 = _findJellyfishInColumns(board, num);
      if (hint2 != null) return hint2;
    }
    return null;
  }

  static SudokuHint? _findJellyfishInRows(SudokuBoard board, int num) {
    List<MapEntry<int, List<int>>> rowsWith = [];
    for (int row = 0; row < 9; row++) {
      List<int> cols = [];
      for (int col = 0; col < 9; col++) {
        if (board.get(row, col) == 0 &&
            board.getCandidates(row, col).contains(num)) {
          cols.add(col);
        }
      }
      if (cols.length >= 2 && cols.length <= 4) {
        rowsWith.add(MapEntry(row, cols));
      }
    }
    if (rowsWith.length < 4) return null;

    for (int i = 0; i < rowsWith.length; i++) {
      for (int j = i + 1; j < rowsWith.length; j++) {
        for (int k = j + 1; k < rowsWith.length; k++) {
          for (int l = k + 1; l < rowsWith.length; l++) {
            var allCols = rowsWith[i]
                .value
                .toSet()
                .union(rowsWith[j].value.toSet())
                .union(rowsWith[k].value.toSet())
                .union(rowsWith[l].value.toSet());
            if (allCols.length != 4) continue;
            var rows = [
              rowsWith[i].key,
              rowsWith[j].key,
              rowsWith[k].key,
              rowsWith[l].key,
            ];
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
                technique: 'Jellyfish',
                explanation: '数字 $num 在 ${rowsList(rows)} 形成 Jellyfish'
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
    }
    return null;
  }

  static SudokuHint? _findJellyfishInColumns(SudokuBoard board, int num) {
    List<MapEntry<int, List<int>>> colsWith = [];
    for (int col = 0; col < 9; col++) {
      List<int> rows = [];
      for (int row = 0; row < 9; row++) {
        if (board.get(row, col) == 0 &&
            board.getCandidates(row, col).contains(num)) {
          rows.add(row);
        }
      }
      if (rows.length >= 2 && rows.length <= 4) {
        colsWith.add(MapEntry(col, rows));
      }
    }
    if (colsWith.length < 4) return null;

    for (int i = 0; i < colsWith.length; i++) {
      for (int j = i + 1; j < colsWith.length; j++) {
        for (int k = j + 1; k < colsWith.length; k++) {
          for (int l = k + 1; l < colsWith.length; l++) {
            var allRows = colsWith[i]
                .value
                .toSet()
                .union(colsWith[j].value.toSet())
                .union(colsWith[k].value.toSet())
                .union(colsWith[l].value.toSet());
            if (allRows.length != 4) continue;
            var cols = [
              colsWith[i].key,
              colsWith[j].key,
              colsWith[k].key,
              colsWith[l].key,
            ];
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
                technique: 'Jellyfish',
                explanation: '数字 $num 在 ${colsList(cols)} 形成 Jellyfish'
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
  // Unique Rectangle Type 1 - 唯一矩形类型 1（填数）
  // ---------------------------------------------------------------------------

  static SudokuHint? findUniqueRectangleType1(SudokuBoard board) {
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board.get(i, j) != 0) continue;
        var cands = board.getCandidates(i, j);
        if (cands.length != 2) continue;

        for (int j2 = j + 1; j2 < 9; j2++) {
          if (board.get(i, j2) != 0) continue;
          var cands2 = board.getCandidates(i, j2);
          if (!(cands.difference(cands2).isEmpty && cands2.length == 2)) {
            continue;
          }

          for (int i2 = i + 1; i2 < 9; i2++) {
            if (board.get(i2, j) != 0 || board.get(i2, j2) != 0) continue;

            // 矩形四角必须落在两个宫格中（列组合确保这一点）
            var cands3 = board.getCandidates(i2, j);
            var cands4 = board.getCandidates(i2, j2);

            // Type 1：三个角是 AB，第四个角是 AB+额外数字
            if (cands3.difference(cands).isEmpty &&
                cands3.length == 2 &&
                cands4.containsAll(cands) &&
                cands4.length == 3) {
              var extraNum = cands4.difference(cands).first;
              return SudokuHint(
                row: i2,
                col: j2,
                value: extraNum,
                technique: '唯一矩形 Type 1',
                explanation: '题目保证唯一解。${cellRef(i, j)}, ${cellRef(i, j2)}, '
                    '${cellRef(i2, j)}, ${cellRef(i2, j2)} 形成唯一矩形，'
                    '为避免多解，${cellRef(i2, j2)} 必须填 $extraNum。',
                patternCells: [
                  ...hintCells(HintRole.pattern, [
                    [i, j],
                    [i, j2],
                    [i2, j],
                  ]),
                  HintCell(i2, j2, HintRole.extra),
                ],
                patternCandidates: [
                  HintCandidate(
                    CandidateRef(i2, j2, extraNum),
                    HintRole.extra,
                  ),
                ],
              );
            }

            if (cands4.difference(cands).isEmpty &&
                cands4.length == 2 &&
                cands3.containsAll(cands) &&
                cands3.length == 3) {
              var extraNum = cands3.difference(cands).first;
              return SudokuHint(
                row: i2,
                col: j,
                value: extraNum,
                technique: '唯一矩形 Type 1',
                explanation: '题目保证唯一解。${cellRef(i, j)}, ${cellRef(i, j2)}, '
                    '${cellRef(i2, j)}, ${cellRef(i2, j2)} 形成唯一矩形，'
                    '为避免多解，${cellRef(i2, j)} 必须填 $extraNum。',
                patternCells: [
                  ...hintCells(HintRole.pattern, [
                    [i, j],
                    [i, j2],
                    [i2, j2],
                  ]),
                  HintCell(i2, j, HintRole.extra),
                ],
                patternCandidates: [
                  HintCandidate(
                    CandidateRef(i2, j, extraNum),
                    HintRole.extra,
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

  static bool _isUrGeometry(int r1, int c1, int r2, int c2) =>
      (r1 ~/ 3 == r2 ~/ 3) != (c1 ~/ 3 == c2 ~/ 3);

  static List<List<int>>? _urExtraCells(
    SudokuBoard board,
    int r1,
    int c1,
    int r2,
    int c2,
    Set<int> pair,
  ) {
    final corners = [
      [r1, c1],
      [r1, c2],
      [r2, c1],
      [r2, c2],
    ];
    final extras = <List<int>>[];
    var floors = 0;
    for (final cell in corners) {
      final cands = board.getCandidates(cell[0], cell[1]);
      if (!cands.containsAll(pair)) return null;
      if (cands.length == 2) {
        floors++;
      } else {
        extras.add(cell);
      }
    }
    if (floors != 2 || extras.length != 2) return null;
    return extras;
  }

  static SudokuHint? findUniqueRectangleType2(SudokuBoard board) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var c1 = 0; c1 < 9; c1++) {
        if (board.get(r1, c1) != 0) continue;
        final pair = board.getCandidates(r1, c1);
        if (pair.length != 2) continue;
        for (var r2 = r1 + 1; r2 < 9; r2++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (!_isUrGeometry(r1, c1, r2, c2)) continue;
            if (board.get(r1, c2) != 0 ||
                board.get(r2, c1) != 0 ||
                board.get(r2, c2) != 0) {
              continue;
            }
            final extras = _urExtraCells(board, r1, c1, r2, c2, pair);
            if (extras == null) continue;
            if (extras[0][0] != extras[1][0] && extras[0][1] != extras[1][1]) {
              continue;
            }
            final extra1 = board
                .getCandidates(extras[0][0], extras[0][1])
                .difference(pair);
            final extra2 = board
                .getCandidates(extras[1][0], extras[1][1])
                .difference(pair);
            if (extra1.length != 1 || extra2.length != 1) continue;
            if (extra1.first != extra2.first) continue;
            final digit = extra1.first;
            final elims = <CandidateElim>[];
            for (var row = 0; row < 9; row++) {
              for (var col = 0; col < 9; col++) {
                if (board.get(row, col) != 0) continue;
                if ((row == extras[0][0] && col == extras[0][1]) ||
                    (row == extras[1][0] && col == extras[1][1])) {
                  continue;
                }
                if (_canSee(row, col, extras[0][0], extras[0][1]) &&
                    _canSee(row, col, extras[1][0], extras[1][1]) &&
                    board.getCandidates(row, col).contains(digit)) {
                  elims.add(CandidateElim(row, col, digit));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '唯一矩形 Type 2',
                explanation: '题目保证唯一解。四个格子形成唯一矩形，额外数字 $digit '
                    '出现在同一侧两格，可从它们共同可见处删除 $digit。',
                eliminations: elims,
                patternCells: [
                  ...hintCells(HintRole.pattern, [
                    [r1, c1],
                    [r1, c2],
                    [r2, c1],
                    [r2, c2],
                  ]),
                  ...hintCells(HintRole.extra, extras),
                  ..._targetCells(elims),
                ],
                patternCandidates: [
                  ...hintCands(HintRole.extra, digit, extras),
                  ..._targetCands(elims),
                ],
              );
            }
          }
        }
      }
    }
    return null;
  }

  static SudokuHint? findUniqueRectangleType3(SudokuBoard board) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var c1 = 0; c1 < 9; c1++) {
        if (board.get(r1, c1) != 0) continue;
        final pair = board.getCandidates(r1, c1);
        if (pair.length != 2) continue;
        for (var r2 = r1 + 1; r2 < 9; r2++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (!_isUrGeometry(r1, c1, r2, c2)) continue;
            if (board.get(r1, c2) != 0 ||
                board.get(r2, c1) != 0 ||
                board.get(r2, c2) != 0) {
              continue;
            }
            final extras = _urExtraCells(board, r1, c1, r2, c2, pair);
            if (extras == null) continue;
            if (extras[0][0] != extras[1][0] && extras[0][1] != extras[1][1]) {
              continue;
            }

            final house = extras[0][0] == extras[1][0]
                ? [
                    for (var col = 0; col < 9; col++) [extras[0][0], col]
                  ]
                : [
                    for (var row = 0; row < 9; row++) [row, extras[0][1]]
                  ];
            final urKeys = {
              '$r1,$c1',
              '$r1,$c2',
              '$r2,$c1',
              '$r2,$c2',
            };

            final extraDigits = {
              ...board
                  .getCandidates(extras[0][0], extras[0][1])
                  .difference(pair),
              ...board
                  .getCandidates(extras[1][0], extras[1][1])
                  .difference(pair),
            };
            if (extraDigits.isEmpty) continue;
            final partners = <_VirtualCell>[];
            for (final cell in house) {
              final key = '${cell[0]},${cell[1]}';
              if (urKeys.contains(key) || board.get(cell[0], cell[1]) != 0) {
                continue;
              }
              partners.add(
                _VirtualCell(
                  cell[0],
                  cell[1],
                  Set<int>.from(board.getCandidates(cell[0], cell[1])),
                ),
              );
            }

            // 两格额外候选只能保证「至少有一个多余数字成立」，
            // 应合成一个虚拟格再去配数组；把它们当成两格纯多余数字会误删。
            for (var size = 2; size <= 4 && size - 1 <= partners.length; size++) {
              for (final combo in _combinations(partners, size - 1)) {
                final union = {...extraDigits};
                for (final cell in combo) {
                  union.addAll(cell.cands);
                }
                if (union.length != size) continue;
                final comboKeys = {
                  for (final cell in combo) '${cell.row},${cell.col}',
                };
                final extraKeys = {
                  for (final cell in extras) '${cell[0]},${cell[1]}',
                };
                final elims = <CandidateElim>[];
                for (final cell in house) {
                  if (board.get(cell[0], cell[1]) != 0) continue;
                  final key = '${cell[0]},${cell[1]}';
                  if (comboKeys.contains(key) || extraKeys.contains(key)) {
                    continue;
                  }
                  for (final digit in union) {
                    if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
                      elims.add(CandidateElim(cell[0], cell[1], digit));
                    }
                  }
                }
                if (elims.isNotEmpty) {
                  final digits = union.toList()..sort();
                  return SudokuHint.elimination(
                    technique: '唯一矩形 Type 3',
                    explanation: '题目保证唯一解。唯一矩形的额外候选与同区域其它格子组成数组 '
                        '${digits.join('、')}，可删除该区域中的这些候选。',
                    eliminations: elims,
                    patternCells: [
                      ...hintCells(HintRole.pattern, [
                        [r1, c1],
                        [r1, c2],
                        [r2, c1],
                        [r2, c2],
                      ]),
                      ...hintCells(HintRole.extra, extras),
                      ...[
                        for (final cell in combo)
                          HintCell(cell.row, cell.col, HintRole.extra)
                      ],
                      ..._targetCells(elims),
                    ],
                    patternCandidates: [
                      for (final cell in extras)
                        for (final digit in extraDigits)
                          if (board
                              .getCandidates(cell[0], cell[1])
                              .contains(digit))
                            HintCandidate(
                              CandidateRef(cell[0], cell[1], digit),
                              HintRole.extra,
                            ),
                      for (final cell in combo)
                        for (final digit in cell.cands)
                          HintCandidate(
                            CandidateRef(cell.row, cell.col, digit),
                            HintRole.extra,
                          ),
                      ..._targetCands(elims),
                    ],
                  );
                }
              }
            }
          }
        }
      }
    }
    return null;
  }

  static SudokuHint? findUniqueRectangleType4(SudokuBoard board) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var c1 = 0; c1 < 9; c1++) {
        if (board.get(r1, c1) != 0) continue;
        final pair = board.getCandidates(r1, c1);
        if (pair.length != 2) continue;
        for (var r2 = r1 + 1; r2 < 9; r2++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (!_isUrGeometry(r1, c1, r2, c2)) continue;
            if (board.get(r1, c2) != 0 ||
                board.get(r2, c1) != 0 ||
                board.get(r2, c2) != 0) {
              continue;
            }
            final extras = _urExtraCells(board, r1, c1, r2, c2, pair);
            if (extras == null) continue;
            if (extras[0][0] != extras[1][0] && extras[0][1] != extras[1][1]) {
              continue;
            }
            final house = extras[0][0] == extras[1][0]
                ? [
                    for (var col = 0; col < 9; col++) [extras[0][0], col]
                  ]
                : [
                    for (var row = 0; row < 9; row++) [row, extras[0][1]]
                  ];
            final digits = pair.toList();
            for (var i = 0; i < 2; i++) {
              final conjugate = digits[i];
              final other = digits[1 - i];
              final positions = house
                  .where((cell) =>
                      board.get(cell[0], cell[1]) == 0 &&
                      board.getCandidates(cell[0], cell[1]).contains(conjugate))
                  .toList();
              if (positions.length != 2) continue;
              final matches = positions.every((cell) =>
                  (cell[0] == extras[0][0] && cell[1] == extras[0][1]) ||
                  (cell[0] == extras[1][0] && cell[1] == extras[1][1]));
              if (!matches) continue;
              final elims = <CandidateElim>[];
              for (final cell in extras) {
                if (board.getCandidates(cell[0], cell[1]).contains(other)) {
                  elims.add(CandidateElim(cell[0], cell[1], other));
                }
              }
              if (elims.isNotEmpty) {
                return SudokuHint.elimination(
                  technique: '唯一矩形 Type 4',
                  explanation: '题目保证唯一解。唯一矩形所在区域中数字 $conjugate 形成强链，'
                      '因此这两格可删除数字 $other。',
                  eliminations: elims,
                  patternCells: [
                    ...hintCells(HintRole.pattern, [
                      [r1, c1],
                      [r1, c2],
                      [r2, c1],
                      [r2, c2],
                    ]),
                    ...hintCells(HintRole.link, extras),
                    ..._targetCells(elims),
                  ],
                  patternCandidates: [
                    ...hintCands(HintRole.link, conjugate, extras),
                    ..._targetCands(elims),
                  ],
                  links: [
                    MarkupArrow(
                      from: CandidateRef(extras[0][0], extras[0][1], conjugate),
                      to: CandidateRef(extras[1][0], extras[1][1], conjugate),
                      kind: ArrowKind.strong,
                    ),
                  ],
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Simple Coloring - 简单着色
  // ---------------------------------------------------------------------------

  static SudokuHint? findSimpleColoring(SudokuBoard board) {
    for (int num = 1; num <= 9; num++) {
      var hint = _findSimpleColoringForNumber(board, num);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _findSimpleColoringForNumber(SudokuBoard board, int num) {
    // 收集候选位置
    List<List<int>> positions = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board.get(i, j) == 0 && board.getCandidates(i, j).contains(num)) {
          positions.add([i, j]);
        }
      }
    }
    if (positions.isEmpty) return null;

    String keyOf(int r, int c) => '$r,$c';
    // 构建强链图：某单元内 num 恰有两个候选位置
    Map<String, Set<String>> graph = {};
    for (final p in positions) {
      graph[keyOf(p[0], p[1])] = <String>{};
    }
    void addLink(List<int> a, List<int> b) {
      graph[keyOf(a[0], a[1])]!.add(keyOf(b[0], b[1]));
      graph[keyOf(b[0], b[1])]!.add(keyOf(a[0], a[1]));
    }

    for (final u in _allUnits()) {
      var cellsWith = u.cells
          .where((c) =>
              board.get(c[0], c[1]) == 0 &&
              board.getCandidates(c[0], c[1]).contains(num))
          .toList();
      if (cellsWith.length == 2) {
        addLink(cellsWith[0], cellsWith[1]);
      }
    }

    // 找连通分量并进行二着色
    Set<String> visited = {};
    Map<String, List<int>> cellOf = {
      for (final p in positions) keyOf(p[0], p[1]): p
    };

    for (final start in graph.keys) {
      if (visited.contains(start)) continue;
      // BFS 着色
      Map<String, int> color = {};
      List<String> queue = [start];
      color[start] = 0;
      visited.add(start);
      List<String> component = [start];
      while (queue.isNotEmpty) {
        var cur = queue.removeLast();
        for (final nb in graph[cur]!) {
          if (!color.containsKey(nb)) {
            color[nb] = 1 - color[cur]!;
            visited.add(nb);
            component.add(nb);
            queue.add(nb);
          }
        }
      }
      if (component.length < 2) continue;

      List<String> color0 = component.where((k) => color[k] == 0).toList();
      List<String> color1 = component.where((k) => color[k] == 1).toList();

      // 规则 2：同色两格互相可见 -> 该颜色全部为假，删除该颜色所有候选
      String? falseColorList;
      List<String>? falseCells;
      for (final group in [color0, color1]) {
        bool contradiction = false;
        for (int a = 0; a < group.length && !contradiction; a++) {
          for (int b = a + 1; b < group.length; b++) {
            var ca = cellOf[group[a]]!;
            var cb = cellOf[group[b]]!;
            if (_canSee(ca[0], ca[1], cb[0], cb[1])) {
              contradiction = true;
              break;
            }
          }
        }
        if (contradiction) {
          falseCells = group;
          falseColorList = group == color0 ? '第一种颜色' : '第二种颜色';
          break;
        }
      }
      if (falseCells != null) {
        List<CandidateElim> elims = [];
        for (final k in falseCells) {
          var c = cellOf[k]!;
          elims.add(CandidateElim(c[0], c[1], num));
        }
        if (elims.isNotEmpty) {
          final trueCells = [
            for (final k in (falseCells == color0 ? color1 : color0)) cellOf[k]!
          ];
          return SudokuHint.elimination(
            technique: 'Simple Coloring',
            explanation: '数字 $num 的着色链中，$falseColorList 的两个格子互相可见，'
                '因此该颜色全部为假，可删除这些格子的候选数 $num。',
            eliminations: elims,
            patternCells: hintCells(HintRole.pattern, trueCells),
            patternCandidates: hintCands(HintRole.pattern, num, trueCells),
            links: _chainArrows(graph, cellOf, component, num),
          );
        }
      }

      // 规则 4：链外某格同时可见两种颜色 -> 删除该格候选
      List<CandidateElim> elims = [];
      var componentSet = component.toSet();
      for (final p in positions) {
        var pk = keyOf(p[0], p[1]);
        if (componentSet.contains(pk)) continue;
        bool seesColor0 = color0.any((k) {
          var c = cellOf[k]!;
          return _canSee(p[0], p[1], c[0], c[1]);
        });
        bool seesColor1 = color1.any((k) {
          var c = cellOf[k]!;
          return _canSee(p[0], p[1], c[0], c[1]);
        });
        if (seesColor0 && seesColor1) {
          elims.add(CandidateElim(p[0], p[1], num));
        }
      }
      if (elims.isNotEmpty) {
        return SudokuHint.elimination(
          technique: 'Simple Coloring',
          explanation: '数字 $num 形成着色链，某些链外格子同时可见两种颜色，'
              '无论哪种颜色为真都会被排除，因此可删除这些格子的候选数 $num。',
          eliminations: elims,
          patternCells: [
            ...hintCells(
              HintRole.pattern,
              [for (final k in color0) cellOf[k]!],
            ),
            ...hintCells(
              HintRole.extra,
              [for (final k in color1) cellOf[k]!],
            ),
          ],
          patternCandidates: [
            ...hintCands(
              HintRole.pattern,
              num,
              [for (final k in color0) cellOf[k]!],
            ),
            ...hintCands(
              HintRole.extra,
              num,
              [for (final k in color1) cellOf[k]!],
            ),
          ],
          links: _chainArrows(graph, cellOf, component, num),
        );
      }
    }
    return null;
  }

  /// 把着色链的每条强链边画成箭头。
  static List<MarkupArrow> _chainArrows(
    Map<String, Set<String>> graph,
    Map<String, List<int>> cellOf,
    Iterable<String> component,
    int num,
  ) {
    final drawn = <String>{};
    final arrows = <MarkupArrow>[];
    for (final key in component) {
      for (final other in graph[key] ?? const <String>{}) {
        final edge = ([key, other]..sort()).join('|');
        if (!drawn.add(edge)) continue;
        final a = cellOf[key]!;
        final b = cellOf[other]!;
        arrows.add(MarkupArrow(
          from: CandidateRef(a[0], a[1], num),
          to: CandidateRef(b[0], b[1], num),
          kind: ArrowKind.strong,
        ));
      }
    }
    return arrows;
  }

  // ---------------------------------------------------------------------------
  // W-Wing
  // ---------------------------------------------------------------------------

  /// 两个候选数相同（{a,b}）且互不可见的双值格，通过某个数字的强链相连，
  /// 则可以从同时可见这两个格子的其他格中删除另一个数字。
  static SudokuHint? findWWing(SudokuBoard board) {
    // 收集双值格
    List<List<int>> biCells = [];
    for (int i = 0; i < 9; i++) {
      for (int j = 0; j < 9; j++) {
        if (board.get(i, j) == 0 && board.getCandidates(i, j).length == 2) {
          biCells.add([i, j]);
        }
      }
    }

    for (int a = 0; a < biCells.length; a++) {
      for (int b = a + 1; b < biCells.length; b++) {
        var c1 = biCells[a];
        var c2 = biCells[b];
        var cand1 = board.getCandidates(c1[0], c1[1]);
        var cand2 = board.getCandidates(c2[0], c2[1]);
        if (!(cand1.length == 2 && cand2.containsAll(cand1))) continue;
        if (_canSee(c1[0], c1[1], c2[0], c2[1])) continue;

        var pair = cand1.toList();
        // 对每个数字作为强链数字
        for (final linkDigit in pair) {
          int elimDigit = pair[0] == linkDigit ? pair[1] : pair[0];

          // 寻找 linkDigit 的强链，两端分别看见 c1 和 c2
          bool linkFound = false;
          List<int>? e1;
          List<int>? e2;
          for (final u in _allUnits()) {
            var ends = u.cells
                .where((c) =>
                    board.get(c[0], c[1]) == 0 &&
                    board.getCandidates(c[0], c[1]).contains(linkDigit))
                .toList();
            if (ends.length != 2) continue;
            var end1 = ends[0];
            var end2 = ends[1];
            // 两端不能是 c1/c2 本身
            bool isPivot(List<int> e) =>
                (e[0] == c1[0] && e[1] == c1[1]) ||
                (e[0] == c2[0] && e[1] == c2[1]);
            if (isPivot(end1) || isPivot(end2)) continue;

            bool caseA = _canSee(end1[0], end1[1], c1[0], c1[1]) &&
                _canSee(end2[0], end2[1], c2[0], c2[1]);
            bool caseB = _canSee(end1[0], end1[1], c2[0], c2[1]) &&
                _canSee(end2[0], end2[1], c1[0], c1[1]);
            if (caseA || caseB) {
              linkFound = true;
              e1 = end1;
              e2 = end2;
              break;
            }
          }
          if (!linkFound) continue;

          // 删除同时可见 c1 和 c2 的格子中的 elimDigit
          List<CandidateElim> elims = [];
          for (int i = 0; i < 9; i++) {
            for (int j = 0; j < 9; j++) {
              if (board.get(i, j) != 0) continue;
              if ((i == c1[0] && j == c1[1]) || (i == c2[0] && j == c2[1])) {
                continue;
              }
              if (_canSee(i, j, c1[0], c1[1]) &&
                  _canSee(i, j, c2[0], c2[1]) &&
                  board.getCandidates(i, j).contains(elimDigit)) {
                elims.add(CandidateElim(i, j, elimDigit));
              }
            }
          }
          if (elims.isNotEmpty) {
            return SudokuHint.elimination(
              technique: 'W-Wing',
              explanation: '双值格 ${cellRef(c1[0], c1[1])} 与 '
                  '${cellRef(c2[0], c2[1])} 候选相同 ${pair..sort()}，'
                  '经 $linkDigit 的强链 '
                  '${candRef(e1![0], e1[1], linkDigit)} = '
                  '${candRef(e2![0], e2[1], linkDigit)} 相连，'
                  '形成 W-Wing，相关格的 $elimDigit 可删。',
              eliminations: elims,
              patternCells: [
                ...hintCells(HintRole.pattern, [c1, c2]),
                ...hintCells(HintRole.link, [e1, e2]),
              ],
              patternCandidates: [
                ...hintDigits(HintRole.pattern, c1, pair),
                ...hintDigits(HintRole.pattern, c2, pair),
                ...hintCands(HintRole.link, linkDigit, [e1, e2]),
              ],
              links: [
                MarkupArrow(
                  from: CandidateRef(e1[0], e1[1], linkDigit),
                  to: CandidateRef(e2[0], e2[1], linkDigit),
                  kind: ArrowKind.strong,
                ),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // Skyscraper
  // ---------------------------------------------------------------------------

  /// 单数字技巧：两条线（行/列）上某数字各有 2 个候选位置，
  /// 其中一端在同一条交叉线上对齐（底部），另一端为“屋顶”。
  /// 可从同时可见两个屋顶的格子中删除该数字。
  static SudokuHint? findSkyscraper(SudokuBoard board) {
    for (int num = 1; num <= 9; num++) {
      var hint = _findSkyscraperRows(board, num);
      if (hint != null) return hint;
      var hint2 = _findSkyscraperCols(board, num);
      if (hint2 != null) return hint2;
    }
    return null;
  }

  static SudokuHint? _findSkyscraperRows(SudokuBoard board, int num) {
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
        var r1 = rowsWithTwo[i].key;
        var r2 = rowsWithTwo[j].key;
        var cols1 = rowsWithTwo[i].value;
        var cols2 = rowsWithTwo[j].value;
        var shared = cols1.toSet().intersection(cols2.toSet());
        if (shared.length != 1) continue; // 恰好共享一个底部列
        int baseCol = shared.first;
        int roof1Col = cols1[0] == baseCol ? cols1[1] : cols1[0];
        int roof2Col = cols2[0] == baseCol ? cols2[1] : cols2[0];
        if (roof1Col == roof2Col) continue; // 那是 X-Wing，不是摩天楼

        var roof1 = [r1, roof1Col];
        var roof2 = [r2, roof2Col];
        List<CandidateElim> elims = [];
        for (int i2 = 0; i2 < 9; i2++) {
          for (int j2 = 0; j2 < 9; j2++) {
            if (board.get(i2, j2) != 0) continue;
            if ((i2 == roof1[0] && j2 == roof1[1]) ||
                (i2 == roof2[0] && j2 == roof2[1])) {
              continue;
            }
            if (_canSee(i2, j2, roof1[0], roof1[1]) &&
                _canSee(i2, j2, roof2[0], roof2[1]) &&
                board.getCandidates(i2, j2).contains(num)) {
              elims.add(CandidateElim(i2, j2, num));
            }
          }
        }
        if (elims.isNotEmpty) {
          return SudokuHint.elimination(
            technique: '摩天楼',
            explanation: '数字 $num 在 ${rowRef(r1)} 和 ${rowRef(r2)} 各只有两个候选，'
                '在 ${colRef(baseCol)} 对齐形成摩天楼，'
                '同时看见两个屋顶处的 $num 可删。',
            eliminations: elims,
            patternCells: [
              ...hintCells(HintRole.link, [
                [r1, cols1[0]],
                [r1, cols1[1]],
                [r2, cols2[0]],
                [r2, cols2[1]],
              ]),
              ..._targetCells(elims),
            ],
            patternCandidates: [
              ...hintCands(HintRole.link, num, [
                [r1, cols1[0]],
                [r1, cols1[1]],
                [r2, cols2[0]],
                [r2, cols2[1]],
              ]),
              ..._targetCands(elims),
            ],
            links: [
              MarkupArrow(
                from: CandidateRef(r1, cols1[0], num),
                to: CandidateRef(r1, cols1[1], num),
                kind: ArrowKind.strong,
              ),
              MarkupArrow(
                from: CandidateRef(r2, cols2[0], num),
                to: CandidateRef(r2, cols2[1], num),
                kind: ArrowKind.strong,
              ),
            ],
          );
        }
      }
    }
    return null;
  }

  static SudokuHint? _findSkyscraperCols(SudokuBoard board, int num) {
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
        var c1 = colsWithTwo[i].key;
        var c2 = colsWithTwo[j].key;
        var rows1 = colsWithTwo[i].value;
        var rows2 = colsWithTwo[j].value;
        var shared = rows1.toSet().intersection(rows2.toSet());
        if (shared.length != 1) continue;
        int baseRow = shared.first;
        int roof1Row = rows1[0] == baseRow ? rows1[1] : rows1[0];
        int roof2Row = rows2[0] == baseRow ? rows2[1] : rows2[0];
        if (roof1Row == roof2Row) continue;

        var roof1 = [roof1Row, c1];
        var roof2 = [roof2Row, c2];
        List<CandidateElim> elims = [];
        for (int i2 = 0; i2 < 9; i2++) {
          for (int j2 = 0; j2 < 9; j2++) {
            if (board.get(i2, j2) != 0) continue;
            if ((i2 == roof1[0] && j2 == roof1[1]) ||
                (i2 == roof2[0] && j2 == roof2[1])) {
              continue;
            }
            if (_canSee(i2, j2, roof1[0], roof1[1]) &&
                _canSee(i2, j2, roof2[0], roof2[1]) &&
                board.getCandidates(i2, j2).contains(num)) {
              elims.add(CandidateElim(i2, j2, num));
            }
          }
        }
        if (elims.isNotEmpty) {
          return SudokuHint.elimination(
            technique: '摩天楼',
            explanation: '数字 $num 在 ${colRef(c1)} 和 ${colRef(c2)} 各只有两个候选，'
                '在 ${rowRef(baseRow)} 对齐形成摩天楼，'
                '同时看见两个屋顶处的 $num 可删。',
            eliminations: elims,
            patternCells: [
              ...hintCells(HintRole.link, [
                [rows1[0], c1],
                [rows1[1], c1],
                [rows2[0], c2],
                [rows2[1], c2],
              ]),
              ..._targetCells(elims),
            ],
            patternCandidates: [
              ...hintCands(HintRole.link, num, [
                [rows1[0], c1],
                [rows1[1], c1],
                [rows2[0], c2],
                [rows2[1], c2],
              ]),
              ..._targetCands(elims),
            ],
            links: [
              MarkupArrow(
                from: CandidateRef(rows1[0], c1, num),
                to: CandidateRef(rows1[1], c1, num),
                kind: ArrowKind.strong,
              ),
              MarkupArrow(
                from: CandidateRef(rows2[0], c2, num),
                to: CandidateRef(rows2[1], c2, num),
                kind: ArrowKind.strong,
              ),
            ],
          );
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 2-String Kite
  // ---------------------------------------------------------------------------

  static SudokuHint? findTwoStringKite(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      final hint = _findTwoStringKiteForDigit(board, digit);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _findTwoStringKiteForDigit(SudokuBoard board, int digit) {
    for (var row = 0; row < 9; row++) {
      final cols = <int>[];
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) == 0 &&
            board.getCandidates(row, col).contains(digit)) {
          cols.add(col);
        }
      }
      if (cols.length != 2) continue;

      for (var col = 0; col < 9; col++) {
        if (cols.contains(col)) continue;
        final rows = <int>[];
        for (var r = 0; r < 9; r++) {
          if (board.get(r, col) == 0 &&
              board.getCandidates(r, col).contains(digit)) {
            rows.add(r);
          }
        }
        if (rows.length != 2) continue;

        for (final rowEndCol in cols) {
          for (final colEndRow in rows) {
            if (rowEndCol ~/ 3 != col ~/ 3 || row ~/ 3 != colEndRow ~/ 3) {
              continue;
            }
            final farRowCol = cols[0] == rowEndCol ? cols[1] : cols[0];
            final farColRow = rows[0] == colEndRow ? rows[1] : rows[0];
            final elims = <CandidateElim>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if (board.get(r, c) != 0) continue;
                if (r == row && c == farRowCol) continue;
                if (r == farColRow && c == col) continue;
                if (_canSee(r, c, row, farRowCol) &&
                    _canSee(r, c, farColRow, col) &&
                    board.getCandidates(r, c).contains(digit)) {
                  elims.add(CandidateElim(r, c, digit));
                }
              }
            }
            if (elims.isNotEmpty) {
              return SudokuHint.elimination(
                technique: '双线风筝',
                explanation:
                    '数字 $digit 在 ${rowRef(row)} 和 ${colRef(col)} 各有一条强链，'
                    '同宫拐弯形成双线风筝，同时看见两个远端的 $digit 可删。',
                eliminations: elims,
                patternCells: [
                  ...hintCells(HintRole.link, [
                    [row, cols[0]],
                    [row, cols[1]],
                    [rows[0], col],
                    [rows[1], col],
                  ]),
                  HintCell(row, rowEndCol, HintRole.pattern),
                  HintCell(colEndRow, col, HintRole.pattern),
                  ..._targetCells(elims),
                ],
                patternCandidates: [
                  ...hintCands(HintRole.link, digit, [
                    [row, cols[0]],
                    [row, cols[1]],
                    [rows[0], col],
                    [rows[1], col],
                  ]),
                  ..._targetCands(elims),
                ],
                links: [
                  MarkupArrow(
                    from: CandidateRef(row, cols[0], digit),
                    to: CandidateRef(row, cols[1], digit),
                    kind: ArrowKind.strong,
                  ),
                  MarkupArrow(
                    from: CandidateRef(rows[0], col, digit),
                    to: CandidateRef(rows[1], col, digit),
                    kind: ArrowKind.strong,
                  ),
                  MarkupArrow(
                    from: CandidateRef(row, rowEndCol, digit),
                    to: CandidateRef(colEndRow, col, digit),
                    kind: ArrowKind.weak,
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
  // Empty Rectangle
  // ---------------------------------------------------------------------------

  static SudokuHint? findEmptyRectangle(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      final hint = _findEmptyRectangleForDigit(board, digit);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _findEmptyRectangleForDigit(SudokuBoard board, int digit) {
    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxCol = 0; boxCol < 3; boxCol++) {
        final startRow = boxRow * 3;
        final startCol = boxCol * 3;
        final positions = <List<int>>[];
        for (var r = startRow; r < startRow + 3; r++) {
          for (var c = startCol; c < startCol + 3; c++) {
            if (board.get(r, c) == 0 &&
                board.getCandidates(r, c).contains(digit)) {
              positions.add([r, c]);
            }
          }
        }
        if (positions.length < 2) continue;

        for (var coverRow = startRow; coverRow < startRow + 3; coverRow++) {
          for (var coverCol = startCol; coverCol < startCol + 3; coverCol++) {
            if (!positions.every((p) => p[0] == coverRow || p[1] == coverCol)) {
              continue;
            }
            if (!positions.any((p) => p[0] != coverRow)) continue;
            if (!positions.any((p) => p[1] != coverCol)) continue;

            for (var linkCol = 0; linkCol < 9; linkCol++) {
              if (linkCol ~/ 3 == boxCol) continue;
              final rows = <int>[];
              for (var r = 0; r < 9; r++) {
                if (board.get(r, linkCol) == 0 &&
                    board.getCandidates(r, linkCol).contains(digit)) {
                  rows.add(r);
                }
              }
              if (rows.length != 2 || !rows.contains(coverRow)) continue;
              final otherRow = rows[0] == coverRow ? rows[1] : rows[0];
              if (board.get(otherRow, coverCol) == 0 &&
                  board.getCandidates(otherRow, coverCol).contains(digit) &&
                  !(otherRow ~/ 3 == boxRow && coverCol ~/ 3 == boxCol)) {
                return SudokuHint.elimination(
                  technique: '空矩形',
                  explanation: '数字 $digit 在 ${boxRef(boxRow, boxCol)} 形成空矩形，'
                      '并与 ${colRef(linkCol)} 的强链配合，可删 '
                      '${candRef(otherRow, coverCol, digit)}。',
                  eliminations: [CandidateElim(otherRow, coverCol, digit)],
                  patternCells: [
                    ...hintCells(HintRole.pattern, positions),
                    ...hintCells(HintRole.link, [
                      [rows[0], linkCol],
                      [rows[1], linkCol],
                    ]),
                    HintCell(otherRow, coverCol, HintRole.target),
                  ],
                  patternCandidates: [
                    ...hintCands(HintRole.pattern, digit, positions),
                    ...hintCands(HintRole.link, digit, [
                      [rows[0], linkCol],
                      [rows[1], linkCol],
                    ]),
                    HintCandidate(
                      CandidateRef(otherRow, coverCol, digit),
                      HintRole.target,
                    ),
                  ],
                  links: [
                    MarkupArrow(
                      from: CandidateRef(rows[0], linkCol, digit),
                      to: CandidateRef(rows[1], linkCol, digit),
                      kind: ArrowKind.strong,
                    ),
                  ],
                );
              }
            }

            for (var linkRow = 0; linkRow < 9; linkRow++) {
              if (linkRow ~/ 3 == boxRow) continue;
              final cols = <int>[];
              for (var c = 0; c < 9; c++) {
                if (board.get(linkRow, c) == 0 &&
                    board.getCandidates(linkRow, c).contains(digit)) {
                  cols.add(c);
                }
              }
              if (cols.length != 2 || !cols.contains(coverCol)) continue;
              final otherCol = cols[0] == coverCol ? cols[1] : cols[0];
              if (board.get(coverRow, otherCol) == 0 &&
                  board.getCandidates(coverRow, otherCol).contains(digit) &&
                  !(coverRow ~/ 3 == boxRow && otherCol ~/ 3 == boxCol)) {
                return SudokuHint.elimination(
                  technique: '空矩形',
                  explanation: '数字 $digit 在 ${boxRef(boxRow, boxCol)} 形成空矩形，'
                      '并与 ${rowRef(linkRow)} 的强链配合，可删 '
                      '${candRef(coverRow, otherCol, digit)}。',
                  eliminations: [CandidateElim(coverRow, otherCol, digit)],
                  patternCells: [
                    ...hintCells(HintRole.pattern, positions),
                    ...hintCells(HintRole.link, [
                      [linkRow, cols[0]],
                      [linkRow, cols[1]],
                    ]),
                    HintCell(coverRow, otherCol, HintRole.target),
                  ],
                  patternCandidates: [
                    ...hintCands(HintRole.pattern, digit, positions),
                    ...hintCands(HintRole.link, digit, [
                      [linkRow, cols[0]],
                      [linkRow, cols[1]],
                    ]),
                    HintCandidate(
                      CandidateRef(coverRow, otherCol, digit),
                      HintRole.target,
                    ),
                  ],
                  links: [
                    MarkupArrow(
                      from: CandidateRef(linkRow, cols[0], digit),
                      to: CandidateRef(linkRow, cols[1], digit),
                      kind: ArrowKind.strong,
                    ),
                  ],
                );
              }
            }
          }
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // ALS-XZ / ALS-XY-Wing（同一行/列/宫的几乎锁定集）
  // ---------------------------------------------------------------------------

  static SudokuHint? findAlsXz(SudokuBoard board) {
    final als = _houseAls(board);
    for (var i = 0; i < als.length; i++) {
      for (var j = i + 1; j < als.length; j++) {
        final a = als[i];
        final b = als[j];
        if (a.overlaps(b)) continue;
        final common = a.digits.intersection(b.digits);
        if (common.length < 2) continue;
        for (final x in common) {
          if (!_restrictedCommon(board, a, b, x)) continue;
          for (final z in common) {
            if (z == x) continue;
            final zCells = [
              ...a.cellsWith(board, z),
              ...b.cellsWith(board, z),
            ];
            final elims = _seenByAll(board, z, zCells);
            if (elims.isEmpty) continue;
            return _alsXzHint(board, a, b, x, z, elims);
          }
        }
      }
    }
    return null;
  }

  static SudokuHint? findAlsXyWing(SudokuBoard board) {
    final als = _houseAls(board);
    final byDigit = <int, List<_Als>>{};
    for (final set in als) {
      for (final digit in set.digits) {
        byDigit.putIfAbsent(digit, () => []).add(set);
      }
    }
    for (final pivot in als) {
      for (final x in pivot.digits) {
        for (final wingA in byDigit[x] ?? const <_Als>[]) {
          if (identical(wingA, pivot) || pivot.overlaps(wingA)) continue;
          if (!_restrictedCommon(board, pivot, wingA, x)) continue;
          for (final y in pivot.digits) {
            if (y == x) continue;
            for (final wingB in byDigit[y] ?? const <_Als>[]) {
              if (identical(wingB, pivot) ||
                  identical(wingB, wingA) ||
                  pivot.overlaps(wingB) ||
                  wingA.overlaps(wingB)) {
                continue;
              }
              if (!_restrictedCommon(board, pivot, wingB, y)) continue;
              final zs = wingA.digits.intersection(wingB.digits);
              for (final z in zs) {
                if (z == x || z == y) continue;
                final zCells = [
                  ...wingA.cellsWith(board, z),
                  ...wingB.cellsWith(board, z),
                ];
                final elims = _seenByAll(board, z, zCells);
                if (elims.isEmpty) continue;
                return _alsXyHint(board, pivot, wingA, wingB, x, y, z, elims);
              }
            }
          }
        }
      }
    }
    return null;
  }

  static List<_Als> _houseAls(SudokuBoard board, {int maxSize = 5}) {
    final out = <_Als>[];
    final seen = <String>{};
    for (final unit in _allUnits()) {
      final empty = [
        for (final cell in unit.cells)
          if (board.get(cell[0], cell[1]) == 0) cell
      ];
      final n = empty.length;
      if (n == 0) continue;
      for (var mask = 1; mask < (1 << n); mask++) {
        final cells = <List<int>>[];
        for (var i = 0; i < n; i++) {
          if (mask & (1 << i) != 0) cells.add(empty[i]);
        }
        if (cells.isEmpty || cells.length > maxSize) continue;
        final digits = <int>{};
        for (final cell in cells) {
          digits.addAll(board.getCandidates(cell[0], cell[1]));
        }
        if (digits.length != cells.length + 1) continue;
        final keys = {for (final cell in cells) '${cell[0]},${cell[1]}'};
        final id = (keys.toList()..sort()).join('|');
        if (!seen.add(id)) continue;
        out.add(_Als(cells, digits, keys));
      }
    }
    out.sort((a, b) {
      final bySize = a.cells.length.compareTo(b.cells.length);
      if (bySize != 0) return bySize;
      return a.id.compareTo(b.id);
    });
    return out;
  }

  static bool _restrictedCommon(
    SudokuBoard board,
    _Als a,
    _Als b,
    int digit,
  ) {
    final aCells = a.cellsWith(board, digit);
    final bCells = b.cellsWith(board, digit);
    if (aCells.isEmpty || bCells.isEmpty) return false;
    return aCells.every(
      (left) => bCells.every(
        (right) => _canSee(left[0], left[1], right[0], right[1]),
      ),
    );
  }

  static List<CandidateElim> _seenByAll(
    SudokuBoard board,
    int digit,
    List<List<int>> sources,
  ) {
    final sourceKeys = {for (final cell in sources) '${cell[0]},${cell[1]}'};
    final elims = <CandidateElim>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        if (sourceKeys.contains('$row,$col')) continue;
        if (!board.getCandidates(row, col).contains(digit)) continue;
        if (sources.every((cell) => _canSee(row, col, cell[0], cell[1]))) {
          elims.add(CandidateElim(row, col, digit));
        }
      }
    }
    return elims;
  }

  static SudokuHint _alsXzHint(
    SudokuBoard board,
    _Als a,
    _Als b,
    int x,
    int z,
    List<CandidateElim> elims,
  ) {
    final aRefs = a.cells.map((c) => cellRef(c[0], c[1])).join(', ');
    final bRefs = b.cells.map((c) => cellRef(c[0], c[1])).join(', ');
    final delRefs = elims.map((e) => candRef(e.row, e.col, e.num)).join(', ');
    return SudokuHint.elimination(
      technique: 'ALS-XZ',
      explanation: 'ALS A（$aRefs）与 ALS B（$bRefs）以 $x 为限制公共候选，'
          '无论 $x 落在哪一侧，Z=$z 都会出现在某个 ALS 里，因此同时看见两边所有 '
          '$z 的 $delRefs 可删。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, a.cells),
        ...hintCells(HintRole.extra, b.cells),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        for (final cell in a.cells)
          ...hintDigits(
              HintRole.pattern, cell, board.getCandidates(cell[0], cell[1])),
        for (final cell in b.cells)
          ...hintDigits(
              HintRole.extra, cell, board.getCandidates(cell[0], cell[1])),
        ..._targetCands(elims),
      ],
      links: [
        for (final left in a.cellsWith(board, x))
          for (final right in b.cellsWith(board, x))
            MarkupArrow(
              from: CandidateRef(left[0], left[1], x),
              to: CandidateRef(right[0], right[1], x),
              kind: ArrowKind.strong,
            ),
      ],
    );
  }

  static SudokuHint _alsXyHint(
    SudokuBoard board,
    _Als pivot,
    _Als wingA,
    _Als wingB,
    int x,
    int y,
    int z,
    List<CandidateElim> elims,
  ) {
    final pRefs = pivot.cells.map((c) => cellRef(c[0], c[1])).join(', ');
    final aRefs = wingA.cells.map((c) => cellRef(c[0], c[1])).join(', ');
    final bRefs = wingB.cells.map((c) => cellRef(c[0], c[1])).join(', ');
    final delRefs = elims.map((e) => candRef(e.row, e.col, e.num)).join(', ');
    return SudokuHint.elimination(
      technique: 'ALS-XY-Wing',
      explanation: '支点 ALS（$pRefs）用 $x 连接翼 A（$aRefs）、用 $y 连接翼 B（$bRefs）。'
          '无论支点用掉 $x 还是 $y，Z=$z 都会落在某个翼里，因此同时看见两翼所有 '
          '$z 的 $delRefs 可删。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, pivot.cells),
        ...hintCells(HintRole.extra, [...wingA.cells, ...wingB.cells]),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        for (final cell in pivot.cells)
          ...hintDigits(
              HintRole.pattern, cell, board.getCandidates(cell[0], cell[1])),
        for (final cell in [...wingA.cells, ...wingB.cells])
          ...hintDigits(
              HintRole.extra, cell, board.getCandidates(cell[0], cell[1])),
        ..._targetCands(elims),
      ],
      links: [
        for (final left in pivot.cellsWith(board, x))
          for (final right in wingA.cellsWith(board, x))
            MarkupArrow(
              from: CandidateRef(left[0], left[1], x),
              to: CandidateRef(right[0], right[1], x),
              kind: ArrowKind.strong,
            ),
        for (final left in pivot.cellsWith(board, y))
          for (final right in wingB.cellsWith(board, y))
            MarkupArrow(
              from: CandidateRef(left[0], left[1], y),
              to: CandidateRef(right[0], right[1], y),
              kind: ArrowKind.strong,
            ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Grouped AIC：节点可以是同宫一行/一列的一组候选，强弱交替，两端同数字
  // ---------------------------------------------------------------------------

  static SudokuHint? findGroupedAic(SudokuBoard board) {
    final nodes = _aicNodes(board);
    if (nodes.isEmpty) return null;
    final byId = {for (final n in nodes) n.id: n};
    final strong = _aicStrong(board, nodes);
    nodes.sort((a, b) => b.cells.length.compareTo(a.cells.length));

    for (final start in nodes) {
      var frontier = <List<String>>[
        [start.id]
      ];
      var needStrong = true;
      final seenStrong = {start.id};
      for (var links = 0; links < 12; links++) {
        final nextFrontier = <List<String>>[];
        final nextSeen = <String>{};
        for (final path in frontier) {
          final cur = byId[path.last]!;
          final nbrs = needStrong
              ? (strong[cur.id] ?? const <String>{})
              : _aicWeak(cur, nodes);
          for (final nxtId in nbrs) {
            if (nxtId == start.id) continue;
            if (path.contains(nxtId)) continue;
            final nxt = byId[nxtId]!;
            if (needStrong &&
                nxt.digit == start.digit &&
                (start.cells.length > 1 || nxt.cells.length > 1)) {
              final elims = _aicElims(board, start, nxt);
              if (elims.isNotEmpty) {
                return _groupedAicHint(
                  board,
                  [for (final id in [...path, nxtId]) byId[id]!],
                  elims,
                );
              }
            }
            if (needStrong && seenStrong.contains(nxtId)) continue;
            nextFrontier.add([...path, nxtId]);
            nextSeen.add(nxtId);
          }
        }
        if (needStrong) seenStrong.addAll(nextSeen);
        if (nextFrontier.isEmpty) break;
        frontier = nextFrontier;
        needStrong = !needStrong;
      }
    }
    return null;
  }

  static List<_AicNode> _aicNodes(SudokuBoard board) {
    final out = <String, _AicNode>{};
    void add(List<List<int>> cells, int digit) {
      if (cells.isEmpty) return;
      final node = _AicNode(cells, digit);
      out.putIfAbsent(node.id, () => node);
    }

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        for (final digit in board.getCandidates(row, col)) {
          add([
            [row, col]
          ], digit);
        }
      }
    }
    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxCol = 0; boxCol < 3; boxCol++) {
        for (var digit = 1; digit <= 9; digit++) {
          for (var i = 0; i < 3; i++) {
            final row = boxRow * 3 + i;
            final cells = [
              for (var j = 0; j < 3; j++)
                if (board.get(row, boxCol * 3 + j) == 0 &&
                    board.getCandidates(row, boxCol * 3 + j).contains(digit))
                  [row, boxCol * 3 + j]
            ];
            if (cells.length >= 2) add(cells, digit);
          }
          for (var j = 0; j < 3; j++) {
            final col = boxCol * 3 + j;
            final cells = [
              for (var i = 0; i < 3; i++)
                if (board.get(boxRow * 3 + i, col) == 0 &&
                    board.getCandidates(boxRow * 3 + i, col).contains(digit))
                  [boxRow * 3 + i, col]
            ];
            if (cells.length >= 2) add(cells, digit);
          }
        }
      }
    }
    return out.values.toList();
  }

  static Map<String, Set<String>> _aicStrong(
    SudokuBoard board,
    List<_AicNode> nodes,
  ) {
    final strong = {for (final n in nodes) n.id: <String>{}};
    for (final house in _allUnits()) {
      for (var digit = 1; digit <= 9; digit++) {
        final spots = [
          for (final cell in house.cells)
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).contains(digit))
              cell
        ];
        if (spots.length < 2) continue;
        final spotKeys = {for (final c in spots) '${c[0]},${c[1]}'};
        final covering = [
          for (final n in nodes)
            if (n.digit == digit && n.keys.difference(spotKeys).isEmpty) n
        ];
        for (var i = 0; i < covering.length; i++) {
          for (var j = i + 1; j < covering.length; j++) {
            final a = covering[i];
            final b = covering[j];
            if (a.overlaps(b)) continue;
            final union = {...a.keys, ...b.keys};
            if (union.length == spotKeys.length &&
                union.containsAll(spotKeys)) {
              strong[a.id]!.add(b.id);
              strong[b.id]!.add(a.id);
            }
          }
        }
      }
    }
    return strong;
  }

  static Set<String> _aicWeak(_AicNode cur, List<_AicNode> nodes) {
    final out = <String>{};
    for (final other in nodes) {
      if (other.id == cur.id) continue;
      if (cur.digit == other.digit) {
        if (cur.cells.every(
            (a) => other.cells.every((b) => _canSee(a[0], a[1], b[0], b[1])))) {
          out.add(other.id);
        }
      } else if (cur.cells.length == 1 &&
          other.cells.length == 1 &&
          cur.cells[0][0] == other.cells[0][0] &&
          cur.cells[0][1] == other.cells[0][1]) {
        out.add(other.id);
      }
    }
    return out;
  }

  static List<CandidateElim> _aicElims(
    SudokuBoard board,
    _AicNode start,
    _AicNode end,
  ) {
    final used = {...start.keys, ...end.keys};
    final elims = <CandidateElim>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        if (used.contains('$row,$col')) continue;
        if (!board.getCandidates(row, col).contains(start.digit)) continue;
        if (start.cells.every((c) => _canSee(row, col, c[0], c[1])) &&
            end.cells.every((c) => _canSee(row, col, c[0], c[1]))) {
          elims.add(CandidateElim(row, col, start.digit));
        }
      }
    }
    return elims;
  }

  static SudokuHint _groupedAicHint(
    SudokuBoard board,
    List<_AicNode> chain,
    List<CandidateElim> elims,
  ) {
    final start = chain.first;
    final end = chain.last;
    final startRefs =
        start.cells.map((c) => candRef(c[0], c[1], start.digit)).join(', ');
    final endRefs =
        end.cells.map((c) => candRef(c[0], c[1], end.digit)).join(', ');
    final delRefs = elims.map((e) => candRef(e.row, e.col, e.num)).join(', ');
    final mid = chain.skip(1).take(chain.length - 2);
    return SudokuHint.elimination(
      technique: 'Grouped AIC',
      explanation: '成组节点 {$startRefs} 与 {$endRefs} 经强弱交替相连，'
          '两端数字 ${start.digit} 至少有一处为真，因此同时看见两端的 $delRefs 可删。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, start.cells),
        ...hintCells(HintRole.extra, end.cells),
        ...hintCells(HintRole.link, [for (final node in mid) ...node.cells]),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ...hintCands(HintRole.pattern, start.digit, start.cells),
        ...hintCands(HintRole.extra, end.digit, end.cells),
        for (final node in mid)
          ...hintCands(HintRole.link, node.digit, node.cells),
        ..._targetCands(elims),
      ],
      links: [
        for (var i = 0; i < chain.length - 1; i++)
          for (final a in chain[i].cells)
            for (final b in chain[i + 1].cells)
              MarkupArrow(
                from: CandidateRef(a[0], a[1], chain[i].digit),
                to: CandidateRef(b[0], b[1], chain[i + 1].digit),
                kind: i.isEven ? ArrowKind.strong : ArrowKind.weak,
              ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // Nishio：假设一个候选，只用唯余/摒除往下推，若某格候选被排空则删除该假设
  // ---------------------------------------------------------------------------

  static SudokuHint? findNishio(SudokuBoard board) {
    final tries = <List<int>>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final cands = board.getCandidates(row, col);
        if (cands.length < 2 || cands.length > 3) continue;
        for (final digit in cands) {
          tries.add([row, col, digit]);
        }
      }
    }
    tries.sort((a, b) {
      final bySize = board
          .getCandidates(a[0], a[1])
          .length
          .compareTo(board.getCandidates(b[0], b[1]).length);
      if (bySize != 0) return bySize;
      return a[2].compareTo(b[2]);
    });

    for (final trial in tries) {
      final row = trial[0];
      final col = trial[1];
      final digit = trial[2];
      final work = board.copy();
      work.set(row, col, digit);
      final result = _propagateSingles(work);
      if (result.contradiction == null) continue;
      final chain = [
        [row, col, digit],
        ...result.path,
      ];
      return SudokuHint.elimination(
        technique: 'Nishio',
        explanation: '假设 ${candRef(row, col, digit)}'
            '${result.path.isEmpty ? '' : ' → ${_pathText(result.path)}'}，'
            '推到 ${cellRef(result.contradiction![0], result.contradiction![1])} '
            '候选被排空，矛盾，因此该假设不成立，删除 '
            '${candRef(row, col, digit)}。',
        eliminations: [CandidateElim(row, col, digit)],
        patternCells: [
          HintCell(row, col, HintRole.pattern),
          ...hintCells(HintRole.link, [
            for (final step in result.path) [step[0], step[1]]
          ]),
          HintCell(
            result.contradiction![0],
            result.contradiction![1],
            HintRole.extra,
          ),
          HintCell(row, col, HintRole.target),
        ],
        patternCandidates: [
          HintCandidate(CandidateRef(row, col, digit), HintRole.pattern),
          ..._pathCands(result.path),
          ..._targetCands([CandidateElim(row, col, digit)]),
        ],
        links: _implicationArrows(chain),
      );
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 教学向浅层技巧：先于 Grouped AIC / ALS 报出更易懂的形态
  // ---------------------------------------------------------------------------

  static SudokuHint? findFinnedXWing(SudokuBoard board) =>
      _findFinnedFish(board, 2, '带鳍 X-Wing');

  static SudokuHint? findFinnedSwordfish(SudokuBoard board) =>
      _findFinnedFish(board, 3, '带鳍 Swordfish');

  static SudokuHint? findFinnedJellyfish(SudokuBoard board) =>
      _findFinnedFish(board, 4, '带鳍 Jellyfish');

  static SudokuHint? _findFinnedFish(
    SudokuBoard board,
    int size,
    String name,
  ) {
    for (var digit = 1; digit <= 9; digit++) {
      final rows = _finnedOnLines(board, size, digit, true, name);
      if (rows != null) return rows;
      final cols = _finnedOnLines(board, size, digit, false, name);
      if (cols != null) return cols;
    }
    return null;
  }

  static List<int> _digitOnLine(
    SudokuBoard board,
    int line,
    int digit, {
    required bool byRow,
  }) =>
      [
        for (var i = 0; i < 9; i++)
          if (board.get(byRow ? line : i, byRow ? i : line) == 0 &&
              board
                  .getCandidates(byRow ? line : i, byRow ? i : line)
                  .contains(digit))
            i
      ];

  static SudokuHint? _finnedOnLines(
    SudokuBoard board,
    int size,
    int digit,
    bool byRow,
    String name,
  ) {
    final lines = [for (var i = 0; i < 9; i++) i];
    for (final base in _combinations(lines, size)) {
      final sets = [
        for (final line in base)
          _digitOnLine(board, line, digit, byRow: byRow).toSet(),
      ];
      if (sets.any((s) => s.isEmpty)) continue;
      for (var finIndex = 0; finIndex < size; finIndex++) {
        final cover = <int>{};
        var ok = true;
        for (var i = 0; i < size; i++) {
          if (i == finIndex) continue;
          cover.addAll(sets[i]);
        }
        if (cover.length != size) continue;
        for (var i = 0; i < size; i++) {
          if (i == finIndex) continue;
          if (!sets[i].every(cover.contains)) {
            ok = false;
            break;
          }
        }
        if (!ok) continue;
        final finned = sets[finIndex];
        if (!cover.every(finned.contains)) continue;
        final fins = finned.difference(cover);
        if (fins.isEmpty) continue;
        final finLine = base[finIndex];
        for (final coverCross in cover) {
          if (!fins.every((pos) => pos ~/ 3 == coverCross ~/ 3)) continue;
          final boxLine = finLine ~/ 3;
          final elims = <CandidateElim>[];
          for (var i = boxLine * 3; i < boxLine * 3 + 3; i++) {
            if (base.contains(i)) continue;
            final row = byRow ? i : coverCross;
            final col = byRow ? coverCross : i;
            if (board.get(row, col) == 0 &&
                board.getCandidates(row, col).contains(digit)) {
              elims.add(CandidateElim(row, col, digit));
            }
          }
          if (elims.isEmpty) continue;
          final body = <List<int>>[
            for (final line in base)
              for (final cross in cover)
                if (board.get(byRow ? line : cross, byRow ? cross : line) ==
                        0 &&
                    board
                        .getCandidates(
                            byRow ? line : cross, byRow ? cross : line)
                        .contains(digit))
                  [byRow ? line : cross, byRow ? cross : line]
          ];
          final finCells = [
            for (final pos in fins)
              [byRow ? finLine : pos, byRow ? pos : finLine]
          ];
          return SudokuHint.elimination(
            technique: name,
            explanation: '数字 $digit 在 $size 条${byRow ? '行' : '列'}上几乎构成'
                '覆盖，多出的鳍 ${finCells.map((c) => cellRef(c[0], c[1])).join('、')} '
                '与一条覆盖线同宫，因此该宫内这条线上的 $digit 可删。',
            eliminations: elims,
            patternCells: [
              ...hintCells(HintRole.pattern, body),
              ...hintCells(HintRole.extra, finCells),
              ..._targetCells(elims),
            ],
            patternCandidates: [
              ...hintCands(HintRole.pattern, digit, body),
              ...hintCands(HintRole.extra, digit, finCells),
              ..._targetCands(elims),
            ],
            highlightRows: byRow ? base : const [],
            highlightCols: byRow ? const [] : base,
          );
        }
      }
    }
    return null;
  }

  static SudokuHint? findFrankenFish(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      final rowBox = _frankenLineAndBox(board, digit, true);
      if (rowBox != null) return rowBox;
      final colBox = _frankenLineAndBox(board, digit, false);
      if (colBox != null) return colBox;
    }
    return null;
  }

  static SudokuHint? _frankenLineAndBox(
    SudokuBoard board,
    int digit,
    bool byRow,
  ) {
    for (var line = 0; line < 9; line++) {
      final lineCells = [
        for (var i = 0; i < 9; i++)
          if (board.get(byRow ? line : i, byRow ? i : line) == 0 &&
              board
                  .getCandidates(byRow ? line : i, byRow ? i : line)
                  .contains(digit))
            [byRow ? line : i, byRow ? i : line]
      ];
      if (lineCells.isEmpty) continue;
      for (var boxRow = 0; boxRow < 3; boxRow++) {
        for (var boxCol = 0; boxCol < 3; boxCol++) {
          final boxCells = <List<int>>[];
          var overlap = false;
          for (var i = 0; i < 3; i++) {
            for (var j = 0; j < 3; j++) {
              final row = boxRow * 3 + i;
              final col = boxCol * 3 + j;
              if (board.get(row, col) != 0) continue;
              if (!board.getCandidates(row, col).contains(digit)) continue;
              if (byRow ? row == line : col == line) {
                overlap = true;
              } else {
                boxCells.add([row, col]);
              }
            }
          }
          if (overlap || boxCells.isEmpty) continue;
          final cover = {
            for (final cell in [...lineCells, ...boxCells])
              byRow ? cell[1] : cell[0]
          };
          if (cover.length != 2) continue;
          final elims = <CandidateElim>[];
          final boxKeys = {for (final cell in boxCells) '${cell[0]},${cell[1]}'};
          for (final cross in cover) {
            for (var i = 0; i < 9; i++) {
              if (byRow ? i == line : i == line) continue;
              final row = byRow ? i : cross;
              final col = byRow ? cross : i;
              if (boxKeys.contains('$row,$col')) continue;
              if (board.get(row, col) == 0 &&
                  board.getCandidates(row, col).contains(digit)) {
                elims.add(CandidateElim(row, col, digit));
              }
            }
          }
          if (elims.isEmpty) continue;
          final body = [...lineCells, ...boxCells];
          return SudokuHint.elimination(
            technique: 'Franken/Mutant Fish',
            explanation: '数字 $digit 在 ${byRow ? rowRef(line) : colRef(line)} '
                '与 ${boxRef(boxRow, boxCol)} 合起来只落在两条线上，这两条线其它位置的 '
                '$digit 可删。',
            eliminations: elims,
            patternCells: [
              ...hintCells(HintRole.pattern, body),
              ..._targetCells(elims),
            ],
            patternCandidates: [
              ...hintCands(HintRole.pattern, digit, body),
              ..._targetCands(elims),
            ],
            highlightRows: byRow ? [line] : const [],
            highlightCols: byRow ? const [] : [line],
          );
        }
      }
    }
    return null;
  }

  static SudokuHint? findWxyzWing(SudokuBoard board) {
    for (var pRow = 0; pRow < 9; pRow++) {
      for (var pCol = 0; pCol < 9; pCol++) {
        if (board.get(pRow, pCol) != 0) continue;
        final pivot = {...board.getCandidates(pRow, pCol)};
        if (pivot.length != 4) continue;
        final wings = <({int row, int col, Set<int> cands})>[];
        for (var row = 0; row < 9; row++) {
          for (var col = 0; col < 9; col++) {
            if (row == pRow && col == pCol) continue;
            if (board.get(row, col) != 0) continue;
            final cands = {...board.getCandidates(row, col)};
            if (cands.length != 2) continue;
            if (!cands.every(pivot.contains)) continue;
            if (!_canSee(pRow, pCol, row, col)) continue;
            wings.add((row: row, col: col, cands: cands));
          }
        }
        for (var i = 0; i < wings.length; i++) {
          for (var j = i + 1; j < wings.length; j++) {
            for (var k = j + 1; k < wings.length; k++) {
              final triple = [wings[i], wings[j], wings[k]];
              final common = pivot.intersection(triple[0].cands)
                  .intersection(triple[1].cands)
                  .intersection(triple[2].cands);
              if (common.length != 1) continue;
              final z = common.single;
              final wingDigits = {
                for (final wing in triple) ...wing.cands,
              };
              final needed = pivot.difference({z});
              final covered = wingDigits.difference({z});
              if (covered.length != needed.length ||
                  !covered.containsAll(needed)) {
                continue;
              }
              final cells = [
                [pRow, pCol],
                ...triple.map((w) => [w.row, w.col]),
              ];
              final elims = _seenByAll(board, z, cells);
              if (elims.isEmpty) continue;
              return SudokuHint.elimination(
                technique: 'WXYZ-Wing',
                explanation: '${cellRef(pRow, pCol)} 是四值支点，三翼 '
                    '${triple.map((w) => cellRef(w.row, w.col)).join('、')} '
                    '都含 $z，四格中 $z 必有其一，同时看见这四格处的 $z 可删。',
                eliminations: elims,
                patternCells: [
                  HintCell(pRow, pCol, HintRole.extra),
                  ...hintCells(HintRole.pattern, [
                    for (final wing in triple) [wing.row, wing.col]
                  ]),
                  ..._targetCells(elims),
                ],
                patternCandidates: [
                  ...hintDigits(HintRole.extra, [pRow, pCol], pivot),
                  ...[
                    for (final wing in triple)
                      ...hintDigits(
                          HintRole.pattern, [wing.row, wing.col], wing.cands)
                  ],
                  ..._targetCands(elims),
                ],
                links: [
                  for (final wing in triple)
                    MarkupArrow(
                      from: CandidateRef(pRow, pCol, z),
                      to: CandidateRef(wing.row, wing.col, z),
                      kind: ArrowKind.weak,
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

  static SudokuHint? findBugPlusOne(SudokuBoard board) {
    final triples = <List<int>>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final n = board.getCandidates(row, col).length;
        if (n == 3) {
          triples.add([row, col]);
        } else if (n != 2) {
          return null;
        }
      }
    }
    if (triples.length != 1) return null;
    final row = triples[0][0];
    final col = triples[0][1];
    final cands = board.getCandidates(row, col);
    int? fill;
    for (final digit in cands) {
      if (_bugCount(board, row, true, digit).isOdd &&
          _bugCount(board, col, false, digit).isOdd &&
          _bugBoxCount(board, row, col, digit).isOdd) {
        fill = digit;
        break;
      }
    }
    if (fill == null) return null;
    return SudokuHint(
      row: row,
      col: col,
      value: fill,
      technique: 'BUG+1',
      explanation: '${cellRef(row, col)} 是盘面唯一的非双值格。候选 $fill '
          '在其所在行、列、宫都出现奇数次；若填其余候选会退化成双值墓地、题目多解，'
          '因此这里必须填 $fill。',
      patternCells: [HintCell(row, col, HintRole.pattern)],
      patternCandidates: [
        HintCandidate(CandidateRef(row, col, fill), HintRole.pattern),
      ],
    );
  }

  static int _bugCount(SudokuBoard board, int line, bool byRow, int digit) {
    var n = 0;
    for (var i = 0; i < 9; i++) {
      final row = byRow ? line : i;
      final col = byRow ? i : line;
      if (board.get(row, col) == 0 &&
          board.getCandidates(row, col).contains(digit)) {
        n++;
      }
    }
    return n;
  }

  static int _bugBoxCount(SudokuBoard board, int row, int col, int digit) {
    var n = 0;
    final br = (row ~/ 3) * 3;
    final bc = (col ~/ 3) * 3;
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        final r = br + i;
        final c = bc + j;
        if (board.get(r, c) == 0 &&
            board.getCandidates(r, c).contains(digit)) {
          n++;
        }
      }
    }
    return n;
  }

  static SudokuHint? findXyChain(SudokuBoard board) =>
      _findCellAic(board, bivalueOnly: true, requireCycle: false, name: 'XY-Chain');

  static SudokuHint? findAic(SudokuBoard board) =>
      _findCellAic(board, bivalueOnly: false, requireCycle: false, name: 'AIC 开链');

  static SudokuHint? findNiceLoop(SudokuBoard board) => _findCellAic(
        board,
        bivalueOnly: false,
        requireCycle: true,
        name: 'Nice Loop / AIC 环',
      );

  static SudokuHint? _findCellAic(
    SudokuBoard board, {
    required bool bivalueOnly,
    required bool requireCycle,
    required String name,
  }) {
    final nodes = <String, List<int>>{};
    void add(int row, int col, int digit) {
      nodes['$row,$col,$digit'] = [row, col, digit];
    }

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final cands = board.getCandidates(row, col);
        if (bivalueOnly && cands.length != 2) continue;
        for (final digit in cands) {
          add(row, col, digit);
        }
      }
    }
    if (nodes.isEmpty) return null;

    final strong = {for (final id in nodes.keys) id: <String>{}};
    final weak = {for (final id in nodes.keys) id: <String>{}};

    void link(Map<String, Set<String>> map, String a, String b) {
      if (a == b) return;
      if (!nodes.containsKey(a) || !nodes.containsKey(b)) return;
      map[a]!.add(b);
      map[b]!.add(a);
    }

    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final cands = board.getCandidates(row, col).toList();
        if (bivalueOnly && cands.length != 2) continue;
        for (var i = 0; i < cands.length; i++) {
          for (var j = i + 1; j < cands.length; j++) {
            final a = '$row,$col,${cands[i]}';
            final b = '$row,$col,${cands[j]}';
            link(weak, a, b);
            if (cands.length == 2) link(strong, a, b);
          }
        }
      }
    }

    for (final house in _allUnits()) {
      for (var digit = 1; digit <= 9; digit++) {
        final allSpots = [
          for (final cell in house.cells)
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).contains(digit))
              cell
        ];
        final spots = [
          for (final cell in allSpots)
            if (nodes.containsKey('${cell[0]},${cell[1]},$digit')) cell
        ];
        for (var i = 0; i < spots.length; i++) {
          for (var j = i + 1; j < spots.length; j++) {
            final a = '${spots[i][0]},${spots[i][1]},$digit';
            final b = '${spots[j][0]},${spots[j][1]},$digit';
            link(weak, a, b);
            if (allSpots.length == 2) link(strong, a, b);
          }
        }
      }
    }

    for (final startId in nodes.keys) {
      final start = nodes[startId]!;
      var frontier = [
        for (final nxt in strong[startId]!) [nxt]
      ];
      final seen = {startId};
      var needStrong = false;
      for (var links = 1; links < 14; links++) {
        final nextFrontier = <List<String>>[];
        final nextSeen = <String>{};
        for (final path in frontier) {
          final curId = path.last;
          final nbrs = needStrong ? strong[curId]! : weak[curId]!;
          for (final nxtId in nbrs) {
            if (nxtId == startId) continue;
            if (seen.contains(nxtId)) continue;
            final nxt = nodes[nxtId]!;
            if (needStrong && nxt[2] == start[2] &&
                (nxt[0] != start[0] || nxt[1] != start[1])) {
              final closes = weak[nxtId]!.contains(startId);
              if (requireCycle != closes) continue;
              final elims = _seenByAll(board, start[2], [
                [start[0], start[1]],
                [nxt[0], nxt[1]],
              ]);
              if (elims.isNotEmpty) {
                final chain = <List<int>>[
                  start,
                  for (final id in path) nodes[id]!,
                  nxt,
                ];
                return SudokuHint.elimination(
                  technique: name,
                  explanation: '${candRef(start[0], start[1], start[2])} 与 '
                      '${candRef(nxt[0], nxt[1], nxt[2])} 经强弱交替相连，'
                      '两端数字 ${start[2]} 至少有一处为真，同时看见两端的候选可删。\n'
                      '${_aicNotation(chain, cycle: requireCycle)}',
                  eliminations: elims,
                  patternCells: [
                    HintCell(start[0], start[1], HintRole.pattern),
                    HintCell(nxt[0], nxt[1], HintRole.extra),
                    ...hintCells(
                      HintRole.link,
                      [
                        for (final node in chain.skip(1).take(chain.length - 2))
                          [node[0], node[1]]
                      ],
                    ),
                    ..._targetCells(elims),
                  ],
                  patternCandidates: [
                    for (var i = 0; i < chain.length; i++)
                      HintCandidate(
                        CandidateRef(chain[i][0], chain[i][1], chain[i][2]),
                        i == 0
                            ? HintRole.pattern
                            : i == chain.length - 1
                                ? HintRole.extra
                                : HintRole.link,
                      ),
                    ..._targetCands(elims),
                  ],
                  links: _aicArrows(chain, cycle: requireCycle),
                );
              }
            }
            nextFrontier.add([...path, nxtId]);
            nextSeen.add(nxtId);
          }
        }
        if (nextFrontier.isEmpty) break;
        seen.addAll(nextSeen);
        frontier = nextFrontier;
        needStrong = !needStrong;
      }
    }
    return null;
  }

  static SudokuHint? findSueDeCoq(SudokuBoard board) {
    for (var boxRow = 0; boxRow < 3; boxRow++) {
      for (var boxCol = 0; boxCol < 3; boxCol++) {
        final boxCells = [
          for (var i = 0; i < 3; i++)
            for (var j = 0; j < 3; j++) [boxRow * 3 + i, boxCol * 3 + j]
        ];
        final lines = <List<List<int>>>[
          for (var i = 0; i < 3; i++)
            [
              for (var col = 0; col < 9; col++) [boxRow * 3 + i, col]
            ],
          for (var j = 0; j < 3; j++)
            [
              for (var row = 0; row < 9; row++) [row, boxCol * 3 + j]
            ],
        ];
        for (final line in lines) {
          final inter = [
            for (final cell in boxCells)
              if (line.any((c) => c[0] == cell[0] && c[1] == cell[1]) &&
                  board.get(cell[0], cell[1]) == 0)
                cell
          ];
          if (inter.length < 2 || inter.length > 3) continue;
          final digits = <int>{
            for (final cell in inter)
              ...board.getCandidates(cell[0], cell[1])
          };
          if (digits.length < inter.length + 2) continue;
          final boxOut = [
            for (final cell in boxCells)
              if (board.get(cell[0], cell[1]) == 0 &&
                  !inter.any((c) => c[0] == cell[0] && c[1] == cell[1]))
                cell
          ];
          final lineOut = [
            for (final cell in line)
              if (board.get(cell[0], cell[1]) == 0 &&
                  !inter.any((c) => c[0] == cell[0] && c[1] == cell[1]))
                cell
          ];
          final digitList = digits.toList()..sort();
          for (var mask = 1; mask < (1 << digitList.length) - 1; mask++) {
            final pileA = <int>{
              for (var i = 0; i < digitList.length; i++)
                if (mask & (1 << i) != 0) digitList[i]
            };
            if (pileA.length < 2) continue;
            final pileB = digits.difference(pileA);
            if (pileB.length < 2) continue;
            final coverA = _exactCover(board, boxOut, pileA);
            if (coverA == null) continue;
            final coverB = _exactCover(board, lineOut, pileB);
            if (coverB == null) continue;
            final elims = <CandidateElim>[];
            final skipA = {
              for (final cell in [...inter, ...coverA]) '${cell[0]},${cell[1]}'
            };
            final skipB = {
              for (final cell in [...inter, ...coverB]) '${cell[0]},${cell[1]}'
            };
            for (final cell in boxCells) {
              if (skipA.contains('${cell[0]},${cell[1]}')) continue;
              if (board.get(cell[0], cell[1]) != 0) continue;
              for (final digit in pileA) {
                if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
                  elims.add(CandidateElim(cell[0], cell[1], digit));
                }
              }
            }
            for (final cell in line) {
              if (skipB.contains('${cell[0]},${cell[1]}')) continue;
              if (board.get(cell[0], cell[1]) != 0) continue;
              for (final digit in pileB) {
                if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
                  elims.add(CandidateElim(cell[0], cell[1], digit));
                }
              }
            }
            if (elims.isEmpty) continue;
            return SudokuHint.elimination(
              technique: 'Sue de Coq',
              explanation:
                  '${inter.map((c) => cellRef(c[0], c[1])).join('、')} 把候选拆成 '
                  '${(pileA.toList()..sort()).join('、')} 与 '
                  '${(pileB.toList()..sort()).join('、')}，分别由宫内、线上的'
                  '几乎锁定集消化，这两堆数字在对应区域的其它格子可删。',
              eliminations: elims,
              patternCells: [
                ...hintCells(HintRole.extra, inter),
                ...hintCells(HintRole.pattern, [...coverA, ...coverB]),
                ..._targetCells(elims),
              ],
              patternCandidates: [
                for (final cell in inter)
                  ...hintDigits(
                    HintRole.extra,
                    cell,
                    board.getCandidates(cell[0], cell[1]),
                  ),
                for (final cell in [...coverA, ...coverB])
                  ...hintDigits(
                    HintRole.pattern,
                    cell,
                    board.getCandidates(cell[0], cell[1]),
                  ),
                ..._targetCands(elims),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  static List<List<int>>? _exactCover(
    SudokuBoard board,
    List<List<int>> cells,
    Set<int> target,
  ) {
    final useful = [
      for (final cell in cells)
        if (board.getCandidates(cell[0], cell[1]).isNotEmpty &&
            board.getCandidates(cell[0], cell[1]).every(target.contains))
          cell
    ];
    for (final size in {target.length - 1, target.length}) {
      if (size < 1 || size > useful.length) continue;
      for (final combo in _combinations(useful, size)) {
        final union = <int>{
          for (final cell in combo) ...board.getCandidates(cell[0], cell[1])
        };
        if (union.containsAll(target) && target.containsAll(union)) {
          return combo;
        }
      }
    }
    return null;
  }

  static SudokuHint? findDeathBlossom(SudokuBoard board) {
    final als = _houseAls(board);
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final stem = board.getCandidates(row, col);
        if (stem.length < 2 || stem.length > 4) continue;
        final options = <int, List<_Als>>{};
        var possible = true;
        for (final digit in stem) {
          final petals = [
            for (final set in als)
              if (!set.keys.contains('$row,$col') &&
                  set.digits.contains(digit) &&
                  set.cellsWith(board, digit).every(
                        (cell) => _canSee(row, col, cell[0], cell[1]),
                      ))
                set
          ];
          if (petals.isEmpty) {
            possible = false;
            break;
          }
          options[digit] = petals.take(8).toList();
        }
        if (!possible) continue;
        final digits = stem.toList()..sort();
        var combo = <_Als>[];
        SudokuHint? found;
        void search(int index, Set<String> used) {
          if (found != null) return;
          if (index == digits.length) {
            final zs = combo.first.digits.difference({digits.first});
            for (var i = 1; i < combo.length; i++) {
              zs.removeWhere(
                (z) => !combo[i].digits.difference({digits[i]}).contains(z),
              );
            }
            for (final z in zs) {
              final zCells = [
                for (final petal in combo) ...petal.cellsWith(board, z)
              ];
              if (zCells.isEmpty) continue;
              final elims = _seenByAll(board, z, zCells);
              if (elims.isEmpty) continue;
              found = SudokuHint.elimination(
                technique: 'Death Blossom',
                explanation: '${cellRef(row, col)} 的每个候选都连到一个几乎锁定集，'
                    '这些花瓣都会挤出 $z，同时看见所有花瓣 $z 的格子可删。',
                eliminations: elims,
                patternCells: [
                  HintCell(row, col, HintRole.extra),
                  ...hintCells(HintRole.pattern, [
                    for (final petal in combo) ...petal.cells
                  ]),
                  ..._targetCells(elims),
                ],
                patternCandidates: [
                  ...hintDigits(HintRole.extra, [row, col], stem),
                  for (final petal in combo)
                    for (final cell in petal.cells)
                      ...hintDigits(
                        HintRole.pattern,
                        cell,
                        board.getCandidates(cell[0], cell[1]),
                      ),
                  ..._targetCands(elims),
                ],
                links: [
                  for (var i = 0; i < digits.length; i++)
                    for (final cell
                        in combo[i].cellsWith(board, digits[i]))
                      MarkupArrow(
                        from: CandidateRef(row, col, digits[i]),
                        to: CandidateRef(cell[0], cell[1], digits[i]),
                        kind: ArrowKind.weak,
                      ),
                ],
              );
              return;
            }
            return;
          }
          for (final petal in options[digits[index]]!) {
            if (petal.keys.any(used.contains)) continue;
            combo.add(petal);
            search(index + 1, {...used, ...petal.keys});
            combo.removeLast();
          }
        }

        search(0, {});
        if (found != null) return found;
      }
    }
    return null;
  }

  static SudokuHint? findKrakenFish(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      for (final house in _allUnits()) {
        final spots = [
          for (final cell in house.cells)
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).contains(digit))
              cell
        ];
        if (spots.length != 2) continue;
        for (var row = 0; row < 9; row++) {
          for (var col = 0; col < 9; col++) {
            if (board.get(row, col) != 0) continue;
            if (!board.getCandidates(row, col).contains(digit)) continue;
            if (spots.any((s) => s[0] == row && s[1] == col)) continue;
            final near = [
              for (final spot in spots)
                if (_canSee(row, col, spot[0], spot[1])) spot
            ];
            if (near.length != 1) continue;
            final far = spots.firstWhere(
              (s) => s[0] != near[0][0] || s[1] != near[0][1],
            );
            final assumed = _assumptionPath(
              board,
              far[0],
              far[1],
              digit,
              row,
              col,
              digit,
            );
            if (!assumed.removes) continue;
            final chain = [
              [far[0], far[1], digit],
              ...assumed.path,
              if (assumed.path.isEmpty ||
                  assumed.path.last[0] != row ||
                  assumed.path.last[1] != col)
                [row, col, digit],
            ];
            return SudokuHint.elimination(
              technique: 'Kraken Fish',
              explanation: '数字 $digit 在 ${house.label} 只剩 '
                  '${cellRef(spots[0][0], spots[0][1])} 与 '
                  '${cellRef(spots[1][0], spots[1][1])}。'
                  '${cellRef(near[0][0], near[0][1])} 直接看到 '
                  '${cellRef(row, col)}；假设 ${candRef(far[0], far[1], digit)}'
                  '${assumed.path.isEmpty ? '' : ' → ${_pathText(assumed.path)}'}，'
                  '同样逼掉 ${candRef(row, col, digit)}。',
              eliminations: [CandidateElim(row, col, digit)],
              patternCells: [
                HintCell(near[0][0], near[0][1], HintRole.pattern),
                HintCell(far[0], far[1], HintRole.extra),
                ...hintCells(HintRole.link, [
                  for (final step in assumed.path) [step[0], step[1]]
                ]),
                HintCell(row, col, HintRole.target),
              ],
              patternCandidates: [
                HintCandidate(
                  CandidateRef(near[0][0], near[0][1], digit),
                  HintRole.pattern,
                ),
                HintCandidate(
                  CandidateRef(far[0], far[1], digit),
                  HintRole.extra,
                ),
                ..._pathCands(assumed.path),
                ..._targetCands([CandidateElim(row, col, digit)]),
              ],
              links: [
                _strong(spots[0][0], spots[0][1], spots[1][0], spots[1][1], digit),
                ..._implicationArrows(chain),
              ],
            );
          }
        }
      }
    }
    return null;
  }

  static ({bool removes, List<List<int>> path}) _assumptionPath(
    SudokuBoard board,
    int assumeRow,
    int assumeCol,
    int assumeDigit,
    int targetRow,
    int targetCol,
    int targetDigit,
  ) {
    final work = board.copy();
    work.set(assumeRow, assumeCol, assumeDigit);
    final result = _propagateSingles(work);
    final removes = work.get(targetRow, targetCol) != 0
        ? work.get(targetRow, targetCol) != targetDigit
        : !work.getCandidates(targetRow, targetCol).contains(targetDigit);
    return (removes: removes, path: result.path);
  }

  static SudokuHint? findForcingChain(SudokuBoard board) =>
      _findForcing(board, minCands: 2, maxCands: 2, name: 'Forcing Chain');

  static SudokuHint? findForcingNet(SudokuBoard board) =>
      _findForcing(board, minCands: 3, maxCands: 4, name: 'Forcing Net');

  static SudokuHint? _findForcing(
    SudokuBoard board, {
    required int minCands,
    required int maxCands,
    required String name,
  }) {
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final cands = board.getCandidates(row, col);
        if (cands.length < minCands || cands.length > maxCands) continue;
        Map<String, int>? common;
        var contradiction = false;
        final branches = <int, List<List<int>>>{};
        for (final digit in cands) {
          final work = board.copy();
          work.set(row, col, digit);
          final result = _propagateSingles(work);
          if (result.contradiction != null) {
            contradiction = true;
            break;
          }
          branches[digit] = result.path;
          final filled = <String, int>{};
          for (var r = 0; r < 9; r++) {
            for (var c = 0; c < 9; c++) {
              if (r == row && c == col) continue;
              final value = work.get(r, c);
              if (value != 0 && board.get(r, c) == 0) {
                filled['$r,$c'] = value;
              }
            }
          }
          if (common == null) {
            common = filled;
          } else {
            common.removeWhere(
              (key, value) => filled[key] != value,
            );
          }
          if (common.isEmpty) break;
        }
        if (contradiction || common == null || common.isEmpty) continue;
        final entry = common.entries.first;
        final parts = entry.key.split(',');
        final fillRow = int.parse(parts[0]);
        final fillCol = int.parse(parts[1]);
        final pathCells = <List<int>>[
          for (final path in branches.values)
            for (final step in path) [step[0], step[1]]
        ];
        final pathCands = [
          for (final path in branches.values) ..._pathCands(path)
        ];
        final arrows = <MarkupArrow>[
          for (final branch in branches.entries)
            ..._implicationArrows([
              [row, col, branch.key],
              ...branch.value,
              if (branch.value.isEmpty ||
                  branch.value.last[0] != fillRow ||
                  branch.value.last[1] != fillCol)
                [fillRow, fillCol, entry.value],
            ]),
        ];
        final lines = [
          for (final digit in cands)
            '假设 ${candRef(row, col, digit)}'
            '${(branches[digit] ?? const []).isEmpty ? '' : ' → ${_pathText(branches[digit]!)}'}'
            ' → ${candRef(fillRow, fillCol, entry.value)}',
        ];
        return SudokuHint(
          row: fillRow,
          col: fillCol,
          value: entry.value,
          technique: name,
          explanation: '${lines.join('；')}。'
              '${cellRef(row, col)} 的每条出路都得到同一结论，'
              '因此 ${cellRef(fillRow, fillCol)} 必须是 ${entry.value}。',
          patternCells: [
            HintCell(row, col, HintRole.extra),
            ...hintCells(HintRole.link, pathCells),
            HintCell(fillRow, fillCol, HintRole.pattern),
          ],
          patternCandidates: [
            ...hintDigits(HintRole.extra, [row, col], cands),
            ...pathCands,
            HintCandidate(
              CandidateRef(fillRow, fillCol, entry.value),
              HintRole.pattern,
            ),
          ],
          links: arrows,
        );
      }
    }
    return null;
  }

  static MarkupArrow _strong(int r1, int c1, int r2, int c2, int digit) =>
      MarkupArrow(
        from: CandidateRef(r1, c1, digit),
        to: CandidateRef(r2, c2, digit),
        kind: ArrowKind.strong,
      );

  static String _pathText(List<List<int>> path) => path
      .map((step) => candRef(step[0], step[1], step[2]))
      .join(' → ');

  static List<HintCandidate> _pathCands(List<List<int>> path) => [
        for (final step in path)
          HintCandidate(
            CandidateRef(step[0], step[1], step[2]),
            HintRole.link,
          )
      ];

  static List<MarkupArrow> _implicationArrows(List<List<int>> nodes) => [
        for (var i = 0; i < nodes.length - 1; i++)
          MarkupArrow(
            from: CandidateRef(nodes[i][0], nodes[i][1], nodes[i][2]),
            to: CandidateRef(nodes[i + 1][0], nodes[i + 1][1], nodes[i + 1][2]),
            kind: ArrowKind.weak,
          )
      ];

  static String _aicNotation(List<List<int>> nodes, {bool cycle = false}) {
    final buf = StringBuffer();
    for (var i = 0; i < nodes.length; i++) {
      if (i > 0) buf.write(i.isOdd ? ' = ' : ' - ');
      buf.write(candRef(nodes[i][0], nodes[i][1], nodes[i][2]));
    }
    if (cycle && nodes.isNotEmpty) {
      buf.write(' - ');
      buf.write(candRef(nodes.first[0], nodes.first[1], nodes.first[2]));
    }
    return buf.toString();
  }

  static List<MarkupArrow> _aicArrows(
    List<List<int>> nodes, {
    bool cycle = false,
  }) {
    final arrows = [
      for (var i = 0; i < nodes.length - 1; i++)
        MarkupArrow(
          from: CandidateRef(nodes[i][0], nodes[i][1], nodes[i][2]),
          to: CandidateRef(nodes[i + 1][0], nodes[i + 1][1], nodes[i + 1][2]),
          kind: i.isEven ? ArrowKind.strong : ArrowKind.weak,
        )
    ];
    if (cycle && nodes.length >= 2) {
      arrows.add(
        MarkupArrow(
          from: CandidateRef(nodes.last[0], nodes.last[1], nodes.last[2]),
          to: CandidateRef(nodes.first[0], nodes.first[1], nodes.first[2]),
          kind: ArrowKind.weak,
        ),
      );
    }
    return arrows;
  }

  static ({List<List<int>> path, List<int>? contradiction}) _propagateSingles(
    SudokuBoard board,
  ) {
    final path = <List<int>>[];
    while (true) {
      List<int>? fill;
      var fillDigit = 0;
      for (var row = 0; row < 9; row++) {
        for (var col = 0; col < 9; col++) {
          if (board.get(row, col) != 0) continue;
          final cands = board.getCandidates(row, col);
          if (cands.isEmpty) {
            return (path: path, contradiction: [row, col]);
          }
          if (cands.length == 1 && fill == null) {
            fill = [row, col];
            fillDigit = cands.single;
          }
        }
      }
      if (fill == null) {
        final hidden = _firstHiddenSingle(board);
        if (hidden != null) {
          fill = [hidden[0], hidden[1]];
          fillDigit = hidden[2];
        }
      }
      if (fill == null) {
        return (path: path, contradiction: null);
      }
      board.set(fill[0], fill[1], fillDigit);
      path.add([fill[0], fill[1], fillDigit]);
    }
  }

  static List<int>? _firstHiddenSingle(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      for (var row = 0; row < 9; row++) {
        final cols = [
          for (var col = 0; col < 9; col++)
            if (board.get(row, col) == 0 &&
                board.getCandidates(row, col).contains(digit))
              col
        ];
        if (cols.length == 1) return [row, cols.single, digit];
      }
      for (var col = 0; col < 9; col++) {
        final rows = [
          for (var row = 0; row < 9; row++)
            if (board.get(row, col) == 0 &&
                board.getCandidates(row, col).contains(digit))
              row
        ];
        if (rows.length == 1) return [rows.single, col, digit];
      }
      for (var boxRow = 0; boxRow < 3; boxRow++) {
        for (var boxCol = 0; boxCol < 3; boxCol++) {
          final spots = <List<int>>[];
          for (var i = 0; i < 3; i++) {
            for (var j = 0; j < 3; j++) {
              final row = boxRow * 3 + i;
              final col = boxCol * 3 + j;
              if (board.get(row, col) == 0 &&
                  board.getCandidates(row, col).contains(digit)) {
                spots.add([row, col]);
              }
            }
          }
          if (spots.length == 1) {
            return [spots[0][0], spots[0][1], digit];
          }
        }
      }
    }
    return null;
  }
}

class _AicNode {
  final List<List<int>> cells;
  final int digit;
  final Set<String> keys;
  final String id;

  _AicNode(this.cells, this.digit)
      : keys = {for (final cell in cells) '${cell[0]},${cell[1]}'},
        id =
            '$digit:${(cells.map((c) => '${c[0]},${c[1]}').toList()..sort()).join('|')}';

  bool overlaps(_AicNode other) => keys.any(other.keys.contains);
}

class _Als {
  final List<List<int>> cells;
  final Set<int> digits;
  final Set<String> keys;

  _Als(this.cells, this.digits, this.keys);

  String get id => (keys.toList()..sort()).join('|');

  bool overlaps(_Als other) => keys.any(other.keys.contains);

  List<List<int>> cellsWith(SudokuBoard board, int digit) => [
        for (final cell in cells)
          if (board.getCandidates(cell[0], cell[1]).contains(digit)) cell
      ];
}

class _VirtualCell {
  final int row;
  final int col;
  final Set<int> cands;

  _VirtualCell(this.row, this.col, this.cands);
}

/// 单元（行/列/宫格）
class _Unit {
  final String type;
  final String label;
  final List<List<int>> cells;

  _Unit(this.type, this.label, this.cells);
}
