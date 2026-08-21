import 'package:flutter/material.dart';

enum MarkupMode { off, cellColor, candidateColor, strong, weak, autoStrong }

class MarkupPalette {
  static const blue = Color(0xFF1565C0);
  static const red = Color(0xFFC62828);
  static const green = Color(0xFF2E7D32);
  static const purple = Color(0xFF6A1B9A);
  static const teal = Color(0xFF00838F);
  static const orange = Color(0xFFE65100);
  static const rose = Color(0xFFAD1457);
  static const brown = Color(0xFF4E342E);
  static const skyBlue = Color(0xFF4FC3F7);
  static const gold = Color(0xFFC9A227);

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
    brown,
    skyBlue,
    gold,
  ];
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

  const MarkupArrow({
    required this.from,
    required this.to,
    required this.kind,
    this.color,
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
  }) {
    arrows.add(MarkupArrow(from: from, to: to, kind: kind, color: color));
    return true;
  }
}
