import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../models/measurement_point.dart';

class HistogramImageRenderer {
  static const List<double> buckets = [
    -1.0, -0.875, -0.75, -0.625, -0.5, -0.375, -0.25, -0.125,
    0.0,
    0.125, 0.25, 0.375, 0.5, 0.625, 0.75, 0.875, 1.0,
  ];

  /// Renders a crisp, high-resolution (800x420) histogram chart into PNG bytes.
  static Future<Uint8List> renderHistogramPng({
    required List<double> deviations,
    required double tolerance,
    String title = 'Measurement Deviation Histogram',
    String subtitle = '',
    int width = 800,
    int height = 420,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()));

    // 1. Background
    final bgPaint = Paint()..color = const Color(0xFFFFFFFF);
    canvas.drawRect(Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()), bgPaint);

    // Subtle container border
    final borderPaint = Paint()
      ..color = const Color(0xFFE2E8F0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(1, 1, width - 2.0, height - 2.0), const Radius.circular(8)),
      borderPaint,
    );

    // 2. Title Header
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title.toUpperCase(),
        style: const TextStyle(
          color: Color(0xFF0F172A),
          fontSize: 16,
          fontWeight: FontWeight.w900,
          letterSpacing: 0.5,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    titlePainter.paint(canvas, const Offset(24, 18));

    if (subtitle.isNotEmpty) {
      final subPainter = TextPainter(
        text: TextSpan(
          text: subtitle,
          style: const TextStyle(
            color: Color(0xFF64748B),
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      subPainter.paint(canvas, const Offset(24, 40));
    }

    // 3. Compute Bucket Counts
    final counts = List<int>.filled(buckets.length, 0);
    int inTolCount = 0;
    int outTolCount = 0;

    for (final dev in deviations) {
      int bestIdx = 0;
      double minDiff = (dev - buckets[0]).abs();
      for (int i = 1; i < buckets.length; i++) {
        final diff = (dev - buckets[i]).abs();
        if (diff < minDiff) {
          minDiff = diff;
          bestIdx = i;
        }
      }
      counts[bestIdx]++;

      if (dev.abs() <= (tolerance + 0.0001)) {
        inTolCount++;
      } else {
        outTolCount++;
      }
    }

    final rawMax = counts.isEmpty ? 1 : counts.reduce((a, b) => a > b ? a : b);
    final maxCount = rawMax <= 0 ? 1 : rawMax;

    // 4. Plot Area Dimensions
    const double plotLeft = 60.0;
    final double plotRight = width - 30.0;
    const double plotTop = 75.0;
    const double plotBottom = 330.0;
    final double plotWidth = plotRight - plotLeft;
    const double plotHeight = plotBottom - plotTop;

    // Grid lines (Horizontal)
    final gridPaint = Paint()
      ..color = const Color(0xFFF1F5F9)
      ..strokeWidth = 1.0;
    final axisLinePaint = Paint()
      ..color = const Color(0xFF94A3B8)
      ..strokeWidth = 1.5;

    final int gridSteps = maxCount <= 5 ? maxCount : 5;
    for (int i = 0; i <= gridSteps; i++) {
      final yVal = (maxCount * (i / gridSteps)).round();
      final yPos = plotBottom - (yVal / maxCount) * plotHeight;

      canvas.drawLine(Offset(plotLeft, yPos), Offset(plotRight, yPos), gridPaint);

      final labelPainter = TextPainter(
        text: TextSpan(
          text: '$yVal',
          style: const TextStyle(
            color: Color(0xFF94A3B8),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.right,
      )..layout(maxWidth: 40);
      labelPainter.paint(canvas, Offset(plotLeft - labelPainter.width - 8, yPos - 6));
    }

    // Baseline
    canvas.drawLine(const Offset(plotLeft, plotBottom), Offset(plotRight, plotBottom), axisLinePaint);

    // 5. Draw Bars & Labels
    final double barSlotWidth = plotWidth / buckets.length;
    final double barWidth = barSlotWidth * 0.72;

    for (int i = 0; i < buckets.length; i++) {
      final bucket = buckets[i];
      final count = counts[i];
      final isZero = bucket == 0.0;
      final isWithin = bucket.abs() <= (tolerance + 0.0001);

      final barHeight = (count / maxCount) * (plotHeight - 15);
      final barX = plotLeft + (i * barSlotWidth) + ((barSlotWidth - barWidth) / 2);
      final barY = plotBottom - barHeight;

      // Determine bar color
      Color barColor;
      if (count == 0) {
        barColor = const Color(0xFFE2E8F0);
      } else if (isZero) {
        barColor = const Color(0xFF0284C7); // Primary Royal Blue
      } else if (isWithin) {
        barColor = const Color(0xFF38BDF8); // Within Tol Cyan
      } else {
        barColor = const Color(0xFFEF4444); // Defect Red
      }

      final barPaint = Paint()..color = barColor;

      if (count > 0) {
        // Draw rounded top bar
        final barRect = Rect.fromLTWH(barX, barY, barWidth, barHeight);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            barRect,
            topLeft: const Radius.circular(4),
            topRight: const Radius.circular(4),
          ),
          barPaint,
        );

        // Count on top of bar
        final countPainter = TextPainter(
          text: TextSpan(
            text: '$count',
            style: TextStyle(
              color: barColor == const Color(0xFFEF4444) ? const Color(0xFFDC2626) : const Color(0xFF0F172A),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
          textAlign: TextAlign.center,
        )..layout();
        countPainter.paint(canvas, Offset(barX + (barWidth - countPainter.width) / 2, barY - 14));
      } else {
        // Zero count dot / baseline marker
        canvas.drawCircle(Offset(barX + barWidth / 2, plotBottom - 2), 2, barPaint);
      }

      // X-Axis Bucket Label
      final labelStr = formatDeviation(bucket);
      final xLabelPainter = TextPainter(
        text: TextSpan(
          text: labelStr,
          style: TextStyle(
            color: isZero ? const Color(0xFF0284C7) : const Color(0xFF475569),
            fontSize: 9.5,
            fontWeight: isZero ? FontWeight.w900 : FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      )..layout();
      xLabelPainter.paint(
        canvas,
        Offset(barX + (barWidth - xLabelPainter.width) / 2, plotBottom + 6),
      );
    }

    // 6. Tolerance Boundary Visual Indicators
    int posTolIdx = -1;
    int negTolIdx = -1;
    for (int i = 0; i < buckets.length; i++) {
      if ((buckets[i] - tolerance).abs() < 0.001) posTolIdx = i;
      if ((buckets[i] - (-tolerance)).abs() < 0.001) negTolIdx = i;
    }

    void drawTolLine(int idx, String label) {
      if (idx >= 0 && idx < buckets.length) {
        final x = plotLeft + (idx * barSlotWidth) + (barSlotWidth / 2);
        final tolPaint = Paint()
          ..color = const Color(0xFF10B981)
          ..strokeWidth = 1.5
          ..style = PaintingStyle.stroke;

        // Dashed line
        double curY = plotTop;
        while (curY < plotBottom) {
          canvas.drawLine(Offset(x, curY), Offset(x, (curY + 5).clamp(plotTop, plotBottom)), tolPaint);
          curY += 9;
        }

        final tLabel = TextPainter(
          text: TextSpan(
            text: label,
            style: const TextStyle(
              color: Color(0xFF059669),
              fontSize: 9,
              fontWeight: FontWeight.w800,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        tLabel.paint(canvas, Offset(x - tLabel.width / 2, plotTop - 14));
      }
    }

    drawTolLine(posTolIdx, '+$tolerance"');
    drawTolLine(negTolIdx, '-$tolerance"');

    // 7. Legend at Bottom
    const double legendY = 370.0;
    _drawLegendItem(canvas, const Offset(120, legendY), const Color(0xFF38BDF8), 'Within Tolerance ($inTolCount pcs)');
    _drawLegendItem(canvas, const Offset(360, legendY), const Color(0xFF0284C7), 'Nominal 0 Spec');
    _drawLegendItem(canvas, const Offset(550, legendY), const Color(0xFFEF4444), 'Out of Tolerance ($outTolCount pcs)');

    // 8. Convert to PNG
    final picture = recorder.endRecording();
    final img = await picture.toImage(width, height);
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  static void _drawLegendItem(Canvas canvas, Offset offset, Color color, String label) {
    final boxPaint = Paint()..color = color;
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(offset.dx, offset.dy + 2, 10, 10), const Radius.circular(2)),
      boxPaint,
    );

    final textPainter = TextPainter(
      text: TextSpan(
        text: label,
        style: const TextStyle(
          color: Color(0xFF334155),
          fontSize: 11,
          fontWeight: FontWeight.w700,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    textPainter.paint(canvas, Offset(offset.dx + 16, offset.dy));
  }
}
