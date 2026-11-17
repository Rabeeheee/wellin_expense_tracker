import 'package:flutter/material.dart';

/// Keeps all shell tab Navigators alive and cross-fades/slides when switching.
class AnimatedBranchContainer extends StatefulWidget {
  const AnimatedBranchContainer({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<AnimatedBranchContainer> createState() =>
      _AnimatedBranchContainerState();
}

class _AnimatedBranchContainerState extends State<AnimatedBranchContainer>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late int _fromIndex;
  late int _toIndex;

  static const _duration = Duration(milliseconds: 280);

  @override
  void initState() {
    super.initState();
    _fromIndex = widget.currentIndex;
    _toIndex = widget.currentIndex;
    _controller = AnimationController(vsync: this, duration: _duration)
      ..value = 1;
  }

  @override
  void didUpdateWidget(covariant AnimatedBranchContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _fromIndex = oldWidget.currentIndex;
      _toIndex = widget.currentIndex;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final forward = _toIndex >= _fromIndex;
    final slideIn = forward ? const Offset(0.08, 0) : const Offset(-0.08, 0);
    final slideOut = forward ? const Offset(-0.08, 0) : const Offset(0.08, 0);

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeOutCubic.transform(_controller.value);

        return Stack(
          fit: StackFit.expand,
          children: [
            for (var index = 0; index < widget.children.length; index++)
              _buildLayer(
                index: index,
                t: t,
                slideIn: slideIn,
                slideOut: slideOut,
                child: widget.children[index],
              ),
          ],
        );
      },
    );
  }

  Widget _buildLayer({
    required int index,
    required double t,
    required Offset slideIn,
    required Offset slideOut,
    required Widget child,
  }) {
    final isTo = index == _toIndex;
    final isFrom = index == _fromIndex && _fromIndex != _toIndex;

    double opacity;
    Offset offset;

    if (isTo) {
      opacity = t;
      offset = Offset.lerp(slideIn, Offset.zero, t)!;
    } else if (isFrom) {
      opacity = 1 - t;
      offset = Offset.lerp(Offset.zero, slideOut, t)!;
    } else {
      opacity = 0;
      offset = Offset.zero;
    }

    final active = index == widget.currentIndex;

    return IgnorePointer(
      ignoring: !active,
      child: TickerMode(
        enabled: active,
        child: Opacity(
          opacity: opacity.clamp(0.0, 1.0),
          child: FractionalTranslation(
            translation: offset,
            child: child,
          ),
        ),
      ),
    );
  }
}
