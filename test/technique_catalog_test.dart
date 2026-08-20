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
    expect(names.any((n) => n.contains('Medusa') || n.contains('Multi-Coloring')),
        isFalse);
  });

  test('含 AIC 与 Forcing Net', () {
    final ids = TechniqueCatalog.all.map((t) => t.id).toSet();
    expect(ids, containsAll(['aic', 'nice_loop', 'forcing_net', 'naked_quad']));
  });
}
