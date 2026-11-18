import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/app_colors.dart';
import '../../core/theme_rebuild_scope.dart';
import 'wellin_logo.dart';

/// Branded Wellin loader — use for full-screen waits and compact button states.
class AppLoader extends StatefulWidget {
  const AppLoader({
    super.key,
    this.message,
    this.size = 56,
    this.compact = false,
    this.color,
  });

  /// Centered full-page loader.
  const AppLoader.page({
    super.key,
    this.message,
    this.color,
  })  : size = 64,
        compact = false;

  /// Small spinner for buttons / inline rows.
  const AppLoader.inline({
    super.key,
    this.size = 18,
    this.color,
  })  : message = null,
        compact = true;

  final String? message;
  final double size;
  final bool compact;
  final Color? color;

  @override
  State<AppLoader> createState() => _AppLoaderState();
}

class _AppLoaderState extends State<AppLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ThemeRebuildScope.depend(context);
    final color = widget.color ?? AppColors.primary;
    final markSize = widget.compact ? widget.size * 0.55 : widget.size * 0.42;

    final spinner = SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder( 
        animation: _controller,
        builder: (context, _) {
          final t = _controller.value;
          final pulse = 0.92 + 0.08 * math.sin(t * math.pi * 2);
          return Stack(
            alignment: Alignment.center,
            children: [
              CustomPaint(
                size: Size.square(widget.size),
                painter: _OrbitPainter(
                  progress: t,
                  color: color,
                  soft: AppColors.primaryMuted,
                  compact: widget.compact,
                ),
              ),
              if (!widget.compact)
                Transform.scale(
                  scale: pulse,
                  child: Opacity(
                    opacity: 0.88 + 0.12 * math.sin(t * math.pi * 2),
                    child: Image.asset(
                      AppColors.isLight
                          ? WellinLogo.assetBlack
                          : WellinLogo.assetWhite,
                      width: markSize,
                      height: markSize,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.high,
                    ),
                  ),
                )
              else
                Container(
                  width: markSize,
                  height: markSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color.withValues(alpha: 0.85),
                  ),
                ),
            ],
          );
        },
      ),
    );

    if (widget.compact) return spinner;

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          spinner,
          if (widget.message != null) ...[
            const SizedBox(height: 18),
            Text(
              widget.message!,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter({
    required this.progress,
    required this.color,
    required this.soft,
    required this.compact,
  });

  final double progress;
  final Color color;
  final Color soft;
  final bool compact;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final stroke = compact ? 2.2 : 3.0;
    final radius = (size.shortestSide - stroke) / 2;

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = soft
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(center, radius, track);

    final sweep = compact ? math.pi * 0.9 : math.pi * 1.15;
    final start = progress * math.pi * 2;

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: 0,
        endAngle: math.pi * 2,
        colors: [
          color.withValues(alpha: 0.05),
          color.withValues(alpha: 0.55),
          color,
          color.withValues(alpha: 0.05),
        ],
        transform: GradientRotation(start),
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      start,
      sweep,
      false,
      arc,
    );

    if (!compact) {
      final reverse = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke * 0.7
        ..strokeCap = StrokeCap.round
        ..color = AppColors.accent.withValues(alpha: 0.55);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius * 0.72),
        -start * 1.35,
        math.pi * 0.7,
        false,
        reverse,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.color != color ||
        oldDelegate.soft != soft ||
        oldDelegate.compact != compact;
  }
}
