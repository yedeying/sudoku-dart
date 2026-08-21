import 'dart:math' as math;

import 'package:flutter/material.dart';
import '../models/board_markup.dart';

class BoardArrowsPainter extends CustomPainter {
  final BoardMarkup markup;
  final double padding;
  final Color strongColor;
  final Color weakColor;

  BoardArrowsPainter({
    required this.markup,
    this.padding = 4,
    this.strongColor = const Color(0xFF3F51B5),
    this.weakColor = const Color(0xFF616161),
  });

  /// 候选数字所在小格的中心。
  Offset _center(CandidateRef ref, Size size) {
    final cell = (size.width - padding * 2) / 9;
    final cr = (ref.num - 1) ~/ 3;
    final cc = (ref.num - 1) % 3;
    return Offset(
      padding + ref.col * cell + (cc + 0.5) * (cell / 3),
      padding + ref.row * cell + (cr + 0.5) * (cell / 3),
    );
  }

  /// 同行/同列的链改走「折出 → 平移 → 折入」：直线会从头到尾压在
  /// 同一排候选数字上，折线把长的那一段挪到两排数字之间的空档里。
  List<Offset> _route(MarkupArrow arrow, Size size) {
    final a = _center(arrow.from, size);
    final b = _center(arrow.to, size);
    final sameRow = arrow.from.row == arrow.to.row;
    final sameCol = arrow.from.col == arrow.to.col;
    // 同格（都相同）和斜向（都不同）走直线。
    if (sameRow == sameCol) return [a, b];

    final cell = (size.width - padding * 2) / 9;
    // 空档正好在相邻两排候选中心的中点，是唯一躲得开候选圆圈的位置。
    final gutter = cell / 6;

    if (sameRow) {
      final lane = a.dy + gutter * _laneSign((arrow.from.num - 1) ~/ 3);
      final run = _riserRun(cell, (b.dx - a.dx).abs());
      final dir = b.dx >= a.dx ? 1.0 : -1.0;
      return [a, Offset(a.dx + dir * run, lane), Offset(b.dx - dir * run, lane), b];
    }

    final lane = a.dx + gutter * _laneSign((arrow.from.num - 1) % 3);
    final run = _riserRun(cell, (b.dy - a.dy).abs());
    final dir = b.dy >= a.dy ? 1.0 : -1.0;
    return [a, Offset(lane, a.dy + dir * run), Offset(lane, b.dy - dir * run), b];
  }

  /// 往格子内部的空档折：上排/左列往里，其余往回。
  double _laneSign(int index) => index == 0 ? 1 : -1;

  /// 折出、折入斜跨的距离；短链按一半距离收着走，避免两个折点交叉。
  /// 比小格宽（cell / 3）窄一点，好在碰到同格的邻居数字之前就爬上空档。
  double _riserRun(double cell, double span) {
    final run = cell / 4;
    return run * 2 <= span ? run : span / 2;
  }

  /// 两端各退开一点（棋盘 360 宽时约 6px），不压在数字上。
  List<Offset> _path(MarkupArrow arrow, Size size) {
    final points = _route(arrow, size);
    final inset = ((size.width - padding * 2) / 9) * 0.155;

    Offset? pull(Offset from, Offset toward) {
      final d = toward - from;
      final len = d.distance;
      if (len <= inset + 1) return null;
      return from + (d / len) * inset;
    }

    final head = pull(points.first, points[1]);
    final tail = pull(points.last, points[points.length - 2]);
    if (head == null || tail == null) return points;
    return [head, ...points.sublist(1, points.length - 1), tail];
  }

  /// 折点用二次贝塞尔抹开：折点当控制点，两侧各让出一段。
  /// 让出的长度给得很宽，所以折出那一小段整个变成弧线，
  /// 弧线末端的切线又正好接上平移段，全程没有硬角。
  Path buildPath(MarkupArrow arrow, Size size) {
    final points = _path(arrow, size);
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    final radius = (size.width - padding * 2) / 9 / 4;

    for (int i = 1; i < points.length - 1; i++) {
      final prev = points[i - 1];
      final corner = points[i];
      final next = points[i + 1];
      final inLen = (corner - prev).distance;
      final outLen = (next - corner).distance;
      if (inLen < 1 || outLen < 1) continue;
      // 端头那段可以整段吃掉；中间的平移段两个折点分，各占一半以内。
      final inBudget = i == 1 ? inLen : inLen / 2;
      final outBudget = i == points.length - 2 ? outLen : outLen / 2;
      final enter =
          corner - (corner - prev) / inLen * math.min(radius, inBudget);
      final exit =
          corner + (next - corner) / outLen * math.min(radius, outBudget);
      path.lineTo(enter.dx, enter.dy);
      path.quadraticBezierTo(corner.dx, corner.dy, exit.dx, exit.dy);
    }
    path.lineTo(points.last.dx, points.last.dy);
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    for (final arrow in markup.arrows) {
      final line = buildPath(arrow, size);
      final color = arrow.color ??
          switch (arrow.kind) {
            ArrowKind.weak => weakColor,
            ArrowKind.strong => strongColor,
          };
      final paint = Paint()
        ..color = color
        ..strokeWidth = arrow.kind == ArrowKind.weak ? 1.4 : 2
        ..style = PaintingStyle.stroke;

      canvas.drawPath(
        arrow.kind == ArrowKind.weak ? _dashed(line) : line,
        paint,
      );
      _arrowHead(canvas, line, color);
    }
  }

  Path _dashed(Path source) {
    const dash = 6.0;
    const gap = 4.0;
    final out = Path();
    for (final metric in source.computeMetrics()) {
      double t = 0;
      while (t < metric.length) {
        final n = math.min(t + dash, metric.length);
        out.addPath(metric.extractPath(t, n), Offset.zero);
        t = n + gap;
      }
    }
    return out;
  }

  void _arrowHead(Canvas canvas, Path line, Color color) {
    final metrics = line.computeMetrics().toList();
    if (metrics.isEmpty || metrics.last.length < 4) return;
    final tangent = metrics.last.getTangentForOffset(metrics.last.length);
    if (tangent == null) return;
    final tip = tangent.position;
    final dir = tangent.vector / tangent.vector.distance;
    final left = tip - dir * 8 + Offset(-dir.dy, dir.dx) * 4;
    final right = tip - dir * 8 + Offset(dir.dy, -dir.dx) * 4;
    final head = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(head, Paint()..color = color);
  }

  /// 测试用：退让后的整条折线。
  List<Offset> debugPath(MarkupArrow arrow, Size size) => _path(arrow, size);

  /// 测试用：退让前的两端。
  (Offset, Offset) debugCenters(MarkupArrow arrow, Size size) =>
      (_center(arrow.from, size), _center(arrow.to, size));

  @override
  bool shouldRepaint(BoardArrowsPainter old) =>
      old.markup != markup ||
      old.padding != padding ||
      old.strongColor != strongColor ||
      old.weakColor != weakColor;
}
