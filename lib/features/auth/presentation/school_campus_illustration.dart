import 'package:flutter/material.dart';

/// Lightweight scalable illustration; avoids stock imagery or network requests.
class SchoolCampusIllustration extends StatelessWidget {
  const SchoolCampusIllustration({super.key});

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return AspectRatio(
      aspectRatio: 2.75,
      child: CustomPaint(
        painter: _CampusPainter(
          ink: dark ? const Color(0xFF69D2C0) : const Color(0xFF087866),
          cloud: dark ? const Color(0xFF1A4C53) : const Color(0xFFD8F1E9),
        ),
      ),
    );
  }
}

class _CampusPainter extends CustomPainter {
  _CampusPainter({required this.ink, required this.cloud});

  final Color ink;
  final Color cloud;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 600, size.height / 218);
    final line = Paint()
      ..color = ink
      ..strokeWidth = 4
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final fillCloud = Paint()..color = cloud;

    void segment(List<Offset> points, {Paint? paint}) {
      final path = Path()..moveTo(points.first.dx, points.first.dy);
      for (final p in points.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(path, paint ?? line);
    }

    void rect(double x, double y, double w, double h) =>
        canvas.drawRect(Rect.fromLTWH(x, y, w, h), line);

    // Gentle clouds behind the building.
    canvas.drawOval(Rect.fromLTWH(55, 51, 150, 30), fillCloud);
    canvas.drawOval(Rect.fromLTWH(82, 31, 70, 56), fillCloud);
    canvas.drawOval(Rect.fromLTWH(400, 34, 120, 28), fillCloud);
    canvas.drawOval(Rect.fromLTWH(430, 15, 62, 48), fillCloud);

    // School building, pitched roof, flag and base.
    segment([const Offset(154, 193), const Offset(154, 93),
      const Offset(243, 93)]);
    segment([const Offset(345, 93), const Offset(439, 93),
      const Offset(439, 193)]);
    segment([const Offset(140, 93), const Offset(182, 53),
      const Offset(245, 53)]);
    segment([const Offset(345, 53), const Offset(410, 53),
      const Offset(454, 93)]);
    segment([const Offset(235, 86), const Offset(297, 28),
      const Offset(359, 86)]);
    segment([const Offset(248, 193), const Offset(248, 87),
      const Offset(297, 43), const Offset(346, 87),
      const Offset(346, 193)]);
    rect(167, 114, 62, 39);
    rect(365, 114, 62, 39);
    rect(260, 110, 74, 34);
    rect(274, 158, 46, 35);
    segment([const Offset(297, 158), const Offset(297, 193)]);
    for (final x in [187.0, 386.0, 283.0, 310.0]) {
      if (x == 283 || x == 310) continue;
      segment([Offset(x + 12, 114), Offset(x + 12, 153)]);
      segment([Offset(x - 20, 133), Offset(x + 41, 133)]);
    }
    canvas.drawCircle(const Offset(297, 75), 8, line);
    segment([const Offset(297, 29), const Offset(297, 5)]);
    segment([const Offset(297, 5), const Offset(329, 12),
      const Offset(297, 19)]);
    segment([const Offset(123, 194), const Offset(459, 194)]);
    segment([const Offset(239, 201), const Offset(355, 201)]);

    // Tree.
    canvas.drawCircle(const Offset(97, 147), 27, line);
    canvas.drawCircle(const Offset(76, 157), 24, line);
    canvas.drawCircle(const Offset(112, 164), 22, line);
    segment([const Offset(96, 167), const Offset(96, 194)]);
    segment([const Offset(96, 179), const Offset(78, 164)]);
    // Academic books and graduation cap, to echo the supplied reference.
    for (final y in [167.0, 178.0, 189.0]) {
      segment([Offset(468, y), Offset(545, y),
        Offset(541, y + 8), Offset(471, y + 8)]);
    }
    segment([const Offset(467, 136), const Offset(516, 115),
      const Offset(567, 136), const Offset(516, 154),
      const Offset(467, 136)]);
    segment([const Offset(487, 146), const Offset(487, 161),
      const Offset(544, 161), const Offset(544, 146)]);
    segment([const Offset(565, 136), const Offset(565, 161)]);
    canvas.drawCircle(const Offset(565, 163), 3, line);
    segment([const Offset(36, 207), const Offset(575, 207)]);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CampusPainter oldDelegate) =>
      oldDelegate.ink != ink || oldDelegate.cloud != cloud;
}
