import '../models/board_markup.dart';
import '../models/notation.dart';
import '../models/sudoku_board.dart';
import 'sudoku_solver.dart';

/// 一条空矩形读法：宫内那几格、宫外那条强链的两格，以及删掉的那个候选。
typedef _ErReading = ({
  int boxRow,
  int boxCol,
  List<List<int>> boxCells,
  List<List<int>> linkCells,
  bool linkIsCol,
  int linkLine,
  CandidateElim elim,
});

/// 一条致命结构读法：结构格、底数，以及带了多余候选的那几格。
///
/// [cells] 上的每一格都含全部 [baseDigits]；[roofs] 是其中还留着别的候选的格子，
/// [roofExtras] 与它一一对应，装的是那几格上除底数以外的候选。
///
/// 各家族的枚举器只负责保证一件事：这些格子要是最后全落在底数里，
/// 整块结构就能换一种排法而盘外毫无变化，于是题目多解。
/// 有了这一条，「至少一个多余候选为真」就成立，
/// 类型 1–4 的推理对每个家族都是同一段话，不必按家族各写一遍。
typedef _DeadlyRead = ({
  List<List<int>> cells,
  Set<int> baseDigits,
  List<List<int>> roofs,
  List<Set<int>> roofExtras,
});

/// 虚拟格配出来的那个数组：成员格、锁住的数字、以及算出来的删除。
typedef _SubsetRead = ({
  List<_VirtualCell> cells,
  Set<int> digits,
  List<CandidateElim> elims,
});

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
                technique: '唯一矩形 1',
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
                technique: '唯一矩形 1',
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
                technique: '唯一矩形 2',
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

            // 数组要在一条同时罩住两个例外格的房屋里配。矩形的四个角正好压在两个宫上，
            // 所以两个例外格同行或同列时，往往还共一个宫，那个宫也是一条能用的房屋；
            // 对角的两格不共任何房屋，这里自然就跳过了。
            for (final house in _housesOf(extras[0][0], extras[0][1])) {
              if (!_houseHasCell(house, extras[1])) continue;
              final houseCells = _houseCells(house);
              final partners = <_VirtualCell>[];
              for (final cell in houseCells) {
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
              for (var size = 2;
                  size <= 4 && size - 1 <= partners.length;
                  size++) {
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
                  for (final cell in houseCells) {
                    if (board.get(cell[0], cell[1]) != 0) continue;
                    final key = '${cell[0]},${cell[1]}';
                    if (comboKeys.contains(key) || extraKeys.contains(key)) {
                      continue;
                    }
                    for (final digit in union) {
                      if (board
                          .getCandidates(cell[0], cell[1])
                          .contains(digit)) {
                        elims.add(CandidateElim(cell[0], cell[1], digit));
                      }
                    }
                  }
                  if (elims.isNotEmpty) {
                    final digits = union.toList()..sort();
                    final hl = _houseHighlight(house);
                    return SudokuHint.elimination(
                      technique: '唯一矩形 3',
                      explanation: '题目保证唯一解。唯一矩形的额外候选与 ${_houseLabel(house)} '
                          '其它格子组成数组 ${digits.join('、')}，'
                          '可删除这条房屋里其余格子的这些候选。',
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
                      highlightRows: hl.rows,
                      highlightCols: hl.cols,
                      highlightBoxes: hl.boxes,
                    );
                  }
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
            final digits = pair.toList();
            // 强链可以架在任何一条同时罩住两个例外格的房屋上，宫也算。
            for (final house in _housesOf(extras[0][0], extras[0][1])) {
              if (!_houseHasCell(house, extras[1])) continue;
              final houseCells = _houseCells(house);
              for (var i = 0; i < 2; i++) {
                final conjugate = digits[i];
                final other = digits[1 - i];
                final positions = houseCells
                    .where((cell) =>
                        board.get(cell[0], cell[1]) == 0 &&
                        board
                            .getCandidates(cell[0], cell[1])
                            .contains(conjugate))
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
                  final hl = _houseHighlight(house);
                  return SudokuHint.elimination(
                    technique: '唯一矩形 4',
                    explanation:
                        '题目保证唯一解。${_houseLabel(house)} 里数字 $conjugate 只剩这两格，'
                        '形成强链，因此这两格可删除数字 $other。',
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
                        from:
                            CandidateRef(extras[0][0], extras[0][1], conjugate),
                        to: CandidateRef(extras[1][0], extras[1][1], conjugate),
                        kind: ArrowKind.strong,
                      ),
                    ],
                    highlightRows: hl.rows,
                    highlightCols: hl.cols,
                    highlightBoxes: hl.boxes,
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

  // ---------------------------------------------------------------------------
  // 致命矩形的两种放宽读法：不完整唯一矩形、可规避矩形
  // ---------------------------------------------------------------------------

  /// 四个角最后要是都落在底数 `{a,b}` 里，把这两个数整块对调就能得到另一张
  /// 跟给定数毫无冲突的完整盘，题目就成了两解。所以「四角全落在底数里」不成立。
  ///
  /// 这条推理只跟给定数有关：候选表当下还剩什么、哪个角已经被玩家填上，都不影响它。
  /// 不完整唯一矩形和可规避矩形就是从这里分出来的两种读法，
  /// 所以两者共用同一段几何，只在「角是空的还是已填」上分岔。
  static SudokuHint? _findDeadlyRectangle(
    SudokuBoard board, {
    required bool avoidable,
  }) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        for (var c1 = 0; c1 < 9; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (!_isUrGeometry(r1, c1, r2, c2)) continue;
            final corners = [
              [r1, c1],
              [r1, c2],
              [r2, c1],
              [r2, c2],
            ];
            // 只要有一个角是给定数，对调就会改动题面，第二张盘造不出来。
            if (corners.any((cell) => board.isInitial(cell[0], cell[1]))) {
              continue;
            }
            final hasFilled =
                corners.any((cell) => board.get(cell[0], cell[1]) != 0);
            if (avoidable ? !hasFilled : hasFilled) continue;
            for (var a = 1; a <= 8; a++) {
              for (var b = a + 1; b <= 9; b++) {
                final hint = _deadlyRectangleReading(
                  board,
                  corners,
                  {a, b},
                  avoidable: avoidable,
                );
                if (hint != null) return hint;
              }
            }
          }
        }
      }
    }
    return null;
  }

  static SudokuHint? _deadlyRectangleReading(
    SudokuBoard board,
    List<List<int>> corners,
    Set<int> pair, {
    required bool avoidable,
  }) {
    final roofs = <List<int>>[];
    final escapes = <List<int>>[];
    final filled = <List<int>>[];
    var incomplete = false;
    for (final cell in corners) {
      final value = board.get(cell[0], cell[1]);
      if (value != 0) {
        // 已填的角只有落在底数上，「四角全是底数」这件事才还有可能发生。
        if (!pair.contains(value)) return null;
        filled.add(cell);
        continue;
      }
      final cands = board.getCandidates(cell[0], cell[1]);
      if (!cands.containsAll(pair)) incomplete = true;
      final extra = cands.difference(pair);
      if (extra.isNotEmpty) {
        roofs.add(cell);
        escapes.add(extra.toList()..sort());
      }
    }
    // 四角都完整留着底数对的，交给标准唯一矩形去报，这里不抢。
    if (!avoidable && !incomplete) return null;
    if (roofs.isEmpty) return null;

    final technique = avoidable ? '可规避矩形' : '不完整唯一矩形';
    final digits = pair.toList()..sort();
    final base = '${digits[0]}、${digits[1]}';
    final premise = avoidable
        ? '${cellsList(corners)} 四个角都不是给定数，'
            '${cellsList(filled)} 上的数字是推出来填的，'
            '把底数 $base 整块对调仍然只跟给定数打交道'
        : '${cellsList(corners)} 四个角都不是给定数，'
            '底数 $base 整块对调只跟给定数打交道；'
            '认形看的是给定数，不看候选表当下还剩什么';

    if (roofs.length == 1) {
      final roof = roofs.first;
      final elims = [
        for (final digit in digits)
          if (board.getCandidates(roof[0], roof[1]).contains(digit))
            CandidateElim(roof[0], roof[1], digit)
      ];
      if (elims.isEmpty) return null;
      final others = corners
          .where((cell) => cell[0] != roof[0] || cell[1] != roof[1])
          .toList();
      return SudokuHint.elimination(
        technique: technique,
        explanation: '$premise。'
            '${cellsList(others)} 三个角都只能落在 $base 里，'
            '${cellRef(roof[0], roof[1])} 再填底数就凑成致命矩形，'
            '所以它只能填 ${escapes.first.join('、')}。',
        eliminations: elims,
        patternCells: [
          ...hintCells(HintRole.pattern, others),
          HintCell(roof[0], roof[1], HintRole.extra),
        ],
        patternCandidates: [
          ..._deadlyBaseCands(board, others, pair),
          ...[
            for (final digit in escapes.first)
              HintCandidate(
                CandidateRef(roof[0], roof[1], digit),
                HintRole.extra,
              )
          ],
          ..._targetCands(elims),
        ],
      );
    }

    if (roofs.length != 2 ||
        escapes[0].length != 1 ||
        escapes[1].length != 1 ||
        escapes[0].first != escapes[1].first) {
      return null;
    }
    final digit = escapes[0].first;
    final elims = <CandidateElim>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        if (roofs.any((cell) => cell[0] == row && cell[1] == col)) continue;
        if (!_canSee(row, col, roofs[0][0], roofs[0][1])) continue;
        if (!_canSee(row, col, roofs[1][0], roofs[1][1])) continue;
        if (!board.getCandidates(row, col).contains(digit)) continue;
        elims.add(CandidateElim(row, col, digit));
      }
    }
    if (elims.isEmpty) return null;
    final floors = corners
        .where((cell) => !roofs.any((r) => r[0] == cell[0] && r[1] == cell[1]))
        .toList();
    return SudokuHint.elimination(
      technique: technique,
      explanation: '$premise。'
          '${cellsList(roofs)} 之外的角都只能落在 $base 里，'
          '这两个角要是也都填底数就凑成致命矩形，'
          '所以 ${cellsList(roofs)} 里至少有一格填 $digit，'
          '同时看得见这两格的 $digit 可删。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, floors),
        ...hintCells(HintRole.extra, roofs),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ..._deadlyBaseCands(board, floors, pair),
        ...hintCands(HintRole.extra, digit, roofs),
        ..._targetCands(elims),
      ],
      links: [
        MarkupArrow(
          from: CandidateRef(roofs[0][0], roofs[0][1], digit),
          to: CandidateRef(roofs[1][0], roofs[1][1], digit),
          kind: ArrowKind.strong,
        ),
      ],
    );
  }

  /// 角上还留着的底数，标成图示里的骨架；已经填好的角没有候选可标。
  static List<HintCandidate> _deadlyBaseCands(
    SudokuBoard board,
    List<List<int>> cells,
    Set<int> pair,
  ) =>
      [
        for (final cell in cells)
          if (board.get(cell[0], cell[1]) == 0)
            for (final digit in pair.toList()..sort())
              if (board.getCandidates(cell[0], cell[1]).contains(digit))
                HintCandidate(
                  CandidateRef(cell[0], cell[1], digit),
                  HintRole.pattern,
                )
      ];

  /// 不完整唯一矩形：矩形还是那个矩形，只是某个角上的底数在之前几步里被删掉过。
  ///
  /// 删除是「在题目唯一解这个前提下」推出来的结论，挡不住整块对调造出来的第二张盘，
  /// 所以认形只看给定数：四个角都不是给定数，这个矩形就依旧致命。
  static SudokuHint? findIncompleteUniqueRectangle(SudokuBoard board) =>
      _findDeadlyRectangle(board, avoidable: false);

  /// 可规避矩形：角上已经填了数字，而且这些数字必须是玩家自己推出来填的。
  ///
  /// 给定数会把对调堵死，所以四个角只要有一个是题面印上去的，这一招就不能用。
  static SudokuHint? findAvoidableRectangle(SudokuBoard board) =>
      _findDeadlyRectangle(board, avoidable: true);

  /// 一条线上这个数字还能落在哪几格。
  static List<List<int>> _digitSpots(
    SudokuBoard board,
    int line,
    int digit,
    bool byRow,
  ) =>
      [
        for (var i = 0; i < 9; i++)
          if (board.get(byRow ? line : i, byRow ? i : line) == 0 &&
              board
                  .getCandidates(byRow ? line : i, byRow ? i : line)
                  .contains(digit))
            [byRow ? line : i, byRow ? i : line]
      ];

  /// 隐性唯一矩形：不数「哪一格只剩底数对」，改数「底数还能落在哪」。
  ///
  /// 目标格 X 的行、列上底数 b 都只剩矩形上的两个位置，而 X 的对角是干净的底数对。
  /// 假设 X 填 a：两条强链把同行、同列那两个角都逼成 b，对角就只能是 a，
  /// 四角正好凑成一种致命排法。所以 a 可以从 X 上删掉。
  static SudokuHint? findHiddenUniqueRectangle(SudokuBoard board) {
    for (var r1 = 0; r1 < 9; r1++) {
      for (var r2 = r1 + 1; r2 < 9; r2++) {
        for (var c1 = 0; c1 < 9; c1++) {
          for (var c2 = c1 + 1; c2 < 9; c2++) {
            if (!_isUrGeometry(r1, c1, r2, c2)) continue;
            final corners = [
              [r1, c1],
              [r1, c2],
              [r2, c1],
              [r2, c2],
            ];
            if (corners.any((cell) =>
                board.get(cell[0], cell[1]) != 0 ||
                board.isInitial(cell[0], cell[1]))) {
              continue;
            }
            for (final target in corners) {
              final row = target[0];
              final col = target[1];
              final otherRow = row == r1 ? r2 : r1;
              final otherCol = col == c1 ? c2 : c1;
              final rowPartner = [row, otherCol];
              final colPartner = [otherRow, col];
              final diagonal = [otherRow, otherCol];
              final pair = board.getCandidates(diagonal[0], diagonal[1]);
              if (pair.length != 2) continue;
              if (!corners.every((cell) =>
                  board.getCandidates(cell[0], cell[1]).containsAll(pair))) {
                continue;
              }
              final digits = pair.toList()..sort();
              for (var i = 0; i < 2; i++) {
                final lock = digits[i];
                final gone = digits[1 - i];
                final rowSpots = _digitSpots(board, row, lock, true);
                if (rowSpots.length != 2) continue;
                if (!rowSpots.any((cell) =>
                    cell[0] == rowPartner[0] && cell[1] == rowPartner[1])) {
                  continue;
                }
                final colSpots = _digitSpots(board, col, lock, false);
                if (colSpots.length != 2) continue;
                if (!colSpots.any((cell) =>
                    cell[0] == colPartner[0] && cell[1] == colPartner[1])) {
                  continue;
                }
                return SudokuHint.elimination(
                  technique: '隐性唯一矩形',
                  explanation: '题目保证唯一解。${cellsList(corners)} 是同一个矩形，'
                      '底数对是 ${digits.join('、')}，'
                      '${cellRef(diagonal[0], diagonal[1])} 干净地只剩这两个数。'
                      '$lock 在 ${rowRef(row)} 上只剩 '
                      '${cellsList([target, rowPartner])}，'
                      '在 ${colRef(col)} 上只剩 '
                      '${cellsList([target, colPartner])}，两条都是强链。'
                      '${cellRef(row, col)} 一旦填 $gone，'
                      '这两条强链就把 ${cellRef(rowPartner[0], rowPartner[1])}、'
                      '${cellRef(colPartner[0], colPartner[1])} 都逼成 $lock，'
                      '${cellRef(diagonal[0], diagonal[1])} 只剩 $gone，'
                      '四角凑成致命排法，所以 $gone 可以从 '
                      '${cellRef(row, col)} 上删掉。',
                  eliminations: [CandidateElim(row, col, gone)],
                  patternCells: [
                    ...hintCells(HintRole.pattern, [
                      diagonal,
                      rowPartner,
                      colPartner,
                    ]),
                    HintCell(row, col, HintRole.target),
                  ],
                  patternCandidates: [
                    ...hintCands(HintRole.link, lock, [
                      target,
                      rowPartner,
                      colPartner,
                    ]),
                    ...hintCands(HintRole.pattern, gone, [
                      diagonal,
                      rowPartner,
                      colPartner,
                    ]),
                    HintCandidate(
                      CandidateRef(row, col, gone),
                      HintRole.target,
                    ),
                  ],
                  links: [
                    MarkupArrow(
                      from: CandidateRef(row, col, lock),
                      to: CandidateRef(rowPartner[0], rowPartner[1], lock),
                      kind: ArrowKind.strong,
                    ),
                    MarkupArrow(
                      from: CandidateRef(row, col, lock),
                      to: CandidateRef(colPartner[0], colPartner[1], lock),
                      kind: ArrowKind.strong,
                    ),
                  ],
                  highlightRows: [row],
                  highlightCols: [col],
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
  // 致命结构的共用判定层
  // ---------------------------------------------------------------------------

  /// 结构格上还留着的底数，标成图示里的骨架。
  static List<HintCandidate> _deadlyBaseMarks(
    SudokuBoard board,
    Iterable<List<int>> cells,
    Set<int> baseDigits,
  ) =>
      [
        for (final cell in cells)
          for (final digit in baseDigits.toList()..sort())
            if (board.getCandidates(cell[0], cell[1]).contains(digit))
              HintCandidate(
                CandidateRef(cell[0], cell[1], digit),
                HintRole.pattern,
              )
      ];

  static List<List<int>> _deadlyFloors(_DeadlyRead read) {
    final roofKeys = {for (final cell in read.roofs) '${cell[0]},${cell[1]}'};
    return [
      for (final cell in read.cells)
        if (!roofKeys.contains('${cell[0]},${cell[1]}')) cell
    ];
  }

  /// 类型 1：只有一格跳出底数，那一格就填不了底数。
  ///
  /// 多余候选恰好一个时结论最干脆——那一格只能填它，直接给填数。
  /// 多余候选有好几个时并不是「这一手不成立」，只是不知道填哪一个：
  /// 能确定的是底数一个都填不了，所以删掉这一格上剩下的全部底数。
  /// 从前这一支直接放弃，等于把一条站得住的删除白扔了。
  static SudokuHint? _deadlyType1(
    SudokuBoard board,
    _DeadlyRead read,
    String technique,
    String shape,
  ) {
    if (read.roofs.length != 1) return null;
    final roof = read.roofs.single;
    final extras = read.roofExtras.single;
    final base = (read.baseDigits.toList()..sort()).join('、');
    final roofBase = (board
        .getCandidates(roof[0], roof[1])
        .intersection(read.baseDigits)
        .toList()
      ..sort());
    final deadEnd = '要是 ${cellRef(roof[0], roof[1])} 也落在底数里，'
        '$shape 就凑成死结、题目会有两个解';

    if (extras.length == 1) {
      final digit = extras.single;
      return SudokuHint(
        row: roof[0],
        col: roof[1],
        value: digit,
        technique: technique,
        explanation: '题目保证唯一解。${cellsList(read.cells)} 构成一个$shape，'
            '底数是 $base，整块换一种排法盘外毫无变化。'
            '这几格里只有 ${cellRef(roof[0], roof[1])} 多出一个候选 $digit，'
            '$deadEnd，'
            '所以 ${cellRef(roof[0], roof[1])} 必须填 $digit。',
        patternCells: [
          ...hintCells(HintRole.pattern, _deadlyFloors(read)),
          HintCell(roof[0], roof[1], HintRole.extra),
        ],
        patternCandidates: [
          ..._deadlyBaseMarks(board, read.cells, read.baseDigits),
          HintCandidate(
            CandidateRef(roof[0], roof[1], digit),
            HintRole.extra,
          ),
        ],
      );
    }

    if (roofBase.isEmpty) return null;
    final extraList = (extras.toList()..sort()).join('、');
    return SudokuHint.elimination(
      technique: technique,
      explanation: '题目保证唯一解。${cellsList(read.cells)} 构成一个$shape，'
          '底数是 $base，整块换一种排法盘外毫无变化。'
          '这几格里只有 ${cellRef(roof[0], roof[1])} 跳得出底数，'
          '它多出来的候选是 $extraList；'
          '$deadEnd，'
          '所以 ${cellRef(roof[0], roof[1])} 只能填这几个多余候选之一——'
          '它身上的底数（${roofBase.join('、')}）都可以删。',
      eliminations: [
        for (final digit in roofBase) CandidateElim(roof[0], roof[1], digit)
      ],
      patternCells: [
        ...hintCells(HintRole.pattern, _deadlyFloors(read)),
        HintCell(roof[0], roof[1], HintRole.extra),
      ],
      patternCandidates: [
        ..._deadlyBaseMarks(board, _deadlyFloors(read), read.baseDigits),
        for (final digit in extras.toList()..sort())
          HintCandidate(
            CandidateRef(roof[0], roof[1], digit),
            HintRole.extra,
          ),
        for (final digit in roofBase)
          HintCandidate(
            CandidateRef(roof[0], roof[1], digit),
            HintRole.target,
          ),
      ],
    );
  }

  /// 类型 2：恰好两格多出同一个数字，删同时看得见这两格的位置。
  static SudokuHint? _deadlyType2(
    SudokuBoard board,
    _DeadlyRead read,
    String technique,
    String shape,
  ) {
    if (read.roofs.length != 2) return null;
    if (read.roofExtras.any((set) => set.length != 1)) return null;
    if (read.roofExtras[0].single != read.roofExtras[1].single) return null;
    final digit = read.roofExtras[0].single;
    final roofs = read.roofs;
    final elims = <CandidateElim>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        if (roofs.any((cell) => cell[0] == row && cell[1] == col)) continue;
        if (!board.getCandidates(row, col).contains(digit)) continue;
        if (!roofs.every((cell) => _canSee(row, col, cell[0], cell[1]))) {
          continue;
        }
        elims.add(CandidateElim(row, col, digit));
      }
    }
    if (elims.isEmpty) return null;
    final base = (read.baseDigits.toList()..sort()).join('、');
    return SudokuHint.elimination(
      technique: technique,
      explanation: '题目保证唯一解。${cellsList(read.cells)} 构成一个$shape，'
          '每一格都含底数 $base。'
          '除了 ${cellsList(roofs)} 各多出一个 $digit，其余格子只剩底数；'
          '这两个 $digit 要是同时为假，$shape 就只剩底数、整块换一种排法就多出一个解。'
          '所以 $digit 至少落在这两格之一，'
          '同时看得见 ${cellsList(roofs)} 的位置都能删 $digit。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, _deadlyFloors(read)),
        ...hintCells(HintRole.extra, roofs),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ..._deadlyBaseMarks(board, _deadlyFloors(read), read.baseDigits),
        ...hintCands(HintRole.extra, digit, roofs),
        ..._targetCands(elims),
      ],
      links: [
        MarkupArrow(
          from: CandidateRef(roofs[0][0], roofs[0][1], digit),
          to: CandidateRef(roofs[1][0], roofs[1][1], digit),
          kind: ArrowKind.strong,
        ),
      ],
    );
  }

  /// 类型 3：两格的多余候选合成虚拟格，和同房屋的格子配数组。
  ///
  /// 虚拟格代表的是完整性约束——「这两格里至少有一格要跳出底数」——
  /// 所以它整体只顶一格用，绝不能把两个多余候选拆开当普通裸对删。
  static SudokuHint? _deadlyType3(
    SudokuBoard board,
    _DeadlyRead read,
    String technique,
    String shape,
  ) {
    if (read.roofs.length != 2) return null;
    final virtual = {...read.roofExtras[0], ...read.roofExtras[1]};
    // 两格多出同一个数字时虚拟格只有一个候选，那是类型 2 的活，不走这里。
    if (virtual.length < 2) return null;
    final roofs = read.roofs;
    final structureKeys = {
      for (final cell in read.cells) '${cell[0]},${cell[1]}'
    };
    for (final house in _housesOf(roofs[0][0], roofs[0][1])) {
      if (!_houseHasCell(house, roofs[1])) continue;
      final sub = _virtualSubsetRead(
        board,
        house,
        roofs,
        virtual,
        structureKeys,
      );
      if (sub == null) continue;
      final digits = (sub.digits.toList()..sort()).join('、');
      final size = sub.cells.length + 1;
      final hl = _houseHighlight(house);
      final outside = (sub.digits.difference(virtual).toList()..sort());
      final roofKeys = {for (final cell in roofs) '${cell[0]},${cell[1]}'};
      final onRoof =
          sub.elims.any((e) => roofKeys.contains('${e.row},${e.col}'));
      return SudokuHint.elimination(
        technique: technique,
        explanation: '题目保证唯一解。${cellsList(read.cells)} 构成一个$shape，'
            '${cellsList(roofs)} 各带额外候选、其余格子只剩底数，'
            '所以这两格里至少有一格要填自己多出来的候选。'
            '把它们合成一个候选为 ${(virtual.toList()..sort()).join('、')} 的虚拟格，'
            '这个虚拟格只顶一格用；'
            '${_houseLabel(house)} 上的 '
            '${cellsList([
              for (final cell in sub.cells) [cell.row, cell.col]
            ])} '
            '和它凑成 $size 格锁 $size 个数字（$digits）的数组，'
            '于是 ${_houseLabel(house)} 别处的这些候选都能删。'
            '${onRoof ? '数组锁住的 ${outside.join('、')} '
                '不在虚拟格里，${cellsList(roofs)} 自己也填不了——'
                '哪一格填了它，「至少一格跳出底数」就得靠另一格兑现，'
                '这条房屋里就有 ${size + 1} 个格子去占 $size 个数字，占不下——'
                '所以这两格上的 ${outside.join('、')} 一并删去。' : ''}',
        eliminations: sub.elims,
        patternCells: [
          ...hintCells(HintRole.pattern, _deadlyFloors(read)),
          ...hintCells(HintRole.extra, roofs),
          ...[
            for (final cell in sub.cells)
              HintCell(cell.row, cell.col, HintRole.link)
          ],
          ..._targetCells(sub.elims),
        ],
        patternCandidates: [
          ..._deadlyBaseMarks(board, _deadlyFloors(read), read.baseDigits),
          for (var i = 0; i < roofs.length; i++)
            for (final digit in read.roofExtras[i].toList()..sort())
              HintCandidate(
                CandidateRef(roofs[i][0], roofs[i][1], digit),
                HintRole.extra,
              ),
          for (final cell in sub.cells)
            for (final digit in cell.cands.toList()..sort())
              HintCandidate(
                CandidateRef(cell.row, cell.col, digit),
                HintRole.link,
              ),
          ..._targetCands(sub.elims),
        ],
        links: [
          // 强链是「这个候选和那个候选至少一个为真」。
          // 两边各只多出一个候选时这话才成立；有一边多出好几个，
          // 成立的只是「这一堆里至少一个为真」，挑两个具体候选连起来就是撒谎。
          // 虚拟格这层关系靠 extra 角色和说明文字表达，不靠箭头。
          if (read.roofExtras[0].length == 1 && read.roofExtras[1].length == 1)
            MarkupArrow(
              from: CandidateRef(
                roofs[0][0],
                roofs[0][1],
                read.roofExtras[0].single,
              ),
              to: CandidateRef(
                roofs[1][0],
                roofs[1][1],
                read.roofExtras[1].single,
              ),
              kind: ArrowKind.strong,
            ),
        ],
        highlightRows: hl.rows,
        highlightCols: hl.cols,
        highlightBoxes: hl.boxes,
      );
    }
    return null;
  }

  /// 类型 4：某个底数被锁在带多余候选那两格所共处的房屋里，删这两格的其它底数。
  ///
  /// 锁定房屋只可能是「恰好盖住这两格」的那一条——结构自己那种一条线上摆三格的
  /// 房屋里，每个底数本来就要各占一次，锁不出强链，这里的落点计数会自己把它挡掉。
  static SudokuHint? _deadlyType4(
    SudokuBoard board,
    _DeadlyRead read,
    String technique,
    String shape,
  ) {
    if (read.roofs.length != 2) return null;
    final roofs = read.roofs;
    for (final house in _housesOf(roofs[0][0], roofs[0][1])) {
      if (!_houseHasCell(house, roofs[1])) continue;
      for (final lock in read.baseDigits.toList()..sort()) {
        final spots = [
          for (final cell in _houseCells(house))
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).contains(lock))
              cell
        ];
        if (spots.length != 2) continue;
        if (!roofs.every(
            (cell) => spots.any((s) => s[0] == cell[0] && s[1] == cell[1]))) {
          continue;
        }
        final elims = <CandidateElim>[];
        for (final cell in roofs) {
          for (final digit in read.baseDigits.toList()..sort()) {
            if (digit == lock) continue;
            if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
              elims.add(CandidateElim(cell[0], cell[1], digit));
            }
          }
        }
        if (elims.isEmpty) continue;
        final others = (read.baseDigits.where((d) => d != lock).toList()
              ..sort())
            .join('、');
        final hl = _houseHighlight(house);
        return SudokuHint.elimination(
          technique: technique,
          explanation: '题目保证唯一解。${cellsList(read.cells)} 构成一个$shape，'
              '每一格都含底数 ${(read.baseDigits.toList()..sort()).join('、')}；'
              '带额外候选的只有 ${cellsList(roofs)} 两格。'
              '再看 ${_houseLabel(house)}：底数 $lock 在这条房屋里只剩这两格，是条强链，'
              '$lock 一定落在其中之一。'
              '哪一格填了别的底数，$lock 就被推到对面那格，'
              '于是两格都落在底数里、$shape 凑成死结——'
              '所以这两格上的其它底数（$others）都可以删。',
          eliminations: elims,
          patternCells: [
            ...hintCells(HintRole.pattern, _deadlyFloors(read)),
            ...hintCells(HintRole.extra, roofs),
            ..._targetCells(elims),
          ],
          patternCandidates: [
            ..._deadlyBaseMarks(board, _deadlyFloors(read), read.baseDigits),
            ...hintCands(HintRole.link, lock, roofs),
            for (var i = 0; i < roofs.length; i++)
              for (final digit in read.roofExtras[i].toList()..sort())
                HintCandidate(
                  CandidateRef(roofs[i][0], roofs[i][1], digit),
                  HintRole.extra,
                ),
            ..._targetCands(elims),
          ],
          links: [
            MarkupArrow(
              from: CandidateRef(roofs[0][0], roofs[0][1], lock),
              to: CandidateRef(roofs[1][0], roofs[1][1], lock),
              kind: ArrowKind.strong,
            ),
          ],
          highlightRows: hl.rows,
          highlightCols: hl.cols,
          highlightBoxes: hl.boxes,
        );
      }
    }
    return null;
  }

  /// 虚拟格数组：[owners] 两格里至少有一格要填自己的额外候选，
  /// 所以它们合起来只顶一格用，候选就是 [virtualDigits]。
  /// 在房屋 [house] 里给这个虚拟格配上 k−1 个格子，凑成 k 格锁 k 个数字的数组，
  /// 返回第一组删得动的读法。
  ///
  /// [structureKeys] 里的格子不许当数组成员：它们是致命结构本体，
  /// 候选被限制在底数里，本来就不该跟虚拟格抢数字。
  ///
  /// [owners] 身上分两种数字：
  /// - 虚拟格自己的候选（[virtualDigits]）一个都不能删。只知道「至少一格跳出底数」，
  ///   不知道是哪一格，拆开删就把完整性约束当成裸对用了。
  /// - 数组锁住、却不属于虚拟格的那些数字可以删。假设某个例外格填了这样一个数字 d：
  ///   它不在虚拟格里，所以「至少一格跳出底数」得靠另一个例外格兑现，
  ///   那一格就要占掉一个虚拟格候选。于是这条房屋里，
  ///   k−1 个数组格 + 这一格的 d + 另一格的那个候选，一共 k+1 个格子
  ///   占了 k+1 个互不相同、全都属于数组的数字，而数组只锁着 k 个——鸽笼矛盾。
  ///   所以 d 填不了。这一支从前整块漏掉了。
  static _SubsetRead? _virtualSubsetRead(
    SudokuBoard board,
    int house,
    List<List<int>> owners,
    Set<int> virtualDigits,
    Set<String> structureKeys,
  ) {
    final ownerKeys = {for (final cell in owners) '${cell[0]},${cell[1]}'};
    final partners = <_VirtualCell>[
      for (final cell in _houseCells(house))
        if (board.get(cell[0], cell[1]) == 0 &&
            !ownerKeys.contains('${cell[0]},${cell[1]}') &&
            !structureKeys.contains('${cell[0]},${cell[1]}'))
          _VirtualCell(
            cell[0],
            cell[1],
            Set<int>.from(board.getCandidates(cell[0], cell[1])),
          )
    ];
    for (var size = 2; size <= 5 && size - 1 <= partners.length; size++) {
      for (final combo in _combinations(partners, size - 1)) {
        final union = {...virtualDigits};
        for (final cell in combo) {
          union.addAll(cell.cands);
        }
        if (union.length != size) continue;
        final comboKeys = {for (final cell in combo) '${cell.row},${cell.col}'};
        final elims = <CandidateElim>[];
        for (final cell in _houseCells(house)) {
          if (board.get(cell[0], cell[1]) != 0) continue;
          final key = '${cell[0]},${cell[1]}';
          if (comboKeys.contains(key) || ownerKeys.contains(key)) continue;
          for (final digit in union.toList()..sort()) {
            if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
              elims.add(CandidateElim(cell[0], cell[1], digit));
            }
          }
        }
        final outside = (union.difference(virtualDigits).toList()..sort());
        for (final cell in owners) {
          for (final digit in outside) {
            if (board.getCandidates(cell[0], cell[1]).contains(digit)) {
              elims.add(CandidateElim(cell[0], cell[1], digit));
            }
          }
        }
        if (elims.isNotEmpty) {
          return (cells: combo, digits: union, elims: elims);
        }
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 扩展矩形 1–4
  // ---------------------------------------------------------------------------

  /// 六格扩展矩形的全部读法。
  ///
  /// 几何是死的：三格那一侧必须整整落在一个宫里，两条线跨在不同的宫柱（宫带）上，
  /// 六格因此恰好占两个宫。这不是形状描述而是致命性的前提——
  /// 三格填的就是三个底数的一种排法，两条线整块对调之后每条线、每个宫里的
  /// 底数集合都没变，盘外看不出任何差别，于是解不唯一。
  /// 三格散在两个宫里就凑不出这一步，所以那种摆法根本不枚举。
  ///
  /// 搜索规模写死在这里：3 个宫柱（宫带）× 27 对线 × 2 种朝向 = 162 副几何，
  /// 每副几何再从六格候选的交集里取三个底数，多余候选超过两格的直接丢掉——
  /// 四型里最宽的类型 2 也只用得上两格。
  static Iterable<_DeadlyRead> _extendedRectReads(SudokuBoard board) sync* {
    for (var band = 0; band < 3; band++) {
      final trip = [band * 3, band * 3 + 1, band * 3 + 2];
      for (var l1 = 0; l1 < 9; l1++) {
        for (var l2 = l1 + 1; l2 < 9; l2++) {
          // 两条线同处一个宫柱（宫带）时六格挤进一个宫，一个宫装不下同一个底数两次。
          if (l1 ~/ 3 == l2 ~/ 3) continue;
          for (var byRow = 0; byRow < 2; byRow++) {
            final lineA = <List<int>>[
              for (final t in trip) byRow == 1 ? [l1, t] : [t, l1]
            ];
            final lineB = <List<int>>[
              for (final t in trip) byRow == 1 ? [l2, t] : [t, l2]
            ];
            yield* _extendedRectReadsOn(board, lineA, lineB);
          }
        }
      }
    }
  }

  /// 一副几何上的全部读法。
  ///
  /// 结构格不必含齐三个底数。残局里候选是一路删下来的，六格常常只剩底数的一部分，
  /// 按「六格都含全部底数」去筛会把这一类读法整批漏掉。
  /// 松开的代价是「整块对调」不再自动成立，所以每副读法都要过一遍
  /// [_extendedRectSwapClosed]：真的存在另一种排法，才算致命形。
  ///
  /// 底数从「两条线各自候选并集的交集」里取——每条线都要放齐三个底数，
  /// 一条线上根本出不来的数字当不了底数。多余候选超过两格的读法先丢掉，
  /// 四型里最宽的类型 2 也只用得上两格；这一步把绝大多数底数组合挡在对调复核之前。
  static Iterable<_DeadlyRead> _extendedRectReadsOn(
    SudokuBoard board,
    List<List<int>> lineA,
    List<List<int>> lineB,
  ) sync* {
    final candsA = <Set<int>>[];
    final candsB = <Set<int>>[];
    var poolA = <int>{};
    var poolB = <int>{};
    for (var i = 0; i < 3; i++) {
      if (board.get(lineA[i][0], lineA[i][1]) != 0) return;
      if (board.get(lineB[i][0], lineB[i][1]) != 0) return;
      candsA.add(board.getCandidates(lineA[i][0], lineA[i][1]));
      candsB.add(board.getCandidates(lineB[i][0], lineB[i][1]));
      poolA = poolA.union(candsA[i]);
      poolB = poolB.union(candsB[i]);
    }
    final pool = (poolA.intersection(poolB).toList())..sort();
    if (pool.length < 3) return;
    final cells = <List<int>>[...lineA, ...lineB];
    for (final combo in _combinations(pool, 3)) {
      final base = combo.toSet();
      final roofs = <List<int>>[];
      final roofExtras = <Set<int>>[];
      for (final cell in cells) {
        final extra = board.getCandidates(cell[0], cell[1]).difference(base);
        if (extra.isEmpty) continue;
        roofs.add(cell);
        roofExtras.add(extra);
      }
      if (roofs.length > 2) continue;
      if (!_extendedRectSwapClosed(candsA, candsB, combo)) continue;
      yield (
        cells: cells,
        baseDigits: base,
        roofs: roofs,
        roofExtras: roofExtras,
      );
    }
  }

  /// 三个下标的六种排法，用来把底数摊到一条线的三格上。
  static const _perm3 = [
    [0, 1, 2],
    [0, 2, 1],
    [1, 0, 2],
    [1, 2, 0],
    [2, 0, 1],
    [2, 1, 0],
  ];

  /// 「整块对调」是不是真的走得通。
  ///
  /// 六格全填底数时，两条线各是三个底数的一种排法，而且同一条垂直房屋上的
  /// 两格不能撞车，所以两种排法处处不同。这一对排法整块换个位置之后，
  /// 每条线、每条垂直房屋、每个宫里的底数集合都分毫不差，盘外看不出任何差别——
  /// 这才是「解不唯一」的来处。
  ///
  /// 结构格只剩底数一部分的时候，对调后要落进去的那个底数可能已经放不下了：
  /// 那种排法没有对调伙伴，「另一个解」并不存在，这一副几何就不是致命形。
  /// 所以这里把六种排法配对枚举一遍，要求
  /// 「每一种放得下的排法，它的对调伙伴也放得下」，并且至少真有一种放得下。
  /// 候选表是从已填格算出来的，六格本身都是空格，
  /// 所以挡住某个底数的一定是结构外面的格子——对调不会把它挪开。
  static bool _extendedRectSwapClosed(
    List<Set<int>> candsA,
    List<Set<int>> candsB,
    List<int> base,
  ) {
    var any = false;
    for (final pi in _perm3) {
      for (final qi in _perm3) {
        var apart = true;
        for (var i = 0; i < 3; i++) {
          if (pi[i] == qi[i]) {
            apart = false;
            break;
          }
        }
        if (!apart) continue;
        var fits = true;
        for (var i = 0; i < 3; i++) {
          if (!candsA[i].contains(base[pi[i]]) ||
              !candsB[i].contains(base[qi[i]])) {
            fits = false;
            break;
          }
        }
        if (!fits) continue;
        any = true;
        for (var i = 0; i < 3; i++) {
          if (!candsA[i].contains(base[qi[i]]) ||
              !candsB[i].contains(base[pi[i]])) {
            return false;
          }
        }
      }
    }
    return any;
  }

  static SudokuHint? findExtendedRectType1(SudokuBoard board) {
    for (final read in _extendedRectReads(board)) {
      final hint = _deadlyType1(board, read, '扩展矩形 1', '扩展矩形');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findExtendedRectType2(SudokuBoard board) {
    for (final read in _extendedRectReads(board)) {
      final hint = _deadlyType2(board, read, '扩展矩形 2', '扩展矩形');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findExtendedRectType3(SudokuBoard board) {
    for (final read in _extendedRectReads(board)) {
      final hint = _deadlyType3(board, read, '扩展矩形 3', '扩展矩形');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findExtendedRectType4(SudokuBoard board) {
    for (final read in _extendedRectReads(board)) {
      final hint = _deadlyType4(board, read, '扩展矩形 4', '扩展矩形');
      if (hint != null) return hint;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 唯一环 1–4
  // ---------------------------------------------------------------------------

  /// 环长上限。六格、八格两档就够覆盖人看得出来的唯一环，
  /// 再往上走一格分支就翻一层，收益远追不上搜索代价。
  static const _loopMaxCells = 8;

  /// 每个起点的访问上限。上面那些剪枝在正常残局上早就把搜索压得很小，
  /// 这一条只是兜底：不管盘面多离谱，这个 finder 都必须在有限步内收工。
  ///
  /// 预算按起点单独发，不是一个底数对共用一份。共用的话，
  /// 前一个起点的子树大一点就会把后面起点的份额吃掉，
  /// 「哪些环搜得到」就变成了「先搜过谁」的函数——同一副盘面、同一个环，
  /// 换个搜索次序就可能找不到。按起点发之后这条边界是说得清的一句话：
  /// 每个（底数对，起点）各有 [_loopVisitBudget] 次访问，谁也不占谁的。
  /// 总量因此有上界 36 × 81 × [_loopVisitBudget]，仍然是个常数。
  static const _loopVisitBudget = 60000;

  /// 唯一环的全部读法。
  ///
  /// 环上相邻两格同行或同列，一步横、一步竖交替走，最后竖着走回起点。
  /// 每一行、每一列、每一宫都恰好占环上两格时，「环上只填底数」这件事
  /// 就等价于「同房屋关系图上的一个两染色」：每条房屋里两格必须一个填 a
  /// 一个填 b。这张图连通又二分时恰好只有两种染色，互换颜色之后每条房屋里
  /// 底数的个数分毫不差，盘外看不出任何差别——于是解不唯一。
  ///
  /// 搜索规模是写死的：底数对 36 种，环长不超过 [_loopMaxCells]，
  /// 多余候选一超过两格就砍掉分支（四型里最宽的类型 2 也只用得上两格），
  /// 再加一条 [_loopVisitBudget] 的访问上限兜底——每个起点各发一份，
  /// 谁也占不到谁的。
  /// 交替走法本身还自带一层强剪枝：横着走用掉的行、竖着走用掉的列都不许重复，
  /// 所以「每行每列恰好两格」不必事后再核；宫的那一条和二分性交给
  /// [_loopStructureValid]。
  static Iterable<_DeadlyRead> _uniqueLoopReads(SudokuBoard board) sync* {
    for (var a = 1; a <= 8; a++) {
      for (var b = a + 1; b <= 9; b++) {
        final base = {a, b};
        final pool = <List<int>>[];
        for (var row = 0; row < 9; row++) {
          for (var col = 0; col < 9; col++) {
            if (board.get(row, col) != 0) continue;
            if (board.getCandidates(row, col).containsAll(base)) {
              pool.add([row, col]);
            }
          }
        }
        if (pool.length < 6) continue;
        for (final start in pool) {
          yield* _loopStep(
            board,
            base,
            pool,
            [start],
            <int>{},
            <int>{},
            start[0] * 9 + start[1],
            board.getCandidates(start[0], start[1]).length > 2 ? 1 : 0,
            [_loopVisitBudget],
          );
        }
      }
    }
  }

  /// 交替走一步。奇数步横着走（同行），偶数步竖着走（同列）；
  /// 起点定成环上编号最小的格子，同一个环因此只会被走出来一次。
  static Iterable<_DeadlyRead> _loopStep(
    SudokuBoard board,
    Set<int> base,
    List<List<int>> pool,
    List<List<int>> path,
    Set<int> usedRows,
    Set<int> usedCols,
    int startIndex,
    int roofs,
    List<int> budget,
  ) sync* {
    if (budget[0] <= 0) return;
    budget[0]--;
    final cur = path.last;
    final byRow = path.length.isOdd;
    final line = byRow ? cur[0] : cur[1];
    // 这一步要用掉一条线。同一条行/列用第二次就说明有格子重复占了它，
    // 「每行每列恰好两格」当场就不成立了。
    if (byRow ? usedRows.contains(line) : usedCols.contains(line)) return;

    // 竖着走时可以就地收口：回到起点所在的列，环就闭合了。
    if (!byRow && path.length >= 6 && cur[1] == path.first[1]) {
      final cells = [
        for (final cell in path) [cell[0], cell[1]]
      ];
      if (_loopStructureValid(cells)) {
        final read = _loopRead(board, cells, base);
        if (read != null) yield read;
      }
    }
    if (path.length >= _loopMaxCells) return;

    if (byRow) {
      usedRows.add(line);
    } else {
      usedCols.add(line);
    }
    for (final next in pool) {
      if (next[0] * 9 + next[1] <= startIndex) continue;
      if (byRow ? next[0] != line : next[1] != line) continue;
      if (path.any((cell) => cell[0] == next[0] && cell[1] == next[1])) {
        continue;
      }
      final grown =
          board.getCandidates(next[0], next[1]).length > 2 ? roofs + 1 : roofs;
      if (grown > 2) continue;
      path.add(next);
      yield* _loopStep(
        board,
        base,
        pool,
        path,
        usedRows,
        usedCols,
        startIndex,
        grown,
        budget,
      );
      path.removeLast();
    }
    if (byRow) {
      usedRows.remove(line);
    } else {
      usedCols.remove(line);
    }
  }

  /// 环的几何复核：每条房屋恰好占两格，而且沿环隔一格一色真的是合法染色。
  ///
  /// 行、列那两条走法已经保证了，这里连宫一起再数一遍。
  /// 二分性必须单独查：交替走出来的环本身长度是偶数，但宫有可能把环上
  /// 两个同色的格子连起来，那时候「换一种填法」根本不存在。
  /// 环连通，所以两染色唯一（只差整体换色），沿环隔一格一色就是它。
  static bool _loopStructureValid(List<List<int>> cells) {
    for (var house = 0; house < 27; house++) {
      var hit = 0;
      for (final cell in cells) {
        if (_houseHasCell(house, cell)) hit++;
      }
      if (hit != 0 && hit != 2) return false;
    }
    for (var i = 0; i < cells.length; i++) {
      for (var j = i + 2; j < cells.length; j += 2) {
        if (_canSee(cells[i][0], cells[i][1], cells[j][0], cells[j][1])) {
          return false;
        }
      }
    }
    return true;
  }

  static _DeadlyRead? _loopRead(
    SudokuBoard board,
    List<List<int>> cells,
    Set<int> base,
  ) {
    final roofs = <List<int>>[];
    final roofExtras = <Set<int>>[];
    for (final cell in cells) {
      final extra = board.getCandidates(cell[0], cell[1]).difference(base);
      if (extra.isEmpty) continue;
      roofs.add(cell);
      roofExtras.add(extra);
    }
    if (roofs.length > 2) return null;
    return (
      cells: cells,
      baseDigits: base,
      roofs: roofs,
      roofExtras: roofExtras,
    );
  }

  static SudokuHint? findUniqueLoopType1(SudokuBoard board) {
    for (final read in _uniqueLoopReads(board)) {
      final hint = _deadlyType1(board, read, '唯一环 1', '唯一环');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findUniqueLoopType2(SudokuBoard board) {
    for (final read in _uniqueLoopReads(board)) {
      final hint = _deadlyType2(board, read, '唯一环 2', '唯一环');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findUniqueLoopType3(SudokuBoard board) {
    for (final read in _uniqueLoopReads(board)) {
      final hint = _deadlyType3(board, read, '唯一环 3', '唯一环');
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? findUniqueLoopType4(SudokuBoard board) {
    for (final read in _uniqueLoopReads(board)) {
      final hint = _deadlyType4(board, read, '唯一环 4', '唯一环');
      if (hint != null) return hint;
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 探长（Borescoper's Deadly Pattern，三数）
  // ---------------------------------------------------------------------------

  /// 「结构格只填底数」的这一种填法 [f] 能不能换成另一种。
  ///
  /// 换的标准和唯一矩形那条老道理一模一样：每个房屋里结构格用掉的数字多重集
  /// 分毫不差，于是把原解里这几格改成新填法，盘外每条房屋看到的数字集合都没变，
  /// 换出来的还是一张合法完整盘——题目就有了第二个解。
  /// 允许只换其中几格：没换的格子对两边每个房屋的贡献相同。
  static bool _hasExchange(
    List<int> f,
    List<Set<int>> allowed,
    List<List<int>> cellHouses,
  ) {
    final n = f.length;
    final need = List<Map<int, int>>.generate(27, (_) => <int, int>{});
    for (var i = 0; i < n; i++) {
      for (final h in cellHouses[i]) {
        need[h][f[i]] = (need[h][f[i]] ?? 0) + 1;
      }
    }
    bool rec(int i, bool differs) {
      if (i == n) return differs;
      for (final d in allowed[i]) {
        if (cellHouses[i].any((h) => (need[h][d] ?? 0) == 0)) continue;
        for (final h in cellHouses[i]) {
          need[h][d] = need[h][d]! - 1;
        }
        final ok = rec(i + 1, differs || d != f[i]);
        for (final h in cellHouses[i]) {
          need[h][d] = need[h][d]! + 1;
        }
        if (ok) return true;
      }
      return false;
    }

    return rec(0, false);
  }

  /// 这组格子当真是致命结构吗：每一种「只填底数」的填法都换得掉，而且至少有一种。
  ///
  /// 不靠任何家族专属的图形常识，只数房屋——所以同一段代码对探长、矩形、
  /// 环都成立。有一种填法换不掉，「至少一个多余候选为真」就不成立，
  /// 类型 1–4 也就一条都不能报。
  static bool _deadlyByExchange(
    List<Set<int>> allowed,
    List<List<int>> cellHouses,
  ) {
    final n = allowed.length;
    final used = List<Set<int>>.generate(27, (_) => <int>{});
    final cur = List<int>.filled(n, 0);
    var any = false;
    var ok = true;
    void rec(int i) {
      if (i == n) {
        any = true;
        if (!_hasExchange(cur, allowed, cellHouses)) ok = false;
        return;
      }
      for (final d in allowed[i]) {
        if (cellHouses[i].any((h) => used[h].contains(d))) continue;
        cur[i] = d;
        for (final h in cellHouses[i]) {
          used[h].add(d);
        }
        rec(i + 1);
        for (final h in cellHouses[i]) {
          used[h].remove(d);
        }
        if (!ok) return;
      }
    }

    rec(0);
    return any && ok;
  }

  /// 三数探长的全部几何。
  ///
  /// 按 kazusa《三数探长致命结构的基本推理》：一个宫里两行两列交出四格、
  /// 去掉一角剩三格（直角），直角那两行各伸出一格落到宫外同一列，
  /// 两列各伸出一格落到宫外同一行，一共七格。这样数下来正好是
  /// 一行一列一宫各占三格、另有两行两列两宫各占两格，横跨三个宫。
  ///
  /// 枚举量是写死的：9 个宫 × 9 个直角顶点 × 2 × 2 种臂 × 6 条宫外列 × 6 条宫外行
  /// = 11664 副几何，与盘面无关。
  static Iterable<_DeadlyRead> _borescoperReads(SudokuBoard board) sync* {
    for (var band = 0; band < 3; band++) {
      for (var stack = 0; stack < 3; stack++) {
        for (var vi = 0; vi < 3; vi++) {
          for (var vj = 0; vj < 3; vj++) {
            final rv = band * 3 + vi;
            final cv = stack * 3 + vj;
            for (var oi = 0; oi < 3; oi++) {
              if (oi == vi) continue;
              for (var oj = 0; oj < 3; oj++) {
                if (oj == vj) continue;
                final ro = band * 3 + oi;
                final co = stack * 3 + oj;
                for (var oc = 0; oc < 9; oc++) {
                  if (oc ~/ 3 == stack) continue;
                  for (var orow = 0; orow < 9; orow++) {
                    if (orow ~/ 3 == band) continue;
                    yield* _borescoperReadsOn(board, [
                      [rv, cv],
                      [rv, co],
                      [ro, cv],
                      [rv, oc],
                      [ro, oc],
                      [orow, cv],
                      [orow, co],
                    ]);
                  }
                }
              }
            }
          }
        }
      }
    }
  }

  /// 一副七格几何上的全部读法。
  ///
  /// 类型 1–4 里最宽的也只用得上两个多余格，所以七格里至少五格的候选要落在
  /// 三个底数里；反过来说，底数只能是某五格候选的并集，而且那个并集正好三个数。
  /// 这一步用位掩码把 128 个子集扫一遍就完了，绝大多数几何在这里就被剪掉，
  /// 剩下的才值得跑一遍致命性复核。
  static Iterable<_DeadlyRead> _borescoperReadsOn(
    SudokuBoard board,
    List<List<int>> cells,
  ) sync* {
    final cands = <Set<int>>[];
    final masks = <int>[];
    for (final cell in cells) {
      if (board.get(cell[0], cell[1]) != 0) return;
      final set = board.getCandidates(cell[0], cell[1]);
      // 只剩一个候选的是唯余法，别拿它凑高阶结构。
      if (set.length < 2) return;
      cands.add(set);
      var mask = 0;
      for (final d in set) {
        mask |= 1 << d;
      }
      masks.add(mask);
    }
    final baseMasks = <int>{};
    for (var pick = 0; pick < 128; pick++) {
      var count = 0;
      var union = 0;
      var fits = true;
      for (var i = 0; i < 7; i++) {
        if (pick & (1 << i) == 0) continue;
        if (cands[i].length > 3) {
          fits = false;
          break;
        }
        count++;
        union |= masks[i];
      }
      if (!fits || count != 5) continue;
      if (_bitCount(union) == 3) baseMasks.add(union);
    }
    if (baseMasks.isEmpty) return;

    final cellHouses = [for (final cell in cells) _housesOf(cell[0], cell[1])];
    for (final mask in baseMasks) {
      final base = <int>{
        for (var d = 1; d <= 9; d++)
          if (mask & (1 << d) != 0) d
      };
      final roofs = <List<int>>[];
      final roofExtras = <Set<int>>[];
      final allowed = <Set<int>>[];
      var usable = true;
      for (var i = 0; i < 7; i++) {
        final keep = cands[i].intersection(base);
        // 一个底数都不剩的格子进不了结构，「整组换排法」也就无从谈起。
        if (keep.isEmpty) {
          usable = false;
          break;
        }
        allowed.add(keep);
        final extra = cands[i].difference(base);
        if (extra.isEmpty) continue;
        roofs.add(cells[i]);
        roofExtras.add(extra);
      }
      if (!usable || roofs.length > 2) continue;
      if (!_deadlyByExchange(allowed, cellHouses)) continue;
      yield (
        cells: cells,
        baseDigits: base,
        roofs: roofs,
        roofExtras: roofExtras,
      );
    }
  }

  /// 探长：七格三数的致命结构，用法完全照搬唯一矩形 1–4。
  ///
  /// 目录里只有「探长」一条名字，所以四型合成一个报法，内部按
  /// 类型 1、2、4、3 的老顺序试——更好认的先出面。
  static SudokuHint? findBorescoper(SudokuBoard board) {
    final reads = _borescoperReads(board).toList();
    if (reads.isEmpty) return null;
    const makers = [_deadlyType1, _deadlyType2, _deadlyType4, _deadlyType3];
    for (final make in makers) {
      for (final read in reads) {
        final hint = make(board, read, '探长', '探长致命结构');
        if (hint != null) return hint;
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 淑芬（Qiu's Deadly Pattern / QDP，类型 1）
  // ---------------------------------------------------------------------------

  /// 淑芬类型 1：两条同带整线，加上线外同宫同交叉线的两格。
  ///
  /// 搜索边界固定：横竖两向 × 3 个带 × 每带 3 对线 × 6 条带外交叉线
  /// × 3 个交点宫 × 宫内 3 对交叉线。每副几何只从线外两格的候选并集里
  /// 取 2–4 个底数；空盘上线外格都有 9 个候选，会在组合前直接剪掉。
  ///
  /// 这里只报类型 1：线外两格恰好一格带非底数候选，删除那格上的全部底数。
  /// 不调用求解器，也不读取答案。
  static SudokuHint? findQiu(SudokuBoard board) {
    // 同一盘面上常能读出好几副几何（教学盘上 r6 那对线外格会先撞上
    // {1,3} 这个真子集）。按删除最多的那一副报——同一个形状、同一层
    // 难度，先给收获大的那一手，也避免子集抢掉完整底数。
    SudokuHint? best;
    for (var byRow = 0; byRow < 2; byRow++) {
      final horizontal = byRow == 1;
      for (var band = 0; band < 3; band++) {
        final bandLines = [band * 3, band * 3 + 1, band * 3 + 2];
        for (final lines in _combinations(bandLines, 2)) {
          for (var cross = 0; cross < 9; cross++) {
            if (cross ~/ 3 == band) continue;
            for (var boxOffset = 0; boxOffset < 3; boxOffset++) {
              final crossLines = [
                boxOffset * 3,
                boxOffset * 3 + 1,
                boxOffset * 3 + 2,
              ];
              for (final pair in _combinations(crossLines, 2)) {
                final c1 = horizontal ? [cross, pair[0]] : [pair[0], cross];
                final c2 = horizontal ? [cross, pair[1]] : [pair[1], cross];
                final hint = _qiuType1On(
                  board,
                  horizontal,
                  lines,
                  c1,
                  c2,
                );
                if (hint == null) continue;
                if (best == null ||
                    hint.eliminations.length > best.eliminations.length) {
                  best = hint;
                }
              }
            }
          }
        }
      }
    }
    return best;
  }

  static SudokuHint? _qiuType1On(
    SudokuBoard board,
    bool horizontal,
    List<int> lines,
    List<int> c1,
    List<int> c2,
  ) {
    if (board.get(c1[0], c1[1]) != 0 || board.get(c2[0], c2[1]) != 0) {
      return null;
    }
    final cands1 = board.getCandidates(c1[0], c1[1]);
    final cands2 = board.getCandidates(c2[0], c2[1]);
    if (cands1.isEmpty || cands2.isEmpty) return null;
    // 类型 1 至少有一格完全落在 2–4 个底数里；两格都超过四候选时不可能。
    if (cands1.length > 4 && cands2.length > 4) return null;

    final intersections = <List<int>>[
      for (final line in lines)
        for (final c in [c1, c2]) horizontal ? [line, c[1]] : [c[0], line],
    ];
    if (intersections.any((c) => board.get(c[0], c[1]) != 0)) return null;
    final boxes = {for (final c in intersections) (c[0] ~/ 3) * 3 + c[1] ~/ 3};
    if (boxes.length != 1) return null;
    final intersectionBox = boxes.single;
    final intersectionKeys = {for (final c in intersections) '${c[0]},${c[1]}'};
    final lineCells = <List<int>>[
      for (final line in lines)
        for (var k = 0; k < 9; k++)
          if (board.get(
                horizontal ? line : k,
                horizontal ? k : line,
              ) ==
              0)
            [horizontal ? line : k, horizontal ? k : line],
    ];
    final patternLineCells = [
      for (final cell in lineCells)
        if (!intersectionKeys.contains('${cell[0]},${cell[1]}')) cell
    ];

    final pool = ({...cands1, ...cands2}.toList()..sort());
    // 从大到小取底数：{1,2,3,8} 成立时，它的真子集 {1,3} 也会过关，
    // 从小到大搜会先报子集、把完整的四数淑芬抢走。
    for (var size = pool.length < 4 ? pool.length : 4; size >= 2; size--) {
      for (final digits in _combinations(pool, size)) {
        final base = digits.toSet();
        final extras1 = cands1.difference(base);
        final extras2 = cands2.difference(base);
        if ((extras1.isEmpty ? 0 : 1) + (extras2.isEmpty ? 0 : 1) != 1) {
          continue;
        }
        final target = extras1.isNotEmpty ? c1 : c2;
        final extras = extras1.isNotEmpty ? extras1 : extras2;
        final cleanCands = extras1.isNotEmpty ? cands2 : cands1;
        // 干净那一格必须正好是底数全集，少一个底数就撑不起整组对调。
        if (cleanCands.length != base.length || !cleanCands.containsAll(base)) {
          continue;
        }
        final targetBase =
            board.getCandidates(target[0], target[1]).intersection(base);
        if (targetBase.isEmpty) continue;
        // 交点 2×2 是底数矩形：格子上不能再挂底数以外的候选，
        // 否则「底数在交点宫只能落在这四格」说的就不是这副矩形。
        if (intersections.any((cell) => board
            .getCandidates(cell[0], cell[1])
            .any((d) => !base.contains(d)))) {
          continue;
        }

        var confined = true;
        for (final digit in base) {
          var spots = 0;
          for (final cell in _houseCells(18 + intersectionBox)) {
            final r = cell[0], c = cell[1];
            final value = board.get(r, c);
            if (value == digit && !intersectionKeys.contains('$r,$c')) {
              confined = false;
              break;
            }
            if (value != 0 || !board.getCandidates(r, c).contains(digit)) {
              continue;
            }
            if (!intersectionKeys.contains('$r,$c')) {
              confined = false;
              break;
            }
            spots++;
          }
          if (!confined || spots == 0) {
            confined = false;
            break;
          }
        }
        if (!confined) continue;

        // 教学声明还要求这副几何真能「换一种排法」：线外两格只准取底数，
        // 两条整线上的空格则保留全部当前候选。逐房屋枚举这些格子的合法填法，
        // 每一种都必须存在房屋数字多重集完全相同的另一种填法。
        final structureCells = [c1, c2, ...lineCells];
        final allowed = <Set<int>>[
          cands1.intersection(base),
          cands2.intersection(base),
          for (final cell in lineCells)
            Set<int>.from(board.getCandidates(cell[0], cell[1])),
        ];
        if (allowed.any((set) => set.isEmpty)) continue;
        final cellHouses = [
          for (final cell in structureCells) _housesOf(cell[0], cell[1])
        ];
        if (!_deadlyByExchange(allowed, cellHouses)) continue;

        final elims = [
          for (final digit in targetBase.toList()..sort())
            CandidateElim(target[0], target[1], digit)
        ];

        final rows = <int>{}, cols = <int>{}, highlightBoxes = <int>{};
        final houses = <int>{
          if (horizontal) ...lines else ...lines.map((c) => 9 + c),
          if (horizontal) c1[0] else 9 + c1[1],
          if (horizontal) ...[9 + c1[1], 9 + c2[1]] else ...[c1[0], c2[0]],
          18 + intersectionBox,
          18 + (c1[0] ~/ 3) * 3 + c1[1] ~/ 3,
        };
        for (final house in houses) {
          final hl = _houseHighlight(house);
          rows.addAll(hl.rows);
          cols.addAll(hl.cols);
          highlightBoxes.addAll(hl.boxes);
        }

        return SudokuHint.elimination(
          technique: '淑芬',
          explanation: '题目保证唯一解。'
              '${horizontal ? rowsList(lines) : colsList(lines)} 是同一个大'
              '${horizontal ? "行" : "列"}里的两条整线，取线上全部空格；'
              '${cellsList([c1, c2])} 在线外同宫、同'
              '${horizontal ? "行" : "列"}，且不在这两条线的带里。'
              '它们与整线交出的 ${cellsList(intersections)} 全在 '
              '${_houseLabel(18 + intersectionBox)}，'
              '底数 ${(base.toList()..sort()).join("、")} 在该宫也只能落在这四格。'
              '${cellRef(target[0], target[1])} 是线外两格里唯一带非底数候选的格，'
              '多出来的是 ${(extras.toList()..sort()).join("、")}；'
              '若它仍填底数，两条整线连同线外两格就能换一种排法而盘外不变，题目会多解。'
              '所以它必须跳出底数，删除 ${_elimsText(elims)}。',
          eliminations: elims,
          patternCells: [
            ...hintCells(HintRole.pattern, patternLineCells),
            ...hintCells(HintRole.pattern, [c1, c2]),
            ...hintCells(HintRole.cover, intersections),
            ..._targetCells(elims),
          ],
          patternCandidates: [
            ..._deadlyBaseMarks(board, [c1, c2, ...intersections], base),
            for (final digit in extras.toList()..sort())
              HintCandidate(
                CandidateRef(target[0], target[1], digit),
                HintRole.extra,
              ),
            ..._targetCands(elims),
          ],
          highlightRows: rows.toList()..sort(),
          highlightCols: cols.toList()..sort(),
          highlightBoxes: highlightBoxes.toList()..sort(),
        );
      }
    }
    return null;
  }

  // ---------------------------------------------------------------------------
  // 死环（带守卫的同数字奇数圈 / Guarded Odd Cycle）
  // ---------------------------------------------------------------------------

  /// 死环：奇数格连成的同数字圈，各边房屋互不相同、每条只占圈上两格。
  ///
  /// 每条边上圈外剩下的同名候选叫守卫。守卫全假时每条边才成为真强链，
  /// 那时沿奇数圈真假交替绕回起点必然矛盾，所以守卫里至少一个为真——
  /// 同时看得见全部守卫的位置都放不下这个数字。
  ///
  /// 结论落在守卫上，不落在圈上：边只是「潜在强链」，直接当强链讲会把
  /// 删除误挂到圈上。守卫一个都没有的圈是「已经全强链」的奇环，
  /// 那在唯一解盘面上根本不存在，也不是这一手能报的东西。
  /// 圈长按 5、7 从短到长找，短圈更好认。
  static SudokuHint? findDeadLoop(SudokuBoard board) {
    for (final len in const [5, 7]) {
      for (var digit = 1; digit <= 9; digit++) {
        final hint = _findDeadLoopFor(board, digit, len);
        if (hint != null) return hint;
      }
    }
    return null;
  }

  static SudokuHint? _findDeadLoopFor(SudokuBoard board, int digit, int len) {
    final spots = <List<int>>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board.get(r, c) != 0) continue;
        if (!board.getCandidates(r, c).contains(digit)) continue;
        spots.add([r, c]);
      }
    }
    final n = spots.length;
    if (n < len) return null;

    final index = <String, int>{
      for (var i = 0; i < n; i++) '${spots[i][0]},${spots[i][1]}': i
    };
    final houseSpots = [
      for (var h = 0; h < 27; h++)
        [
          for (final cell in _houseCells(h))
            if (index.containsKey('${cell[0]},${cell[1]}'))
              index['${cell[0]},${cell[1]}']!
        ]
    ];
    final shared = List.generate(n, (_) => <int, List<int>>{});
    for (var h = 0; h < 27; h++) {
      final list = houseSpots[h];
      for (final i in list) {
        for (final j in list) {
          if (i == j) continue;
          (shared[i][j] ??= <int>[]).add(h);
        }
      }
    }
    final sight = List.generate(
      n,
      (i) => List.generate(
        n,
        (j) => _canSee(spots[i][0], spots[i][1], spots[j][0], spots[j][1]),
      ),
    );

    final path = <int>[];
    final houses = <int>[];
    final onPath = List<bool>.filled(n, false);
    // 被某条已定边房屋压住的格子：它们要么是守卫，要么进了圈就会让
    // 那条房屋占到第三个圈格。两种都不许再往圈上添，所以直接封掉。
    final blocked = List<int>.filled(n, 0);
    final guard = List<bool>.filled(n, false);
    final usedHouse = <int>{};

    /// committing 一条边房屋：封住它圈外的落点，同时把「看得见全部守卫」
    /// 的候选落点集收窄。收窄到空就说明这一支再往下走也删不出东西。
    List<int>? commit(int h, int a, int b, List<int> visible) {
      final newGuards = <int>[];
      for (final i in houseSpots[h]) {
        if (i == a || i == b) continue;
        newGuards.add(i);
      }
      for (final i in newGuards) {
        blocked[i]++;
        guard[i] = true;
      }
      usedHouse.add(h);
      if (newGuards.isEmpty) return visible;
      return [
        for (final v in visible)
          if (newGuards.every((g) => sight[v][g])) v
      ];
    }

    void undo(int h, int a, int b) {
      for (final i in houseSpots[h]) {
        if (i == a || i == b) continue;
        blocked[i]--;
        if (blocked[i] == 0) guard[i] = false;
      }
      usedHouse.remove(h);
    }

    SudokuHint? walk(int start, List<int> visible) {
      if (path.length == len) {
        final back = shared[path.last][start];
        if (back == null) return null;
        for (final h in back) {
          if (usedHouse.contains(h)) continue;
          if (houseSpots[h]
              .any((i) => onPath[i] && i != start && i != path.last)) {
            continue;
          }
          final last = path.last;
          final narrowed = commit(h, start, last, visible)!;
          final hint = narrowed.isEmpty
              ? null
              : _deadLoopHint(
                  board,
                  digit,
                  [for (final i in path) spots[i]],
                  [...houses, h],
                  [
                    for (var i = 0; i < n; i++)
                      if (guard[i]) spots[i]
                  ],
                );
          undo(h, start, last);
          if (hint != null) return hint;
        }
        return null;
      }
      // 起点固定成圈上编号最小的一格，同一个圈就不会正着反着各报一遍。
      final prev = path.last;
      for (var next = start + 1; next < n; next++) {
        if (onPath[next] || blocked[next] != 0) continue;
        final edges = shared[prev][next];
        if (edges == null) continue;
        for (final h in edges) {
          if (usedHouse.contains(h)) continue;
          if (houseSpots[h].any((i) => onPath[i] && i != prev)) continue;
          final narrowed = commit(h, prev, next, visible)!;
          SudokuHint? hint;
          if (narrowed.isNotEmpty && blocked[start] == 0) {
            path.add(next);
            houses.add(h);
            onPath[next] = true;
            hint = walk(start, narrowed);
            onPath[next] = false;
            houses.removeLast();
            path.removeLast();
          }
          undo(h, prev, next);
          if (hint != null) return hint;
        }
      }
      return null;
    }

    for (var start = 0; start + len <= n; start++) {
      path
        ..clear()
        ..add(start);
      houses.clear();
      usedHouse.clear();
      onPath[start] = true;
      final hint = walk(start, [
        for (var i = 0; i < n; i++)
          if (i != start) i
      ]);
      onPath[start] = false;
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _deadLoopHint(
    SudokuBoard board,
    int digit,
    List<List<int>> cycle,
    List<int> houses,
    List<List<int>> guards,
  ) {
    if (guards.isEmpty) return null;
    final cycleKeys = {for (final cell in cycle) '${cell[0]},${cell[1]}'};
    final guardKeys = {for (final cell in guards) '${cell[0]},${cell[1]}'};

    final elims = <CandidateElim>[];
    for (var r = 0; r < 9; r++) {
      for (var c = 0; c < 9; c++) {
        if (board.get(r, c) != 0) continue;
        if (!board.getCandidates(r, c).contains(digit)) continue;
        if (cycleKeys.contains('$r,$c') || guardKeys.contains('$r,$c')) {
          continue;
        }
        if (!guards.every((g) => _canSee(r, c, g[0], g[1]))) continue;
        elims.add(CandidateElim(r, c, digit));
      }
    }
    if (elims.isEmpty) return null;

    final rows = <int>[], cols = <int>[], boxes = <int>[];
    for (final h in houses) {
      final hl = _houseHighlight(h);
      rows.addAll(hl.rows);
      cols.addAll(hl.cols);
      boxes.addAll(hl.boxes);
    }
    return SudokuHint.elimination(
      technique: '死环',
      explanation:
          '盯数字 $digit。${cellsList(cycle)} 首尾连成一个 ${cycle.length} 格的奇数圈，'
          '相邻两格分别同处 ${houses.map(_houseLabel).join('、')}，'
          '这几条房屋互不相同，而且每条只占了圈上两格。'
          '这些房屋里圈外还剩的 $digit 是 ${cellsList(guards)}，叫守卫。'
          '先把守卫全假设为假：每条边的房屋里 $digit 就只剩圈上两格，条条都成了真强链，'
          '沿圈真假交替绕回起点时奇偶对不上，矛盾。'
          '所以守卫里至少有一个为真——'
          '同时看得见 ${cellsList(guards)} 的位置都放不下 $digit。'
          '（结论落在守卫上，圈上的候选一个都不删。）',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, cycle),
        ...hintCells(HintRole.extra, guards),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ...hintCands(HintRole.pattern, digit, cycle),
        ...hintCands(HintRole.extra, digit, guards),
        ..._targetCands(elims),
      ],
      links: [
        // 边画成弱箭头：守卫还在，这几条边就只是「潜在强链」。
        // 画成强链等于把「守卫全假」这个假设当成事实，结论就会滑到圈上去。
        for (var i = 0; i < cycle.length; i++)
          MarkupArrow(
            from: CandidateRef(cycle[i][0], cycle[i][1], digit),
            to: CandidateRef(
              cycle[(i + 1) % cycle.length][0],
              cycle[(i + 1) % cycle.length][1],
              digit,
            ),
            kind: ArrowKind.weak,
          ),
      ],
      highlightRows: rows,
      highlightCols: cols,
      highlightBoxes: boxes,
    );
  }

  // ---------------------------------------------------------------------------
  // 毛刺数组（Burred Subset）
  // ---------------------------------------------------------------------------

  /// 毛刺数组：一条房屋里 N 格锁 N+1 个数字，多出来的那个数字只落在一格上。
  ///
  /// 那一枚候选就是毛刺，它不当「删除对象」用，而是当推理节点：
  /// * 毛刺为假 → 剩下的 N 个数字被 N 格锁死，这条房屋里别处的这些数字都能删；
  /// * 毛刺为真 → 那一格填掉毛刺，顺着唯余摒除往下推。
  ///
  /// 只有两支都删掉的候选才算结论。甲支单删的那一串不能报——
  /// 乙支里它可能好端端地活着。
  static SudokuHint? findBurredSubset(SudokuBoard board) {
    // 两格的「数组」是一个双值格加一个三值格，甲支就是现成的裸对，
    // 乙支不过是把那一格填下去看一眼——那是裸对加短链，不是毛刺数组。
    // 报它只会把浅技巧换个难名字，所以从三格起。
    for (var size = 3; size <= 5; size++) {
      for (var house = 0; house < 27; house++) {
        final spots = [
          for (final cell in _houseCells(house))
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).length >= 2)
              cell
        ];
        if (spots.length <= size) continue;
        // 同一条房屋上常常读得出好几副毛刺数组。挑删得最多的那一副报——
        // 同一个形状、同一层难度，先给玩家收获大的那一手。
        SudokuHint? best;
        for (final combo in _combinations(spots, size)) {
          final hint = _burredSubsetOn(board, house, combo);
          if (hint == null) continue;
          if (best == null ||
              hint.eliminations.length > best.eliminations.length) {
            best = hint;
          }
        }
        if (best != null) return best;
      }
    }
    return null;
  }

  static SudokuHint? _burredSubsetOn(
    SudokuBoard board,
    int house,
    List<List<int>> cells,
  ) {
    final union = <int>{};
    for (final cell in cells) {
      union.addAll(board.getCandidates(cell[0], cell[1]));
    }
    if (union.length != cells.length + 1) return null;

    for (final burr in union.toList()..sort()) {
      final owners = [
        for (final cell in cells)
          if (board.getCandidates(cell[0], cell[1]).contains(burr)) cell
      ];
      if (owners.length != 1) continue;
      final owner = owners.single;
      // 毛刺格只剩两个候选时，「有毛刺还是没毛刺」就是这一格的双值，
      // 那是链的活，不是数组的活。
      if (board.getCandidates(owner[0], owner[1]).length < 3) continue;

      // 拿掉毛刺格之后剩的格子要是已经自己锁住自己的数字，
      // 那就是一个现成的显性数组，报毛刺等于把浅技巧换个难名字。
      final rest = [
        for (final cell in cells)
          if (cell[0] != owner[0] || cell[1] != owner[1]) cell
      ];
      final restUnion = <int>{};
      for (final cell in rest) {
        restUnion.addAll(board.getCandidates(cell[0], cell[1]));
      }
      if (restUnion.length <= rest.length) continue;

      final base = union.difference({burr});
      final cellKeys = {for (final cell in cells) '${cell[0]},${cell[1]}'};
      final lock = <CandidateElim>[];
      for (final cell in _houseCells(house)) {
        if (board.get(cell[0], cell[1]) != 0) continue;
        if (cellKeys.contains('${cell[0]},${cell[1]}')) continue;
        for (final d in base.toList()..sort()) {
          if (board.getCandidates(cell[0], cell[1]).contains(d)) {
            lock.add(CandidateElim(cell[0], cell[1], d));
          }
        }
      }
      if (lock.isEmpty) continue;

      final probe = board.copy();
      probe.set(owner[0], owner[1], burr);
      // 毛刺为真那一支就是「填下去，顺着唯余摒除推到推不动为止」，
      // 不再往前假设第二步——所以这一支里没有回溯。
      final replay = _propagateSingles(probe);
      // 当场矛盾说明毛刺本身就能删，那是 Nishio 的活，不按毛刺数组讲。
      if (replay.contradiction != null) continue;
      final both = [
        for (final e in lock)
          if (probe.get(e.row, e.col) != 0
              ? probe.get(e.row, e.col) != e.num
              : !probe.getCandidates(e.row, e.col).contains(e.num))
            e
      ];
      if (both.isEmpty) continue;

      final baseText = (base.toList()..sort()).join('、');
      final onlyA = [
        for (final e in lock)
          if (!both
              .any((b) => b.row == e.row && b.col == e.col && b.num == e.num))
            e
      ];
      final hl = _houseHighlight(house);
      return SudokuHint.elimination(
        technique: '毛刺数组',
        explanation:
            '${_houseLabel(house)} 上的 ${cellsList(cells)} 一共 ${cells.length} 格，'
            '候选并集是 ${(union.toList()..sort()).join('、')} 共 ${union.length} 个数字，'
            '多出来的 $burr 只落在 ${cellRef(owner[0], owner[1])} 上，这一枚就是毛刺。'
            '把它当成推理节点分两支看：'
            '毛刺为假时，${cellsList(cells)} 就是锁住 $baseText 的显性数组，'
            '${_houseLabel(house)} 里别处的这些数字全删；'
            '毛刺为真时，${cellRef(owner[0], owner[1])} 填 $burr，'
            '顺着唯余摒除往下推。'
            '两支都删掉的是 ${_elimsText(both)}，这才是站得住的结论。'
            '${onlyA.isEmpty ? '' : '（${_elimsText(onlyA)} 只有前一支删得掉，'
                '后一支里还活着，不能算进来。）'}',
        eliminations: both,
        patternCells: [
          ...hintCells(HintRole.pattern, cells),
          ..._targetCells(both),
        ],
        patternCandidates: [
          for (final cell in cells)
            for (final d in base.toList()..sort())
              if (board.getCandidates(cell[0], cell[1]).contains(d))
                HintCandidate(
                  CandidateRef(cell[0], cell[1], d),
                  HintRole.pattern,
                ),
          HintCandidate(CandidateRef(owner[0], owner[1], burr), HintRole.extra),
          ..._targetCands(both),
        ],
        links: [
          // 同一条房屋里同一个数字只落在两格上时，这两枚候选不可能同时为真——
          // 这是一条真弱链。落到三格上就不是链，画出来是撒谎，所以不画。
          for (final d in base.toList()..sort())
            if (cells
                    .where((c) => board.getCandidates(c[0], c[1]).contains(d))
                    .length ==
                2)
              () {
                final pair = [
                  for (final c in cells)
                    if (board.getCandidates(c[0], c[1]).contains(d)) c
                ];
                return MarkupArrow(
                  from: CandidateRef(pair[0][0], pair[0][1], d),
                  to: CandidateRef(pair[1][0], pair[1][1], d),
                  kind: ArrowKind.weak,
                );
              }(),
        ],
        highlightRows: hl.rows,
        highlightCols: hl.cols,
        highlightBoxes: hl.boxes,
      );
    }
    return null;
  }

  static String _elimsText(List<CandidateElim> elims) =>
      elims.map((e) => candRef(e.row, e.col, e.num)).join('、');

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
    for (final reading in _emptyRectangleReadings(board, digit)) {
      return _emptyRectangleHint(digit, reading);
    }
    return null;
  }

  /// 这个数字在这张盘上全部说得通的空矩形读法。
  ///
  /// 空矩形自己只报第一条，但一般多宝鱼要拿它来判重：
  /// 只有当某条读法用的是同两格强链、删的又是同一批候选时，
  /// 那条链才真的等于空矩形那一手，该让位。所以这里把读法都摊开。
  static List<_ErReading> _emptyRectangleReadings(
      SudokuBoard board, int digit) {
    final readings = <_ErReading>[];
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
                readings.add((
                  boxRow: boxRow,
                  boxCol: boxCol,
                  boxCells: positions,
                  linkCells: [
                    [rows[0], linkCol],
                    [rows[1], linkCol],
                  ],
                  linkIsCol: true,
                  linkLine: linkCol,
                  elim: CandidateElim(otherRow, coverCol, digit),
                ));
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
                readings.add((
                  boxRow: boxRow,
                  boxCol: boxCol,
                  boxCells: positions,
                  linkCells: [
                    [linkRow, cols[0]],
                    [linkRow, cols[1]],
                  ],
                  linkIsCol: false,
                  linkLine: linkRow,
                  elim: CandidateElim(coverRow, otherCol, digit),
                ));
              }
            }
          }
        }
      }
    }
    return readings;
  }

  static SudokuHint _emptyRectangleHint(int digit, _ErReading reading) {
    final elim = reading.elim;
    final lineLabel =
        reading.linkIsCol ? colRef(reading.linkLine) : rowRef(reading.linkLine);
    return SudokuHint.elimination(
      technique: '空矩形',
      explanation:
          '数字 $digit 在 ${boxRef(reading.boxRow, reading.boxCol)} 形成空矩形，'
          '并与 $lineLabel 的强链配合，可删 '
          '${candRef(elim.row, elim.col, digit)}。',
      eliminations: [elim],
      patternCells: [
        ...hintCells(HintRole.pattern, reading.boxCells),
        ...hintCells(HintRole.link, reading.linkCells),
        HintCell(elim.row, elim.col, HintRole.target),
      ],
      patternCandidates: [
        ...hintCands(HintRole.pattern, digit, reading.boxCells),
        ...hintCands(HintRole.link, digit, reading.linkCells),
        HintCandidate(
          CandidateRef(elim.row, elim.col, digit),
          HintRole.target,
        ),
      ],
      links: [
        MarkupArrow(
          from: CandidateRef(
            reading.linkCells[0][0],
            reading.linkCells[0][1],
            digit,
          ),
          to: CandidateRef(
            reading.linkCells[1][0],
            reading.linkCells[1][1],
            digit,
          ),
          kind: ArrowKind.strong,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // 多宝鱼（一般形）
  // ---------------------------------------------------------------------------

  /// 一个房屋（0-8 行，9-17 列，18-26 宫）里的全部格子。
  static List<List<int>> _houseCells(int house) {
    if (house < 9) {
      return [
        for (var c = 0; c < 9; c++) [house, c]
      ];
    }
    if (house < 18) {
      return [
        for (var r = 0; r < 9; r++) [r, house - 9]
      ];
    }
    final b = house - 18;
    final br = (b ~/ 3) * 3;
    final bc = (b % 3) * 3;
    return [
      for (var i = 0; i < 3; i++)
        for (var j = 0; j < 3; j++) [br + i, bc + j]
    ];
  }

  /// 一个格子所属的三个房屋编号。
  static List<int> _housesOf(int row, int col) =>
      [row, 9 + col, 18 + (row ~/ 3) * 3 + col ~/ 3];

  /// 把房屋编号翻成提示要淡亮的那一条房屋。
  ///
  /// 宫也是房屋。虚拟格数组、底数锁定这些技巧的关键房屋本来就可能是一个宫，
  /// 只翻行列会把这一手最要紧的那块地方整块丢掉。
  static ({List<int> rows, List<int> cols, List<int> boxes}) _houseHighlight(
    int house,
  ) =>
      (
        rows: house < 9 ? [house] : const <int>[],
        cols: house >= 9 && house < 18 ? [house - 9] : const <int>[],
        boxes: house >= 18 ? [house - 18] : const <int>[],
      );

  static String _houseLabel(int house) {
    if (house < 9) return rowRef(house);
    if (house < 18) return colRef(house - 9);
    final b = house - 18;
    return boxRef(b ~/ 3, b % 3);
  }

  /// 每个房屋里这个数字还剩的落点，按房屋编号索引。
  static List<List<List<int>>> _houseSpots(SudokuBoard board, int digit) => [
        for (var h = 0; h < 27; h++)
          [
            for (final cell in _houseCells(h))
              if (board.get(cell[0], cell[1]) == 0 &&
                  board.getCandidates(cell[0], cell[1]).contains(digit))
                cell
          ]
      ];

  /// 同一个数字的强链—弱链—强链。两条强链的远端不可能同时为假，
  /// 所以同时看得见两个远端的位置上，这个数字可删。
  ///
  /// 摩天楼、双线风筝、空矩形都是这条链的固定几何，各自有更好认的报法，
  /// 所以这里只报「换遍所有说得通的房屋组合都落不回那三个特例」的一般形状：
  /// 摩天楼和双线风筝看房屋形状就能认（见 [_isNamedLineTurbot]），
  /// 空矩形则要拿真的空矩形读法来对（见 [_emptyRectangleCovers]）——
  /// 宫里摆成十字并不等于空矩形报得出这一手。
  static SudokuHint? findTurbotFish(SudokuBoard board) {
    for (var digit = 1; digit <= 9; digit++) {
      final hint = _findTurbotForDigit(board, digit);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _findTurbotForDigit(SudokuBoard board, int digit) {
    final spots = _houseSpots(board, digit);
    List<_ErReading>? erReadings;
    final links = <({int house, List<int> a, List<int> b})>[];
    for (var h = 0; h < 27; h++) {
      if (spots[h].length == 2) {
        links.add((house: h, a: spots[h][0], b: spots[h][1]));
      }
    }
    for (var i = 0; i < links.length; i++) {
      for (var j = 0; j < links.length; j++) {
        if (i == j || links[i].house == links[j].house) continue;
        for (var ea = 0; ea < 2; ea++) {
          for (var eb = 0; eb < 2; eb++) {
            final tailA = ea == 0 ? links[i].a : links[i].b;
            final midA = ea == 0 ? links[i].b : links[i].a;
            final midB = eb == 0 ? links[j].a : links[j].b;
            final tailB = eb == 0 ? links[j].b : links[j].a;
            final nodes = [tailA, midA, midB, tailB];
            final keys = {for (final n in nodes) n[0] * 9 + n[1]};
            if (keys.length != 4) continue;
            // 中间一段必须是弱链（互相看得见），两端则不能互相看见——
            // 首尾自己撞上就不是一条开链，也谈不上「两端至少一真」。
            if (!_canSee(midA[0], midA[1], midB[0], midB[1])) continue;
            if (_canSee(tailA[0], tailA[1], tailB[0], tailB[1])) continue;
            final weakHouses = [
              for (final h in _housesOf(midA[0], midA[1]))
                if (_housesOf(midB[0], midB[1]).contains(h) &&
                    h != links[i].house &&
                    h != links[j].house)
                  h
            ];
            if (weakHouses.isEmpty) continue;
            if (_isNamedLineTurbot(spots, nodes)) continue;

            final elims = <CandidateElim>[];
            for (var r = 0; r < 9; r++) {
              for (var c = 0; c < 9; c++) {
                if (board.get(r, c) != 0) continue;
                if (keys.contains(r * 9 + c)) continue;
                if (!board.getCandidates(r, c).contains(digit)) continue;
                if (_canSee(r, c, tailA[0], tailA[1]) &&
                    _canSee(r, c, tailB[0], tailB[1])) {
                  elims.add(CandidateElim(r, c, digit));
                }
              }
            }
            if (elims.isEmpty) continue;
            erReadings ??= _emptyRectangleReadings(board, digit);
            if (_emptyRectangleCovers(erReadings, keys, elims)) continue;
            return _turbotHint(
              digit,
              nodes,
              links[i].house,
              weakHouses.first,
              links[j].house,
              elims,
            );
          }
        }
      }
    }
    return null;
  }

  /// 这四个节点能不能被重新贴标签，读成摩天楼或双线风筝。
  ///
  /// 同两个候选常常既同处一条线、又同处一个宫，挑哪个当强链房屋是可选的，
  /// 所以这里把所有说得通的组合都试一遍：只要有一种读法落进这两个特例，
  /// 就交给那条更早、更好认的报法，不按一般多宝鱼报。
  static bool _isNamedLineTurbot(
    List<List<List<int>>> spots,
    List<List<int>> nodes,
  ) {
    List<int> strongHouses(List<int> a, List<int> b) => [
          for (final h in _housesOf(a[0], a[1]))
            if (_housesOf(b[0], b[1]).contains(h) && spots[h].length == 2) h
        ];
    List<int> sharedHouses(List<int> a, List<int> b) => [
          for (final h in _housesOf(a[0], a[1]))
            if (_housesOf(b[0], b[1]).contains(h)) h
        ];
    bool isBox(int h) => h >= 18;
    bool isLine(int h) => h < 18;
    bool isRow(int h) => h < 9;

    for (final h0 in strongHouses(nodes[0], nodes[1])) {
      for (final h2 in strongHouses(nodes[2], nodes[3])) {
        for (final h1 in sharedHouses(nodes[1], nodes[2])) {
          if ({h0, h1, h2}.length != 3) continue;
          if (isLine(h0) &&
              isLine(h2) &&
              isLine(h1) &&
              isRow(h0) == isRow(h2) &&
              isRow(h1) != isRow(h0)) {
            return true; // 摩天楼
          }
          if (isLine(h0) && isLine(h2) && isRow(h0) != isRow(h2) && isBox(h1)) {
            return true; // 双线风筝
          }
        }
      }
    }
    return false;
  }

  /// 空矩形是不是真的读得出这一手：同两格强链，删的也是同一批候选。
  ///
  /// 光看「宫里摆成十字」不算数——空矩形还要求那条强链在宫外的带/列上，
  /// 删除格也得落在宫外，两条里差一条它就什么都报不出来，
  /// 这时候把链压下去就等于白丢一步。
  static bool _emptyRectangleCovers(
    List<_ErReading> readings,
    Set<int> nodeKeys,
    List<CandidateElim> elims,
  ) {
    for (final reading in readings) {
      final sameLinks = reading.linkCells
          .every((cell) => nodeKeys.contains(cell[0] * 9 + cell[1]));
      if (!sameLinks) continue;
      final covered = elims.every((e) =>
          e.row == reading.elim.row &&
          e.col == reading.elim.col &&
          e.num == reading.elim.num);
      if (covered) return true;
    }
    return false;
  }

  static SudokuHint _turbotHint(
    int digit,
    List<List<int>> nodes,
    int strongA,
    int weak,
    int strongB,
    List<CandidateElim> elims,
  ) {
    final arrows = [
      MarkupArrow(
        from: CandidateRef(nodes[0][0], nodes[0][1], digit),
        to: CandidateRef(nodes[1][0], nodes[1][1], digit),
        kind: ArrowKind.strong,
      ),
      MarkupArrow(
        from: CandidateRef(nodes[1][0], nodes[1][1], digit),
        to: CandidateRef(nodes[2][0], nodes[2][1], digit),
        kind: ArrowKind.weak,
      ),
      MarkupArrow(
        from: CandidateRef(nodes[2][0], nodes[2][1], digit),
        to: CandidateRef(nodes[3][0], nodes[3][1], digit),
        kind: ArrowKind.strong,
      ),
    ];
    return SudokuHint.elimination(
      technique: '多宝鱼',
      explanation:
          '数字 $digit 在 ${_houseLabel(strongA)} 与 ${_houseLabel(strongB)} '
          '各成强链，中间在 ${_houseLabel(weak)} 上接一条弱链：${chainExpr(arrows)}。'
          '两端不可能同时为假，同时看见两端处的 $digit 可删。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.link, nodes),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ...hintCands(HintRole.link, digit, nodes),
        ..._targetCands(elims),
      ],
      links: arrows,
      highlightRows: [
        for (final h in [strongA, strongB])
          if (h < 9) h
      ],
      highlightCols: [
        for (final h in [strongA, strongB])
          if (h >= 9 && h < 18) h - 9
      ],
    );
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
                  [
                    for (final id in [...path, nxtId]) byId[id]!
                  ],
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

  /// 一条基线上这个数字的落点，压成 9 位掩码。
  static int _lineMask(SudokuBoard board, int line, int digit, bool byRow) {
    var mask = 0;
    for (var i = 0; i < 9; i++) {
      final row = byRow ? line : i;
      final col = byRow ? i : line;
      if (board.get(row, col) == 0 &&
          board.getCandidates(row, col).contains(digit)) {
        mask |= 1 << i;
      }
    }
    return mask;
  }

  static int _bitCount(int mask) {
    var n = 0;
    var m = mask;
    while (m != 0) {
      m &= m - 1;
      n++;
    }
    return n;
  }

  /// 刺身鱼：带鳍鱼再缺一个覆盖顶点。
  ///
  /// 去掉鳍以后，某条基线在覆盖线上只剩一个候选，鱼本身已经不是完整的
  /// Swordfish / Jellyfish 了——这就是刺身和普通带鳍的分界。
  /// 推理两边一字不差：鳍全为假时鱼成立，覆盖线上鱼身之外的同名候选没位置可待；
  /// 只要有一个鳍为真，鳍看得见的地方也塌。两种情形都删得掉的，
  /// 正是同时看得见全部鳍、又踩在覆盖线上的那些候选。
  ///
  /// 只搜 Swordfish 与 Jellyfish 两档：刺身 X-Wing 的删除和摩天楼一模一样，
  /// 而摩天楼在提示顺序里更早也更好认，再按刺身报一遍只是换个名字。
  static SudokuHint? findSashimiFish(SudokuBoard board) {
    for (final size in [3, 4]) {
      for (var digit = 1; digit <= 9; digit++) {
        for (final byRow in [true, false]) {
          final hint = _sashimiOnLines(board, size, digit, byRow);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  static SudokuHint? _sashimiOnLines(
    SudokuBoard board,
    int size,
    int digit,
    bool byRow,
  ) {
    final masks = [
      for (var i = 0; i < 9; i++) _lineMask(board, i, digit, byRow)
    ];
    // 只剩一个落点的线是摒除法，不该当基线。
    final lines = [
      for (var i = 0; i < 9; i++)
        if (_bitCount(masks[i]) >= 2) i
    ];
    for (final base in _combinations(lines, size)) {
      var union = 0;
      for (final line in base) {
        union |= masks[line];
      }
      // 覆盖只有 size 条，union 里多出来的每一条都至少留下一个鳍。
      // 鳍多于两个的形状讲不清也几乎删不到东西，这里直接不看，搜索也就有了界。
      if (_bitCount(union) > size + 2) continue;
      final crosses = [
        for (var i = 0; i < 9; i++)
          if (union & (1 << i) != 0) i
      ];
      for (final cover in _combinations(crosses, size)) {
        var coverMask = 0;
        for (final cross in cover) {
          coverMask |= 1 << cross;
        }
        var thin = false;
        var ok = true;
        for (final line in base) {
          final covered = _bitCount(masks[line] & coverMask);
          if (covered == 0) {
            ok = false; // 整条基线都是鳍，那不是鱼
            break;
          }
          if (covered == 1) thin = true;
        }
        if (!ok || !thin) continue;

        final fins = <List<int>>[];
        for (final line in base) {
          for (var i = 0; i < 9; i++) {
            if (masks[line] & (1 << i) != 0 && coverMask & (1 << i) == 0) {
              fins.add([byRow ? line : i, byRow ? i : line]);
            }
          }
        }
        if (fins.isEmpty || fins.length > 2) continue;

        // 鳍也在基线上，一样不能删，但图示上要和鱼身分开标。
        final body = <List<int>>[];
        final bodyKeys = <int>{};
        for (final line in base) {
          for (var i = 0; i < 9; i++) {
            if (masks[line] & (1 << i) == 0) continue;
            final cell = [byRow ? line : i, byRow ? i : line];
            bodyKeys.add(cell[0] * 9 + cell[1]);
            if (coverMask & (1 << i) != 0) body.add(cell);
          }
        }
        final elims = <CandidateElim>[];
        for (final cross in cover) {
          for (var i = 0; i < 9; i++) {
            final row = byRow ? i : cross;
            final col = byRow ? cross : i;
            if (bodyKeys.contains(row * 9 + col)) continue;
            if (board.get(row, col) != 0) continue;
            if (!board.getCandidates(row, col).contains(digit)) continue;
            if (!fins.every((f) => _canSee(row, col, f[0], f[1]))) continue;
            elims.add(CandidateElim(row, col, digit));
          }
        }
        if (elims.isEmpty) continue;

        final deficits = <List<int>>[];
        for (final line in base) {
          if (_bitCount(masks[line] & coverMask) != 1) continue;
          for (final cross in cover) {
            if (masks[line] & (1 << cross) != 0) continue;
            deficits.add([byRow ? line : cross, byRow ? cross : line]);
          }
        }
        final lineWord = byRow ? '行' : '列';
        final coverWord = byRow ? '列' : '行';
        return SudokuHint.elimination(
          technique: '刺身鱼',
          explanation:
              '数字 $digit 以 ${base.map((l) => byRow ? rowRef(l) : colRef(l)).join(',')} '
              '为基线、${cover.map((c) => byRow ? colRef(c) : rowRef(c)).join(',')} 为覆盖。'
              '有基线在覆盖上只剩一个顶点（${cellsList(deficits)} 空着），'
              '去掉鳍这条$lineWord就撑不起整条鱼，所以是刺身而不是普通带鳍。'
              '鳍 ${cellsList(fins)} 为真时它看得见的地方塌，为假时鱼成立，'
              '两种情形都删得掉的是同时看见鳍、又踩在覆盖$coverWord上的 $digit。',
          eliminations: elims,
          patternCells: [
            ...hintCells(HintRole.pattern, body),
            ...hintCells(HintRole.extra, fins),
            ..._targetCells(elims),
          ],
          patternCandidates: [
            ...hintCands(HintRole.pattern, digit, body),
            ...hintCands(HintRole.extra, digit, fins),
            ..._targetCands(elims),
          ],
          highlightRows: byRow ? base : const [],
          highlightCols: byRow ? const [] : base,
        );
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
    for (final size in [3, 4]) {
      for (var digit = 1; digit <= 9; digit++) {
        for (final byRow in [true, false]) {
          final hint = _frankenFishOfSize(board, digit, size, byRow);
          if (hint != null) return hint;
        }
      }
    }
    return null;
  }

  /// Swordfish、Jellyfish 规格的 Franken 鱼：基和覆盖都可以是宫。
  ///
  /// 数法还是那一套：几个互不重叠的基，每个基都必须给这个数字留一个位置；
  /// 这些位置全落在同样多的覆盖里，而一个覆盖最多只装得下一个，
  /// 于是覆盖里鱼身之外的同名候选都没位置可待。
  ///
  /// 搜索之所以收得住，是因为一个基格只有两种盖法——它那条覆盖线，或者它所在的宫，
  /// 所以选覆盖的分支最多两条岔一层，一组基至多摊开 2^size 套盖法；
  /// 规格也只开到 Jellyfish 为止。
  static SudokuHint? _frankenFishOfSize(
    SudokuBoard board,
    int digit,
    int size,
    bool byRow,
  ) {
    final spots = _houseSpots(board, digit);
    final lineFrom = byRow ? 0 : 9;
    final units = <int>[
      for (var h = lineFrom; h < lineFrom + 9; h++)
        if (spots[h].isNotEmpty) h,
      for (var h = 18; h < 27; h++)
        if (spots[h].isNotEmpty) h,
    ];
    int coverLineOf(List<int> cell) => byRow ? 9 + cell[1] : cell[0];
    int boxOf(List<int> cell) => 18 + (cell[0] ~/ 3) * 3 + cell[1] ~/ 3;

    for (final base in _combinations(units, size)) {
      final cells = <List<int>>[];
      final keys = <String>{};
      var disjoint = true;
      for (final unit in base) {
        for (final cell in spots[unit]) {
          if (!keys.add('${cell[0]},${cell[1]}')) {
            disjoint = false;
            break;
          }
          cells.add(cell);
        }
        if (!disjoint) break;
      }
      // 基之间只要共用一个候选格，这个候选就被算了两遍，数数的道理就断了。
      if (!disjoint) continue;

      // 同一组基常常有好几套盖法：先凑出来的那套可能全是行列（那是普通鱼），
      // 也可能一个都删不掉，但换一套带宫的照样能成立，所以这里全部摊开。
      final covers = <List<int>>[];
      final cover = <int>[];
      void pick(int index) {
        var i = index;
        while (i < cells.length &&
            cover.any((unit) => _houseHasCell(unit, cells[i]))) {
          i++;
        }
        if (i == cells.length) {
          if (cover.length == size) covers.add(List.of(cover));
          return;
        }
        if (cover.length == size) return;
        for (final unit in [coverLineOf(cells[i]), boxOf(cells[i])]) {
          if (base.contains(unit) || cover.contains(unit)) continue;
          cover.add(unit);
          pick(i + 1);
          cover.removeLast();
        }
      }

      pick(0);

      for (final cover in covers) {
        // 全是行列的读法归普通鱼，这里只留真的用上宫的形状。
        if (!base.any((u) => u >= 18) && !cover.any((u) => u >= 18)) continue;

        final elims = <CandidateElim>[];
        final seen = <String>{};
        for (final unit in cover) {
          for (final cell in spots[unit]) {
            final key = '${cell[0]},${cell[1]}';
            if (keys.contains(key) || !seen.add(key)) continue;
            elims.add(CandidateElim(cell[0], cell[1], digit));
          }
        }
        if (elims.isEmpty) continue;

        return SudokuHint.elimination(
          technique: 'Franken 鱼',
          explanation: '数字 $digit 以 ${base.map(_houseLabel).join('、')} 为基：'
              '这 $size 个单位互不重叠，每个都必须给 $digit 留一个位置。'
              '这些位置全落在 ${cover.map(_houseLabel).join('、')} 里，'
              '而一个单位最多只装得下一个 $digit，'
              '所以这几个覆盖单位里鱼身之外的 $digit 都可以删。',
          eliminations: elims,
          patternCells: [
            ...hintCells(HintRole.pattern, cells),
            ..._targetCells(elims),
          ],
          patternCandidates: [
            ...hintCands(HintRole.pattern, digit, cells),
            ..._targetCands(elims),
          ],
          highlightRows: [
            for (final unit in base)
              if (unit < 9) unit
          ],
          highlightCols: [
            for (final unit in base)
              if (unit >= 9 && unit < 18) unit - 9
          ],
        );
      }
    }
    return null;
  }

  static bool _houseHasCell(int house, List<int> cell) {
    if (house < 9) return cell[0] == house;
    if (house < 18) return cell[1] == house - 9;
    final b = house - 18;
    return cell[0] ~/ 3 == b ~/ 3 && cell[1] ~/ 3 == b % 3;
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
          final boxKeys = {
            for (final cell in boxCells) '${cell[0]},${cell[1]}'
          };
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
            technique: 'Franken 鱼',
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
              final common = pivot
                  .intersection(triple[0].cands)
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
        if (board.get(r, c) == 0 && board.getCandidates(r, c).contains(digit)) {
          n++;
        }
      }
    }
    return n;
  }

  /// 盘面差两个多余候选就退回双值死盘时，所有说得通的「例外格 + 多余数字」读法。
  ///
  /// 认死盘不能只看「是不是每格都两个候选」，还要连奇偶条件一起查：
  /// 每个房屋里每个未填数字恰好出现两次。两条都成立，解的个数才一定是偶数，
  /// 「题目唯一解，所以不可能退回死盘」这个反证才站得住。
  /// 这里的做法是把两个例外格各自去掉一个候选，再逐条复核奇偶，
  /// 只有真的凑成死盘才认——省得把普通残局当成死盘乱删。
  ///
  /// 同一张盘偶尔不止一种拿法凑得成死盘，所以全部留下，
  /// 由各档自己挑第一组删得动的，而不是让枚举次序替它们做主。
  static List<_GraveExceptions> _graveReadings(SudokuBoard board) {
    final owners = <List<int>>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        final n = board.getCandidates(row, col).length;
        if (n == 3) {
          owners.add([row, col]);
          if (owners.length > 2) return const [];
        } else if (n != 2) {
          return const [];
        }
      }
    }
    if (owners.length != 2) return const [];
    final first = board.getCandidates(owners[0][0], owners[0][1]).toList()
      ..sort();
    final second = board.getCandidates(owners[1][0], owners[1][1]).toList()
      ..sort();
    return [
      for (final a in first)
        for (final b in second)
          if (_isGraveAfterRemoval(board, owners, [a, b]))
            _GraveExceptions(owners, [a, b])
    ];
  }

  /// 去掉这两个多余候选之后，盘面是不是每个房屋里每个未填数字都恰好出现两次。
  static bool _isGraveAfterRemoval(
    SudokuBoard board,
    List<List<int>> owners,
    List<int> extras,
  ) {
    bool has(int row, int col, int digit) {
      if (!board.getCandidates(row, col).contains(digit)) return false;
      for (var i = 0; i < owners.length; i++) {
        if (owners[i][0] == row && owners[i][1] == col && extras[i] == digit) {
          return false;
        }
      }
      return true;
    }

    for (var house = 0; house < 27; house++) {
      final placed = <int>{};
      final counts = List.filled(10, 0);
      for (final cell in _houseCells(house)) {
        final value = board.get(cell[0], cell[1]);
        if (value != 0) {
          placed.add(value);
          continue;
        }
        for (var digit = 1; digit <= 9; digit++) {
          if (has(cell[0], cell[1], digit)) counts[digit]++;
        }
      }
      for (var digit = 1; digit <= 9; digit++) {
        if (placed.contains(digit)) {
          if (counts[digit] != 0) return false;
        } else if (counts[digit] != 2) {
          return false;
        }
      }
    }
    return true;
  }

  /// BUG 类型 2：两个例外格多出的是同一个数字。
  ///
  /// 两个多余候选不能同时为假，否则盘面退回死盘、解数成偶数，和唯一解冲突。
  /// 这一档多出来的又是同一个数字，所以它至少落在两个例外格之一，
  /// 同时看得见这两格的位置就填不了它。
  static SudokuHint? findBugType2(SudokuBoard board) {
    for (final grave in _graveReadings(board)) {
      final hint = _bugType2Hint(board, grave);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _bugType2Hint(SudokuBoard board, _GraveExceptions grave) {
    if (grave.extras[0] != grave.extras[1]) return null;
    final digit = grave.extras[0];
    final owners = grave.owners;
    final elims = <CandidateElim>[];
    for (var row = 0; row < 9; row++) {
      for (var col = 0; col < 9; col++) {
        if (board.get(row, col) != 0) continue;
        if (owners.any((o) => o[0] == row && o[1] == col)) continue;
        if (!board.getCandidates(row, col).contains(digit)) continue;
        if (!owners.every((o) => _canSee(row, col, o[0], o[1]))) continue;
        elims.add(CandidateElim(row, col, digit));
      }
    }
    if (elims.isEmpty) return null;
    return SudokuHint.elimination(
      technique: 'BUG 类型 2',
      explanation: '题目保证唯一解。除了 ${cellsList(owners)}，'
          '盘上每个空格都只剩两个候选，而且把这两格多出来的 $digit 拿掉之后，'
          '每个房屋里每个未填数字都恰好出现两次——那就是一张双值死盘，解的个数会是偶数。'
          '所以 $digit 至少在这两格之一为真，同时看得见它们的位置都能删 $digit。',
      eliminations: elims,
      patternCells: [
        ...hintCells(HintRole.pattern, owners),
        ..._targetCells(elims),
      ],
      patternCandidates: [
        ...hintCands(HintRole.extra, digit, owners),
        ..._targetCands(elims),
      ],
      links: [
        MarkupArrow(
          from: CandidateRef(owners[0][0], owners[0][1], digit),
          to: CandidateRef(owners[1][0], owners[1][1], digit),
          kind: ArrowKind.strong,
        ),
      ],
    );
  }

  /// BUG 类型 3：两个例外格落在同一条房屋里，各多出一个不同的数字。
  ///
  /// 起点和类型 2、4 是同一条：把两个多余候选拿掉之后盘面满足完整的死盘奇偶条件，
  /// 解数为偶数，而题目保证唯一解，所以这两个多余候选至少一个为真。
  /// 于是这两格合起来只顶一格用，候选就是那两个额外数字——
  /// 把这个虚拟格和同房屋其它格子配成数组，再按数组规则删。
  ///
  /// 虚拟格和矩形族的类型 3 是同一套 [_virtualSubsetRead]：
  /// 都是「这两格里至少有一格要跳出底数」，只是死盘的底数是各格自己那一对。
  /// 也正因为这样，两个例外格自己一个都不能删——不知道是哪一格跳出去，
  /// 拆开删就把完整性约束当成裸对用了。
  static SudokuHint? findBugType3(SudokuBoard board) {
    for (final grave in _graveReadings(board)) {
      final hint = _bugType3Hint(board, grave);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _bugType3Hint(SudokuBoard board, _GraveExceptions grave) {
    // 多出来的是同一个数字时虚拟格只剩一个候选，那一手归类型 2，不必绕数组。
    if (grave.extras[0] == grave.extras[1]) return null;
    final owners = grave.owners;
    final virtual = {grave.extras[0], grave.extras[1]};
    for (final house in _housesOf(owners[0][0], owners[0][1])) {
      if (!_houseHasCell(house, owners[1])) continue;
      final sub = _virtualSubsetRead(board, house, owners, virtual, const {});
      if (sub == null) continue;
      final digits = (sub.digits.toList()..sort()).join('、');
      final size = sub.cells.length + 1;
      final members = [
        for (final cell in sub.cells) [cell.row, cell.col]
      ];
      final hl = _houseHighlight(house);
      final outside = (sub.digits.difference(virtual).toList()..sort());
      final struck = {
        for (final e in sub.elims) '${e.row},${e.col},${e.num}',
      };
      final ownerKeys = {for (final cell in owners) '${cell[0]},${cell[1]}'};
      final onOwner =
          sub.elims.any((e) => ownerKeys.contains('${e.row},${e.col}'));
      return SudokuHint.elimination(
        technique: 'BUG 类型 3',
        explanation: '题目保证唯一解。除了 ${cellsList(owners)}，'
            '盘上每个空格都只剩两个候选；把 '
            '${candRef(owners[0][0], owners[0][1], grave.extras[0])}、'
            '${candRef(owners[1][0], owners[1][1], grave.extras[1])} '
            '拿掉之后每个房屋里每个未填数字都恰好出现两次，是一张双值死盘，'
            '所以这两个多余候选至少一个为真。'
            '把它们合成一个候选为 ${grave.extras[0]}、${grave.extras[1]} 的虚拟格，'
            '这个虚拟格只顶一格用；'
            '${_houseLabel(house)} 上的 ${cellsList(members)} 和它凑成 '
            '$size 格锁 $size 个数字（$digits）的数组，'
            '于是 ${_houseLabel(house)} 别处的这些候选都能删。'
            '${onOwner ? '数组锁住的 ${outside.join('、')} '
                '不在虚拟格里，${cellsList(owners)} 自己也填不了——'
                '哪一格填了它，多余候选就得靠另一格兑现，'
                '这条房屋里就有 ${size + 1} 个格子去占 $size 个数字，占不下——'
                '所以这两格上的 ${outside.join('、')} 一并删去。' : ''}',
        eliminations: sub.elims,
        patternCells: [
          // 这两格就是多出候选的那两格，和致命形里的屋顶格同一个角色。
          ...hintCells(HintRole.extra, owners),
          ...hintCells(HintRole.link, members),
          ..._targetCells(sub.elims),
        ],
        patternCandidates: [
          for (var i = 0; i < 2; i++)
            for (final digit
                in board
                    .getCandidates(owners[i][0], owners[i][1])
                    .difference({grave.extras[i]}).toList()
                  ..sort())
              // 要删的那些底数走 target，不要在同一个候选上再盖一层依据色。
              if (!struck.contains('${owners[i][0]},${owners[i][1]},$digit'))
                HintCandidate(
                  CandidateRef(owners[i][0], owners[i][1], digit),
                  HintRole.pattern,
                ),
          for (var i = 0; i < 2; i++)
            HintCandidate(
              CandidateRef(owners[i][0], owners[i][1], grave.extras[i]),
              HintRole.extra,
            ),
          for (final cell in sub.cells)
            for (final digit in cell.cands.toList()..sort())
              HintCandidate(
                CandidateRef(cell.row, cell.col, digit),
                HintRole.link,
              ),
          ..._targetCands(sub.elims),
        ],
        links: [
          MarkupArrow(
            from: CandidateRef(owners[0][0], owners[0][1], grave.extras[0]),
            to: CandidateRef(owners[1][0], owners[1][1], grave.extras[1]),
            kind: ArrowKind.strong,
          ),
        ],
        highlightRows: hl.rows,
        highlightCols: hl.cols,
        highlightBoxes: hl.boxes,
      );
    }
    return null;
  }

  /// BUG 类型 4：两个例外格落在同一条房屋里，共有的某个底数在这条房屋里只剩这两格。
  ///
  /// 多余候选不能同时为假；共有底数的强链又说它必落在两格之一。
  /// 若某格填了自己「另一个底数」，强链就把共有底数推给对面那格，
  /// 对面也就填不了自己的多余候选，两个多余候选同时为假——正好撞上前一句。
  /// 所以两个例外格的另一个底数都可以删。
  ///
  /// 这段推理只用到「两个多余候选至少一真」和那条强链，
  /// 两格多出来的是不是同一个数字并不相干：多出同一个数字时类型 2 也成立，
  /// 但两档删的不是同一批候选，所以这里不因为撞上类型 2 就收手。
  static SudokuHint? findBugType4(SudokuBoard board) {
    for (final grave in _graveReadings(board)) {
      final hint = _bugType4Hint(board, grave);
      if (hint != null) return hint;
    }
    return null;
  }

  static SudokuHint? _bugType4Hint(SudokuBoard board, _GraveExceptions grave) {
    final owners = grave.owners;
    final bases = [
      for (var i = 0; i < 2; i++)
        board.getCandidates(owners[i][0], owners[i][1]).difference({
          grave.extras[i],
        })
    ];
    final shared = bases[0].intersection(bases[1]);
    if (shared.isEmpty) return null;
    for (final house in _housesOf(owners[0][0], owners[0][1])) {
      if (!_houseCells(house).any(
        (cell) => cell[0] == owners[1][0] && cell[1] == owners[1][1],
      )) {
        continue;
      }
      for (final lock in shared.toList()..sort()) {
        final spots = _houseSpots(board, lock)[house];
        if (spots.length != 2) continue;
        if (!owners.every(
            (o) => spots.any((cell) => cell[0] == o[0] && cell[1] == o[1]))) {
          continue;
        }
        final elims = <CandidateElim>[];
        for (var i = 0; i < 2; i++) {
          for (final digit in bases[i].difference({lock})) {
            elims.add(CandidateElim(owners[i][0], owners[i][1], digit));
          }
        }
        if (elims.isEmpty) continue;
        final hl = _houseHighlight(house);
        return SudokuHint.elimination(
          technique: 'BUG 类型 4',
          explanation: '题目保证唯一解。除了 ${cellsList(owners)}，'
              '盘上每个空格都只剩两个候选；把 '
              '${candRef(owners[0][0], owners[0][1], grave.extras[0])}、'
              '${candRef(owners[1][0], owners[1][1], grave.extras[1])} '
              '拿掉之后每个房屋里每个未填数字都恰好出现两次，是一张双值死盘，'
              '所以这两个多余候选至少一个为真。'
              '再看 ${_houseLabel(house)}：$lock 只剩 ${cellsList(owners)} 两格，是条强链。'
              '哪一格填了自己的另一个底数，$lock 就被推到对面，'
              '对面也就填不了多余候选，两个多余候选同时落空——'
              '所以这两个「另一个底数」都可以删。',
          eliminations: elims,
          patternCells: [
            // 这两格既是多出候选的格子，也是那条强链的两端。
            ...hintCells(HintRole.extra, owners),
            ..._targetCells(elims),
          ],
          patternCandidates: [
            ...hintCands(HintRole.link, lock, owners),
            for (var i = 0; i < 2; i++)
              HintCandidate(
                CandidateRef(owners[i][0], owners[i][1], grave.extras[i]),
                HintRole.extra,
              ),
            ..._targetCands(elims),
          ],
          links: [
            MarkupArrow(
              from: CandidateRef(owners[0][0], owners[0][1], lock),
              to: CandidateRef(owners[1][0], owners[1][1], lock),
              kind: ArrowKind.strong,
            ),
          ],
          highlightRows: hl.rows,
          highlightCols: hl.cols,
          highlightBoxes: hl.boxes,
        );
      }
    }
    return null;
  }

  static SudokuHint? findXyChain(SudokuBoard board) => _findCellAic(board,
      bivalueOnly: true, requireCycle: false, name: 'XY-Chain');

  static SudokuHint? findAic(SudokuBoard board) => _findCellAic(board,
      bivalueOnly: false, requireCycle: false, name: 'AIC 开链');

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
            if (needStrong &&
                nxt[2] == start[2] &&
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
            for (final cell in inter) ...board.getCandidates(cell[0], cell[1])
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
                  ...hintCells(HintRole.pattern,
                      [for (final petal in combo) ...petal.cells]),
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
                    for (final cell in combo[i].cellsWith(board, digits[i]))
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
                _strong(
                    spots[0][0], spots[0][1], spots[1][0], spots[1][1], digit),
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

  static String _pathText(List<List<int>> path) =>
      path.map((step) => candRef(step[0], step[1], step[2])).join(' → ');

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

/// 差两个多余候选就退回双值死盘的局面：例外格，以及各自多出来的那个数字。
class _GraveExceptions {
  final List<List<int>> owners;
  final List<int> extras;

  const _GraveExceptions(this.owners, this.extras);
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
