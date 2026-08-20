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

  /// 返回所有 27 个单元（行/列/宫格）
  static List<_Unit> _allUnits() {
    List<_Unit> units = [];
    for (int r = 0; r < 9; r++) {
      units.add(_Unit('行', '第 ${r + 1} 行',
          [for (int c = 0; c < 9; c++) [r, c]]));
    }
    for (int c = 0; c < 9; c++) {
      units.add(_Unit('列', '第 ${c + 1} 列',
          [for (int r = 0; r < 9; r++) [r, c]]));
    }
    for (int br = 0; br < 3; br++) {
      for (int bc = 0; bc < 3; bc++) {
        units.add(_Unit('宫格', '宫格 ${br + 1}-${bc + 1}', [
          for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++) [br * 3 + i, bc * 3 + j]
        ]));
      }
    }
    return units;
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
                technique: '隐藏数字对（${u.type}）',
                explanation: '${u.label} 中数字 ${nums[i]} 和 ${nums[j]} 只能出现在 '
                    '(${p1[0][0] + 1},${p1[0][1] + 1}) 和 '
                    '(${p1[1][0] + 1},${p1[1][1] + 1})，'
                    '因此这两格只能是这两个数字，可删除其他候选数。',
                eliminations: elims,
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
                technique: '隐藏数字三元组（${u.type}）',
                explanation: '${u.label} 中数字 ${nums[i]}, ${nums[j]}, ${nums[k]} '
                    '只能出现在三个固定位置，因此可删除这些格子的其他候选数。',
                eliminations: elims,
              );
            }
          }
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
            var allCols = rowsWith[i].value.toSet()
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
                explanation: '数字 $num 在第 ${rows.map((r) => r + 1).join('、')} 行'
                    '形成 Jellyfish（涉及列 ${allCols.map((c) => c + 1).join('、')}），'
                    '可从这些列的其他位置删除 $num。',
                eliminations: elims,
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
            var allRows = colsWith[i].value.toSet()
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
                explanation: '数字 $num 在第 ${cols.map((c) => c + 1).join('、')} 列'
                    '形成 Jellyfish（涉及行 ${allRows.map((r) => r + 1).join('、')}），'
                    '可从这些行的其他位置删除 $num。',
                eliminations: elims,
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
          if (!(cands.difference(cands2).isEmpty && cands2.length == 2)) continue;

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
                explanation: '格子 (${i + 1},${j + 1}), (${i + 1},${j2 + 1}), '
                    '(${i2 + 1},${j + 1}), (${i2 + 1},${j2 + 1}) 形成唯一矩形，'
                    '为避免出现多解，(${i2 + 1},${j2 + 1}) 必须填 $extraNum。',
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
                explanation: '格子 (${i + 1},${j + 1}), (${i + 1},${j2 + 1}), '
                    '(${i2 + 1},${j + 1}), (${i2 + 1},${j2 + 1}) 形成唯一矩形，'
                    '为避免出现多解，(${i2 + 1},${j + 1}) 必须填 $extraNum。',
              );
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
        if (board.get(i, j) == 0 &&
            board.getCandidates(i, j).contains(num)) {
          positions.add([i, j]);
        }
      }
    }
    if (positions.isEmpty) return null;

    String keyOf(int r, int c) => '$r,$c';
    // 构建强链（共轭对）图：某单元内 num 恰有两个候选位置
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

      List<String> color0 =
          component.where((k) => color[k] == 0).toList();
      List<String> color1 =
          component.where((k) => color[k] == 1).toList();

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
          return SudokuHint.elimination(
            technique: 'Simple Coloring',
            explanation: '数字 $num 的着色链中，$falseColorList 的两个格子互相可见，'
                '因此该颜色全部为假，可删除这些格子的候选数 $num。',
            eliminations: elims,
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
        );
      }
    }
    return null;
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
        if (board.get(i, j) == 0 &&
            board.getCandidates(i, j).length == 2) {
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
              explanation: '双值格 (${c1[0] + 1},${c1[1] + 1}) 与 '
                  '(${c2[0] + 1},${c2[1] + 1}) 候选相同 ${pair..sort()}，'
                  '通过数字 $linkDigit 的强链（'
                  '${e1![0] + 1},${e1[1] + 1} - ${e2![0] + 1},${e2[1] + 1}）相连，'
                  '形成 W-Wing，可删除相关格子的候选数 $elimDigit。',
              eliminations: elims,
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
            explanation: '数字 $num 在第 ${r1 + 1} 行和第 ${r2 + 1} 行各只有两个候选位置，'
                '且在第 ${baseCol + 1} 列对齐形成 Skyscraper，'
                '可删除同时可见两个屋顶的格子的候选数 $num。',
            eliminations: elims,
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
            explanation: '数字 $num 在第 ${c1 + 1} 列和第 ${c2 + 1} 列各只有两个候选位置，'
                '且在第 ${baseRow + 1} 行对齐形成 Skyscraper，'
                '可删除同时可见两个屋顶的格子的候选数 $num。',
            eliminations: elims,
          );
        }
      }
    }
    return null;
  }
}

/// 单元（行/列/宫格）
class _Unit {
  final String type;
  final String label;
  final List<List<int>> cells;

  _Unit(this.type, this.label, this.cells);
}
