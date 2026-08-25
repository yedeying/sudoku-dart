import 'package:flutter/material.dart';

enum MarkupMode { off, cellColor, candidateColor, strong, weak, autoStrong }

class MarkupPalette {
  /// 中等浅色：比旧的 800 档淡，候选圆和箭头仍分得清。
  /// 格底请用 [wash]，不要直接铺这些颜色。
  static const blue = Color(0xFF42A5F5);
  static const red = Color(0xFFEF5350);
  static const green = Color(0xFF66BB6A);
  static const purple = Color(0xFFAB47BC);
  static const teal = Color(0xFF26A69A);
  static const orange = Color(0xFFFFA726);
  static const rose = Color(0xFFEC407A);
  static const indigo = Color(0xFF5C6BC0);
  static const skyBlue = Color(0xFF80DEEA);
  static const gold = Color(0xFFFFE082);

  /// 鱼类基线：整行/整列的淡底，比鱼身 [pattern] 更浅。
  static const house = Color(0xFFD6E6F2);

  /// 十个色相/明度都拉开的颜色，够同时标几条链而不互相冒充。
  /// 常用的蓝红绿紫排在前面，第一个也就是默认色；金黄压到最后。
  static const colors = [
    blue,
    red,
    green,
    purple,
    teal,
    orange,
    rose,
    indigo,
    skyBlue,
    gold,
  ];

  /// 格子底色用的淡洗，数字保持深色可读。
  static Color wash(Color color) {
    final hsl = HSLColor.fromColor(color);
    if (hsl.lightness >= 0.84) return color;
    return hsl.withLightness(0.86).toColor();
  }
}

/// 某个格子上的一个候选数字
class CandidateRef {
  final int row;
  final int col;
  final int num;

  const CandidateRef(this.row, this.col, this.num);

  @override
  bool operator ==(Object other) =>
      other is CandidateRef &&
      other.row == row &&
      other.col == col &&
      other.num == num;

  @override
  int get hashCode => Object.hash(row, col, num);
}

enum ArrowKind { strong, weak }

class MarkupArrow {
  final CandidateRef from;
  final CandidateRef to;
  final ArrowKind kind;

  /// 用户画的链带上当前标记色；提示自动生成的链留空，走主题的强/弱链色。
  final Color? color;

  /// 是否绘制箭头（手动画链有方向，自动强链无方向）。
  final bool directed;

  const MarkupArrow({
    required this.from,
    required this.to,
    required this.kind,
    this.color,
    this.directed = true,
  });
}

/// 棋盘标记：格色、候选色、箭头、用户划掉的候选
class BoardMarkup {
  final Map<int, Color> cellColors;
  final Map<CandidateRef, Color> candidateColors;
  final List<MarkupArrow> arrows;
  final Set<CandidateRef> struck;
  final int? filterDigit;

  BoardMarkup({
    Map<int, Color>? cellColors,
    Map<CandidateRef, Color>? candidateColors,
    List<MarkupArrow>? arrows,
    Set<CandidateRef>? struck,
    this.filterDigit,
  })  : cellColors = cellColors ?? {},
        candidateColors = candidateColors ?? {},
        arrows = arrows ?? [],
        struck = struck ?? {};

  static int cellKey(int row, int col) => row * 9 + col;

  BoardMarkup copy({int? filterDigit}) => BoardMarkup(
        cellColors: Map.of(cellColors),
        candidateColors: Map.of(candidateColors),
        arrows: List.of(arrows),
        struck: Set.of(struck),
        filterDigit: filterDigit ?? this.filterDigit,
      );

  /// 双值强链：同数字，且所在行或列或宫内该数字候选格恰好 2 个。
  static bool isLegalConjugate(
    CandidateRef a,
    CandidateRef b,
    List<List<Set<int>>> candidates,
  ) {
    if (a.num != b.num) return false;
    if (a.row == b.row && a.col == b.col) return false;
    if (!candidates[a.row][a.col].contains(a.num)) return false;
    if (!candidates[b.row][b.col].contains(b.num)) return false;

    final digit = a.num;
    bool twoIn(Iterable<List<int>> cells) {
      final hits = <String>{};
      for (final c in cells) {
        if (candidates[c[0]][c[1]].contains(digit)) {
          hits.add('${c[0]},${c[1]}');
        }
      }
      return hits.length == 2 &&
          hits.contains('${a.row},${a.col}') &&
          hits.contains('${b.row},${b.col}');
    }

    final sameRow = a.row == b.row &&
        twoIn([
          for (int c = 0; c < 9; c++) [a.row, c]
        ]);
    final sameCol = a.col == b.col &&
        twoIn([
          for (int r = 0; r < 9; r++) [r, a.col]
        ]);
    final sameBox = a.row ~/ 3 == b.row ~/ 3 &&
        a.col ~/ 3 == b.col ~/ 3 &&
        twoIn([
          for (int i = 0; i < 3; i++)
            for (int j = 0; j < 3; j++)
              [(a.row ~/ 3) * 3 + i, (a.col ~/ 3) * 3 + j]
        ]);
    return sameRow || sameCol || sameBox;
  }

  bool addArrow(
    CandidateRef from,
    CandidateRef to,
    ArrowKind kind,
    List<List<Set<int>>> candidates, {
    Color? color,
    bool directed = true,
  }) {
    arrows.add(
      MarkupArrow(
        from: from,
        to: to,
        kind: kind,
        color: color,
        directed: directed,
      ),
    );
    return true;
  }
}
