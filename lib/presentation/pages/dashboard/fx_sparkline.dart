import 'package:flutter/material.dart';

import '../../../domain/entities/dashboard_summary.dart';

/// A minimal line chart of the USD/KRW history — drawn with [CustomPaint] so
/// the app pulls in no charting dependency. Renders a smooth-ish polyline with
/// a soft gradient fill and a dot on the latest point.
class FxSparkline extends StatelessWidget {
  const FxSparkline({
    super.key,
    required this.points,
    required this.color,
    this.height = 72,
  });

  final List<FxPoint> points;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _SparklinePainter(points: points, color: color),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.points, required this.color});

  final List<FxPoint> points;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;

    var min = points.first.rate;
    var max = points.first.rate;
    for (final p in points) {
      if (p.rate < min) min = p.rate;
      if (p.rate > max) max = p.rate;
    }
    final range = (max - min).abs() < 1e-9 ? 1.0 : max - min;

    // Leave a little vertical breathing room so the line never touches edges.
    const padY = 6.0;
    final usableH = size.height - padY * 2;
    final dx = size.width / (points.length - 1);

    Offset offsetFor(int i) {
      final norm = (points[i].rate - min) / range; // 0 (min) .. 1 (max)
      final y = padY + (1 - norm) * usableH;
      return Offset(dx * i, y);
    }

    final line = Path()..moveTo(0, offsetFor(0).dy);
    for (var i = 1; i < points.length; i++) {
      final o = offsetFor(i);
      line.lineTo(o.dx, o.dy);
    }

    // Gradient fill under the line.
    final fill = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [color.withValues(alpha: 0.18), color.withValues(alpha: 0.0)],
        ).createShader(Offset.zero & size),
    );

    // The line itself.
    canvas.drawPath(
      line,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    // Latest-point dot.
    final last = offsetFor(points.length - 1);
    canvas.drawCircle(last, 3.5, Paint()..color = color);
    canvas.drawCircle(
      last,
      3.5,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_SparklinePainter old) =>
      old.points != points || old.color != color;
}
