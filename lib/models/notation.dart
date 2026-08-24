import 'board_markup.dart';

String cellRef(int row, int col) => 'r${row + 1}c${col + 1}';

String candRef(int row, int col, int digit) => '$digit${cellRef(row, col)}';

String rowRef(int row) => 'r${row + 1}';

String colRef(int col) => 'c${col + 1}';

/// 宫编号 1–9，行优先：上左 b1 … 下右 b9。
String boxRef(int boxRow, int boxCol) => 'b${boxRow * 3 + boxCol + 1}';

String fillLine(int row, int col, int digit) => '填 ${cellRef(row, col)}=$digit';

String elimLine(Iterable<({int row, int col, int digit})> elims) =>
    '删 ${elims.map((e) => candRef(e.row, e.col, e.digit)).join(', ')}';

String chainExpr(List<MarkupArrow> arrows) {
  if (arrows.isEmpty) return '';
  final buf = StringBuffer(
    candRef(
        arrows.first.from.row, arrows.first.from.col, arrows.first.from.num),
  );
  for (final a in arrows) {
    buf.write(a.kind == ArrowKind.strong ? ' = ' : ' - ');
    buf.write(candRef(a.to.row, a.to.col, a.to.num));
  }
  return buf.toString();
}

String rowsList(Iterable<int> rows) => rows.map(rowRef).join(',');

String colsList(Iterable<int> cols) => cols.map(colRef).join(',');

String cellsList(Iterable<List<int>> cells) =>
    cells.map((c) => cellRef(c[0], c[1])).join(', ');

String candsAt(List<int> cell, Iterable<int> digits) =>
    (digits.toList()..sort())
        .map((d) => candRef(cell[0], cell[1], d))
        .join(', ');
