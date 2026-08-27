import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/models/sudoku_board.dart';
import 'package:sudoku_app/models/technique_structure.dart';
import 'package:sudoku_app/services/sudoku_solver.dart';

/// 教学盘面的独立复核工具。
///
/// 这里刻意不碰任何 finder：全部结论都从盘面的已知数重新算候选、
/// 或者用回溯求解器数解，这样教学页说的话和引擎实现是两条独立的证据链。
/// 每个函数返回违规说明列表，空列表表示这一项通过。

/// 一个房屋：0-8 行，9-17 列，18-26 宫。
String houseName(int house) {
  if (house < 9) return 'r${house + 1}';
  if (house < 18) return 'c${house - 9 + 1}';
  return 'b${house - 18 + 1}';
}

List<List<int>> houseCells(int house) {
  if (house < 9) {
    return [
      for (int c = 0; c < 9; c++) [house, c]
    ];
  }
  if (house < 18) {
    return [
      for (int r = 0; r < 9; r++) [r, house - 9]
    ];
  }
  final b = house - 18;
  final br = (b ~/ 3) * 3, bc = (b % 3) * 3;
  return [
    for (int i = 0; i < 3; i++)
      for (int j = 0; j < 3; j++) [br + i, bc + j]
  ];
}

List<int> housesOf(int row, int col) =>
    [row, 9 + col, 18 + (row ~/ 3) * 3 + col ~/ 3];

bool sees(int r1, int c1, int r2, int c2) {
  if (r1 == r2 && c1 == c2) return false;
  return r1 == r2 || c1 == c2 || (r1 ~/ 3 == r2 ~/ 3 && c1 ~/ 3 == c2 ~/ 3);
}

/// 盘面的唯一解；不唯一或无解时返回 null。
List<List<int>>? uniqueSolution(String puzzle) {
  final board = SudokuBoard.fromString(puzzle);
  if (SudokuSolver.countSolutions(board, limit: 2) != 1) return null;
  final probe = SudokuBoard.fromString(puzzle);
  if (!SudokuSolver.solve(probe)) return null;
  return probe.board.map((r) => List<int>.from(r)).toList();
}

/// 盘面本身的体检：81 位、唯一解、没有空格候选为零。
List<String> boardViolations(String puzzle) {
  final out = <String>[];
  if (puzzle.length != 81) {
    out.add('盘面长度 ${puzzle.length}，应为 81');
    return out;
  }
  final board = SudokuBoard.fromString(puzzle);
  final count = SudokuSolver.countSolutions(board, limit: 2);
  if (count != 1) out.add('解的个数为 $count，教学盘必须唯一解');
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) == 0 && board.getCandidates(r, c).isEmpty) {
        out.add('r${r + 1}c${c + 1} 是空格却一个候选都没有');
      }
    }
  }
  return out;
}

/// 标记里引用的每个候选都必须真实存在于当前盘面。
List<String> markupCandidateViolations(String puzzle, BoardMarkup markup) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  void check(CandidateRef ref, String what) {
    if (board.get(ref.row, ref.col) != 0) {
      out.add('$what r${ref.row + 1}c${ref.col + 1} 是已填的已知数，不该标候选');
      return;
    }
    if (!board.getCandidates(ref.row, ref.col).contains(ref.num)) {
      out.add('$what r${ref.row + 1}c${ref.col + 1} 上没有候选 ${ref.num}');
    }
  }

  markup.candidateColors.forEach((ref, _) => check(ref, '候选标记'));
  for (final arrow in markup.arrows) {
    check(arrow.from, '连线起点');
    check(arrow.to, '连线终点');
  }
  return out;
}

/// 致命结构系列：示意图里的连线一律是「同房屋同数字」或「同格两候选」的单候选链节。
///
/// 链/ALS/鱼那几族的示意图另有约定——组强链（一端是一组格子）、
/// ALS 内部的链节、以及「假设 A 推出 B」的蕴含箭头都会画成一条线，
/// 光看两个端点判断不出来，所以 [linkHouseViolations] 只对这几族生效。
const deadlyPatternFamilies = <TeachingFamily>{
  TeachingFamily.uniqueRect,
  TeachingFamily.extendedRect,
  TeachingFamily.uniqueLoop,
  TeachingFamily.avoidableRect,
  TeachingFamily.bivalueGrave,
  TeachingFamily.borescoper,
  TeachingFamily.qiu,
};

/// 示意图上的连线可以逐条核对的家族。
///
/// 鱼类和同数字短链的图上只画两种线：同房屋同数字的弱链，以及确认过
/// 「该房屋里这个数字恰好两个位置」的强链。两者都能被 [linkHouseViolations]
/// 直接验，所以这几族也一起收进来。
const linkCheckedFamilies = <TeachingFamily>{
  ...deadlyPatternFamilies,
  TeachingFamily.fish,
  TeachingFamily.siameseFish,
  TeachingFamily.turbot,
};

/// 示意图上的链节连线必须真的成立。
///
/// 弱链（同数字）两端要共处一个房屋，否则两个候选之间没有任何约束，连不成链。
/// 强链要求更硬：
/// * 同数字的强链，得在两端共处的某个房屋里该数字恰好只有这两个位置；
/// * 同格不同数字的强链，得是这一格恰好只剩这两个候选。
/// 剩下的组合（不同格又不同数字）不是链节，只能是「假设 A 推出 B」的蕴含箭头，
/// 示意图里不画。
List<String> linkHouseViolations(String puzzle, BoardMarkup markup) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  for (final arrow in markup.arrows) {
    final a = arrow.from, b = arrow.to;
    final tag = '${a.num}r${a.row + 1}c${a.col + 1} 与 '
        '${b.num}r${b.row + 1}c${b.col + 1}';
    final sameCell = a.row == b.row && a.col == b.col;
    if (a.num == b.num) {
      if (sameCell) {
        out.add('$tag 是同一个候选，连不成链');
        continue;
      }
      if (!sees(a.row, a.col, b.row, b.col)) {
        out.add('$tag 不同行不同列不同宫，连不成链');
        continue;
      }
      if (arrow.kind != ArrowKind.strong) continue;
      final shared = [
        for (final h in housesOf(a.row, a.col))
          if (housesOf(b.row, b.col).contains(h)) h
      ];
      final ok = shared.any((h) {
        var spots = 0;
        for (final cell in houseCells(h)) {
          if (board.get(cell[0], cell[1]) != 0) continue;
          if (board.getCandidates(cell[0], cell[1]).contains(a.num)) spots++;
        }
        return spots == 2;
      });
      if (!ok) {
        out.add('$tag 画成了强链，可是 ${shared.map(houseName).join("/")} '
            '里数字 ${a.num} 的候选位置不止两个');
      }
    } else {
      if (!sameCell) {
        if (arrow.kind == ArrowKind.strong) {
          out.add('$tag 既不同格又不同数字，构不成强链');
        }
        continue;
      }
      if (arrow.kind != ArrowKind.strong) continue;
      final cands = board.getCandidates(a.row, a.col);
      if (cands.length != 2) {
        out.add('$tag 画成同格强链，可是 r${a.row + 1}c${a.col + 1} '
            '还剩 ${cands.length} 个候选');
      }
    }
  }
  return out;
}

/// 拿掉 [extras] 之后，盘面是不是一个真正的双值死盘（BUG）。
///
/// 死盘的完整条件有两条，缺一不可：
/// 1. 每个空格恰好剩两个候选；
/// 2. 每个房屋里，每个还没填的数字恰好出现两次。
///
/// 只满足第一条的盘面不是死盘——奇偶条件才是「解的个数为偶数」这个结论的来源，
/// 也是 BUG+n「多出来的候选不能同时为假」的依据。
List<String> bugParityViolations(
  String puzzle,
  Iterable<CandidateRef> extras,
) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final grave = <int, Set<int>>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) == 0) {
        grave[r * 9 + c] = Set<int>.from(board.getCandidates(r, c));
      }
    }
  }
  for (final e in extras) {
    final key = e.row * 9 + e.col;
    final set = grave[key];
    if (set == null) {
      out.add('声明的多余候选 r${e.row + 1}c${e.col + 1}=${e.num} 落在已填格上');
      continue;
    }
    if (!set.remove(e.num)) {
      out.add('声明的多余候选 r${e.row + 1}c${e.col + 1}=${e.num} 本来就不存在');
    }
  }
  grave.forEach((key, set) {
    if (set.length != 2) {
      out.add('去掉多余候选后 r${key ~/ 9 + 1}c${key % 9 + 1} 剩 ${set.length} 个候选，'
          '死盘要求恰好 2 个');
    }
  });
  for (int h = 0; h < 27; h++) {
    final placed = <int>{};
    final counts = <int, int>{};
    for (final cell in houseCells(h)) {
      final v = board.get(cell[0], cell[1]);
      if (v != 0) {
        placed.add(v);
        continue;
      }
      for (final d in grave[cell[0] * 9 + cell[1]]!) {
        counts[d] = (counts[d] ?? 0) + 1;
      }
    }
    for (int d = 1; d <= 9; d++) {
      final n = counts[d] ?? 0;
      if (placed.contains(d)) {
        if (n != 0) out.add('${houseName(h)} 里 $d 已填，却还有 $n 个候选');
      } else if (n != 2) {
        out.add('${houseName(h)} 里未填数字 $d 出现 $n 次，死盘的奇偶条件要求恰好 2 次');
      }
    }
  }
  return out;
}

/// 结构格上除底数以外的候选，必须和声明的 [TeachingStructure.extras] 完全一致。
List<String> extrasExhaustiveViolations(
  String puzzle,
  TeachingStructure s, {
  bool requireAllBase = true,
}) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final declared = <String>{
    for (final e in s.extras) '${e.row},${e.col},${e.num}'
  };
  final actual = <String>{};
  for (final cell in s.cells) {
    if (board.get(cell.row, cell.col) != 0) {
      out.add('${cell.label} 是已知数，不能当结构格');
      continue;
    }
    final cands = board.getCandidates(cell.row, cell.col);
    if (requireAllBase) {
      for (final d in s.baseDigits) {
        if (!cands.contains(d)) {
          out.add('${cell.label} 上没有底数 $d，结构不成立');
        }
      }
    }
    for (final d in cands) {
      if (!s.baseDigits.contains(d)) actual.add('${cell.row},${cell.col},$d');
    }
  }
  String pretty(String k) {
    final p = k.split(',');
    return 'r${int.parse(p[0]) + 1}c${int.parse(p[1]) + 1}=${p[2]}';
  }

  for (final missing in actual.difference(declared)) {
    out.add('额外候选 ${pretty(missing)} 没有在结构声明里列出，教学文字漏讲了它');
  }
  for (final ghost in declared.difference(actual)) {
    out.add('结构声明里的额外候选 ${pretty(ghost)} 在盘面上并不存在');
  }
  return out;
}

/// 结构格上每一格允许填的数字：受底数限制的格子取「候选 ∩ 底数」，
/// [TeachingStructure.freeCells] 取全部候选。
///
/// 返回的两个列表下标一一对应；遇到已填格或者无数可填时把说明写进 [out]。
({List<CellRef> cells, List<Set<int>> allowed}) _dpDomain(
  SudokuBoard board,
  TeachingStructure s,
  List<String> out,
) {
  final cells = <CellRef>[];
  final allowed = <Set<int>>[];
  void add(CellRef c, bool restricted) {
    if (board.get(c.row, c.col) != 0) {
      out.add('${c.label} 是已知数，不能当结构格');
      return;
    }
    final cands = board.getCandidates(c.row, c.col);
    final dom = restricted
        ? {
            for (final d in cands)
              if (s.baseDigits.contains(d)) d
          }
        : Set<int>.from(cands);
    if (dom.isEmpty) {
      out.add('${c.label} 上没有任何可填的结构数字');
      return;
    }
    cells.add(c);
    allowed.add(dom);
  }

  for (final c in s.cells) {
    add(c, true);
  }
  for (final c in s.freeCells) {
    add(c, false);
  }
  return (cells: cells, allowed: allowed);
}

/// 枚举结构格的全部「合法填法」：每格取自己允许的数字，同房屋不重号。
///
/// 超过 [limit] 种就放弃——那说明结构声明得太松，测试没法真正把它验完。
List<List<int>>? _allFillings(
  List<Set<int>> allowed,
  List<List<int>> cellHouses,
  int limit,
) {
  final n = allowed.length;
  final out = <List<int>>[];
  final cur = List<int>.filled(n, 0);
  final used = List<Set<int>>.generate(27, (_) => <int>{});
  var overflow = false;
  bool rec(int i) {
    if (i == n) {
      out.add(List<int>.from(cur));
      if (out.length >= limit) {
        overflow = true;
        return false;
      }
      return true;
    }
    for (final d in allowed[i]) {
      if (cellHouses[i].any((h) => used[h].contains(d))) continue;
      cur[i] = d;
      for (final h in cellHouses[i]) {
        used[h].add(d);
      }
      final keepGoing = rec(i + 1);
      for (final h in cellHouses[i]) {
        used[h].remove(d);
      }
      if (!keepGoing) return false;
    }
    return true;
  }

  rec(0);
  return overflow ? null : out;
}

/// 填法 [f] 能不能换成另一种填法：每格的新值仍是本格候选，
/// 每个房屋里结构格用掉的数字多重集一模一样，且至少有一格换了数字。
///
/// 能换掉就说明「盘面按 f 填出来」会多出第二个解，所以 f 不可能出现在唯一解里。
/// 允许只换其中几格——没换的格子在每个房屋里对两边的贡献相同，不影响多重集相等。
bool _hasSwap(
  List<int> f,
  List<Set<int>> allowed,
  List<List<int>> cellHouses,
) {
  final n = f.length;
  final need = List<Map<int, int>>.generate(27, (_) => <int, int>{});
  for (int i = 0; i < n; i++) {
    for (final h in cellHouses[i]) {
      need[h][f[i]] = (need[h][f[i]] ?? 0) + 1;
    }
  }
  final g = List<int>.filled(n, 0);
  bool rec(int i, bool differs) {
    if (i == n) return differs;
    for (final d in allowed[i]) {
      if (cellHouses[i].any((h) => (need[h][d] ?? 0) == 0)) continue;
      g[i] = d;
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

/// 致命结构的公共核对：结构格上「只填底数」的每一种填法都必须能被换掉。
///
/// 这是唯一矩形、扩展矩形、唯一环、探长致命结构、淑芬致命结构共用的那条原理，
/// 不靠任何家族专属的图形常识：只要有一种填法换不掉，这个结构就不致命，
/// 教学页据它下的结论也就不成立。
///
/// 顺带核对结论的前提：唯一解在结构格上必须至少有一格不是底数，
/// 而那一格的值必须出现在声明的 [TeachingStructure.extras] 里。
List<String> deadlyPatternViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final domain = _dpDomain(board, s, out);
  if (out.isNotEmpty) return out;
  final cells = domain.cells;
  final allowed = domain.allowed;
  final cellHouses = [for (final c in cells) housesOf(c.row, c.col)];

  final fillings = _allFillings(allowed, cellHouses, 200000);
  if (fillings == null) {
    out.add('结构格的填法多到枚举不完，无法验证致命性');
    return out;
  }
  if (fillings.isEmpty) {
    out.add('结构格连一种「只填底数」的填法都排不出来，这不是致命结构');
    return out;
  }
  for (final f in fillings) {
    if (_hasSwap(f, allowed, cellHouses)) continue;
    final shown = [
      for (int i = 0; i < cells.length; i++) '${cells[i].label}=${f[i]}'
    ].join(' ');
    out.add('填法「$shown」换不成第二种填法，这个结构并不致命');
    break;
  }

  final solution = uniqueSolution(puzzle);
  if (solution == null) {
    out.add('盘面不是唯一解，无法核对结论前提');
    return out;
  }
  final declared = <String>{
    for (final e in s.extras) '${e.row},${e.col},${e.num}'
  };
  final offBase = <String>[];
  for (final c in s.cells) {
    final v = solution[c.row][c.col];
    if (s.baseDigits.contains(v)) continue;
    offBase.add('${c.label}=$v');
    if (!declared.contains('${c.row},${c.col},$v')) {
      out.add('唯一解里 ${c.label} 填 $v，这个候选却没写进结构声明的额外候选');
    }
  }
  if (offBase.isEmpty) {
    out.add('唯一解在结构格上全是底数，和「至少一个多余候选为真」矛盾');
  }
  return out;
}

/// 声明的跨宫数必须和结构格实际占的宫数一致。
///
/// 教学正文常写「四角落在两个宫里」这类话，[TeachingStructure.boxSpan] 就是那句话的
/// 机器版；不核对的话，声明写几都没人管，正文写错也照样过。
List<String> boxSpanViolations(TeachingStructure s) {
  final want = s.boxSpan;
  if (want == null) return const [];
  final actual = s.boxes;
  if (actual.length == want) return const [];
  return [
    '声明跨 $want 个宫，结构格实际占 ${actual.length} 个：$actual',
  ];
}

/// 唯一矩形族的几何：两行两列四角，跨恰好两个宫。
List<String> rectGeometryViolations(TeachingStructure s) {
  final out = <String>[];
  if (s.cells.length != 4) {
    out.add('唯一矩形要四个角，声明了 ${s.cells.length} 个');
    return out;
  }
  final rows = s.cells.map((c) => c.row).toSet();
  final cols = s.cells.map((c) => c.col).toSet();
  if (rows.length != 2 || cols.length != 2) {
    out.add('四角应落在两行两列上，实际是 ${rows.length} 行 ${cols.length} 列');
  }
  if (s.boxes.length != 2) {
    out.add('唯一矩形必须跨恰好两个宫，实际跨 ${s.boxes.length} 个：${s.boxes}');
  }
  if (s.baseDigits.length != 2) {
    out.add('唯一矩形的底数应为一对，声明了 ${s.baseDigits.length} 个');
  }
  return out;
}

/// 扩展矩形的几何：两条同向线各三格，六格跨恰好两个宫。
List<String> extendedRectGeometryViolations(TeachingStructure s) {
  final out = <String>[];
  if (s.cells.length != 6) {
    out.add('扩展矩形要六格，声明了 ${s.cells.length} 个');
    return out;
  }
  final rows = s.cells.map((c) => c.row).toSet();
  final cols = s.cells.map((c) => c.col).toSet();
  final byRow = rows.length == 2 && cols.length == 3;
  final byCol = cols.length == 2 && rows.length == 3;
  if (!byRow && !byCol) {
    out.add('六格应是两行×三列或两列×三行，实际是 ${rows.length} 行 ${cols.length} 列');
  }
  if (s.boxes.length != 2) {
    out.add('扩展矩形必须跨恰好两个宫，实际跨 ${s.boxes.length} 个：${s.boxes}');
  }
  if (s.baseDigits.length != 3) {
    out.add('两条线各三格，底数应为三个，声明了 ${s.baseDigits.length} 个');
  }
  // 每条三格线必须整整落在一个宫里，两条线还要落在不同的宫。
  //
  // 光查「恰好两个宫」拦不住这一条：两条线同处一个宫带、三格又跨两个宫柱时，
  // 六格照样只占两个宫（比如 r1c1,r1c2,r1c4 / r2c1,r2c2,r2c4 只占 b1、b2），
  // 可是整块对调之后宫里的底数个数就变了，根本不是致命形。
  // 三格一线各自成宫，才有「每条线、每条垂直房屋、每个宫都不变」这回事。
  if (byRow || byCol) {
    final lines = <int, List<CellRef>>{};
    for (final c in s.cells) {
      lines.putIfAbsent(byRow ? c.row : c.col, () => []).add(c);
    }
    final lineBoxes = <int>[];
    for (final entry in lines.entries) {
      final boxes = {for (final c in entry.value) c.box};
      if (boxes.length != 1) {
        out.add('${houseName(byRow ? entry.key : entry.key + 9)} 上那三格'
            '跨了 ${boxes.length} 个宫（$boxes），三格一线必须整整落在一个宫里');
      } else {
        lineBoxes.add(boxes.single);
      }
    }
    if (lineBoxes.length == 2 && lineBoxes[0] == lineBoxes[1]) {
      out.add('两条线落在同一个宫（b${lineBoxes[0] + 1}）里，'
          '一个宫装不下同一个底数两次');
    }
  }
  return out;
}

/// 唯一环：偶数格，每个用到的行/列/宫都恰好占环上两格，
/// 而且这些格子真的串成**一个**环、隔一格一色是个合法两染色。
///
/// 只数房屋是不够的。两个各自合法的环拼在一起，每条房屋照样恰好占两格，
/// 可那是两圈不是一圈；「整环换一种填法」这句话对拼起来的东西并不成立。
/// 所以这里把环真的走一遍：同房屋的两格之间连一条边，
/// 每格必须恰好两个邻居，从任意一格出发要正好 n 步回到起点、把所有格子走完。
/// 走出这一圈之后隔一格一色就是那个两染色，再核对每条边都连着不同色的两格——
/// 这才是「两种填法都合法、盘外看不出差别」的依据。
List<String> loopGeometryViolations(TeachingStructure s) {
  final out = <String>[];
  if (s.cells.length < 6 || s.cells.length.isOdd) {
    out.add('唯一环要偶数格且不少于六格，声明了 ${s.cells.length} 个');
    return out;
  }
  if (s.baseDigits.length != 2) {
    out.add('唯一环的底数应为一对，声明了 ${s.baseDigits.length} 个');
  }
  for (int h = 0; h < 27; h++) {
    final hit =
        s.cells.where((c) => housesOf(c.row, c.col).contains(h)).toList();
    if (hit.isNotEmpty && hit.length != 2) {
      out.add('${houseName(h)} 上占了环的 ${hit.length} 格'
          '（${hit.map((c) => c.label).join(",")}），唯一环要求恰好 2 格');
    }
  }
  if (out.isNotEmpty) return out;

  final n = s.cells.length;
  final neighbors = <int, Set<int>>{for (var i = 0; i < n; i++) i: <int>{}};
  for (var i = 0; i < n; i++) {
    for (var j = i + 1; j < n; j++) {
      if (sees(s.cells[i].row, s.cells[i].col, s.cells[j].row,
          s.cells[j].col)) {
        neighbors[i]!.add(j);
        neighbors[j]!.add(i);
      }
    }
  }
  for (var i = 0; i < n; i++) {
    if (neighbors[i]!.length != 2) {
      out.add('${s.cells[i].label} 在环上有 ${neighbors[i]!.length} 个同房屋的邻居，'
          '环上每格只能连着前后两格');
    }
  }
  if (out.isNotEmpty) return out;

  // 从 0 号格顺着邻居走一圈。
  final order = <int>[0];
  var prev = -1;
  var cur = 0;
  for (var step = 0; step < n - 1; step++) {
    final next = neighbors[cur]!.firstWhere((x) => x != prev, orElse: () => -1);
    if (next == -1 || order.contains(next)) break;
    order.add(next);
    prev = cur;
    cur = next;
  }
  if (order.length != n) {
    out.add('这些格子串不成一个环：从 ${s.cells[0].label} 出发只走到了 '
        '${order.length} 格（共 $n 格），'
        '${order.map((i) => s.cells[i].label).join("-")}');
    return out;
  }
  if (!neighbors[order.last]!.contains(0)) {
    out.add('环没有闭合：${s.cells[order.last].label} 回不到 ${s.cells[0].label}');
    return out;
  }

  // 隔一格一色，核对每条边都连着不同色的两格。
  final color = <int, int>{};
  for (var i = 0; i < n; i++) {
    color[order[i]] = i % 2;
  }
  for (var i = 0; i < n; i++) {
    for (final j in neighbors[i]!) {
      if (color[i] == color[j]) {
        out.add('${s.cells[i].label} 和 ${s.cells[j].label} 同房屋又同色，'
            '环上的两染色不成立，「换一种填法」也就不存在');
      }
    }
  }
  return out;
}

/// 探长致命结构（三数 BDP）的几何。
///
/// 按 kazusa《三数探长致命结构的基本推理》：一个宫里两行两列取三格的直角，
/// 直角的两行伸到宫外同一列上各一格，两列伸到宫外同一行上各一格，共七格三个数。
/// 这样数下来，正好有一行、一列、一宫各占三格，另有两行两列两宫各占两格。
List<String> borescoperGeometryViolations(TeachingStructure s) {
  final out = <String>[];
  if (s.cells.length != 7) {
    out.add('三数探长致命结构是七格，声明了 ${s.cells.length} 个');
    return out;
  }
  if (s.baseDigits.length != 3) {
    out.add('三数探长致命结构用三个数字，声明了 ${s.baseDigits.length} 个');
  }
  final triple = <String>[];
  final pair = <String>[];
  for (int h = 0; h < 27; h++) {
    final hit = s.cells.where((c) => housesOf(c.row, c.col).contains(h)).length;
    if (hit == 0) continue;
    if (hit == 3) {
      triple.add(houseName(h));
    } else if (hit == 2) {
      pair.add(houseName(h));
    } else {
      out.add('${houseName(h)} 上占了 $hit 格，探长致命结构的房屋只能占 2 格或 3 格');
    }
  }
  if (triple.length != 3) {
    out.add('应有一行、一列、一宫各占三格，实际占三格的房屋是 $triple');
  } else {
    final kinds = triple.map((n) => n[0]).toSet();
    if (kinds.length != 3) {
      out.add('占三格的三个房屋应各是一行、一列、一宫，实际是 $triple');
    }
  }
  if (pair.length != 6) {
    out.add('应有两行两列两宫各占两格，实际占两格的房屋是 $pair');
  }
  final boxes = s.boxes;
  if (boxes.length != 3) {
    out.add('三数探长致命结构横跨三个宫，实际跨 ${boxes.length} 个：$boxes');
  }
  return out;
}

/// 淑芬致命结构（QDP）的几何。
///
/// 按 kazusa《淑芬致命结构的基本推理》列出的结构特征：
/// 1. 结构 = 两条整线 L1、L2 上的全部空格，加线外两格 C1、C2；
/// 2. C1、C2 同宫，且横放（竖放）时 L1、L2 必须是行（列）；
/// 3. L1、L2 同处一个大行（大列），C1、C2 既不在 L1、L2 上，也不在那个大行（大列）里；
/// 4. C1、C2 涉及 2–4 个数字，就是这里的底数；
/// 5. C1、C2 各自看得见的 L1、L2 空格并起来同处一宫 B，
///    且每个底数在 B 里的位置只能落在这几格上。
List<String> qiuGeometryViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  if (s.cells.length != 2) {
    out.add('淑芬致命结构的线外格恰好两个，声明了 ${s.cells.length} 个');
    return out;
  }
  final c1 = s.cells[0], c2 = s.cells[1];
  if (c1.box != c2.box) {
    out.add('线外两格 ${c1.label}、${c2.label} 不同宫');
  }
  final horizontal = c1.row == c2.row;
  final vertical = c1.col == c2.col;
  if (!horizontal && !vertical) {
    out.add('线外两格既不横放也不竖放');
    return out;
  }

  final lineIds = horizontal
      ? s.freeCells.map((c) => c.row).toSet()
      : s.freeCells.map((c) => c.col).toSet();
  if (lineIds.length != 2) {
    out.add('结构应盖住两条整线，实际盖住 ${lineIds.length} 条：$lineIds');
    return out;
  }
  final lines = lineIds.toList()..sort();
  if (lines[0] ~/ 3 != lines[1] ~/ 3) {
    out.add('两条线 $lines 不在同一个大行/大列里');
  }
  final declared = {for (final c in s.freeCells) '${c.row},${c.col}'};
  for (final line in lines) {
    for (int k = 0; k < 9; k++) {
      final r = horizontal ? line : k;
      final c = horizontal ? k : line;
      if (board.get(r, c) != 0) continue;
      if (!declared.contains('$r,$c')) {
        out.add('${horizontal ? "r${line + 1}" : "c${line + 1}"} 上的空格 '
            'r${r + 1}c${c + 1} 没有算进结构，淑芬致命结构要求整线上的空格一个不漏');
      }
    }
  }
  for (final c in s.freeCells) {
    final id = horizontal ? c.row : c.col;
    if (!lines.contains(id)) {
      out.add('${c.label} 不在声明的两条线上');
    }
  }
  for (final c in [c1, c2]) {
    final id = horizontal ? c.row : c.col;
    if (lines.contains(id)) {
      out.add('线外格 ${c.label} 落在线上了');
    }
    if (id ~/ 3 == lines[0] ~/ 3) {
      out.add('线外格 ${c.label} 落在两条线所在的大行/大列里');
    }
  }

  final union = <int>{
    ...board.getCandidates(c1.row, c1.col),
    ...board.getCandidates(c2.row, c2.col),
  };
  if (s.baseDigits.length < 2 || s.baseDigits.length > 4) {
    out.add('淑芬致命结构的底数是 2–4 个，声明了 ${s.baseDigits.length} 个');
  }
  for (final d in s.baseDigits) {
    if (!union.contains(d)) {
      out.add('底数 $d 在线外两格上都没有候选，结构不成立');
    }
  }

  // 交点格：C1、C2 各自看得见的线上空格。它们必须同处一宫，
  // 而且底数在那个宫里只能落在这几格上，否则底数会漏到结构外面去。
  final joint = <CellRef>[];
  for (final line in lines) {
    for (final c in [c1, c2]) {
      final r = horizontal ? line : c.row;
      final col = horizontal ? c.col : line;
      if (board.get(r, col) != 0) continue;
      joint.add(CellRef(r, col));
    }
  }
  if (joint.isEmpty) {
    out.add('交点格全是已知数，结构不成立');
    return out;
  }
  final jointBoxes = joint.map((c) => c.box).toSet();
  if (jointBoxes.length != 1) {
    out.add('交点格 ${joint.map((c) => c.label).join(",")} 不同宫：$jointBoxes');
    return out;
  }
  final box = 18 + jointBoxes.first;
  final jointKeys = {for (final c in joint) '${c.row},${c.col}'};
  for (final cell in houseCells(box)) {
    final r = cell[0], col = cell[1];
    if (jointKeys.contains('$r,$col')) continue;
    final filled = board.get(r, col);
    if (filled != 0) {
      if (s.baseDigits.contains(filled)) {
        out.add('底数 $filled 在 ${houseName(box)} 里已经填在交点格外的 '
            'r${r + 1}c${col + 1} 上，淑芬致命结构的第 7 条不成立');
      }
      continue;
    }
    for (final d in board.getCandidates(r, col)) {
      if (s.baseDigits.contains(d)) {
        out.add('底数 $d 在 ${houseName(box)} 里还能落到 r${r + 1}c${col + 1}，'
            '不只在交点格上，淑芬致命结构的第 7 条不成立');
      }
    }
  }
  return out;
}

String _candLabel(CandidateRef r) => '${r.num}r${r.row + 1}c${r.col + 1}';

String _prettyCand(String key) {
  final p = key.split(',');
  return '${p[2]}r${int.parse(p[0]) + 1}c${int.parse(p[1]) + 1}';
}

String _prettyCell(String key) {
  final p = key.split(',');
  return 'r${int.parse(p[0]) + 1}c${int.parse(p[1]) + 1}';
}

/// 一条鱼在盘面上算出来的东西，全部独立重算，不看声明。
class _FishFacts {
  /// 鱼身：基线上带这个数字的格子 → 盖住它的覆盖线条数。
  final Map<String, int> bodyCoverCount;

  /// 鳍：鱼身里一条覆盖线都没盖住的格子。
  final Set<String> fins;

  /// 「去鳍后在覆盖线上只剩一个候选」的基线。刺身就是靠它成立。
  final List<FishHouse> thinBases;

  /// 那些基线和覆盖线交出的、没有这个数字的格子，也就是缺掉的覆盖顶点。
  final Set<String> deficits;

  /// 删除：覆盖线上鱼身之外的同名候选，以及压在两条覆盖线交叉处的鱼身候选。
  final Set<String> elims;

  /// 落在鱼身上的那部分删除。
  final Set<String> cannibalElims;

  _FishFacts({
    required this.bodyCoverCount,
    required this.fins,
    required this.thinBases,
    required this.deficits,
    required this.elims,
    required this.cannibalElims,
  });
}

_FishFacts _fishFacts(SudokuBoard board, FishSpec f) {
  final d = f.digit;
  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(d);
  int coverCount(int r, int c) =>
      f.coverHouses.where((h) => h.contains(r, c)).length;

  final body = <String, int>{};
  for (final b in f.baseHouses) {
    for (final cell in houseCells(b.house)) {
      if (has(cell[0], cell[1])) {
        body['${cell[0]},${cell[1]}'] = coverCount(cell[0], cell[1]);
      }
    }
  }
  final fins = {
    for (final e in body.entries)
      if (e.value == 0) e.key
  };

  final thin = <FishHouse>[];
  for (final b in f.baseHouses) {
    var covered = 0;
    for (final cell in houseCells(b.house)) {
      if (has(cell[0], cell[1]) && coverCount(cell[0], cell[1]) > 0) covered++;
    }
    if (covered == 1) thin.add(b);
  }
  final deficits = <String>{};
  for (final b in thin) {
    for (final cell in houseCells(b.house)) {
      final r = cell[0], c = cell[1];
      if (coverCount(r, c) == 0) continue;
      if (!has(r, c)) deficits.add('$r,$c');
    }
  }

  final elims = <String>{};
  final cannibal = <String>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (!has(r, c)) continue;
      final cc = coverCount(r, c);
      if (cc == 0) continue;
      final inBody = body.containsKey('$r,$c');
      if (inBody && cc < 2) continue;
      if (fins.any((k) {
        final p = k.split(',');
        return !sees(r, c, int.parse(p[0]), int.parse(p[1]));
      })) {
        continue;
      }
      elims.add('$r,$c,$d');
      if (inBody) cannibal.add('$r,$c,$d');
    }
  }
  return _FishFacts(
    bodyCoverCount: body,
    fins: fins,
    thinBases: thin,
    deficits: deficits,
    elims: elims,
    cannibalElims: cannibal,
  );
}

/// 一条鱼的全部核对：几何、鳍、缺掉的覆盖顶点、刺身/Mutant/自噬这几个标签，
/// 以及它算出来的那组删除。
///
/// 判定不分「普通鱼 / Franken / Mutant」，全走同一条道理，所以基线掺宫、
/// 覆盖混行列都不需要另写一套；每一项都从盘面重算再和声明对齐。
List<String> fishSpecViolations(String puzzle, FishSpec f, {String tag = '鱼'}) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final d = f.digit;
  if (d < 1 || d > 9) {
    out.add('$tag 盯的数字是 $d，不在 1–9 里');
    return out;
  }
  if (f.baseHouses.isEmpty) {
    out.add('$tag 一条基线都没声明');
    return out;
  }
  if (f.baseHouses.length != f.coverHouses.length) {
    out.add('$tag 基线 ${f.baseHouses.length} 条、覆盖 ${f.coverHouses.length} 条，'
        '鱼要求条数相同');
    return out;
  }
  if (f.baseHouses.toSet().length != f.baseHouses.length) {
    out.add('$tag 的基线里有重复房屋：${f.baseHouses}');
  }
  if (f.coverHouses.toSet().length != f.coverHouses.length) {
    out.add('$tag 的覆盖里有重复房屋：${f.coverHouses}');
  }
  if (f.baseHouses.any((b) => f.coverHouses.contains(b))) {
    out.add('$tag 有房屋同时当基线和覆盖，那条房屋两边都算一次，道理站不住');
  }

  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(d);

  // 基线两两不共格：鱼的整套计数就建立在「落点个数 = 基线条数」上，
  // 两条基线共用一格的话落点会少一个，配对论证立刻失效。
  for (int i = 0; i < f.baseHouses.length; i++) {
    for (int j = i + 1; j < f.baseHouses.length; j++) {
      final a = f.baseHouses[i], b = f.baseHouses[j];
      final shared = [
        for (final cell in houseCells(a.house))
          if (b.contains(cell[0], cell[1]) && has(cell[0], cell[1]))
            'r${cell[0] + 1}c${cell[1] + 1}'
      ];
      if (shared.isNotEmpty) {
        out.add('$tag 的基线 ${a.label} 与 ${b.label} 共用 $shared 上的 $d，'
            '鱼要求基线两两不共格');
      }
    }
  }
  for (final b in f.baseHouses) {
    final n = houseCells(b.house).where((c) => has(c[0], c[1])).length;
    if (n == 0) out.add('$tag 的基线 ${b.label} 上没有 $d 的候选');
    if (n == 1) {
      out.add('$tag 的基线 ${b.label} 上 $d 只剩一个位置，那是摒除法，不该当基线');
    }
  }

  final facts = _fishFacts(board, f);
  final declaredFins = {for (final x in f.fins) '${x.row},${x.col}'};
  if (f.fins.any((x) => x.num != d)) {
    out.add('$tag 的鳍上写了别的数字，鳍必须是同一个数字 $d');
  }
  for (final miss in facts.fins.difference(declaredFins)) {
    out.add('$tag 的基线上 ${_prettyCell(miss)} 的 $d 没被任何覆盖线盖住，'
        '却没算作鳍');
  }
  for (final ghost in declaredFins.difference(facts.fins)) {
    out.add('$tag 声明的鳍 ${_prettyCell(ghost)} 其实被覆盖线盖住了，或者根本不在鱼身上');
  }
  for (final b in f.baseHouses) {
    final covered = houseCells(b.house)
        .where((c) =>
            has(c[0], c[1]) && f.coverHouses.any((h) => h.contains(c[0], c[1])))
        .length;
    if (covered == 0) {
      out.add('$tag 的基线 ${b.label} 上的 $d 全是鳍，覆盖里一个顶点都不剩，这不是鱼');
    }
  }

  // 刺身：去鳍以后有基线在覆盖里只剩一个顶点。
  final thin = facts.thinBases.map((b) => b.label).toList();
  if (f.sashimi && thin.isEmpty) {
    out.add('$tag 声明是刺身，可是每条基线在覆盖里都还剩两个以上顶点，'
        '这只是普通带鳍鱼');
  }
  if (!f.sashimi && thin.isNotEmpty) {
    out.add('$tag 的基线 $thin 在覆盖里只剩一个顶点，这已经是刺身了，声明里却没说');
  }
  final declaredDeficits = {
    for (final c in f.coverDeficits) '${c.row},${c.col}'
  };
  for (final miss in facts.deficits.difference(declaredDeficits)) {
    out.add('$tag 缺掉的覆盖顶点 ${_prettyCell(miss)} 没写进声明');
  }
  for (final ghost in declaredDeficits.difference(facts.deficits)) {
    out.add('$tag 声明缺掉的覆盖顶点 ${_prettyCell(ghost)} 其实上面有 $d，'
        '或者不在刺身那条基线的覆盖交点上');
  }

  // 鳍的对齐。鳍为真的时候鱼散掉，所以鳍只能删「同时看得见它」的那些覆盖格；
  // 一个连一格都管不到的鳍等于白挂在图上。刺身还要求鳍和缺掉的那个覆盖顶点同宫——
  // 那正是「基线被截断的那一段」，也是教学正文里说的那句对齐条件。
  for (final fin in f.fins) {
    final finBox = (fin.row ~/ 3) * 3 + fin.col ~/ 3;
    final room = <String>[];
    for (int r = 0; r < 9; r++) {
      for (int c = 0; c < 9; c++) {
        if (!has(r, c) || facts.bodyCoverCount.containsKey('$r,$c')) continue;
        if (!f.coverHouses.any((h) => h.contains(r, c))) continue;
        if (sees(r, c, fin.row, fin.col)) room.add('r${r + 1}c${c + 1}');
      }
    }
    if (room.isEmpty) {
      out.add('$tag 的鳍 ${_candLabel(fin)} 在覆盖线上看不到任何鱼身之外的 $d，'
          '这个鳍的删除范围是空的');
    }
    if (f.sashimi &&
        !facts.deficits.any((k) {
          final p = k.split(',');
          final r = int.parse(p[0]), c = int.parse(p[1]);
          return (r ~/ 3) * 3 + c ~/ 3 == finBox;
        })) {
      out.add('$tag 的鳍 ${_candLabel(fin)} 和缺掉的覆盖顶点 '
          '${facts.deficits.map(_prettyCell).toList()} 不同宫，刺身的鳍对不上位');
    }
  }

  // Mutant：同一侧混了行与列，两侧合起来还用到宫。Franken 只在一侧掺宫，不算。
  final baseKinds = f.baseHouses.map((h) => h.kind).toSet();
  final coverKinds = f.coverHouses.map((h) => h.kind).toSet();
  final mixedSide = (baseKinds.containsAll({HouseKind.row, HouseKind.col})) ||
      (coverKinds.containsAll({HouseKind.row, HouseKind.col}));
  final usesBox =
      baseKinds.contains(HouseKind.box) || coverKinds.contains(HouseKind.box);
  final isMutant = mixedSide && usesBox;
  if (f.mutant && !isMutant) {
    out.add('$tag 声明是 Mutant，可是基线 $baseKinds、覆盖 $coverKinds '
        '并没有在同一侧混行与列、再掺上宫');
  }
  if (!f.mutant && isMutant) {
    out.add('$tag 的基线 $baseKinds、覆盖 $coverKinds 已经是 Mutant 了，声明里却没说');
  }

  // 删除：独立重算一遍再逐条对齐，多一个少一个都是教学文字说错了。
  if (facts.elims.isEmpty) {
    out.add('$tag 在这个盘面上删不出任何候选，教学页拿它举例说不通');
  }
  out.addAll(_sameElims(f.eliminations, facts.elims, tag));
  if (f.cannibal && facts.cannibalElims.isEmpty) {
    out.add('$tag 声明有自噬，可是算出来的删除没有一个落在鱼身上');
  }
  if (!f.cannibal && facts.cannibalElims.isNotEmpty) {
    out.add('$tag 算出来的 ${facts.cannibalElims.map(_prettyCand).toList()} '
        '落在鱼身上，这已经是自噬了，声明里却没说');
  }

  // 收获的成色：这套删除能不能被同数字的某一条多宝鱼整个包住。
  final covered = _turbotEliminationSets(board, d)
      .any((set) => facts.elims.every(set.contains));
  if (f.beyondTurbot && covered) {
    out.add('$tag 声明收获超出多宝鱼一档，可是同数字已经有一条多宝鱼'
        '把这组删除整个包住了');
  }
  if (!f.beyondTurbot && !covered) {
    out.add('$tag 这组删除其实没有任何一条同数字多宝鱼包得住，'
        '声明里可以（也应该）说明这一点');
  }
  final locked = lockedCandidateElims(board, d).intersection(facts.elims);
  if (f.beyondLocked && locked.isNotEmpty) {
    out.add('$tag 声明避开了区块摒除，可是 ${locked.map(_prettyCand).toList()} '
        '本来就是区块摒除删得到的');
  }
  if (!f.beyondLocked && locked.isEmpty) {
    out.add('$tag 这组删除区块摒除一个都碰不到，声明里应当标明这一点');
  }
  return out;
}

/// 区块摒除（宫线锁定）在这个盘面上能删掉的同数字候选。
///
/// 教学盘很容易一不小心举了个「换个说法的区块摒除」——图画得很热闹，
/// 删的却是初学第三课就该看出来的那一个。所以每条鱼、每条短链都要过一遍这个集合。
Set<String> lockedCandidateElims(SudokuBoard board, int digit) {
  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(digit);
  final out = <String>{};
  for (int b = 0; b < 9; b++) {
    final inBox = [
      for (final cell in houseCells(18 + b))
        if (has(cell[0], cell[1])) cell
    ];
    if (inBox.isEmpty) continue;
    for (int h = 0; h < 18; h++) {
      final inLine = [
        for (final cell in houseCells(h))
          if (has(cell[0], cell[1])) cell
      ];
      if (inLine.isEmpty) continue;
      bool onLine(List<int> cell) => h < 9 ? cell[0] == h : cell[1] == h - 9;
      bool inThisBox(List<int> cell) => (cell[0] ~/ 3) * 3 + cell[1] ~/ 3 == b;
      if (inBox.every(onLine)) {
        for (final cell in inLine) {
          if (!inThisBox(cell)) out.add('${cell[0]},${cell[1]},$digit');
        }
      }
      if (inLine.every(inThisBox)) {
        for (final cell in inBox) {
          if (!onLine(cell)) out.add('${cell[0]},${cell[1]},$digit');
        }
      }
    }
  }
  return out;
}

/// 盘面上某个数字的全部「强-弱-强」多宝鱼各自能删出的候选集合。
///
/// 用来给鱼类页面的收获定成色：如果某条鱼的删除被其中一条整个包住，
/// 那这一页教的东西并没有超出摩天楼/双线风筝那一档。
List<Set<String>> _turbotEliminationSets(SudokuBoard board, int digit) {
  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(digit);
  final strong = <List<int>>[];
  for (int h = 0; h < 27; h++) {
    final spots = [
      for (final cell in houseCells(h))
        if (has(cell[0], cell[1])) cell
    ];
    if (spots.length != 2) continue;
    strong.add([spots[0][0], spots[0][1], spots[1][0], spots[1][1]]);
  }
  final out = <Set<String>>[];
  for (int i = 0; i < strong.length; i++) {
    for (int j = 0; j < strong.length; j++) {
      if (i == j) continue;
      for (final aEnd in [0, 1]) {
        for (final bEnd in [0, 1]) {
          // a 的一端留作链尾，另一端和 b 的一端连弱链。
          final tailA = [strong[i][aEnd * 2], strong[i][aEnd * 2 + 1]];
          final midA = [
            strong[i][(1 - aEnd) * 2],
            strong[i][(1 - aEnd) * 2 + 1]
          ];
          final midB = [strong[j][bEnd * 2], strong[j][bEnd * 2 + 1]];
          final tailB = [
            strong[j][(1 - bEnd) * 2],
            strong[j][(1 - bEnd) * 2 + 1]
          ];
          if (!sees(midA[0], midA[1], midB[0], midB[1])) continue;
          final cells = {
            '${tailA[0]},${tailA[1]}',
            '${midA[0]},${midA[1]}',
            '${midB[0]},${midB[1]}',
            '${tailB[0]},${tailB[1]}',
          };
          if (cells.length != 4) continue;
          final elims = <String>{};
          for (int r = 0; r < 9; r++) {
            for (int c = 0; c < 9; c++) {
              if (!has(r, c) || cells.contains('$r,$c')) continue;
              if (sees(r, c, tailA[0], tailA[1]) &&
                  sees(r, c, tailB[0], tailB[1])) {
                elims.add('$r,$c,$digit');
              }
            }
          }
          if (elims.isNotEmpty) out.add(elims);
        }
      }
    }
  }
  return out;
}

/// 鱼类页面：把声明的每条鱼逐条验完，再核对页面结论和各条鱼算出的删除一致。
List<String> fishFamilyViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  if (s.fishes.isEmpty) {
    out.add('鱼类结构一条鱼都没声明');
    return out;
  }
  if (s.fishes.length != 1) {
    out.add('单条鱼的页面只该声明一条鱼，实际声明了 ${s.fishes.length} 条');
  }
  for (int i = 0; i < s.fishes.length; i++) {
    out.addAll(fishSpecViolations(puzzle, s.fishes[i], tag: '第 ${i + 1} 条鱼'));
  }
  final all = <String>{
    for (final f in s.fishes)
      for (final e in f.eliminations) '${e.row},${e.col},${e.num}'
  };
  out.addAll(_sameElims(s.conclusionFalse, all, '鱼类页面的结论'));
  return out;
}

/// 双生鱼：两条鱼共用鱼身，各自的鳍和覆盖不同，算出来的删除也必须真的不同。
List<String> siameseViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  if (s.fishes.length != 2) {
    out.add('双生鱼要声明两条鱼，实际声明了 ${s.fishes.length} 条');
    return out;
  }
  final a = s.fishes[0], b = s.fishes[1];
  out.addAll(fishSpecViolations(puzzle, a, tag: '双生的第一条鱼'));
  out.addAll(fishSpecViolations(puzzle, b, tag: '双生的第二条鱼'));

  if (a.digit != b.digit) {
    out.add('两条鱼盯的数字是 ${a.digit} 和 ${b.digit}，双生鱼必须是同一个数字');
  }
  if (!setEquals(
    a.baseHouses.map((h) => h.house).toSet(),
    b.baseHouses.map((h) => h.house).toSet(),
  )) {
    out.add('两条鱼的基线是 ${a.baseHouses} 和 ${b.baseHouses}，'
        '双生鱼说的是「共用鱼身」，基线集合必须一模一样');
  }
  if (setEquals(
    a.coverHouses.map((h) => h.house).toSet(),
    b.coverHouses.map((h) => h.house).toSet(),
  )) {
    out.add('两条鱼的覆盖 ${a.coverHouses} 完全相同，那是同一条鱼，不是双生');
  }
  final finsA = {for (final x in a.fins) '${x.row},${x.col}'};
  final finsB = {for (final x in b.fins) '${x.row},${x.col}'};
  if (finsA.isEmpty || finsB.isEmpty) {
    out.add('双生鱼的两条都得带鳍，实际鳍数是 ${finsA.length} 和 ${finsB.length}');
  }
  if (_sameStrings(finsA, finsB)) {
    out.add('两条鱼的鳍 $finsA 完全相同，配不成双生');
  }
  final elimsA = {for (final e in a.eliminations) '${e.row},${e.col},${e.num}'};
  final elimsB = {for (final e in b.eliminations) '${e.row},${e.col},${e.num}'};
  if (_sameStrings(elimsA, elimsB)) {
    out.add('两条鱼算出来的删除完全一样（${elimsA.map(_prettyCand).toList()}），'
        '合成一张图没有多出任何收获，不该按双生讲');
  }
  out.addAll(_sameElims(s.conclusionFalse, {...elimsA, ...elimsB}, '双生鱼的结论'));
  return out;
}

/// 多宝鱼：同数字的强-弱-强三段短链，两端共同可见处删这个数字。
List<String> turbotViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final d = s.fishDigit;
  if (d == null) {
    out.add('多宝鱼没有声明盯的数字');
    return out;
  }
  if (s.chain.length != 3) {
    out.add('多宝鱼是强-弱-强三段，实际声明了 ${s.chain.length} 段');
    return out;
  }
  const wantStrong = [true, false, true];
  for (int i = 0; i < 3; i++) {
    if (s.chain[i].strong != wantStrong[i]) {
      out.add('第 ${i + 1} 段应当是${wantStrong[i] ? "强" : "弱"}链，声明成了'
          '${s.chain[i].strong ? "强" : "弱"}链');
    }
  }
  bool has(CandidateRef x) =>
      board.get(x.row, x.col) == 0 &&
      board.getCandidates(x.row, x.col).contains(x.num);
  final nodes = <CandidateRef>[
    s.chain[0].from,
    s.chain[0].to,
    s.chain[1].to,
    s.chain[2].to,
  ];
  for (final seg in s.chain) {
    for (final end in [seg.from, seg.to]) {
      if (end.num != d) {
        out.add('${_candLabel(end)} 不是这条链盯的数字 $d，同数字链上不该出现别的数字');
      }
      if (!has(end)) {
        out.add('${_candLabel(end)} 在盘面上不存在');
      }
    }
  }
  for (int i = 0; i < 2; i++) {
    final prev = s.chain[i].to, next = s.chain[i + 1].from;
    if (prev.row != next.row || prev.col != next.col || prev.num != next.num) {
      out.add('第 ${i + 1} 段的终点 ${_candLabel(prev)} 和第 ${i + 2} 段的起点 '
          '${_candLabel(next)} 接不上，串不成一条链');
    }
  }
  if (out.isNotEmpty) return out;

  final cellKeys = {for (final n in nodes) '${n.row},${n.col}'};
  if (cellKeys.length != 4) {
    out.add('链上四个节点落在 ${cellKeys.length} 个格子上，短链要求四格互不相同');
    return out;
  }
  final houses = s.chain.map((c) => c.house).toList();
  if (houses.toSet().length != 3) {
    out.add('三段共用了房屋 $houses，强-弱-强要走三个不同的房屋');
  }
  for (int i = 0; i < 3; i++) {
    final seg = s.chain[i];
    final h = seg.house;
    if (h < 0 || h > 26) {
      out.add('第 ${i + 1} 段声明的房屋编号 $h 不合法');
      continue;
    }
    bool inHouse(CandidateRef x) =>
        houseCells(h).any((c) => c[0] == x.row && c[1] == x.col);
    if (!inHouse(seg.from) || !inHouse(seg.to)) {
      out.add('第 ${i + 1} 段的 ${_candLabel(seg.from)} 与 ${_candLabel(seg.to)} '
          '并非同处 ${houseName(h)}，这一段连不成链节');
      continue;
    }
    if (!seg.strong) continue;
    final spots = [
      for (final c in houseCells(h))
        if (board.get(c[0], c[1]) == 0 &&
            board.getCandidates(c[0], c[1]).contains(d))
          'r${c[0] + 1}c${c[1] + 1}'
    ];
    if (spots.length != 2 ||
        !spots.contains('r${seg.from.row + 1}c${seg.from.col + 1}') ||
        !spots.contains('r${seg.to.row + 1}c${seg.to.col + 1}')) {
      out.add('第 ${i + 1} 段画成强链，可是 $d 在 ${houseName(h)} 里的位置是 $spots，'
          '不是这一段的两端');
    }
  }

  final head = nodes.first, tail = nodes.last;
  if (sees(head.row, head.col, tail.row, tail.col)) {
    out.add('两端 ${_candLabel(head)} 与 ${_candLabel(tail)} 互相看得见，'
        '链首尾自己就撞上了，不是一条开链');
  }
  final computed = <String>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) != 0) continue;
      if (!board.getCandidates(r, c).contains(d)) continue;
      if (cellKeys.contains('$r,$c')) continue;
      if (sees(r, c, head.row, head.col) && sees(r, c, tail.row, tail.col)) {
        computed.add('$r,$c,$d');
      }
    }
  }
  if (computed.isEmpty) {
    out.add('没有任何位置同时看得见两端，这条链在这个盘面上删不出东西');
  }
  out.addAll(_sameElims(s.conclusionFalse, computed, '多宝鱼'));

  final named = _namedTurbotShape(board, d, nodes);
  if (s.generalizedTurbot && named != null) {
    out.add('换个说法这条链就是$named，不能算超出已命名特例');
  }
  if (!s.generalizedTurbot && named == null) {
    out.add('这条链换遍所有说得通的房屋组合都凑不成摩天楼、双线风筝或空矩形，'
        '声明里应当标明它是一般形状');
  }
  final locked = lockedCandidateElims(board, d).intersection(computed);
  if (s.beyondLocked && locked.isNotEmpty) {
    out.add('声明避开了区块摒除，可是 ${locked.map(_prettyCand).toList()} '
        '本来就是区块摒除删得到的');
  }
  if (!s.beyondLocked && locked.isEmpty) {
    out.add('这条链的删除区块摒除一个都碰不到，声明里应当标明这一点');
  }
  return out;
}

/// 这四个节点能不能被重新贴标签，读成摩天楼、双线风筝或空矩形。
///
/// 光看声明的那三个房屋不够：同两个候选常常同时处在一条线和一个宫里，
/// 挑哪个当强链房屋是写声明的人自己决定的。所以这里把所有说得通的组合
/// 都枚举一遍，只有每一种读法都落在三个已命名特例之外，才算「一般形状」。
String? _namedTurbotShape(
  SudokuBoard board,
  int digit,
  List<CandidateRef> nodes,
) {
  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(digit);
  List<int> spotsOf(int h) => [
        for (final cell in houseCells(h))
          if (has(cell[0], cell[1])) cell[0] * 9 + cell[1]
      ];
  List<int> strongHouses(CandidateRef a, CandidateRef b) => [
        for (final h in housesOf(a.row, a.col))
          if (housesOf(b.row, b.col).contains(h) &&
              spotsOf(h).length == 2 &&
              spotsOf(h).contains(a.row * 9 + a.col) &&
              spotsOf(h).contains(b.row * 9 + b.col))
            h
      ];
  List<int> sharedHouses(CandidateRef a, CandidateRef b) => [
        for (final h in housesOf(a.row, a.col))
          if (housesOf(b.row, b.col).contains(h)) h
      ];

  HouseKind kindOf(int h) =>
      h < 9 ? HouseKind.row : (h < 18 ? HouseKind.col : HouseKind.box);
  const lines = {HouseKind.row, HouseKind.col};
  // 空矩形的宫是一个「十字」：宫里这个数字的候选靠一行加一列才盖得住，
  // 而且行外列外各有落点。只剩两个候选时，那就是错行又错列的一对。
  bool cross(int h) {
    if (kindOf(h) != HouseKind.box) return false;
    final s = spotsOf(h);
    if (s.length != 2) return false;
    return s[0] ~/ 9 != s[1] ~/ 9 && s[0] % 9 != s[1] % 9;
  }

  for (final h0 in strongHouses(nodes[0], nodes[1])) {
    for (final h2 in strongHouses(nodes[2], nodes[3])) {
      for (final h1 in sharedHouses(nodes[1], nodes[2])) {
        if ({h0, h1, h2}.length != 3) continue;
        final k0 = kindOf(h0), k1 = kindOf(h1), k2 = kindOf(h2);
        if (k0 == k2 && lines.contains(k0) && lines.contains(k1) && k1 != k0) {
          return '摩天楼';
        }
        if (lines.contains(k0) &&
            lines.contains(k2) &&
            k0 != k2 &&
            k1 == HouseKind.box) {
          return '双线风筝';
        }
        final boxCount =
            (k0 == HouseKind.box ? 1 : 0) + (k2 == HouseKind.box ? 1 : 0);
        if (boxCount == 1 && (cross(h0) || cross(h2))) return '空矩形';
      }
    }
  }
  return null;
}

/// 锁定集：格子上的候选并集大小要等于声明值。
List<String> lockedSetViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final union = <int>{};
  for (final cell in s.cells) {
    if (board.get(cell.row, cell.col) != 0) {
      out.add('${cell.label} 是已知数，不能算进锁定集');
      continue;
    }
    final cands = board.getCandidates(cell.row, cell.col);
    if (cands.length < 2) {
      out.add('${cell.label} 只剩 ${cands.length} 个候选，是唯余法，不该当结构格');
    }
    union.addAll(cands);
  }
  final want = s.lockedDigitCount;
  if (want != null && union.length != want) {
    out.add('${s.cells.length} 格的候选并集是 $union（${union.length} 个数字），'
        '声明应为 $want 个');
  }
  return out;
}

/// 靠唯余加摒除推到底能删掉的候选，也就是「基础招式顺手就删得到」的那一批。
///
/// 教学页举的高阶结构必须比这一批更远：随机挖出来的盘面十有八九光靠唯余摒除
/// 就能推掉一大片，不拿这个集合兜一下，「结构删出了 X」经常只是
/// 「X 本来就活不下来」的另一种说法。
Set<String> singlesClosureKills(String puzzle) {
  final board = SudokuBoard.fromString(puzzle);
  final grid = LogicGrid.fromPuzzle(puzzle);
  final out = <String>{};
  if (grid.broken) return out;
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) != 0) continue;
      for (final d in board.getCandidates(r, c)) {
        if (!grid.has(r * 9 + c, d)) out.add('$r,$c,$d');
      }
    }
  }
  return out;
}

/// 两支互斥假设都删掉的候选，也就是这一页真正能下的结论。
///
/// 两支都必须是从 [LogicGrid.fromBoard] 起步的，量出来的才是页面上那张盘面的变化。
Set<String> _bothBranchKills(String puzzle, LogicGrid a, LogicGrid b) {
  final board = SudokuBoard.fromString(puzzle);
  final out = <String>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) != 0) continue;
      for (final d in board.getCandidates(r, c)) {
        final cell = r * 9 + c;
        if (!a.has(cell, d) && !b.has(cell, d)) out.add('$r,$c,$d');
      }
    }
  }
  return out;
}

/// 这一组删除里至少要有一条是唯余摒除推不到的，否则这一页教的是基础招式。
List<String> _beyondSinglesViolations(
  String puzzle,
  Set<String> elims,
  String what,
) {
  if (elims.isEmpty) return const [];
  final easy = singlesClosureKills(puzzle);
  if (elims.any((k) => !easy.contains(k))) return const [];
  return [
    '$what 算出的 ${elims.map(_prettyCand).toList()} 全都是唯余加摒除'
        '推到底就能删掉的，这一页没有讲出高阶结构的价值',
  ];
}

/// 同数字奇数圈（死环 / Broken Wing）。
///
/// 道理只有一条：把圈上每条边所在房屋里的守卫都假设为假，那条房屋里这个数字
/// 就只剩圈上那两格，于是每条边都成了真强链——「恰好一端为真」。奇数圈上
/// 这种交替染色是办不到的，所以守卫里至少有一个为真。
///
/// 因此这几项必须逐条坐实，缺一条结论就不成立：
/// 1. 圈长为奇数，且 [TeachingStructure.lockHouses] 按顺序给出每条边的房屋；
/// 2. 每条边的两个端点确实同处那条房屋，各条边的房屋互不相同；
/// 3. 每条边的房屋里恰好只有它自己的两个圈上格——挤进第三个圈上格，
///    「全假设为假之后只剩两格」就不成立了；
/// 4. [TeachingStructure.guards] 穷尽列出各边房屋里圈外的同名候选；
/// 5. 删除恰好是「同时看得见全部守卫」的那些同名候选。
List<String> oddCycleViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final digit = s.fishDigit;
  if (digit == null) {
    out.add('奇数圈没有声明数字');
    return out;
  }
  final n = s.cells.length;
  if (n < 5 || n.isEven) {
    out.add('圈长 $n 不合法，死环要奇数圈且不少于五格');
    return out;
  }
  bool has(int r, int c) =>
      board.get(r, c) == 0 && board.getCandidates(r, c).contains(digit);
  for (final c in s.cells) {
    if (!has(c.row, c.col)) {
      out.add('${c.label} 上没有 $digit 的候选，它不能在圈上');
    }
  }
  final houses = s.lockHouses;
  if (houses.length != n) {
    out.add('圈有 $n 条边，声明了 ${houses.length} 条边房屋');
    return out;
  }
  if (houses.toSet().length != n) {
    out.add('各条边的房屋必须互不相同，实际是 ${houses.map(houseName).toList()}');
  }
  for (int i = 0; i < n; i++) {
    final a = s.cells[i], b = s.cells[(i + 1) % n];
    final h = houses[i];
    if (h < 0 || h > 26) {
      out.add('第 ${i + 1} 条边的房屋编号 $h 不合法');
      continue;
    }
    bool inHouse(CellRef x) =>
        houseCells(h).any((c) => c[0] == x.row && c[1] == x.col);
    if (!inHouse(a) || !inHouse(b)) {
      out.add('${a.label} 与 ${b.label} 并非同处 ${houseName(h)}，这条边连不起来');
      continue;
    }
    final onCycle = s.cells.where(inHouse).toList();
    if (onCycle.length != 2) {
      out.add('${houseName(h)} 里有 ${onCycle.length} 个圈上格'
          '（${onCycle.map((c) => c.label).join(",")}），'
          '每条边的房屋只能占圈上两格，否则守卫全假之后它也撑不成强链');
    }
  }
  if (out.isNotEmpty) return out;

  final cycleKeys = {for (final c in s.cells) '${c.row},${c.col}'};
  final found = <String>{};
  for (final h in houses) {
    for (final cell in houseCells(h)) {
      final r = cell[0], c = cell[1];
      if (!has(r, c) || cycleKeys.contains('$r,$c')) continue;
      found.add('$r,$c');
    }
  }
  final guardKeys = {for (final g in s.guards) '${g.row},${g.col}'};
  if (s.guards.any((g) => g.num != digit)) {
    out.add('守卫候选必须都是圈盯的数字 $digit');
  }
  for (final extra in found.difference(guardKeys)) {
    out.add('${_prettyCell(extra)} 也在圈的边上，却没被算成守卫');
  }
  for (final ghost in guardKeys.difference(found)) {
    out.add('声明的守卫 ${_prettyCell(ghost)} 并不在圈的任何一条边上');
  }
  if (found.isEmpty) {
    out.add('圈上没有守卫，全强链奇数圈在唯一解盘面上不可能存在');
    return out;
  }
  if (out.isNotEmpty) return out;

  final guards = found.map((k) {
    final p = k.split(',');
    return [int.parse(p[0]), int.parse(p[1])];
  }).toList();
  final computed = <String>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (!has(r, c)) continue;
      if (cycleKeys.contains('$r,$c') || found.contains('$r,$c')) continue;
      if (guards.every((g) => sees(r, c, g[0], g[1]))) {
        computed.add('$r,$c,$digit');
      }
    }
  }
  if (computed.isEmpty) {
    out.add('没有任何位置同时看得见全部守卫，这个圈在这个盘面上删不出东西');
  }
  out.addAll(_sameElims(s.conclusionFalse, computed, '死环'));
  out.addAll(_beyondSinglesViolations(puzzle, computed, '死环'));
  return out;
}

/// 一个房屋里 [cells] 之外的空格上、属于 [digits] 的候选。
///
/// 数组一旦锁住，这些就是它删得到的东西。
Set<String> _lockedOutOfHouse(
  SudokuBoard board,
  int house,
  Set<String> cellKeys,
  Set<int> digits,
) {
  final out = <String>{};
  for (final cell in houseCells(house)) {
    final r = cell[0], c = cell[1];
    if (board.get(r, c) != 0 || cellKeys.contains('$r,$c')) continue;
    for (final d in board.getCandidates(r, c)) {
      if (digits.contains(d)) out.add('$r,$c,$d');
    }
  }
  return out;
}

/// 毛刺数组：N 格锁 N+1 个数字，多出来的那一个候选只落在一格上。
///
/// 结论不是「数组直接删完」，而是两条出路取交集：
/// * 毛刺为假 → 剩下的 N 个数字被 N 格锁死，房屋里别处的这些数字都能删；
/// * 毛刺为真 → 那一格填掉毛刺，顺着唯余摒除往下推。
///
/// 两种情况都删掉的候选就是这一页的收获，也正是「把毛刺当推理节点」的意思——
/// 只画一张 ALS 的图、不交代这两种情况各推出什么，是说不出结论的。
List<String> burredSubsetViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final burr = s.burr;
  if (burr == null) {
    out.add('毛刺数组没有声明那枚毛刺候选');
    return out;
  }
  if (s.lockHouses.length != 1) {
    out.add('毛刺数组要声明它所在的那一个房屋，实际声明了 ${s.lockHouses.length} 个');
    return out;
  }
  final house = s.lockHouses.single;
  if (house < 0 || house > 26) {
    out.add('房屋编号 $house 不合法');
    return out;
  }
  final n = s.cells.length;
  if (n < 2) {
    out.add('毛刺数组至少两格，声明了 $n 格');
    return out;
  }
  final union = <int>{};
  for (final c in s.cells) {
    if (board.get(c.row, c.col) != 0) {
      out.add('${c.label} 是已知数，不能算进数组');
      continue;
    }
    if (!houseCells(house).any((x) => x[0] == c.row && x[1] == c.col)) {
      out.add('${c.label} 不在 ${houseName(house)} 里');
    }
    final cands = board.getCandidates(c.row, c.col);
    if (cands.length < 2) {
      out.add('${c.label} 只剩 ${cands.length} 个候选，是唯余法，不该当结构格');
    }
    union.addAll(cands);
  }
  if (out.isNotEmpty) return out;
  if (union.length != n + 1) {
    out.add('$n 格的候选并集是 $union（${union.length} 个），'
        '待定数组要求恰好 ${n + 1} 个');
    return out;
  }
  if (!union.contains(burr.num)) {
    out.add('毛刺 ${_candLabel(burr)} 的数字不在数组的并集 $union 里');
    return out;
  }
  final owners = s.cells
      .where((c) => board.getCandidates(c.row, c.col).contains(burr.num))
      .toList();
  if (owners.length != 1) {
    out.add('数字 ${burr.num} 在数组里出现在 ${owners.map((c) => c.label).toList()}，'
        '毛刺必须只落在一格上');
    return out;
  }
  final owner = owners.single;
  if (owner.row != burr.row || owner.col != burr.col) {
    out.add('数字 ${burr.num} 落在 ${owner.label} 上，'
        '声明的毛刺却写在 r${burr.row + 1}c${burr.col + 1}');
    return out;
  }
  final ownerCands = board.getCandidates(owner.row, owner.col);
  if (ownerCands.length < 3) {
    out.add('毛刺格 ${owner.label} 只剩 $ownerCands，'
        '「有毛刺还是没毛刺」在这一格上就是个双值格，谈不上毛刺数组');
  }
  final base = union.where((d) => d != burr.num).toSet();
  if (!setEquals(base, s.baseDigits)) {
    out.add('去掉毛刺后锁住的是 $base，声明的底数是 ${s.baseDigits}');
  }
  // 退化检查：把毛刺格拿掉，其余格子不能已经自己锁住自己的数字，
  // 否则那是一个现成的显性数组，毛刺根本没参与推理。
  final rest = s.cells.where((c) => c != owner).toList();
  final restUnion = <int>{};
  for (final c in rest) {
    restUnion.addAll(board.getCandidates(c.row, c.col));
  }
  if (restUnion.length <= rest.length) {
    out.add('去掉毛刺格 ${owner.label} 之后，${rest.map((c) => c.label).toList()} '
        '已经锁住 $restUnion，这是个现成的显性数组，不必绕毛刺');
  }
  if (out.isNotEmpty) return out;

  final cellKeys = {for (final c in s.cells) '${c.row},${c.col}'};
  final lock = _lockedOutOfHouse(board, house, cellKeys, base);
  if (lock.isEmpty) {
    out.add('${houseName(house)} 里数组之外没有底数候选，「毛刺为假」这一种情况删不出东西');
    return out;
  }
  final budget = s.replayBudget;
  if (budget == null) {
    out.add('毛刺为真那一种情况要声明只许往下填几格（replayBudget）');
    return out;
  }
  final probe = LogicGrid.fromBoard(puzzle);
  probe.budget = budget;
  probe.assign(burr.row * 9 + burr.col, burr.num, '假设');
  if (probe.broken) {
    out.add('毛刺 ${_candLabel(burr)} 为真这一种情况当场矛盾，那它直接就能删，'
        '不必按毛刺数组讲');
    return out;
  }
  final both = {
    for (final k in lock)
      if (!probe.has(_keyCell(k), _keyDigit(k))) k
  };
  if (both.isEmpty) {
    out.add('两种情况的交集是空的：毛刺为真那一种情况（往下填 $budget 格）'
        '一个都没删到，这一页得不出结论');
  }
  out.addAll(_sameElims(s.conclusionFalse, both, '毛刺数组'));
  out.addAll(_beyondSinglesViolations(puzzle, both, '毛刺数组'));
  return out;
}

int _keyCell(String key) {
  final p = key.split(',');
  return int.parse(p[0]) * 9 + int.parse(p[1]);
}

int _keyDigit(String key) => int.parse(key.split(',')[2]);

/// rank 0 集合（DDS / MSLS）共用的那套核对。
///
/// 道理：每个结构格都要填一个数，而它填的那个数必须落在某条声明的链接上；
/// 两个不同的格子不可能用同一条链接（同房屋同数字只能有一个）。
/// 所以格子到链接是个单射，链接条数又和格数相等，于是这是个双射——
/// 每条链接都被用掉一次。链接 (d, h) 被用掉，就意味着 d 在 h 里落在结构格上，
/// 那么 h 里结构之外的 d 统统可以删。
///
/// 判定按这条道理逐项落实：
/// 1. 每个结构格的每个候选都被恰好一条链接盖住（漏盖单射就断了，重盖要另说自噬）；
/// 2. 每条链接声明的房屋确实盖住了结构里带那个数字的全部格子；
/// 3. 链接条数 = 格数；
/// 4. 不是换个说法的显性数组（没有单个房屋装得下全部结构格），
///    也不是换个说法的隐性数组（链接不能全挤在一个房屋里）；
/// 5. 删除恰好是各条链接房屋里结构之外的同名候选。
List<String> rankZeroViolations(
  String puzzle,
  TeachingStructure s, {
  required String tag,
}) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final links = s.sectorLinks;
  if (links.isEmpty) {
    out.add('$tag 一条链接都没声明');
    return out;
  }
  if (links.map((l) => l.digit).toSet().length != links.length) {
    out.add('$tag 的链接里同一个数字写了两条，应当把房屋合并进同一条');
  }
  for (final l in links) {
    if (l.houses.isEmpty) {
      out.add('$tag 里数字 ${l.digit} 的链接没有房屋');
    }
    if (l.houses.toSet().length != l.houses.length) {
      out.add(
          '$tag 里数字 ${l.digit} 的链接有重复房屋：${l.houses.map(houseName).toList()}');
    }
    for (final h in l.houses) {
      if (h < 0 || h > 26) out.add('$tag 的房屋编号 $h 不合法');
    }
  }
  final cellKeys = <String>{};
  for (final c in s.cells) {
    if (board.get(c.row, c.col) != 0) {
      out.add('${c.label} 是已知数，不能算进结构');
      continue;
    }
    if (board.getCandidates(c.row, c.col).length < 2) {
      out.add('${c.label} 只剩一个候选，是唯余法，不该当结构格');
    }
    cellKeys.add('${c.row},${c.col}');
  }
  if (out.isNotEmpty) return out;
  if (s.cells.length < 3) {
    out.add('$tag 至少三格，声明了 ${s.cells.length} 格');
    return out;
  }

  final linkCount = links.fold<int>(0, (a, l) => a + l.houses.length);
  if (linkCount != s.cells.length) {
    out.add('$tag 有 ${s.cells.length} 格、$linkCount 条链接，rank 0 要求两者相等');
  }
  bool inHouse(int h, CellRef c) =>
      houseCells(h).any((x) => x[0] == c.row && x[1] == c.col);
  final byDigit = <int, List<CellRef>>{};
  for (final c in s.cells) {
    for (final d in board.getCandidates(c.row, c.col)) {
      byDigit.putIfAbsent(d, () => <CellRef>[]).add(c);
    }
  }
  for (final l in links) {
    final owners = byDigit[l.digit] ?? const <CellRef>[];
    if (owners.isEmpty) {
      out.add('$tag 声明了数字 ${l.digit} 的链接，可是结构格上没有这个候选');
      continue;
    }
    for (final o in owners) {
      if (!l.houses.any((h) => inHouse(h, o))) {
        out.add('$tag 里 ${l.digit}${o.label} 没被声明的 '
            '${l.houses.map(houseName).toList()} 盖住，这条链接不成立');
      }
    }
  }
  final declaredDigits = {for (final l in links) l.digit};
  for (final entry in byDigit.entries) {
    if (!declaredDigits.contains(entry.key)) {
      out.add('$tag 的结构格上有候选 ${entry.key}'
          '（${entry.value.map((c) => c.label).join(",")}），却没有对应的链接，'
          '那一格可以跳出结构，rank 0 的计数就断了');
    }
  }
  for (final c in s.cells) {
    for (final d in board.getCandidates(c.row, c.col)) {
      final link = links.where((l) => l.digit == d).toList();
      if (link.isEmpty) continue;
      final hit = link.single.houses.where((h) => inHouse(h, c)).length;
      if (hit > 1) {
        out.add(
            '$tag 里 $d${c.label} 同时压住 ${link.single.houses.map(houseName).toList()} '
            '两条链接，这是自噬，本页没有交代');
      }
    }
  }
  if (out.isNotEmpty) return out;

  final all = List<int>.generate(27, (h) => h);
  final oneHouse =
      all.where((h) => s.cells.every((c) => inHouse(h, c))).toList();
  if (oneHouse.isNotEmpty) {
    out.add('$tag 的全部结构格都在 ${oneHouse.map(houseName).toList()} 里，'
        '这是换个说法的显性数组');
  }
  final sectors = {for (final l in links) ...l.houses};
  if (sectors.length < 3) {
    out.add('$tag 只用到 ${sectors.map(houseName).toList()} '
        '这 ${sectors.length} 个区域，够不上「多区域」，'
        '一两个区域的情形已经有显性/隐性数组和 Sue de Coq 讲过了');
  }

  final computed = <String>{};
  for (final l in links) {
    for (final h in l.houses) {
      computed.addAll(_lockedOutOfHouse(board, h, cellKeys, {l.digit}));
    }
  }
  if (computed.isEmpty) {
    out.add('$tag 在这个盘面上删不出任何候选');
  }
  out.addAll(_sameElims(s.conclusionFalse, computed, tag));
  out.addAll(_beyondSinglesViolations(puzzle, computed, tag));
  return out;
}

/// 分布式互斥数组（DDS）比一般 rank 0 多两条要求。
///
/// 一是每条链接只占一条房屋——于是「N 格锁 N 个数字」，这是 DDS 的招牌；
/// 二是那些房屋换不成两条：只要存在两个房屋能把每个数字的结构格都装下，
/// 这个图形骨子里就是 Sue de Coq（宫线交叉那一档），不该按「分布到三个以上区域」讲。
List<String> ddsViolations(String puzzle, TeachingStructure s) {
  final out = rankZeroViolations(puzzle, s, tag: '分布式互斥数组');
  if (out.isNotEmpty) return out;
  final board = SudokuBoard.fromString(puzzle);
  for (final l in s.sectorLinks) {
    if (l.houses.length != 1) {
      out.add('数字 ${l.digit} 占了 ${l.houses.map(houseName).toList()} 两条房屋，'
          'DDS 要求每个数字各占一条——占两条的是 MSLS');
    }
  }
  final digits = {for (final l in s.sectorLinks) l.digit};
  if (digits.length != s.cells.length) {
    out.add('${s.cells.length} 格锁了 ${digits.length} 个数字，DDS 要求格数等于数字个数');
  }
  final want = s.lockedDigitCount;
  if (want != null && want != digits.length) {
    out.add('声明锁住 $want 个数字，实际锁住 ${digits.length} 个');
  }
  bool inHouse(int h, CellRef c) =>
      houseCells(h).any((x) => x[0] == c.row && x[1] == c.col);
  final byDigit = <int, List<CellRef>>{};
  for (final c in s.cells) {
    for (final d in board.getCandidates(c.row, c.col)) {
      byDigit.putIfAbsent(d, () => <CellRef>[]).add(c);
    }
  }
  for (final entry in byDigit.entries) {
    if (entry.value.length < 2) {
      out.add('数字 ${entry.key} 在结构里只落在 ${entry.value.single.label} 上，'
          '那一格直接就被这个数字占了，是换个说法的摒除法');
    }
  }
  final all = List<int>.generate(27, (h) => h);
  for (int i = 0; i < all.length; i++) {
    for (int j = i + 1; j < all.length; j++) {
      final pair = [all[i], all[j]];
      final fits = byDigit.values.every(
        (cs) => pair.any((h) => cs.every((c) => inHouse(h, c))),
      );
      if (fits) {
        out.add('${pair.map(houseName).toList()} 这两个房屋就能装下每个数字的结构格，'
            '这不是分布到三个以上区域的 DDS，而是 Sue de Coq 那一档');
        return out;
      }
    }
  }
  return out;
}

/// 多区域锁定集（MSLS）就是 rank 0 的一般形。
///
/// 这一页要讲的正是「一个数字可以吃掉两条房屋」——那是 DDS 做不到的事。
/// 所以每条链接都只占一条房屋时要报出来：那种图形应该按 DDS 讲，
/// 拿它当 MSLS 的例子等于举了个反例。
List<String> mslsViolations(String puzzle, TeachingStructure s) {
  final out = rankZeroViolations(puzzle, s, tag: '多区域锁定集');
  if (out.isNotEmpty) return out;
  if (s.sectorLinks.every((l) => l.houses.length == 1)) {
    out.add('每个数字都只占一条房屋，这正好是 DDS，'
        '当不了「一个数字吃两条房屋」的 MSLS 例子');
  }
  final digits = {for (final l in s.sectorLinks) l.digit};
  if (digits.length >= s.cells.length) {
    out.add('${s.cells.length} 格对 ${digits.length} 个数字，'
        'MSLS 的看点是数字个数少于格数、靠多占房屋补平');
  }
  return out;
}

/// 弱待定数组（AHS，隐性一侧的待定数组）。
///
/// 一个房屋里 N 个数字的落点合起来恰好 N+1 格，于是分成两种情况：
/// * 那多出来的一格填的是这 N 个数字之一 → 它上面别的候选都得让位；
/// * 它填的不是 → N 个数字被锁进其余 N 格，那 N 格上别的候选都得让位。
///
/// 两种情况都删掉的候选就是这一页的收获。它和 ALS-W-Wing 不是一回事：
/// ALS 数的是「格子上的候选并集」（显性一侧），AHS 数的是
/// 「房屋里某几个数字的落点个数」（隐性一侧），所以这里还要核对
/// 同一批格子的候选并集大到撑不成 ALS——否则这张图两边都读得通，讲不清区别。
List<String> almostHiddenSetViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  if (s.lockHouses.length != 1) {
    out.add('弱待定数组要声明它所在的那一个房屋，实际声明了 ${s.lockHouses.length} 个');
    return out;
  }
  final house = s.lockHouses.single;
  if (house < 0 || house > 26) {
    out.add('房屋编号 $house 不合法');
    return out;
  }
  final digits = s.baseDigits;
  if (digits.length < 2) {
    out.add('弱待定数组至少盯两个数字，声明了 ${digits.length} 个');
    return out;
  }
  List<CellRef> spotsOf(int d) => [
        for (final cell in houseCells(house))
          if (board.get(cell[0], cell[1]) == 0 &&
              board.getCandidates(cell[0], cell[1]).contains(d))
            CellRef(cell[0], cell[1])
      ];
  for (final d in digits) {
    if (houseCells(house).any((c) => board.get(c[0], c[1]) == d)) {
      out.add('${houseName(house)} 里 $d 已经填好了，它不该算进弱待定数组');
    }
  }
  if (out.isNotEmpty) return out;
  final union = <String, CellRef>{};
  for (final d in digits) {
    for (final c in spotsOf(d)) {
      union['${c.row},${c.col}'] = c;
    }
  }
  final cells = union.values.toList()
    ..sort((a, b) => (a.row * 9 + a.col).compareTo(b.row * 9 + b.col));
  if (cells.length != digits.length + 1) {
    out.add('${houseName(house)} 里 $digits 的落点合起来是 '
        '${cells.map((c) => c.label).toList()}（${cells.length} 格），'
        '弱待定数组要求恰好 ${digits.length + 1} 格');
    return out;
  }
  final declared = {for (final c in s.cells) '${c.row},${c.col}'};
  final actual = union.keys.toSet();
  for (final miss in actual.difference(declared)) {
    out.add('落点 ${_prettyCell(miss)} 没有写进结构声明');
  }
  for (final ghost in declared.difference(actual)) {
    out.add('结构声明里的 ${_prettyCell(ghost)} 并不是这几个数字的落点');
  }
  if (out.isNotEmpty) return out;

  // 退化检查：任何真子集都不能已经是个隐性数组，否则那一步先做完更省事。
  final digitList = digits.toList()..sort();
  for (int k = 1; k < digitList.length; k++) {
    for (final sub in _combinations(digitList, k)) {
      final s2 = <String>{};
      for (final d in sub) {
        for (final c in spotsOf(d)) {
          s2.add('${c.row},${c.col}');
        }
      }
      if (s2.length <= k) {
        out.add('$sub 这 $k 个数字的落点只有 ${s2.length} 格，'
            '${houseName(house)} 里已经有一个现成的隐性数组，用不着弱待定数组');
      }
    }
  }
  // 隐性一侧：同一批格子的候选并集必须撑不成 ALS，否则这张图按显性数组也读得通。
  final candUnion = <int>{};
  for (final c in cells) {
    candUnion.addAll(board.getCandidates(c.row, c.col));
  }
  if (candUnion.length <= cells.length + 1) {
    out.add('这 ${cells.length} 格的候选并集是 $candUnion（${candUnion.length} 个），'
        '本身就是一朵显性待定数组，说不清「弱待定数组是隐性一侧」这件事');
  }
  final withExtras = cells
      .where((c) =>
          board.getCandidates(c.row, c.col).any((d) => !digits.contains(d)))
      .length;
  if (withExtras < 2) {
    out.add('只有 $withExtras 格带着非成员候选，这张图读成显性数组更直接');
  }
  final split = s.splitCell;
  if (split == null) {
    out.add('弱待定数组要声明从哪一格分成两种情况');
    return out;
  }
  if (!actual.contains('${split.row},${split.col}')) {
    out.add('声明的分支格 ${split.label} 不在落点里');
    return out;
  }
  final budget = s.replayBudget;
  if (budget == null) {
    out.add('两支复核要声明只许往下填几格（replayBudget）');
    return out;
  }
  if (out.isNotEmpty) return out;

  final z = split.row * 9 + split.col;
  // 情况一：分支格填的是成员数字，于是它上面的非成员候选都能去掉。
  final used = LogicGrid.fromBoard(puzzle);
  used.budget = budget;
  for (final d in board.getCandidates(split.row, split.col)) {
    if (!digits.contains(d)) used.eliminate(z, d);
  }
  // 情况二：分支格不是成员数字，成员就锁进其余各格，那几格的非成员候选都能去掉。
  final free = LogicGrid.fromBoard(puzzle);
  free.budget = budget;
  for (final d in digits) {
    free.eliminate(z, d);
  }
  for (final c in cells) {
    if (c.row == split.row && c.col == split.col) continue;
    for (final d in board.getCandidates(c.row, c.col)) {
      if (!digits.contains(d)) free.eliminate(c.row * 9 + c.col, d);
    }
  }
  if (used.broken) {
    out.add('「${split.label} 填成员数字」这一种情况当场矛盾，'
        '那它直接就能定下来，不必按弱待定数组讲');
  }
  if (free.broken) {
    out.add('「${split.label} 不填成员数字」这一种情况当场矛盾，'
        '那它直接就能定下来，不必按弱待定数组讲');
  }
  if (out.isNotEmpty) return out;
  final both = _bothBranchKills(puzzle, used, free);
  if (both.isEmpty) {
    out.add('两种情况的交集是空的，这一页得不出任何结论');
  }
  out.addAll(_sameElims(s.conclusionFalse, both, '弱待定数组'));
  out.addAll(_beyondSinglesViolations(puzzle, both, '弱待定数组'));
  return out;
}

List<List<T>> _combinations<T>(List<T> src, int k) {
  final out = <List<T>>[];
  final cur = <T>[];
  void rec(int start) {
    if (cur.length == k) {
      out.add(List<T>.from(cur));
      return;
    }
    for (int i = start; i < src.length; i++) {
      cur.add(src[i]);
      rec(i + 1);
      cur.removeLast();
    }
  }

  rec(0);
  return out;
}

/// 动态 AIC：假设之后才长出来的那条强链，必须真的是「之前没有、之后才有」。
///
/// 所以复核分三步：
/// 1. 静态时这条强链不能存在。这一刀砍两遍：教学页画出来的那张盘面上落点要多于
///    两个（而且个数要和声明的 [DynamicAssumption.staticSpots] 一致，读者数得出来），
///    把唯余摒除推到底也仍要多于两个（否则它只是基础招式顺手就有的东西）；
/// 2. 再从教学页那张盘面把假设填进去，只许往下推
///    [TeachingStructure.replayBudget] 格，确认落点正好收成声明的那两格；
/// 3. 最后从这个中间盘面分别假设那两格，两支都得出矛盾。
///
/// 三步都成立，假设的那个候选就是假的。少了第一步就分不清「动态长出来的强链」
/// 和「本来就在、只是没注意」；少了第三步就只是画了条链，没有结论。
List<String> dynamicChainViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final a = s.assumption;
  if (a == null) {
    out.add('动态 AIC 没有声明那一步假设');
    return out;
  }
  final budget = s.replayBudget;
  if (budget == null) {
    out.add('动态 AIC 要声明每一种情况只许往下填几格（replayBudget）');
    return out;
  }
  if (board.get(a.assume.row, a.assume.col) != 0 ||
      !board.getCandidates(a.assume.row, a.assume.col).contains(a.assume.num)) {
    out.add('被假设的 ${_candLabel(a.assume)} 在盘面上不存在');
    return out;
  }
  if (a.linkHouse < 0 || a.linkHouse > 26) {
    out.add('动态强链的房屋编号 ${a.linkHouse} 不合法');
    return out;
  }
  if (a.linkCells.length != 2) {
    out.add('动态强链要收成两格，声明了 ${a.linkCells.length} 格');
    return out;
  }
  for (final c in a.linkCells) {
    if (!houseCells(a.linkHouse).any((x) => x[0] == c.row && x[1] == c.col)) {
      out.add('${c.label} 不在 ${houseName(a.linkHouse)} 里');
    }
  }
  if (houseCells(a.linkHouse)
      .any((x) => board.get(x[0], x[1]) == a.linkDigit)) {
    out.add('${houseName(a.linkHouse)} 里 ${a.linkDigit} 已经填好了，'
        '谈不上强链');
  }
  if (out.isNotEmpty) return out;

  // 第一步之一：声明的落点数要和教学页画出来的那张盘面对得上，
  // 读者数得出来才谈得上「假设之前是几个落点」。
  final pageSpots = [
    for (final x in houseCells(a.linkHouse))
      if (board.get(x[0], x[1]) == 0 &&
          board.getCandidates(x[0], x[1]).contains(a.linkDigit))
        'r${x[0] + 1}c${x[1] + 1}'
  ];
  if (pageSpots.length != a.staticSpots) {
    out.add('声明假设之前 ${a.linkDigit} 在 ${houseName(a.linkHouse)} 里有 '
        '${a.staticSpots} 个落点，教学页这张盘面上实际是 '
        '${pageSpots.length} 个（$pageSpots）');
  }
  if (pageSpots.length <= 2) {
    out.add('${a.linkDigit} 在 ${houseName(a.linkHouse)} 里本来就只剩 '
        '$pageSpots，这条强链是静态的，不是假设之后长出来的');
    return out;
  }

  // 第一步之二：更硬的一刀——把唯余摒除推到底也不该冒出这条强链，
  // 否则它只是「基础招式顺手就有、只是没注意」，不是假设之后才长出来的。
  final closure = LogicGrid.fromPuzzle(puzzle);
  if (closure.broken) {
    out.add('盘面光靠唯余摒除就推出了矛盾');
    return out;
  }
  final closureSpots = [
    for (final x in houseCells(a.linkHouse))
      if (closure.has(x[0] * 9 + x[1], a.linkDigit)) 'r${x[0] + 1}c${x[1] + 1}'
  ];
  if (closureSpots.length <= 2) {
    out.add('把唯余摒除推到底，${a.linkDigit} 在 ${houseName(a.linkHouse)} 里就只剩 '
        '$closureSpots 了，这条强链靠基础招式就有，不必假设');
    return out;
  }

  // 第二步：填进假设，看强链是不是正好收成声明的那两格。
  final probe = LogicGrid.fromBoard(puzzle);
  probe.budget = budget;
  probe.assign(a.assume.row * 9 + a.assume.col, a.assume.num, '假设');
  if (probe.broken) {
    out.add('假设 ${_candLabel(a.assume)} 当场矛盾，用不上动态强链就能删掉它，'
        '拿它举例说不清动态 AIC');
    return out;
  }
  final now = [
    for (final x in houseCells(a.linkHouse))
      if (probe.value[x[0] * 9 + x[1]] == 0 &&
          probe.has(x[0] * 9 + x[1], a.linkDigit))
        'r${x[0] + 1}c${x[1] + 1}'
  ];
  final declaredLink = a.linkCells.map((c) => c.label).toList()..sort();
  final nowSorted = now.toList()..sort();
  if (nowSorted.length != 2 || !declaredLink.every(nowSorted.contains)) {
    out.add('假设 ${_candLabel(a.assume)} 并往下填 $budget 格之后，'
        '${a.linkDigit} 在 ${houseName(a.linkHouse)} 里落在 $nowSorted，'
        '不是声明的 $declaredLink');
    return out;
  }

  // 这条强链得真的在干活：整套论证一共写 budget（假设）+ budget（一支）格，
  // 如果光凭唯余摒除盲推这么多格就已经推翻了假设，那动态强链只是装饰。
  final blind = LogicGrid.fromBoard(puzzle);
  blind.budget = budget * 2;
  blind.assign(a.assume.row * 9 + a.assume.col, a.assume.num, '假设');
  if (blind.broken) {
    out.add('光靠唯余摒除盲推 ${budget * 2} 格就已经推翻了 ${_candLabel(a.assume)}，'
        '动态强链在这个例子里没有省下任何东西');
    return out;
  }

  // 第三步：这条动态强链的两端各成一支，两支都得矛盾。
  for (final c in a.linkCells) {
    final branch = probe.clone();
    branch.budget = probe.spent + budget;
    branch.assign(c.row * 9 + c.col, a.linkDigit, '沿强链假设');
    if (!branch.broken) {
      out.add('沿动态强链假设 ${a.linkDigit}${c.label} 这一种情况往下填 $budget 格'
          '并没有矛盾，收不了口');
    }
  }
  if (out.isNotEmpty) return out;

  out.addAll(_sameElims(
    s.conclusionFalse,
    {'${a.assume.row},${a.assume.col},${a.assume.num}'},
    '动态 AIC',
  ));
  out.addAll(_beyondSinglesViolations(
    puzzle,
    {'${a.assume.row},${a.assume.col},${a.assume.num}'},
    '动态 AIC',
  ));
  return out;
}

/// 飞鱼导弹（Junior Exocet）的全套几何与结论。
///
/// 结论的道理：设基格里真填的两个数是 A、B。三条交叉线各自要放一个 A，
/// 一共三个；这三个既不能落在基格看得见的逃逸格上，也不能落在伴随格
/// （按定义一个基格数字都不带），所以只能落在目标格或 S 格里。
/// S 格上的 A 全被两条覆盖线盖住，两条线最多放下两个 A，
/// 于是至少有一个 A 落在目标格上；B 同理，而两个目标格互不相同，
/// 只好一个装 A、一个装 B。所以目标格上不属于基格数字集的候选统统可以删。
List<String> exocetViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final e = s.exocet;
  if (e == null) {
    out.add('飞鱼导弹没有声明它的部件');
    return out;
  }
  if (e.baseCells.length != 2) {
    out.add('飞鱼导弹要两个基格，声明了 ${e.baseCells.length} 个');
    return out;
  }
  if (e.targets.length != 2 || e.companions.length != 2) {
    out.add('要两个目标格和两个伴随格，声明了 ${e.targets.length} 与 '
        '${e.companions.length} 个');
    return out;
  }
  if (e.mirrors.length != 2 || e.mirrors.any((m) => m.length != 2)) {
    out.add('每个目标格配两枚镜像格，声明的是 ${e.mirrors.map((m) => m.length).toList()}');
    return out;
  }
  final b1 = e.baseCells[0], b2 = e.baseCells[1];
  for (final c in e.baseCells) {
    if (board.get(c.row, c.col) != 0) {
      out.add('基格 ${c.label} 是已知数');
    }
  }
  if (out.isNotEmpty) return out;
  final horizontal = b1.row == b2.row;
  final vertical = b1.col == b2.col;
  if (!horizontal && !vertical) {
    out.add('两个基格 ${b1.label}、${b2.label} 既不同行也不同列');
    return out;
  }
  if (b1.box != b2.box) {
    out.add('两个基格不同宫，飞鱼导弹要求它们同宫同线');
    return out;
  }
  // 统一按横带来读；竖带把行列互换即可，判定完全对称。
  int line(CellRef c) => horizontal ? c.row : c.col;
  int cross(CellRef c) => horizontal ? c.col : c.row;
  final baseLine = line(b1);
  final band = baseLine ~/ 3;
  final bandLines = [band * 3, band * 3 + 1, band * 3 + 2];
  final otherLines = bandLines.where((x) => x != baseLine).toList();

  final baseDigits = <int>{
    ...board.getCandidates(b1.row, b1.col),
    ...board.getCandidates(b2.row, b2.col),
  };
  if (!setEquals(baseDigits, s.baseDigits)) {
    out.add('基格候选并集是 $baseDigits，声明的基格数字是 ${s.baseDigits}，两者应一致');
  }
  if (baseDigits.length < 3 || baseDigits.length > 4) {
    out.add('基格数字应为 3 到 4 个，实际 ${baseDigits.length} 个：$baseDigits');
  }
  bool holdsBase(CellRef c) {
    final v = board.get(c.row, c.col);
    return v == 0
        ? board.getCandidates(c.row, c.col).any(baseDigits.contains)
        : baseDigits.contains(v);
  }

  final baseCrossBlock = cross(b1) ~/ 3;
  final usedCross = {cross(b1), cross(b2)};
  final freeCross = [for (int k = 0; k < 3; k++) baseCrossBlock * 3 + k]
      .where((x) => !usedCross.contains(x))
      .toList();
  if (freeCross.length != 1) {
    out.add('基格宫里应恰好剩一条交叉线没被基格占住，实际剩 ${freeCross.length} 条');
    return out;
  }
  final crossOfTarget = <int>[];
  for (int i = 0; i < 2; i++) {
    final t = e.targets[i], c = e.companions[i];
    if (board.get(t.row, t.col) != 0) {
      out.add('目标格 ${t.label} 是已知数');
      continue;
    }
    if (line(t) == baseLine) {
      out.add('目标格 ${t.label} 和基格同线，它看得见基格，当不了目标格');
    }
    if (cross(t) ~/ 3 == baseCrossBlock) {
      out.add('目标格 ${t.label} 落在基格所在的那一宫里');
    }
    if (line(t) ~/ 3 != band) {
      out.add('目标格 ${t.label} 不在基格那条带里');
    }
    if (cross(c) != cross(t)) {
      out.add('伴随格 ${c.label} 和目标格 ${t.label} 不在同一条交叉线上，'
          '配不成一对对象格');
    }
    if (line(c) == baseLine || line(c) == line(t) || line(c) ~/ 3 != band) {
      out.add('伴随格 ${c.label} 应当是同一条交叉线上另一条非基线格');
    }
    if (holdsBase(c)) {
      out.add('伴随格 ${c.label} 带着基格数字，'
          '这对对象格就可能装下两个基格数字，飞鱼导弹不成立');
    }
    if (!holdsBase(t)) {
      out.add('目标格 ${t.label} 一个基格数字都不带，它不是目标格');
    }
    crossOfTarget.add(cross(t));
  }
  if (out.isNotEmpty) return out;
  if (crossOfTarget.toSet().length != 2) {
    out.add('两个目标格落在同一条交叉线上');
    return out;
  }
  if ({crossOfTarget[0] ~/ 3, crossOfTarget[1] ~/ 3}.length != 2) {
    out.add('两个目标格落在同一个宫里，应当分处带上另外两个宫');
    return out;
  }

  final wantCross = {freeCross.single, ...crossOfTarget};
  final gotCross = e.crossLines.map((h) => horizontal ? h - 9 : h).toSet();
  for (final h in e.crossLines) {
    final ok = horizontal ? (h >= 9 && h < 18) : (h >= 0 && h < 9);
    if (!ok) {
      out.add('交叉线 ${houseName(h)} 的方向和基格的摆法不一致');
    }
  }
  if (!setEquals(gotCross, wantCross)) {
    out.add('交叉线应当是「两个目标格所在的线，加基格宫里空着的那条」'
        '${wantCross.toList()..sort()}，声明的是 ${gotCross.toList()..sort()}');
    return out;
  }

  // 镜像格：贴着对面那个目标格——在对面目标格的宫里、另一条非基线上、
  // 避开对面目标格自己那条交叉线。
  for (int i = 0; i < 2; i++) {
    final self = e.targets[i], other = e.targets[1 - i];
    final mirrorLine = otherLines.firstWhere((x) => x != line(self));
    final block = cross(other) ~/ 3;
    final want = <String>{};
    for (int k = 0; k < 3; k++) {
      final x = block * 3 + k;
      if (x == cross(other)) continue;
      want.add(horizontal ? '$mirrorLine,$x' : '$x,$mirrorLine');
    }
    final got = {for (final m in e.mirrors[i]) '${m.row},${m.col}'};
    if (!_sameStrings(got, want)) {
      out.add('${self.label} 的镜像格应当是 ${want.map(_prettyCell).toList()}，'
          '声明的是 ${got.map(_prettyCell).toList()}');
    }
  }

  // 覆盖线：每个基格数字在 S 格上的落点（含已知数）都要被不超过两条房屋盖住。
  final sCells = <List<int>>[];
  for (final x in wantCross) {
    for (int k = 0; k < 9; k++) {
      if (k ~/ 3 == band) continue;
      sCells.add(horizontal ? [k, x] : [x, k]);
    }
  }
  final coverOf = {for (final l in e.coverLines) l.digit: l.houses};
  for (final d in baseDigits) {
    final spots = [
      for (final c in sCells)
        if (board.get(c[0], c[1]) == d ||
            (board.get(c[0], c[1]) == 0 &&
                board.getCandidates(c[0], c[1]).contains(d)))
          c
    ];
    final houses = coverOf[d];
    if (houses == null) {
      out.add('基格数字 $d 没有声明覆盖线');
      continue;
    }
    if (houses.length > 2) {
      out.add('基格数字 $d 声明了 ${houses.length} 条覆盖线，最多两条');
    }
    for (final c in spots) {
      if (!houses
          .any((h) => houseCells(h).any((x) => x[0] == c[0] && x[1] == c[1]))) {
        out.add('S 格 r${c[0] + 1}c${c[1] + 1} 上的 $d 没被 '
            '${houses.map(houseName).toList()} 盖住，'
            '「两个目标格落到不同基格数字上」的依据不成立');
      }
    }
  }
  for (final l in e.coverLines) {
    if (!baseDigits.contains(l.digit)) {
      out.add('覆盖线声明里的 ${l.digit} 不是基格数字');
    }
  }
  if (out.isNotEmpty) return out;

  final computed = <String>{};
  for (final t in e.targets) {
    for (final d in board.getCandidates(t.row, t.col)) {
      if (!baseDigits.contains(d)) computed.add('${t.row},${t.col},$d');
    }
  }
  if (computed.isEmpty) {
    out.add('两个目标格上没有非基格候选，这枚飞鱼导弹删不出东西');
  }
  out.addAll(_sameElims(e.eliminations, computed, '飞鱼导弹'));
  out.addAll(_sameElims(s.conclusionFalse, computed, '飞鱼导弹的页面结论'));
  out.addAll(_beyondSinglesViolations(puzzle, computed, '飞鱼导弹'));
  return out;
}

/// 只会「唯余 + 摒除」两招的候选盘，用来独立复核一支假设能推出什么。
///
/// 只给它这两招是故意的：强制类技巧的每一种情况都只沿唯一后果往下推，
/// 既不能顺手用上别的技巧，也不能借盘面的唯一解反推结论。
class LogicGrid {
  final List<Set<int>> cand =
      List.generate(81, (_) => {1, 2, 3, 4, 5, 6, 7, 8, 9});
  final List<int> value = List<int>.filled(81, 0);
  bool broken = false;

  /// 还许往下填几格。教学页要写得出这一种情况，所以推理长度必须夹得住：
  /// 不设上限的话唯余摒除常常顺手把整盘解完，那时「这一种情况删掉了某个候选」
  /// 就只是在复述答案，说明不了结构本身的力量。
  int budget = 1 << 30;
  int spent = 0;

  /// 填过的格子，按顺序记下来，好让教学正文照抄这条路径。
  /// 每一项形如 `r2c1=9(唯余)` 或 `r2c2=8(c2 摒除)`，括号里是这一步的依据。
  final List<String> trace = [];

  LogicGrid.fromPuzzle(String puzzle) {
    for (int i = 0; i < 81; i++) {
      final ch = puzzle[i];
      final d = ch == '.' ? 0 : int.parse(ch);
      if (d != 0) assign(i, d);
    }
    // 已知数不算进预算，从这里开始数假设推出来的那几步。
    spent = 0;
    trace.clear();
  }

  /// 从教学页真正画出来的那张盘面起步：候选只做了同房屋排除，没有替读者推唯余摒除。
  ///
  /// [LogicGrid.fromPuzzle] 一建好就把唯余摒除推到了底，那张盘面和页面上画的
  /// 不是同一张——结构画在页面这张上，假设却从推完的那张往下走，读者跟不上，
  /// 「这个数字在这个房屋里只有两个位置」之类的静态断言也会对不上号。
  /// 凡是要把某个假设往下推、再拿结果和页面对照的核对，都得用这个构造函数。
  factory LogicGrid.fromBoard(String puzzle) {
    final board = SudokuBoard.fromString(puzzle);
    final out = LogicGrid._();
    for (int i = 0; i < 81; i++) {
      final r = i ~/ 9, c = i % 9;
      final v = board.get(r, c);
      if (v != 0) {
        out.value[i] = v;
        out.cand[i] = {v};
      } else {
        out.cand[i] = board.getCandidates(r, c).toSet();
      }
    }
    return out;
  }

  LogicGrid._();

  /// 复制当前状态，好让两支假设从同一个中间盘面各走各的。
  LogicGrid clone() {
    final out = LogicGrid._();
    for (int i = 0; i < 81; i++) {
      out.cand[i] = Set<int>.from(cand[i]);
      out.value[i] = value[i];
    }
    out.broken = broken;
    out.budget = budget;
    out.spent = spent;
    out.trace.addAll(trace);
    return out;
  }

  bool has(int cell, int d) => cand[cell].contains(d);

  /// 不加任何假设，光靠唯余加摒除往下推，直到推不动或者用光预算。
  ///
  /// [LogicGrid.fromBoard] 建好的盘面是「页面上画的那张」——候选只做过同房屋排除，
  /// 一步唯余摒除都没替读者走。想知道某个结论是不是不用假设、光靠基础招式就能拿到，
  /// 就从那张盘面调这个方法：它是各种「假设到底有没有出力」的对照组。
  void propagate() {
    var moved = true;
    while (moved && !broken && spent < budget) {
      moved = false;
      for (int cell = 0; cell < 81 && !broken && spent < budget; cell++) {
        if (value[cell] != 0 || cand[cell].length != 1) continue;
        assign(cell, cand[cell].first, '唯余');
        moved = true;
      }
      for (int h = 0; h < 27 && !broken && spent < budget; h++) {
        for (int d = 1; d <= 9 && !broken && spent < budget; d++) {
          final places = [
            for (final x in houseCells(h))
              if (cand[x[0] * 9 + x[1]].contains(d)) x[0] * 9 + x[1]
          ];
          if (places.length == 1 && value[places.first] == 0) {
            assign(places.first, d, '${houseName(h)} 摒除');
            moved = true;
          }
        }
      }
    }
  }

  static List<int> _peers(int cell) {
    final r = cell ~/ 9, c = cell % 9;
    final out = <int>{};
    for (int k = 0; k < 9; k++) {
      out.add(r * 9 + k);
      out.add(k * 9 + c);
    }
    final br = (r ~/ 3) * 3, bc = (c ~/ 3) * 3;
    for (int i = 0; i < 3; i++) {
      for (int j = 0; j < 3; j++) {
        out.add((br + i) * 9 + bc + j);
      }
    }
    out.remove(cell);
    return out.toList();
  }

  void assign(int cell, int d, [String why = '给定']) {
    if (broken || value[cell] == d) return;
    if (!cand[cell].contains(d)) {
      broken = true;
      return;
    }
    if (spent >= budget) return;
    spent++;
    trace.add('r${cell ~/ 9 + 1}c${cell % 9 + 1}=$d($why)');
    value[cell] = d;
    final others = cand[cell].where((x) => x != d).toList();
    cand[cell] = {d};
    for (final o in others) {
      _drop(cell, o);
      if (broken) return;
    }
    for (final p in _peers(cell)) {
      eliminate(p, d);
      if (broken) return;
    }
  }

  void eliminate(int cell, int d) {
    if (broken || !cand[cell].contains(d)) return;
    if (value[cell] == d) {
      broken = true;
      return;
    }
    cand[cell].remove(d);
    _drop(cell, d);
  }

  /// 候选 [d] 刚从 [cell] 上消失之后要跟着走的两招。
  void _drop(int cell, int d) {
    if (cand[cell].isEmpty) {
      broken = true;
      return;
    }
    if (cand[cell].length == 1 && value[cell] == 0) {
      assign(cell, cand[cell].first, '唯余');
      if (broken) return;
    }
    for (final h in housesOf(cell ~/ 9, cell % 9)) {
      final places = [
        for (final x in houseCells(h))
          if (cand[x[0] * 9 + x[1]].contains(d)) x[0] * 9 + x[1]
      ];
      if (places.isEmpty) {
        broken = true;
        return;
      }
      if (places.length == 1 && value[places.first] == 0) {
        assign(places.first, d, '${houseName(h)} 摒除');
        if (broken) return;
      }
    }
  }
}

/// 结构格上带额外候选的格子 → 那一格的额外候选。
Map<String, Set<int>> _extrasByCell(TeachingStructure s) {
  final out = <String, Set<int>>{};
  for (final e in s.extras) {
    out.putIfAbsent('${e.row},${e.col}', () => <int>{}).add(e.num);
  }
  return out;
}

CellRef _cellOf(String key) {
  final p = key.split(',');
  return CellRef(int.parse(p[0]), int.parse(p[1]));
}

/// 除了 [keys] 里那几格，其余结构格必须只剩底数。
List<String> _restPureBase(
  SudokuBoard board,
  TeachingStructure s,
  Set<String> keys,
) {
  final out = <String>[];
  for (final c in s.cells) {
    if (keys.contains('${c.row},${c.col}')) continue;
    final cands = board.getCandidates(c.row, c.col);
    if (!setEquals(Set<int>.from(cands), s.baseDigits)) {
      out.add('${c.label} 上是 $cands，这一型要求除带额外候选的格子外都只剩底数');
    }
  }
  return out;
}

/// 声明的删除结论必须和算出来的那一组完全一致。
List<String> _sameElims(
  Iterable<CandidateRef> declared,
  Set<String> computed,
  String what,
) {
  final out = <String>[];
  final got = {for (final e in declared) '${e.row},${e.col},${e.num}'};
  String pretty(String k) {
    final p = k.split(',');
    return '${p[2]}r${int.parse(p[0]) + 1}c${int.parse(p[1]) + 1}';
  }

  for (final miss in computed.difference(got)) {
    out.add('$what 还能删 ${pretty(miss)}，结论声明漏了它');
  }
  for (final ghost in got.difference(computed)) {
    out.add('$what 声明要删 ${pretty(ghost)}，但按这一型的规则删不到它');
  }
  return out;
}

/// 例外格上「不是多余候选」的那两个候选，也就是这一格的底数。
///
/// 死盘家族没有全盘公用的底数：奇偶条件保证去掉多余候选之后每格恰好剩两个，
/// 那两个就是这一格的底数。[bugParityViolations] 已经把这件事查过，
/// 所以下面几档重算删除时可以直接用它。
Set<int> _graveBase(SudokuBoard board, CellRef cell, Set<int> extras) => {
      for (final d in board.getCandidates(cell.row, cell.col))
        if (!extras.contains(d)) d
    };

/// 死盘家族各档共用的前置条件：例外格的个数、每格多出几个数字，以及底数是不是两个。
///
/// 返回按坐标排好序的例外格；发现问题就写进 [out] 并返回空表，
/// 让调用方直接停手——例外格都没数清楚，重算删除只会得出更离谱的结论。
List<CellRef> _graveOwners(
  SudokuBoard board,
  TeachingStructure s,
  List<String> out, {
  required int minCells,
  int? maxCells,
  required bool oneExtraEach,
}) {
  final byCell = _extrasByCell(s);
  final owners = [for (final k in byCell.keys.toList()..sort()) _cellOf(k)];
  if (owners.length < minCells ||
      (maxCells != null && owners.length > maxCells)) {
    out.add(
        '这一档要求例外格${maxCells == minCells ? '恰好 $minCells' : '至少 $minCells'} 个，'
        '实际 ${owners.length} 个');
    return const [];
  }
  for (final c in owners) {
    final extras = byCell['${c.row},${c.col}']!;
    if (oneExtraEach && extras.length != 1) {
      out.add('${c.label} 多出了 $extras，这一档要求每个例外格只多出一个数字');
      return const [];
    }
    if (_graveBase(board, c, extras).length != 2) {
      out.add('${c.label} 去掉多余候选后不是两个候选，例外格数错了');
      return const [];
    }
  }
  return owners;
}

/// 死盘 Type 2 / +n 的删除：同时看得见全部例外格的位置上，那个数字站不住。
///
/// 道理：奇偶条件成立的盘面解数为偶数，题目却唯一解，所以多余候选不能同时为假；
/// 这一档的多余候选又都是同一个数字 c，于是 c 至少落在这些例外格之一。
/// 任何同时看得见全部例外格的位置填了 c，就把每个例外格的 c 都挡掉了，与上一句冲突。
Set<String> _graveSameDigitElims(
  SudokuBoard board,
  List<CellRef> owners,
  int digit,
) {
  final out = <String>{};
  for (int r = 0; r < 9; r++) {
    for (int c = 0; c < 9; c++) {
      if (board.get(r, c) != 0) continue;
      if (owners.any((o) => o.row == r && o.col == c)) continue;
      if (!board.getCandidates(r, c).contains(digit)) continue;
      if (owners.every((o) => sees(r, c, o.row, o.col))) {
        out.add('$r,$c,$digit');
      }
    }
  }
  return out;
}

/// 两个例外格共处的那条房屋，必须正是声明里写的那一条。
int? _graveSharedHouse(
  List<CellRef> owners,
  TeachingStructure s,
  List<String> out,
) {
  final a = owners[0], b = owners[1];
  final shared = housesOf(a.row, a.col)
      .where((h) => housesOf(b.row, b.col).contains(h))
      .toList();
  if (shared.isEmpty) {
    out.add('${a.label} 与 ${b.label} 不同行不同列不同宫，'
        '这一档要求两个例外格落在同一条房屋里');
    return null;
  }
  if (s.lockHouses.length != 1) {
    out.add('这一档要写明两个例外格共处的那一条房屋，实际声明了 ${s.lockHouses.length} 条');
    return null;
  }
  final h = s.lockHouses.single;
  if (!shared.contains(h)) {
    out.add('声明的房屋 ${houseName(h)} 并不同时容纳 ${a.label} 与 ${b.label}，'
        '它们共处的是 ${shared.map(houseName).toList()}');
    return null;
  }
  return h;
}

/// 带死盘节点往下推一支假设：唯余、摒除照走，另外多一条
/// 「多余候选不能同时为假」——只剩一个还活着时，那一个必须为真。
///
/// 返回是否推出了矛盾。这条节点规则和奇偶条件同源：去掉多余候选后的盘面解数为偶数，
/// 而题目唯一解，所以唯一解一定用到了其中至少一个。
bool _graveReplayBroken(LogicGrid g, List<CandidateRef> extras) {
  var nodeUsed = false;
  while (true) {
    g.propagate();
    if (g.broken) return true;
    final live = [
      for (final e in extras)
        if (g.has(e.row * 9 + e.col, e.num)) e
    ];
    if (live.isEmpty) return true;
    if (live.length == 1 && !nodeUsed) {
      nodeUsed = true;
      final e = live.single;
      g.assign(e.row * 9 + e.col, e.num, '死盘节点');
      if (g.broken) return true;
      continue;
    }
    return false;
  }
}

/// 死盘家族各档的推理条件，逐档拿盘面重算一遍。
///
/// 这几档共同的起点是同一条事实：把 [TeachingStructure.extras] 拿掉之后盘面满足
/// 完整的死盘奇偶条件（由 [bugParityViolations] 坐实），于是解数为偶数；
/// 题目保证唯一解，所以唯一解至少用到一个多余候选。下面每一档都只许从这句话出发，
/// 不许拿「答案里本来就不是它」充当依据——所以删除集合一律重算后逐条对齐，
/// 而不是拿唯一解去对答案。
List<String> graveClaimViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final byCell = _extrasByCell(s);

  switch (s.claim) {
    case TeachingClaim.graveType2:
    case TeachingClaim.gravePlusN:
      final plus = s.claim == TeachingClaim.gravePlusN;
      final owners = _graveOwners(
        board,
        s,
        out,
        minCells: plus ? 3 : 2,
        maxCells: plus ? null : 2,
        oneExtraEach: true,
      );
      if (owners.isEmpty) break;
      final digits = s.extras.map((e) => e.num).toSet();
      if (digits.length != 1) {
        out.add('这一档要求全部例外候选是同一个数字，实际是 $digits');
        break;
      }
      final computed = _graveSameDigitElims(board, owners, digits.single);
      if (computed.isEmpty) {
        out.add('没有位置同时看得见这 ${owners.length} 个例外格，'
            '这一档在这张盘面上删不出东西');
      }
      out.addAll(_sameElims(
        s.conclusionFalse,
        computed,
        plus ? '死盘 +n' : '死盘 Type 2',
      ));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('这一档给的是删除结论，不该声明填数');
      }
    case TeachingClaim.graveType4:
      final owners = _graveOwners(board, s, out,
          minCells: 2, maxCells: 2, oneExtraEach: true);
      if (owners.isEmpty) break;
      final a = owners[0], b = owners[1];
      final ea = byCell['${a.row},${a.col}']!.single;
      final eb = byCell['${b.row},${b.col}']!.single;
      if (ea == eb) {
        out.add('两个例外格多出的是同一个数字 $ea，那是 Type 2，不必绕锁定');
        break;
      }
      final house = _graveSharedHouse(owners, s, out);
      if (house == null) break;
      final lock = s.lockDigit;
      if (lock == null) {
        out.add('Type 4 要写明被锁在这条房屋里的那个共有底数');
        break;
      }
      final baseA = _graveBase(board, a, {ea});
      final baseB = _graveBase(board, b, {eb});
      if (!baseA.contains(lock) || !baseB.contains(lock)) {
        out.add('$lock 不是 ${a.label}（底数 $baseA）与 ${b.label}（底数 $baseB）'
            '共有的底数，撑不起 Type 4');
        break;
      }
      final spots = [
        for (final cell in houseCells(house))
          if (board.get(cell[0], cell[1]) == 0 &&
              board.getCandidates(cell[0], cell[1]).contains(lock))
            CellRef(cell[0], cell[1])
      ];
      if (spots.length != 2 || !spots.contains(a) || !spots.contains(b)) {
        out.add('${houseName(house)} 里 $lock 的落点是 '
            '${spots.map((c) => c.label).toList()}，'
            '不是恰好 ${a.label} 与 ${b.label} 两格，强链不成立');
        break;
      }
      // lock 落在两个例外格之一。落在 a 则 a 不填 ea，节点逼 b 填 eb；反之同理。
      // 于是 a 只剩 {lock, ea}、b 只剩 {lock, eb}，各自另一个底数可以删。
      //
      // 上面那条强链检查在满足奇偶条件的盘面上其实注定通过：奇偶条件说的就是
      // 每个房屋里每个未填数字恰好出现两次，而两格的共有底数在这条房屋里的两次
      // 只能落在它们自己身上。留着它是因为「奇偶条件」和「这一步的依据」是两件事，
      // 将来谁把 extras 或房屋改错了，这里要能自己站住，不靠上游兜。
      final computed = <String>{
        for (final d in board.getCandidates(a.row, a.col))
          if (d != lock && d != ea) '${a.row},${a.col},$d',
        for (final d in board.getCandidates(b.row, b.col))
          if (d != lock && d != eb) '${b.row},${b.col},$d',
      };
      out.addAll(_sameElims(s.conclusionFalse, computed, '死盘 Type 4'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('这一档给的是删除结论，不该声明填数');
      }
    case TeachingClaim.graveType3:
      final owners = _graveOwners(board, s, out,
          minCells: 2, maxCells: 2, oneExtraEach: true);
      if (owners.isEmpty) break;
      final a = owners[0], b = owners[1];
      final ea = byCell['${a.row},${a.col}']!.single;
      final eb = byCell['${b.row},${b.col}']!.single;
      if (ea == eb) {
        out.add('两个例外格多出的是同一个数字 $ea，那是 Type 2，不必并虚拟格');
        break;
      }
      final house = _graveSharedHouse(owners, s, out);
      if (house == null) break;
      final members = s.subsetCells;
      final digits = s.subsetDigits;
      if (members.isEmpty) {
        out.add('Type 3 要写明和虚拟格配成数组的那些格子');
        break;
      }
      if (digits.length != members.length + 1) {
        out.add('虚拟格加 ${members.length} 个成员格共 ${members.length + 1} 格，'
            '数组要求同样多的数字，实际声明了 ${digits.length} 个：$digits');
        break;
      }
      if (!digits.contains(ea) || !digits.contains(eb)) {
        out.add('虚拟格的候选是 {$ea, $eb}，必须都落在数组数字 $digits 里');
        break;
      }
      var badMember = false;
      for (final m in members) {
        if (m == a || m == b) {
          out.add('${m.label} 就是例外格本身，不能再当数组的成员格');
          badMember = true;
          continue;
        }
        if (!houseCells(house)
            .any((cell) => cell[0] == m.row && cell[1] == m.col)) {
          out.add('${m.label} 不在 ${houseName(house)} 上，进不了这个数组');
          badMember = true;
          continue;
        }
        if (board.get(m.row, m.col) != 0) {
          out.add('${m.label} 是已填格，当不了数组的成员格');
          badMember = true;
          continue;
        }
        final cands = board.getCandidates(m.row, m.col).toSet();
        if (!cands.every(digits.contains)) {
          out.add('${m.label} 上是 $cands，越出了数组数字 $digits，锁不住');
          badMember = true;
        }
      }
      if (badMember) break;
      // 虚拟格必占一个数组数字，成员格各占一个，共 digits.length 个数字被
      // 例外格与成员格用尽，所以这条房屋上其余格子的这些数字都可以删。
      final computed = <String>{};
      for (final cell in houseCells(house)) {
        final r = cell[0], c = cell[1];
        if (board.get(r, c) != 0) continue;
        if (r == a.row && c == a.col) continue;
        if (r == b.row && c == b.col) continue;
        if (members.any((m) => m.row == r && m.col == c)) continue;
        for (final d in board.getCandidates(r, c)) {
          if (digits.contains(d)) computed.add('$r,$c,$d');
        }
      }
      if (computed.isEmpty) {
        out.add('${houseName(house)} 上没有别的格子带这几个数字，这一档删不出东西');
      }
      out.addAll(_sameElims(s.conclusionFalse, computed, '死盘 Type 3'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('这一档给的是删除结论，不该声明填数');
      }
    case TeachingClaim.graveChainNode:
      final owners = _graveOwners(board, s, out,
          minCells: 2, maxCells: 2, oneExtraEach: true);
      if (owners.isEmpty) break;
      final a = owners[0], b = owners[1];
      final ea = byCell['${a.row},${a.col}']!.single;
      final eb = byCell['${b.row},${b.col}']!.single;
      // 直接型能用上就不该停在链节点上：同数字互见是 Type 2，
      // 同房屋则可能凑得出 Type 3 / 4。
      if (ea == eb && sees(a.row, a.col, b.row, b.col)) {
        out.add('两个例外候选是同一个数字又互相看得见，那是 Type 2，能直接删，'
            '不该绕成一条链');
        break;
      }
      if (housesOf(a.row, a.col)
          .any((h) => housesOf(b.row, b.col).contains(h))) {
        out.add('${a.label} 与 ${b.label} 同处一条房屋，'
            '该先看 Type 3 / 4 能不能直接删，再谈接链');
        break;
      }
      final budget = s.replayBudget;
      if (budget == null || budget <= 0) {
        out.add('待定死盘要声明 replayBudget：教学页写得出的那条链有多长，'
            '就只许推那么多步，不然「推出了矛盾」可能只是把整盘解完了');
        break;
      }
      if (s.conclusionTrue.isNotEmpty) {
        out.add('这一档给的是删除结论，不该声明填数');
      }
      if (s.conclusionFalse.isEmpty) {
        out.add('待定死盘这一页要么老实停在链节点上（改用 chainNode 档），'
            '要么给出靠这条链推出来的删除');
        break;
      }
      final elims = <String>{};
      for (final e in s.conclusionFalse) {
        elims.add('${e.row},${e.col},${e.num}');
        if (board.get(e.row, e.col) != 0) {
          out.add('${_candLabel(e)} 落在已填格上，谈不上删除');
          continue;
        }
        if (!board.getCandidates(e.row, e.col).contains(e.num)) {
          out.add('${_candLabel(e)} 在盘面上并不存在，谈不上删除');
          continue;
        }
        final g = LogicGrid.fromBoard(puzzle);
        g.budget = budget;
        g.assign(e.row * 9 + e.col, e.num, '假设');
        if (!_graveReplayBroken(g, s.extras)) {
          out.add('假设 ${_candLabel(e)} 为真，'
              '在 $budget 步之内配上死盘节点推不出矛盾，这条删除没有落地');
        }
      }
      out.addAll(_beyondSinglesViolations(puzzle, elims, '待定死盘'));
    // 其余档位不属于死盘家族，交给 [claimViolations] 各自的分支。
    case TeachingClaim.deadlyOnly:
    case TeachingClaim.type1:
    case TeachingClaim.type2:
    case TeachingClaim.type3:
    case TeachingClaim.type4:
    case TeachingClaim.hiddenRect:
    case TeachingClaim.qiuType1:
    case TeachingClaim.chainNode:
    case TeachingClaim.forcing:
    case TeachingClaim.elimination:
      out.add('双值死盘家族要用 grave 系列的结论档位，实际写的是 ${s.claim.name}');
  }
  return out;
}

/// 按结论档位核对推理条件。
List<String> claimViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  final byCell = _extrasByCell(s);
  final extraCells = byCell.keys.toList()..sort();

  switch (s.claim) {
    case TeachingClaim.deadlyOnly:
      // 只讲致命性本身，不下删除或填数结论；结论留空的检查在这里。
      if (s.conclusionTrue.isNotEmpty || s.conclusionFalse.isNotEmpty) {
        out.add('这一页只讲到「至少一个多余候选为真」，不该带填数或删除结论');
      }
      if (s.extras.length < 2) {
        out.add('只剩一个多余候选时就是 Type 1，该给出填数结论，不能停在致命性上');
      }
    case TeachingClaim.type1:
      if (s.extras.length != 1) {
        out.add('Type 1 要求整个结构只多出一个候选，实际有 ${s.extras.length} 个');
        break;
      }
      final e = s.extras.single;
      out.addAll(_restPureBase(board, s, {'${e.row},${e.col}'}));
      final want = {'${e.row},${e.col},${e.num}'};
      final got = {
        for (final t in s.conclusionTrue) '${t.row},${t.col},${t.num}'
      };
      if (got.length != want.length || !want.containsAll(got)) {
        out.add('Type 1 的结论应当就是「多出来的 ${e.num}r${e.row + 1}c${e.col + 1} '
            '必须为真」，实际声明了 $got');
      }
      if (s.conclusionFalse.isNotEmpty) {
        out.add('Type 1 给的是填数结论，不该同时声明删除');
      }
    case TeachingClaim.type2:
      final digits = s.extras.map((e) => e.num).toSet();
      if (digits.length != 1 || extraCells.length < 2) {
        out.add('Type 2 要求恰好两格以上多出同一个数字，'
            '实际多出的数字是 $digits，分布在 ${extraCells.length} 格上');
        break;
      }
      if (byCell.values.any((v) => v.length != 1)) {
        out.add('Type 2 的每个带额外候选的格子只能多出一个数字');
      }
      out.addAll(_restPureBase(board, s, byCell.keys.toSet()));
      final c = digits.single;
      final owners = extraCells.map(_cellOf).toList();
      final computed = <String>{};
      for (int r = 0; r < 9; r++) {
        for (int col = 0; col < 9; col++) {
          if (board.get(r, col) != 0) continue;
          if (owners.any((o) => o.row == r && o.col == col)) continue;
          if (!board.getCandidates(r, col).contains(c)) continue;
          if (owners.every((o) => sees(r, col, o.row, o.col))) {
            computed.add('$r,$col,$c');
          }
        }
      }
      if (computed.isEmpty) {
        out.add('没有任何位置同时看得见这几格，Type 2 在这个盘面上删不出东西');
      }
      out.addAll(_sameElims(s.conclusionFalse, computed, 'Type 2'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('Type 2 给的是删除结论，不该声明填数');
      }
    case TeachingClaim.qiuType1:
      if (extraCells.length != 1) {
        out.add('淑芬致命结构 Type 1 要求线外两格里只有一格带额外候选，'
            '实际有 ${extraCells.length} 格');
        break;
      }
      final owner = _cellOf(extraCells.single);
      final clean = s.cells.where((c) => c != owner).toList();
      if (clean.length != 1) {
        out.add('淑芬致命结构的线外格应为两个，实际 ${s.cells.length} 个');
        break;
      }
      final computedQ = <String>{
        for (final d in board.getCandidates(owner.row, owner.col))
          if (s.baseDigits.contains(d)) '${owner.row},${owner.col},$d'
      };
      if (computedQ.isEmpty) {
        out.add('${owner.label} 上没有底数，删不出东西');
      }
      out.addAll(_sameElims(s.conclusionFalse, computedQ, '淑芬致命结构 Type 1'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('淑芬致命结构 Type 1 给的是删除结论，不该声明填数');
      }
    case TeachingClaim.type3:
      if (extraCells.length < 2) {
        out.add('Type 3 要求至少两格带额外候选，实际 ${extraCells.length} 格');
        break;
      }
      out.addAll(_restPureBase(board, s, byCell.keys.toSet()));
      final owners = extraCells.map(_cellOf).toList();
      final virtual = <int>{for (final e in s.extras) e.num};
      if (virtual.intersection(s.baseDigits).isNotEmpty) {
        out.add('虚拟格的候选 $virtual 里混进了底数');
      }
      // 虚拟格要能当一格用，带额外候选的格子必须和数组格同处一个房屋。
      final shared = housesOf(owners.first.row, owners.first.col)
          .where((h) => owners.every((o) => housesOf(o.row, o.col).contains(h)))
          .toList();
      if (shared.isEmpty) {
        out.add('带额外候选的 ${owners.map((o) => o.label).join(",")} 不同房屋，'
            '合不成一个虚拟格');
        break;
      }
      final withSubset = shared
          .where((h) => s.subsetCells.every((cell) =>
              houseCells(h).any((x) => x[0] == cell.row && x[1] == cell.col)))
          .toList();
      if (withSubset.isEmpty) {
        out.add('数组格 ${s.subsetCells.map((c) => c.label).join(",")} 不在'
            '虚拟格所在的任何房屋（${shared.map(houseName).join("/")}）里');
        break;
      }
      final house = withSubset.first;
      final union = <int>{...virtual};
      for (final cell in s.subsetCells) {
        if (board.get(cell.row, cell.col) != 0) {
          out.add('数组格 ${cell.label} 是已知数');
          continue;
        }
        if (!houseCells(house)
            .any((x) => x[0] == cell.row && x[1] == cell.col)) {
          out.add('数组格 ${cell.label} 不在 ${houseName(house)} 里，配不成数组');
        }
        union.addAll(board.getCandidates(cell.row, cell.col));
      }
      if (!setEquals(union, s.subsetDigits)) {
        out.add('虚拟格加数组格的候选并集是 $union，声明的数组数字是 ${s.subsetDigits}');
      }
      if (union.length != s.subsetCells.length + 1) {
        out.add('虚拟格算一格，${s.subsetCells.length + 1} 格应锁 '
            '${s.subsetCells.length + 1} 个数字，实际并集有 ${union.length} 个');
      }
      final computed3 = <String>{};
      for (final x in houseCells(house)) {
        final r = x[0], col = x[1];
        if (board.get(r, col) != 0) continue;
        if (owners.any((o) => o.row == r && o.col == col)) continue;
        if (s.subsetCells.any((o) => o.row == r && o.col == col)) continue;
        for (final d in board.getCandidates(r, col)) {
          if (union.contains(d)) computed3.add('$r,$col,$d');
        }
      }
      if (computed3.isEmpty) {
        out.add('${houseName(house)} 里没有别的格子含这组数字，Type 3 删不出东西');
      }
      out.addAll(_sameElims(s.conclusionFalse, computed3, 'Type 3'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('Type 3 给的是删除结论，不该声明填数');
      }
    case TeachingClaim.type4:
      if (extraCells.length != 2) {
        out.add('Type 4 要求恰好两格带额外候选，实际 ${extraCells.length} 格');
        break;
      }
      out.addAll(_restPureBase(board, s, byCell.keys.toSet()));
      final owners = extraCells.map(_cellOf).toList();
      final x = s.lockDigit;
      if (x == null || !s.baseDigits.contains(x)) {
        out.add('Type 4 要声明一个被锁住的底数，实际 lockDigit=$x');
        break;
      }
      if (s.lockHouses.length != 1) {
        out.add('Type 4 只锁一个房屋，实际声明了 ${s.lockHouses.length} 个');
        break;
      }
      final h = s.lockHouses.single;
      final inHouse = s.cells
          .where((c) => housesOf(c.row, c.col).contains(h))
          .map((c) => c.label)
          .toList();
      if (inHouse.length != 2 ||
          !owners.every((o) => housesOf(o.row, o.col).contains(h))) {
        out.add('${houseName(h)} 里的结构格是 $inHouse，'
            'Type 4 要求它恰好盖住带额外候选的那两格');
      }
      final places = [
        for (final cell in houseCells(h))
          if (board.get(cell[0], cell[1]) == 0 &&
              board.getCandidates(cell[0], cell[1]).contains(x))
            'r${cell[0] + 1}c${cell[1] + 1}'
      ];
      if (places.length != 2 ||
          !owners.every((o) => places.contains(o.label))) {
        out.add('底数 $x 在 ${houseName(h)} 里的位置是 $places，'
            '没被锁在结构的那两格上，强链不成立');
      }
      final computed4 = <String>{};
      for (final o in owners) {
        for (final d in board.getCandidates(o.row, o.col)) {
          if (d != x && s.baseDigits.contains(d)) {
            computed4.add('${o.row},${o.col},$d');
          }
        }
      }
      out.addAll(_sameElims(s.conclusionFalse, computed4, 'Type 4'));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('Type 4 给的是删除结论，不该声明填数');
      }
    case TeachingClaim.hiddenRect:
      final b = s.lockDigit;
      if (b == null || !s.baseDigits.contains(b) || s.baseDigits.length != 2) {
        out.add('隐性唯一矩形要声明一个成强链的底数，实际 lockDigit=$b');
        break;
      }
      if (s.lockHouses.length != 2) {
        out.add('隐性唯一矩形要两条强链，实际声明了 ${s.lockHouses.length} 条');
        break;
      }
      final a = s.baseDigits.firstWhere((d) => d != b);
      final corners = s.cells;
      final onBoth = corners
          .where((c) =>
              s.lockHouses.every((h) => housesOf(c.row, c.col).contains(h)))
          .toList();
      if (onBoth.length != 1) {
        out.add('两条强链应交在唯一一个角上，实际交在 ${onBoth.length} 个角上');
        break;
      }
      final diag = onBoth.single;
      final floor = corners.firstWhere(
        (c) => c.row != diag.row && c.col != diag.col,
        orElse: () => diag,
      );
      if (floor == diag) {
        out.add('找不到和 ${diag.label} 对角的那一角');
        break;
      }
      if (!setEquals(Set<int>.from(board.getCandidates(floor.row, floor.col)),
          s.baseDigits)) {
        out.add('对角格 ${floor.label} 上是 '
            '${board.getCandidates(floor.row, floor.col)}，'
            '隐性唯一矩形要求它干净地只剩底数对');
      }
      for (final lh in s.lockHouses) {
        final onLine =
            corners.where((c) => housesOf(c.row, c.col).contains(lh)).toList();
        if (onLine.length != 2) {
          out.add('${houseName(lh)} 上有 ${onLine.length} 个角，强链要求恰好两个');
          continue;
        }
        final places = [
          for (final cell in houseCells(lh))
            if (board.get(cell[0], cell[1]) == 0 &&
                board.getCandidates(cell[0], cell[1]).contains(b))
              'r${cell[0] + 1}c${cell[1] + 1}'
        ];
        if (places.length != 2 ||
            !onLine.every((c) => places.contains(c.label))) {
          out.add('底数 $b 在 ${houseName(lh)} 里的位置是 $places，'
              '不是矩形上那两个角，强链不成立');
        }
      }
      if (!board.getCandidates(diag.row, diag.col).contains(a)) {
        out.add('${diag.label} 上本来就没有 $a，没什么可删');
      }
      out.addAll(_sameElims(
        s.conclusionFalse,
        {'${diag.row},${diag.col},$a'},
        '隐性唯一矩形',
      ));
      if (s.conclusionTrue.isNotEmpty) {
        out.add('隐性唯一矩形给的是删除结论，不该声明填数');
      }
    case TeachingClaim.chainNode:
      if (s.conclusionTrue.isNotEmpty || s.conclusionFalse.isNotEmpty) {
        out.add('待定结构本页只交出一个链节点，不该直接下删除或填数结论');
      }
      if (extraCells.length != 2 || s.extras.length != 2) {
        out.add('待定结构的链节点要恰好两个多余候选，'
            '实际 ${s.extras.length} 个分布在 ${extraCells.length} 格上');
        break;
      }
      out.addAll(_restPureBase(board, s, byCell.keys.toSet()));
      final e1 = s.extras[0], e2 = s.extras[1];
      if (e1.num == e2.num && sees(e1.row, e1.col, e2.row, e2.col)) {
        out.add('两个多余候选是同一个数字又互相看得见，那是 Type 2，能直接删，'
            '不该停在链节点上');
      }
    case TeachingClaim.forcing:
      out.addAll(forcingViolations(puzzle, s));
    case TeachingClaim.graveType2:
    case TeachingClaim.gravePlusN:
    case TeachingClaim.graveType3:
    case TeachingClaim.graveType4:
    case TeachingClaim.graveChainNode:
      if (s.family != TeachingFamily.bivalueGrave) {
        out.add('${s.claim.name} 是双值死盘家族的档位，'
            '${s.family.name} 用不了它的推理');
        break;
      }
      out.addAll(graveClaimViolations(puzzle, s));
    case TeachingClaim.elimination:
      // 删除集合本身由各家族的几何检查逐条对齐，这里只管档位自己的规矩。
      if (s.conclusionFalse.isEmpty) {
        out.add('这一档讲的是「算出一组删除」，结论里却一条删除都没有');
      }
      if (s.conclusionTrue.isNotEmpty) {
        out.add('这一档给的是删除结论，不该同时声明填数');
      }
  }
  return out;
}

/// 可规避矩形的前提：矩形里已填的那个角必须是玩家自己推出来填的。
///
/// 静态教学盘只存得下候选，存不下「这一格是谁填的」，所以这里核对的是
/// 教学页真正说得出口的那句话：四个角在题目里都不是已知数，
/// 而唯一解会让 [TeachingStructure.filledCorner] 这一角落上底数
/// [TeachingStructure.filledDigit]——也就是说，对局里这一格确实由玩家自己填出来，
/// 填完的那一刻矩形就成了可规避矩形。
List<String> avoidableFillViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final corner = s.filledCorner;
  final digit = s.filledDigit;
  if (s.family != TeachingFamily.avoidableRect) {
    if (corner != null || digit != null) {
      out.add('只有可规避矩形才声明「玩家填出来的那一角」');
    }
    return out;
  }
  if (corner == null || digit == null) {
    out.add('可规避矩形要声明唯一解里由玩家填出来的那个角和那个底数');
    return out;
  }
  if (!s.cells.contains(corner)) {
    out.add('${corner.label} 不是这个矩形的角');
  }
  if (!s.baseDigits.contains(digit)) {
    out.add('$digit 不是这个矩形的底数，填上它不构成可规避矩形');
  }
  final solution = uniqueSolution(puzzle);
  if (solution == null) {
    out.add('盘面不是唯一解，无法核对那一角填的是什么');
    return out;
  }
  final actual = solution[corner.row][corner.col];
  if (actual != digit) {
    out.add('唯一解里 ${corner.label} 填的是 $actual，不是声明的 $digit');
  }
  return out;
}

/// 强制类技巧：每个多余候选各成一支，各支都得推出同一个结论。
///
/// 这一档最容易写出「看着绿其实空转」的复核，所以四刀都得砍下去：
///
/// 1. **从页面那张盘面起步**。用 [LogicGrid.fromBoard]，不能用
///    [LogicGrid.fromPuzzle]——后者一建好就把唯余摒除推到了底，
///    假设的那一格常常已经被填成同一个数字，`assign` 直接返回，
///    这一种情况根本没走，结论却是从推完的盘面上读出来的。
/// 2. **假设必须真的是个假设**。被假设的候选要在页面这张盘面上还活着，
///    而且填进去之后 [LogicGrid.spent] 得真的涨（不是原地打转）。
/// 3. **推理长度夹得住**。[TeachingStructure.replayBudget] 必须声明且有限，
///    每一种情况只许唯余摒除往下填这么多格；不设上限的话常常顺手把整盘解完，
///    「两种情况都删掉同一个候选」就退化成了「答案里本来就不是它」。
/// 4. **结论得超出基础招式**。不加任何假设、光靠唯余摒除盲推
///    `replayBudget × 支数` 格（也就是整套论证花掉的全部步数），
///    如果声明的删除自己就掉下来了，那这一页教的是唯余摒除，不是强制致命结构。
///
/// 另外每一种情况都不能当场矛盾：某支一填就矛盾，说明那个多余候选可以直接删掉，
/// 页面该讲的是那个删除，而不是绕一圈取交集。
List<String> forcingViolations(String puzzle, TeachingStructure s) {
  final out = <String>[];
  final board = SudokuBoard.fromString(puzzle);
  if (s.conclusionTrue.isEmpty && s.conclusionFalse.isEmpty) {
    out.add('强制类技巧要给出各支共同的结论，这里一条都没有');
    return out;
  }
  if (s.extras.length < 2) {
    out.add('强制类技巧至少要有两支假设，实际只有 ${s.extras.length} 个多余候选');
    return out;
  }
  final budget = s.replayBudget;
  if (budget == null) {
    out.add('强制类技巧要声明每一种情况只许往下填几格（replayBudget）');
    return out;
  }
  if (budget <= 0 || budget > 20) {
    out.add('replayBudget 是 $budget，教学页写得出的分支只能是有限的几步（1–20 格）');
    return out;
  }

  for (final e in s.extras) {
    final tag = _candLabel(e);
    if (board.get(e.row, e.col) != 0) {
      out.add('假设 $tag 那一格在页面上已经填好了，这一种情况是空的');
      continue;
    }
    if (!board.getCandidates(e.row, e.col).contains(e.num)) {
      out.add('假设 $tag 在页面这张盘面上并不存在，这一种情况无从谈起');
      continue;
    }
    final branch = LogicGrid.fromBoard(puzzle);
    branch.budget = budget;
    branch.assign(e.row * 9 + e.col, e.num, '假设');
    if (branch.spent == 0) {
      out.add('假设 $tag 填进去之后盘面没有任何变化，这一种情况空转');
      continue;
    }
    if (branch.broken) {
      out.add('假设 $tag 往下填不到 $budget 格就矛盾了，'
          '这个多余候选可以直接删掉，用不着绕一圈取交集');
      continue;
    }
    for (final t in s.conclusionTrue) {
      if (branch.value[t.row * 9 + t.col] != t.num) {
        out.add('假设 $tag 这一种情况往下填 $budget 格推不出 '
            'r${t.row + 1}c${t.col + 1}=${t.num}'
            '（这一种情况实际填了 ${branch.spent} 格：${branch.trace.join(" → ")}）');
      }
    }
    for (final f in s.conclusionFalse) {
      if (branch.cand[f.row * 9 + f.col].contains(f.num)) {
        out.add('假设 $tag 这一种情况往下填 $budget 格删不掉 ${_candLabel(f)}'
            '（这一种情况实际填了 ${branch.spent} 格：${branch.trace.join(" → ")}）');
      }
    }
  }

  // 第四刀：整套论证花掉的步数拿来盲推，声明的结论一条都不该自己掉下来。
  final blind = LogicGrid.fromBoard(puzzle);
  blind.budget = budget * s.extras.length;
  blind.propagate();
  if (blind.broken) {
    out.add('页面这张盘面光靠唯余摒除盲推就推出了矛盾');
    return out;
  }
  for (final t in s.conclusionTrue) {
    if (blind.value[t.row * 9 + t.col] == t.num) {
      out.add('不用任何假设，盲推 ${budget * s.extras.length} 格就填出了 '
          'r${t.row + 1}c${t.col + 1}=${t.num}，这一条不是强制推出来的');
    }
  }
  for (final f in s.conclusionFalse) {
    if (!blind.cand[f.row * 9 + f.col].contains(f.num)) {
      out.add('不用任何假设，盲推 ${budget * s.extras.length} 格就删掉了 '
          '${_candLabel(f)}，这一条不是强制推出来的');
    }
  }
  return out;
}

/// 结论（填数/删除）不能和盘面的唯一解冲突。
List<String> conclusionViolations(
  String puzzle,
  Iterable<CandidateRef> mustBeTrue,
  Iterable<CandidateRef> mustBeFalse,
) {
  final out = <String>[];
  final solution = uniqueSolution(puzzle);
  if (solution == null) {
    out.add('盘面不是唯一解，无法核对结论');
    return out;
  }
  for (final ref in mustBeTrue) {
    if (solution[ref.row][ref.col] != ref.num) {
      out.add('结论说 r${ref.row + 1}c${ref.col + 1} 填 ${ref.num}，'
          '但唯一解那一格是 ${solution[ref.row][ref.col]}');
    }
  }
  for (final ref in mustBeFalse) {
    if (solution[ref.row][ref.col] == ref.num) {
      out.add('结论说要删 r${ref.row + 1}c${ref.col + 1} 的 ${ref.num}，'
          '但唯一解那一格正是 ${ref.num}');
    }
  }
  return out;
}

/// 按家族分派全部几何检查。
List<String> structureViolations(String puzzle, TeachingStructure s) {
  final out = <String>[
    ...boardViolations(puzzle),
    ...boxSpanViolations(s),
  ];
  switch (s.family) {
    case TeachingFamily.uniqueRect:
    case TeachingFamily.avoidableRect:
      out.addAll(rectGeometryViolations(s));
      out.addAll(extrasExhaustiveViolations(puzzle, s));
      out.addAll(deadlyPatternViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
      out.addAll(avoidableFillViolations(puzzle, s));
    case TeachingFamily.extendedRect:
      out.addAll(extendedRectGeometryViolations(s));
      out.addAll(extrasExhaustiveViolations(puzzle, s));
      out.addAll(deadlyPatternViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.uniqueLoop:
      out.addAll(loopGeometryViolations(s));
      out.addAll(extrasExhaustiveViolations(puzzle, s));
      out.addAll(deadlyPatternViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.bivalueGrave:
      out.addAll(bugParityViolations(puzzle, s.extras));
      // 死盘家族直接走 grave 系列的重算，不许落到矩形族的同名类型上：
      // 那几档的前置检查（比如「其余结构格只剩底数」）在 cells 为空的死盘上
      // 会自动通过，等于什么都没查。
      out.addAll(graveClaimViolations(puzzle, s));
    case TeachingFamily.borescoper:
      out.addAll(borescoperGeometryViolations(s));
      out.addAll(extrasExhaustiveViolations(puzzle, s));
      out.addAll(deadlyPatternViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.qiu:
      out.addAll(qiuGeometryViolations(puzzle, s));
      out.addAll(extrasExhaustiveViolations(puzzle, s, requireAllBase: false));
      out.addAll(deadlyPatternViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.fish:
      out.addAll(fishFamilyViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.siameseFish:
      out.addAll(siameseViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.turbot:
      out.addAll(turbotViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.lockedSet:
      out.addAll(lockedSetViolations(puzzle, s));
    case TeachingFamily.guardedOddCycle:
      out.addAll(oddCycleViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.exocet:
      out.addAll(exocetViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.burredSubset:
      out.addAll(burredSubsetViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.distributedDisjointSubset:
      out.addAll(ddsViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.multiSectorLockedSet:
      out.addAll(mslsViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.almostHiddenSet:
      out.addAll(almostHiddenSetViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
    case TeachingFamily.dynamicChain:
      out.addAll(dynamicChainViolations(puzzle, s));
      out.addAll(claimViolations(puzzle, s));
  }
  return out;
}

bool setEquals(Set<int> a, Set<int> b) =>
    a.length == b.length && a.every(b.contains);

bool _sameStrings(Set<String> a, Set<String> b) =>
    a.length == b.length && a.every(b.contains);
