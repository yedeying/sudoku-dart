import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_catalog.dart';

void main() {
  test('技巧目录 rank 严格递增', () {
    final all = TechniqueCatalog.all;
    expect(all, isNotEmpty);
    for (int i = 1; i < all.length; i++) {
      expect(all[i].rank, greaterThan(all[i - 1].rank),
          reason: '${all[i].id} rank 应大于 ${all[i - 1].id}');
    }
  });

  test('保留 Simple Coloring，不含独立 3D Medusa', () {
    final names = TechniqueCatalog.all.map((t) => t.name).toList();
    expect(names, contains('Simple Coloring'));
    expect(
        names.any((n) => n.contains('Medusa') || n.contains('Multi-Coloring')),
        isFalse);
  });

  test('含 AIC 与 Forcing Net', () {
    final ids = TechniqueCatalog.all.map((t) => t.id).toSet();
    expect(ids, containsAll(['aic', 'nice_loop', 'forcing_net', 'naked_quad']));
  });

  test('每条技巧都有独立盘面和完整说明', () {
    const placeholder =
        '530070000600195000098000060800060003400803001700020006060000280000419005000080079';
    final puzzles = <String>{};
    for (final t in TechniqueCatalog.all) {
      expect(t.examplePuzzle.length, 81, reason: t.id);
      expect(t.examplePuzzle, isNot(placeholder), reason: '${t.id} 仍是占位盘');
      expect(puzzles.add(t.examplePuzzle), isTrue, reason: '${t.id} 盘面重复');
      expect(t.definition.length, greaterThanOrEqualTo(80), reason: t.id);
      expect(t.howToSpot.length, greaterThanOrEqualTo(40), reason: t.id);
      expect(t.walkthrough.length, greaterThanOrEqualTo(80), reason: t.id);
      expect(t.caveats.length, greaterThanOrEqualTo(20), reason: t.id);
      expect(t.legend, isNotEmpty, reason: t.id);
      final marked = t.exampleMarkup.cellColors.isNotEmpty ||
          t.exampleMarkup.candidateColors.isNotEmpty ||
          t.exampleMarkup.arrows.isNotEmpty ||
          t.exampleMarkup.struck.isNotEmpty;
      expect(marked, isTrue, reason: '${t.id} 没有标记');
    }
  });

  test('基础技巧盘面互不相同且带标记', () {
    const ids = [
      'naked_single',
      'hidden_single',
      'naked_pair',
      'naked_triple',
      'naked_quad',
      'hidden_pair',
      'hidden_triple',
      'hidden_quad',
      'pointing',
      'box_line',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in ids) {
      final t = map[id]!;
      expect(
          t.exampleMarkup.cellColors.length +
              t.exampleMarkup.candidateColors.length,
          greaterThan(1),
          reason: id);
    }
  });

  test('鱼类与带鳍/Franken 鱼盘面都有实质标记', () {
    const ids = [
      'xwing',
      'swordfish',
      'jellyfish',
      'finned_xwing',
      'finned_swordfish',
      'finned_jellyfish',
      'franken_fish',
    ];
    final map = {for (final t in TechniqueCatalog.all) t.id: t};
    for (final id in ids) {
      final t = map[id]!;
      final marked = t.exampleMarkup.arrows.isNotEmpty ||
          t.exampleMarkup.cellColors.length >= 4;
      expect(marked, isTrue, reason: '$id 缺少足够的标记');
    }
  });
}
