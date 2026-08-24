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
            technique: '显性四数组（${unit.type}）',
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
                technique: '隐性数对（${u.type}）',
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
                technique: '隐性三数组（${u.type}）',
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
            technique: '隐性四数组（${unit.type}）',
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
                technique: 'Unique Rectangle Type 1',
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
                technique: 'Unique Rectangle Type 1',
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
                technique: 'Unique Rectangle Type 2',
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

            final virtual = <_VirtualCell>[
              _VirtualCell(
                extras[0][0],
                extras[0][1],
                board
                    .getCandidates(extras[0][0], extras[0][1])
                    .difference(pair),
              ),
              _VirtualCell(
                extras[1][0],
                extras[1][1],
                board
                    .getCandidates(extras[1][0], extras[1][1])
                    .difference(pair),
              ),
            ];
            if (virtual.any((cell) => cell.cands.isEmpty)) continue;
            for (final cell in house) {
              final key = '${cell[0]},${cell[1]}';
              if (urKeys.contains(key) || board.get(cell[0], cell[1]) != 0) {
                continue;
              }
              virtual.add(
                _VirtualCell(
                  cell[0],
                  cell[1],
                  Set<int>.from(board.getCandidates(cell[0], cell[1])),
                ),
              );
            }

            for (var size = 2; size <= 4 && size <= virtual.length; size++) {
              for (final combo in _combinations(virtual, size)) {
                if (!combo.any(
                    (c) => c.row == extras[0][0] && c.col == extras[0][1])) {
                  continue;
                }
                if (!combo.any(
                    (c) => c.row == extras[1][0] && c.col == extras[1][1])) {
                  continue;
                }
                final union = <int>{};
                for (final cell in combo) {
                  union.addAll(cell.cands);
                }
                if (union.length != size) continue;
                final comboKeys = {
                  for (final cell in combo) '${cell.row},${cell.col}',
                };
                final elims = <CandidateElim>[];
                for (final cell in house) {
                  if (board.get(cell[0], cell[1]) != 0) continue;
                  if (comboKeys.contains('${cell[0]},${cell[1]}')) continue;
                  for (final digit in union) {
                    if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
                      elims.add(CandidateElim(cell[0], cell[1], digit));
                    }
                  }
                }
                if (elims.isNotEmpty) {
                  final digits = union.toList()..sort();
                  return SudokuHint.elimination(
                    technique: 'Unique Rectangle Type 3',
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
                  technique: 'Unique Rectangle Type 4',
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
            technique: 'Skyscraper',
            explanation: '数字 $num 在 ${rowRef(r1)} 和 ${rowRef(r2)} 各只有两个候选，'
                '在 ${colRef(baseCol)} 对齐形成 Skyscraper，'
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
            technique: 'Skyscraper',
            explanation: '数字 $num 在 ${colRef(c1)} 和 ${colRef(c2)} 各只有两个候选，'
                '在 ${rowRef(baseRow)} 对齐形成 Skyscraper，'
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
                technique: '2-String Kite',
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
                  technique: 'Empty Rectangle',
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
                  technique: 'Empty Rectangle',
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
