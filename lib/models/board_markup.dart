import 'package:flutter/material.dart';

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

enum ArrowKind { strong, weak, conjugate }

class MarkupArrow {
  final CandidateRef from;
  final CandidateRef to;
  final ArrowKind kind;

  const MarkupArrow({
    required this.from,
    required this.to,
    required this.kind,
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

  /// 共轭：同数字，且所在行或列或宫内该数字候选格恰好 2 个，这两格就是这两点
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

    if (a.row == b.row) {
      return twoIn([for (int c = 0; c < 9; c++) [a.row, c]]);
    }
    if (a.col == b.col) {
      return twoIn([for (int r = 0; r < 9; r++) [r, a.col]]);
    }
    if (a.row ~/ 3 == b.row ~/ 3 && a.col ~/ 3 == b.col ~/ 3) {
      final br = (a.row ~/ 3) * 3;
      final bc = (a.col ~/ 3) * 3;
      return twoIn([
        for (int i = 0; i < 3; i++)
          for (int j = 0; j < 3; j++) [br + i, bc + j]
      ]);
    }
    return false;
  }

  bool addArrow(
    CandidateRef from,
    CandidateRef to,
    ArrowKind kind,
    List<List<Set<int>>> candidates,
  ) {
    if (kind == ArrowKind.conjugate &&
        !isLegalConjugate(from, to, candidates)) {
      return false;
    }
    arrows.add(MarkupArrow(from: from, to: to, kind: kind));
    return true;
  }
}
