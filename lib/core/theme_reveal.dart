import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Circular theme reveal that expands from a tap point.
class ThemeRevealController extends ChangeNotifier {
  ThemeRevealController();

  final GlobalKey boundaryKey = GlobalKey(debugLabel: 'themeRevealBoundary');

  ui.Image? snapshot;
  Offset center = Offset.zero;
  double progress = 0;
  bool active = false;
  bool _busy = false;

  Future<void> revealFrom({
    required Offset globalCenter,
    required Future<void> Function() switchTheme,
  }) async {
    if (_busy) return;
    _busy = true;

    final boundary =
        boundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null) {
      await switchTheme();
      _busy = false;
      return;
    }

    final dpr = ui.PlatformDispatcher.instance.views.first.devicePixelRatio;
    late final ui.Image image;
    try {
      image = await boundary.toImage(pixelRatio: dpr);
    } catch (_) {
      await switchTheme();
      _busy = false;
      return;
    }

    snapshot = image;
    center = boundary.globalToLocal(globalCenter);
    progress = 0;
    active = true;
    notifyListeners();

    // Paint frozen frame once, then flip theme underneath.
    await Future<void>.delayed(Duration.zero);
    await switchTheme();
    await Future<void>.delayed(Duration.zero);

    const steps = 52;
    const totalMs = 560;
    final stepMs = (totalMs / steps).round().clamp(8, 24);
    for (var i = 1; i <= steps; i++) {
      progress = Curves.easeInOutCubic.transform(i / steps);
      notifyListeners();
      await Future<void>.delayed(Duration(milliseconds: stepMs));
    }

    snapshot?.dispose();
    snapshot = null;
    active = false;
    progress = 0;
    notifyListeners();
    _busy = false;
  }

  @override
  void dispose() {
    snapshot?.dispose();
    super.dispose();
  }
}

class ThemeRevealScope extends InheritedNotifier<ThemeRevealController> {
  const ThemeRevealScope({
    super.key,
    required ThemeRevealController controller,
    required super.child,
  }) : super(notifier: controller);

  static ThemeRevealController of(BuildContext context) {
    final scope =
        context.dependOnInheritedWidgetOfExactType<ThemeRevealScope>();
    assert(scope != null, 'ThemeRevealScope not found');
    return scope!.notifier!;
  }
}

class ThemeRevealLayer extends StatelessWidget {
  const ThemeRevealLayer({
    super.key,
    required this.controller,
    required this.child,
  });

  final ThemeRevealController controller;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        return RepaintBoundary(
          key: controller.boundaryKey,
          child: Stack(
            fit: StackFit.expand,
            children: [
              child,
              if (controller.active && controller.snapshot != null)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _RevealPainter(
                        image: controller.snapshot!,
                        center: controller.center,
                        progress: controller.progress,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Old screenshot with a growing clear hole so the new theme shows through.
class _RevealPainter extends CustomPainter {
  _RevealPainter({
    required this.image,
    required this.center,
    required this.progress,
  });

  final ui.Image image;
  final Offset center;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final dst = Offset.zero & size;
    final maxRadius = _maxReach(size, center);
    final radius = maxRadius * progress.clamp(0.0, 1.0);

    canvas.saveLayer(dst, Paint());
    paintImage(
      canvas: canvas,
      rect: dst,
      image: image,
      fit: BoxFit.fill,
      filterQuality: FilterQuality.medium,
    );
    canvas.drawCircle(
      center,
      radius,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();

    if (progress > 0.02 && progress < 0.98) {
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5
          ..color = Colors.white.withValues(alpha: 0.22 * (1 - progress)),
      );
    }
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

  @override
  bool shouldRepaint(covariant _RevealPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.center != center ||
        oldDelegate.image != image;
  }
}
