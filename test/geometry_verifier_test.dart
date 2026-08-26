import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/technique_structure.dart';

import 'support/teaching_verifier.dart';

TeachingStructure _er(List<List<int>> cells) => TeachingStructure(
      family: TeachingFamily.extendedRect,
      baseDigits: const {1, 2, 3},
      cells: [for (final c in cells) CellRef(c[0], c[1])],
    );

TeachingStructure _loop(List<List<int>> cells) => TeachingStructure(
      family: TeachingFamily.uniqueLoop,
      baseDigits: const {1, 2},
      cells: [for (final c in cells) CellRef(c[0], c[1])],
    );

void main() {
  group('扩展矩形的几何复核', () {
    test('三格一线各自整整落在一个宫里，才算合法几何', () {
      expect(
        extendedRectGeometryViolations(_er([
          [0, 0],
          [0, 1],
          [0, 2],
          [3, 0],
          [3, 1],
          [3, 2],
        ])),
        isEmpty,
        reason: 'r1c1-3 在 b1、r4c1-3 在 b4，两条线各自成宫',
      );
    });

    test('两条线同处一个宫带、三格跨了两个宫，不是扩展矩形', () {
      // r1c1,r1c2,r1c4 / r2c1,r2c2,r2c4：只跨 b1、b2 两个宫，
      // 「恰好两个宫」这一条查不出来，但每条三格线自己就跨了两个宫，
      // 整块对调时宫里的底数个数会变，根本不是致命形。
      final bad = extendedRectGeometryViolations(_er([
        [0, 0],
        [0, 1],
        [0, 3],
        [1, 0],
        [1, 1],
        [1, 3],
      ]));
      expect(bad, isNotEmpty, reason: '三格线跨宫必须报出来');
      expect(bad.join(), contains('宫'));
    });

    test('两条线落在同一个宫里也不行', () {
      final bad = extendedRectGeometryViolations(_er([
        [0, 0],
        [0, 1],
        [0, 2],
        [1, 0],
        [1, 1],
        [1, 2],
      ]));
      expect(bad, isNotEmpty);
    });
  });

  group('唯一环的几何复核', () {
    test('一个真六格环走得过', () {
      // r1c1-r1c2-r4c2-r4c3-r7c3-r7c1：横一步竖一步交替，回到起点。
      // 三行三列三宫各占两格，隔一格一色是个合法两染色。
      expect(
        loopGeometryViolations(_loop([
          [0, 0],
          [0, 1],
          [3, 1],
          [3, 2],
          [6, 2],
          [6, 0],
        ])),
        isEmpty,
      );
    });

    test('两个各自独立的环拼在一起，不是一个环', () {
      // 上下各一个合法六格环。每条房屋照样恰好占两格，光数房屋查不出来；
      // 必须真的把环按顺序串一遍，才知道这是两圈而不是一圈。
      final bad = loopGeometryViolations(_loop([
        [0, 0],
        [0, 1],
        [3, 1],
        [3, 2],
        [6, 2],
        [6, 0],
        [1, 3],
        [1, 4],
        [4, 4],
        [4, 5],
        [7, 5],
        [7, 3],
      ]));
      expect(bad, isNotEmpty, reason: '两个环拼一起必须报出来');
      expect(bad.join(), contains('环'));
    });
  });
}
