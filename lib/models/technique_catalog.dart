import 'package:flutter/material.dart';
import 'board_markup.dart';
import 'technique_examples_basic.dart';
import 'technique_examples_chains.dart';
import 'technique_examples_fish.dart';
import 'technique_examples_wings.dart';

class TechniqueLegendItem {
  final Color color;
  final String label;

  const TechniqueLegendItem({required this.color, required this.label});
}

class TechniqueInfo {
  final String id;
  final String name;
  final String summary;
  final String definition;
  final String howToSpot;
  final String walkthrough;
  final String caveats;
  final int rank;

  /// 81-char puzzle; 0 = empty
  final String examplePuzzle;
  final BoardMarkup exampleMarkup;
  final List<TechniqueLegendItem> legend;

  const TechniqueInfo({
    required this.id,
    required this.name,
    required this.summary,
    required this.definition,
    required this.howToSpot,
    required this.walkthrough,
    required this.caveats,
    required this.rank,
    required this.examplePuzzle,
    required this.exampleMarkup,
    required this.legend,
  });
}

/// 从易到难的教学目录，所有条目都配有真实盘面、完整说明与标记。
class TechniqueCatalog {
  static final List<TechniqueInfo> all = _build();

  static List<TechniqueInfo> _build() {
    final items = <TechniqueInfo>[
      ...basicTechniqueExamples(),
      ...fishTechniqueExamples(),
      ...wingTechniqueExamples(),
      ...chainTechniqueExamples(),
    ];
    return items;
  }
}
