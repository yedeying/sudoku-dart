import 'package:flutter/material.dart';
import '../models/board_markup.dart';

class BoardArrowsPainter extends CustomPainter {
  final BoardMarkup markup;
  final double padding;

  BoardArrowsPainter({required this.markup, this.padding = 4});

  @override
  void paint(Canvas canvas, Size size) {
    final inner = Size(size.width - padding * 2, size.height - padding * 2);
    final cell = inner.width / 9;

    Offset candidateCenter(CandidateRef ref) {
      final cr = (ref.num - 1) ~/ 3;
      final cc = (ref.num - 1) % 3;
      return Offset(
        padding + ref.col * cell + (cc + 0.5) * (cell / 3),
        padding + ref.row * cell + (cr + 0.5) * (cell / 3),
      );
    }

    for (final arrow in markup.arrows) {
      final p1 = candidateCenter(arrow.from);
      final p2 = candidateCenter(arrow.to);
      final paint = Paint()
        ..color = switch (arrow.kind) {
          ArrowKind.weak => Colors.grey.shade700,
          ArrowKind.strong => Colors.indigo,
          ArrowKind.conjugate => Colors.deepPurple,
        }
        ..strokeWidth = arrow.kind == ArrowKind.weak ? 1.2 : 2
        ..style = PaintingStyle.stroke;

      if (arrow.kind == ArrowKind.weak) {
        _dashed(canvas, p1, p2, paint);
      } else {
        canvas.drawLine(p1, p2, paint);
      }
      _arrowHead(canvas, p1, p2, paint.color);
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final d = (b - a);
    final len = d.distance;
    if (len < 1) return;
    final dir = d / len;
    double t = 0;
    const dash = 6.0;
    const gap = 4.0;
    while (t < len) {
      final n = (t + dash).clamp(0.0, len).toDouble();
      canvas.drawLine(a + dir * t, a + dir * n, paint);
      t += dash + gap;
    }
  }

  void _arrowHead(Canvas canvas, Offset a, Offset b, Color color) {
    final d = b - a;
    final len = d.distance;
    if (len < 4) return;
    final dir = d / len;
    final tip = b;
    final left = tip - dir * 8 + Offset(-dir.dy, dir.dx) * 4;
    final right = tip - dir * 8 + Offset(dir.dy, -dir.dx) * 4;
    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(BoardArrowsPainter old) => old.markup != markup;
}
