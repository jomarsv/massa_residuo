import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../data/models/normalized_point.dart';

class RulerPointSelector extends StatelessWidget {
  const RulerPointSelector({
    super.key,
    required this.imageBytes,
    required this.aspectRatio,
    required this.points,
    required this.onTapNormalized,
  });

  final Uint8List imageBytes;
  final double aspectRatio;
  final List<NormalizedPoint> points;
  final ValueChanged<NormalizedPoint> onTapNormalized;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: LayoutBuilder(
        builder: (context, constraints) {
          return GestureDetector(
            onTapDown: (details) {
              final normalized = NormalizedPoint(
                x: (details.localPosition.dx / constraints.maxWidth).clamp(
                  0.0,
                  1.0,
                ),
                y: (details.localPosition.dy / constraints.maxHeight).clamp(
                  0.0,
                  1.0,
                ),
              );
              onTapNormalized(normalized);
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.memory(imageBytes, fit: BoxFit.fill),
                ),
                CustomPaint(painter: _RulerSelectionPainter(points: points)),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _RulerSelectionPainter extends CustomPainter {
  const _RulerSelectionPainter({required this.points});

  final List<NormalizedPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    final linePaint = Paint()
      ..color = const Color(0xFFE6582B)
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    final fillPaint = Paint()
      ..color = const Color(0xFFE6582B)
      ..style = PaintingStyle.fill;
    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      text: const TextSpan(
        text: '1 m',
        style: TextStyle(
          color: Color(0xFFE6582B),
          fontSize: 14,
          fontWeight: FontWeight.w700,
        ),
      ),
    )..layout();

    final offsets = points
        .map((point) => Offset(point.x * size.width, point.y * size.height))
        .toList();

    if (offsets.length == 2) {
      canvas.drawLine(offsets[0], offsets[1], linePaint);
      final labelOffset = Offset(
        (offsets[0].dx + offsets[1].dx) / 2 - textPainter.width / 2,
        (offsets[0].dy + offsets[1].dy) / 2 - 28,
      );
      textPainter.paint(canvas, labelOffset);
    }

    for (var index = 0; index < offsets.length; index++) {
      final offset = offsets[index];
      canvas.drawCircle(offset, 8, fillPaint);
      final markerPainter = TextPainter(
        textDirection: TextDirection.ltr,
        text: TextSpan(
          text: '${index + 1}',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 11,
            fontWeight: FontWeight.w700,
          ),
        ),
      )..layout();
      markerPainter.paint(
        canvas,
        Offset(offset.dx - markerPainter.width / 2, offset.dy - 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _RulerSelectionPainter oldDelegate) {
    return oldDelegate.points != points;
  }
}
