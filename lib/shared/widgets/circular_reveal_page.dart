import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/app_colors.dart';

/// Opens from the FAB with a visible colored expand + content fade/scale.
CustomTransitionPage<void> circularRevealPage({
  required GoRouterState state,
  required Widget child,
  required Offset origin,
  Duration duration = const Duration(milliseconds: 520),
  Duration reverseDuration = const Duration(milliseconds: 400),
}) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: duration,
    reverseTransitionDuration: reverseDuration,
    barrierDismissible: false,
    // Let the previous screen show around the expanding circle.
    opaque: false,
    barrierColor: Colors.transparent,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeInOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return AnimatedBuilder(
        animation: curved,
        builder: (context, child) {
          final progress = curved.value.clamp(0.0, 1.0);
          final size = MediaQuery.sizeOf(context);
          final center = Offset(
            origin.dx.clamp(0.0, size.width),
            origin.dy.clamp(0.0, size.height),
          );
          final maxRadius = _maxReach(size, center);
          final start = 29.0;
          final radius = start + (maxRadius - start) * progress;

          // Content appears after the color burst starts.
          final contentT =
              Curves.easeOutCubic.transform(((progress - 0.18) / 0.82).clamp(0.0, 1.0));
          final scale = 0.92 + (0.08 * contentT);

          return Stack(
            fit: StackFit.expand,
            children: [
              // Soft dim over the screen left behind.
              IgnorePointer(
                child: ColoredBox(
                  color: Colors.black.withValues(alpha: 0.28 * progress),
                ),
              ),
              // High-contrast FAB-colored burst — this is what you see expand.
              IgnorePointer(
                child: CustomPaint(
                  painter: _FabBurstPainter(
                    center: center,
                    radius: radius,
                    fill: AppColors.fab,
                    rim: AppColors.fabIcon,
                    progress: progress,
                  ),
                ),
              ),
              // Form grows out of that burst.
              ClipPath(
                clipper: _CircleRevealClipper(
                  center: center,
                  radius: radius,
                ),
                child: Opacity(
                  opacity: contentT,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment(
                      (center.dx / size.width) * 2 - 1,
                      (center.dy / size.height) * 2 - 1,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          );
        },
        child: child,
      );
    },
  );
}

double _maxReach(Size size, Offset c) {
  final corners = <Offset>[
    Offset.zero,
    Offset(size.width, 0),
    Offset(0, size.height),
    Offset(size.width, size.height),
  ];
  var max = 0.0;
  for (final p in corners) {
    max = math.max(max, (p - c).distance);
  }
  return max;
}

class _CircleRevealClipper extends CustomClipper<Path> {
  _CircleRevealClipper({
    required this.center,
    required this.radius,
  });

  final Offset center;
  final double radius;

  @override
  Path getClip(Size size) {
    return Path()..addOval(Rect.fromCircle(center: center, radius: radius));
  }

  @override
  bool shouldReclip(covariant _CircleRevealClipper oldClipper) {
    return oldClipper.center != center || oldClipper.radius != radius;
  }
}

class _FabBurstPainter extends CustomPainter {
  _FabBurstPainter({
    required this.center,
    required this.radius,
    required this.fill,
    required this.rim,
    required this.progress,
  });

  final Offset center;
  final double radius;
  final Color fill;
  final Color rim;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    // Fade the burst away as the form covers the screen.
    final burstAlpha = (1.0 - Curves.easeIn.transform(progress)).clamp(0.0, 1.0);
    if (burstAlpha <= 0.01) return;

    canvas.drawCircle(
      center,
      radius,
      Paint()..color = fill.withValues(alpha: 0.92 * burstAlpha + 0.08),
    );

    if (progress > 0.02 && progress < 0.95) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..color = rim.withValues(alpha: 0.45 * burstAlpha),
      );
      canvas.drawCircle(
        center,
        radius + 5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 10
          ..color = fill.withValues(alpha: 0.18 * burstAlpha),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _FabBurstPainter oldDelegate) {
    return oldDelegate.radius != radius ||
        oldDelegate.progress != progress ||
        oldDelegate.center != center ||
        oldDelegate.fill != fill ||
        oldDelegate.rim != rim;
  }
}
