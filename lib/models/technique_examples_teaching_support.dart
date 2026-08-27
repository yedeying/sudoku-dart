import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'teaching_colors.dart';
import 'technique_catalog.dart';

int tKey(int r, int c) => BoardMarkup.cellKey(r, c);

CandidateRef tRef(int r, int c, int n) => CandidateRef(r, c, n);

/// 只讲结构、不下结论的示意标记。
///
/// 这些技巧引擎还没有独立报法，示意图只负责把形状指出来：
/// [pattern] 是结构本体的格子，[cover] 是被结构压住或提供鳍/伴随集的格子，
/// [nodes] 是结构上的底数与链节点候选，[keys] 是「多出来的那一个」关键候选。
///
/// 这里一律不用 [TeachingColors.elimCand] 和 [TeachingColors.start]：
/// 前者表示「这个候选一定不成立」，后者表示「这一格一定填这个数」，
/// 都是要靠 finder 或求解器验证过才敢说的结论。
///
/// [targets] 是结论落点：教学正文里说「这一格的那个数字可以删」的格子。
/// 用的是格底色 [TeachingColors.elimCell]，不是红色候选——红色表示
/// finder 已经算出这条删除，而这里的删除是靠盘面唯一解核对出来的，
/// 写进 [TechniqueInfo.structure] 的 `conclusionFalse` 由测试复核。
///
/// [strongLinks] 只在确认过所在区域里该数字恰好两个候选位置时才传；
/// [weakLinks] 只连同区域、同数字的两个候选，那是天然成立的弱链。
/// 两种连线都写成 `[r1, c1, r2, c2, digit]`。
BoardMarkup schematicMarkup({
  List<List<int>> pattern = const [],
  List<List<int>> cover = const [],
  List<List<int>> nodes = const [],
  List<List<int>> keys = const [],
  List<List<int>> targets = const [],
  List<List<int>> strongLinks = const [],
  List<List<int>> weakLinks = const [],
}) {
  final cellColors = <int, Color>{
    for (final c in cover) tKey(c[0], c[1]): TeachingColors.cover,
    for (final c in pattern) tKey(c[0], c[1]): TeachingColors.pattern,
    for (final c in targets) tKey(c[0], c[1]): TeachingColors.elimCell,
  };
  final candidateColors = <CandidateRef, Color>{
    for (final n in nodes) tRef(n[0], n[1], n[2]): TeachingColors.node,
    for (final k in keys) tRef(k[0], k[1], k[2]): TeachingColors.end,
  };
  MarkupArrow link(List<int> l, ArrowKind kind) => MarkupArrow(
        from: tRef(l[0], l[1], l[4]),
        to: tRef(l[2], l[3], l[4]),
        kind: kind,
        directed: kind == ArrowKind.weak,
      );
  return BoardMarkup(
    cellColors: cellColors,
    candidateColors: candidateColors,
    arrows: [
      for (final l in strongLinks) link(l, ArrowKind.strong),
      for (final l in weakLinks) link(l, ArrowKind.weak),
    ],
  );
}

const structureLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '结构格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '底数候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '多出来的候选'),
];

const chainNodeLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '结构格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '结构底数'),
  TechniqueLegendItem(color: TeachingColors.end, label: '入链的多余候选'),
];

const fishStructureLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '基线格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '覆盖/鳍所在格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '鱼身候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '鳍或链尾候选'),
];

const setStructureLegend = [
  TechniqueLegendItem(color: TeachingColors.pattern, label: '数组格'),
  TechniqueLegendItem(color: TeachingColors.cover, label: '伴随格'),
  TechniqueLegendItem(color: TeachingColors.node, label: '数组候选'),
  TechniqueLegendItem(color: TeachingColors.end, label: '关键数字'),
];

const graveLegend = [
  TechniqueLegendItem(color: TeachingColors.cover, label: '双值死盘格'),
  TechniqueLegendItem(color: TeachingColors.pattern, label: '例外格'),
  TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点'),
  TechniqueLegendItem(color: TeachingColors.node, label: '死盘底数'),
  TechniqueLegendItem(color: TeachingColors.end, label: '多出来的候选'),
];

const targetLegendItem =
    TechniqueLegendItem(color: TeachingColors.elimCell, label: '结论落点');
