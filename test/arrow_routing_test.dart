import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sudoku_app/models/board_markup.dart';
import 'package:sudoku_app/widgets/board_arrows_painter.dart';

const _size = Size(360, 360);
const _padding = 4.0;
const _cell = (360 - _padding * 2) / 9;

BoardArrowsPainter _painter(MarkupArrow arrow) => BoardArrowsPainter(
      markup: BoardMarkup(arrows: [arrow]),
      strongColor: Colors.blue,
      weakColor: Colors.grey,
    );

/// 候选小格中心的纵坐标（和画笔里的算法一致）。
double _candidateCenterY(int row, int miniRow) =>
    _padding + row * _cell + (miniRow + 0.5) * (_cell / 3);

double _candidateCenterX(int col, int miniCol) =>
    _padding + col * _cell + (miniCol + 0.5) * (_cell / 3);

/// 沿绘制路径每 1px 取一个点。
List<Offset> _sample(Path path) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    for (double t = 0; t <= metric.length; t += 1) {
      points.add(metric.getTangentForOffset(t)!.position);
    }
    points.add(metric.getTangentForOffset(metric.length)!.position);
  }
  return points;
}

double _length(List<Offset> points) {
  double total = 0;
  for (int i = 0; i + 1 < points.length; i++) {
    total += (points[i + 1] - points[i]).distance;
  }
  return total;
}

void main() {
  test('同一行的链折出折入，长段落在候选数之间的空档里', () {
    const arrow = MarkupArrow(
      from: CandidateRef(4, 1, 5),
      to: CandidateRef(4, 7, 5),
      kind: ArrowKind.strong,
    );
    final path = _painter(arrow).debugPath(arrow, _size);

    expect(path, hasLength(4), reason: '应该是折出、平移、折入三段');
    expect(path[1].dy, closeTo(path[2].dy, 0.001), reason: '中间那段要水平');

    // 平移段必须避开这一行所有候选数字的高度，别横穿数字。
    final lane = path[1].dy;
    for (int miniRow = 0; miniRow < 3; miniRow++) {
      final gap = (lane - _candidateCenterY(4, miniRow)).abs();
      expect(gap, greaterThanOrEqualTo(_cell * 0.15),
          reason: '第 $miniRow 排候选被压住了');
    }

    // 折出、折入都发生在起止格附近，不是绕整行一圈。
    expect((path[1].dx - path.first.dx).abs(), lessThan(_cell));
    expect((path[2].dx - path.last.dx).abs(), lessThan(_cell));
  });

  test('同一列的链同样折出折入，长段落在竖向空档里', () {
    const arrow = MarkupArrow(
      from: CandidateRef(1, 3, 2),
      to: CandidateRef(7, 3, 2),
      kind: ArrowKind.weak,
    );
    final path = _painter(arrow).debugPath(arrow, _size);

    expect(path, hasLength(4));
    expect(path[1].dx, closeTo(path[2].dx, 0.001), reason: '中间那段要竖直');

    final lane = path[1].dx;
    for (int miniCol = 0; miniCol < 3; miniCol++) {
      final gap = (lane - _candidateCenterX(3, miniCol)).abs();
      expect(gap, greaterThanOrEqualTo(_cell * 0.15),
          reason: '第 $miniCol 列候选被压住了');
    }
  });

  test('斜向的链还是直线，不用绕', () {
    const arrow = MarkupArrow(
      from: CandidateRef(2, 2, 4),
      to: CandidateRef(5, 6, 4),
      kind: ArrowKind.strong,
    );
    expect(_painter(arrow).debugPath(arrow, _size), hasLength(2));
  });

  test('转折走贝塞尔圆角，不是硬折角', () {
    const arrow = MarkupArrow(
      from: CandidateRef(4, 1, 5),
      to: CandidateRef(4, 7, 5),
      kind: ArrowKind.strong,
    );
    final painter = _painter(arrow);
    final corners = painter.debugPath(arrow, _size);
    final line = painter.buildPath(arrow, _size);

    // 硬折角只有三种切线方向；圆角要能连续过渡。
    final angles = <double>[];
    for (final metric in line.computeMetrics()) {
      for (double t = 0; t <= metric.length; t += 1) {
        final v = metric.getTangentForOffset(t)!.vector;
        angles.add(math.atan2(v.dy, v.dx) * 180 / math.pi);
      }
    }
    expect(angles.map((a) => a.round()).toSet().length, greaterThan(8));

    // 方向要一点点转过去：任何 1px 内的转角都不能像折角那样突变。
    double maxJump = 0;
    for (int i = 0; i + 1 < angles.length; i++) {
      maxJump = math.max(maxJump, (angles[i + 1] - angles[i]).abs());
    }
    expect(maxJump, lessThan(8));

    // 起手就在转，不留一截直的小尾巴。
    expect((angles[1] - angles[0]).abs(), greaterThan(0.5));

    // 圆角抄了近路，比硬折角短；但仍比直连长，说明绕行还在。
    expect(_length(_sample(line)), lessThan(_length(corners)));
    expect(_length(_sample(line)),
        greaterThan((corners.last - corners.first).distance));
  });

  test('曲线全程都不压在候选数字上', () {
    const arrow = MarkupArrow(
      from: CandidateRef(4, 1, 5),
      to: CandidateRef(4, 7, 5),
      kind: ArrowKind.strong,
    );
    final points = _sample(_painter(arrow).buildPath(arrow, _size));

    // 含起止格：折出、折入也不该刮到同格里的别的候选。
    for (int col = 1; col <= 7; col++) {
      for (int num = 1; num <= 9; num++) {
        if (num == 5 && (col == 1 || col == 7)) continue; // 链本身的两端
        final center = Offset(
          _candidateCenterX(col, (num - 1) % 3),
          _candidateCenterY(4, (num - 1) ~/ 3),
        );
        final nearest = points
            .map((p) => (p - center).distance)
            .reduce((a, b) => a < b ? a : b);
        expect(nearest, greaterThanOrEqualTo(_cell * 0.15),
            reason: 'R5C${col + 1} 的候选 $num 被压住了');
      }
    }
  });

  test('同格双值强链弓出去，相邻候选之间仍看得到线', () {
    const arrow = MarkupArrow(
      from: CandidateRef(2, 3, 1),
      to: CandidateRef(2, 3, 2),
      kind: ArrowKind.strong,
    );
    final painter = _painter(arrow);
    final path = painter.debugPath(arrow, _size);
    expect(path.length, greaterThanOrEqualTo(3), reason: '同格链要弓一下，不能缩成看不见的短直线');
    expect(_length(path), greaterThan(_cell * 0.28));
    final centers = painter.debugCenters(arrow, _size);
    expect((path.first - centers.$1).distance, lessThan(_cell * 0.12));
    expect((path.last - centers.$2).distance, lessThan(_cell * 0.12));
  });

  test('折线两端依旧从数字上退开约 6px', () {
    const arrow = MarkupArrow(
      from: CandidateRef(4, 1, 5),
      to: CandidateRef(4, 7, 5),
      kind: ArrowKind.strong,
    );
    final painter = _painter(arrow);
    final path = painter.debugPath(arrow, _size);
    final centers = painter.debugCenters(arrow, _size);

    expect((path.first - centers.$1).distance, inInclusiveRange(5, 7));
    expect((path.last - centers.$2).distance, inInclusiveRange(5, 7));
  });
}
