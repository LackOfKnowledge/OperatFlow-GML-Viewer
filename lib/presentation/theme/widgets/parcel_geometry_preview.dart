import 'package:flutter/material.dart';
import 'package:gmlviewer/data/models/parcel.dart';

class ParcelGeometryPreview extends StatelessWidget {
  final Parcel parcel;

  const ParcelGeometryPreview({super.key, required this.parcel});

  @override
  Widget build(BuildContext context) {
    if (parcel.geometryPoints.isEmpty) {
      return Container(
        height: 200,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Colors.grey.shade50,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.format_shapes, size: 48, color: Colors.grey.shade300),
            const SizedBox(height: 8),
            const Text('Brak geometrii', style: TextStyle(color: Colors.grey)),
          ],
        ),
      );
    }

    return Container(
      height: 300,
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: CustomPaint(
          painter: GeometryPainter(
            points: parcel.geometryPoints,
            color: const Color(0xFF3498DB),
          ),
        ),
      ),
    );
  }
}

class GeometryPainter extends CustomPainter {
  final List<ParsedPoint> points;
  final Color color;

  GeometryPainter({required this.points, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    final paintStroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    double minX = double.infinity, maxX = double.negativeInfinity;
    double minY = double.infinity, maxY = double.negativeInfinity;

    for (var p in points) {
      if (p.y < minX) minX = p.y;
      if (p.y > maxX) maxX = p.y;
      if (p.x < minY) minY = p.x;
      if (p.x > maxY) maxY = p.x;
    }
    
    final w = maxX - minX;
    final h = maxY - minY;
    if (w == 0 || h == 0) return;

    final scaleX = (size.width - 20) / w;
    final scaleY = (size.height - 20) / h;
    final scale = scaleX < scaleY ? scaleX : scaleY;

    final offsetX = (size.width - w * scale) / 2;
    final offsetY = (size.height - h * scale) / 2;

    final path = Path();
    final startX = (points[0].y - minX) * scale + offsetX;
    final startY = (maxY - points[0].x) * scale + offsetY;
    path.moveTo(startX, startY);

    for (int i = 1; i < points.length; i++) {
      final x = (points[i].y - minX) * scale + offsetX;
      final y = (maxY - points[i].x) * scale + offsetY;
      path.lineTo(x, y);
    }
    path.close();
    canvas.drawPath(path, paintStroke);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}