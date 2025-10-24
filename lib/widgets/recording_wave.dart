import 'package:flutter/material.dart';
import 'dart:math' as math;

class RecordingWave extends StatelessWidget {
  final AnimationController animation;
  final bool isAnalyzing;

  const RecordingWave({
    super.key,
    required this.animation,
    required this.isAnalyzing,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      child: isAnalyzing
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Analyzing your breathing pattern...'),
                ],
              ),
            )
          : CustomPaint(
              painter: WavePainter(
                animation: animation,
                color: Theme.of(context).primaryColor,
              ),
            ),
    );
  }
}

class WavePainter extends CustomPainter {
  final Animation<double> animation;
  final Color color;
  final Paint wavePaint;
  final int waveCount = 3;

  WavePainter({required this.animation, required this.color})
      : wavePaint = Paint()
          ..color = color.withValues(alpha: 0.4)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.0,
        super(repaint: animation);

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;
    final centerY = height / 2;
    final amplitude = height / 6;
    final frequency = math.pi / 180;

    for (var i = 0; i < waveCount; i++) {
      final path = Path();
      final opacity = 1.0 - (i * 0.3);
      wavePaint.color = color.withValues(alpha: math.max(0.1, opacity));

      for (var x = 0.0; x < width; x++) {
        final y = centerY +
            math.sin((x * frequency) - (animation.value * 2 * math.pi) + (i * math.pi / 2)) *
                amplitude *
                math.sin(math.pi * x / width);
        
        if (x == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
      }

      canvas.drawPath(path, wavePaint);
    }
  }

  @override
  bool shouldRepaint(WavePainter oldDelegate) =>
      animation != oldDelegate.animation || color != oldDelegate.color;
}
