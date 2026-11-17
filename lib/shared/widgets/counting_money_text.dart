import 'package:flutter/material.dart';

import '../utils/formatters.dart';

/// Money text that counts from the previous value to [value].
class CountingMoneyText extends ImplicitlyAnimatedWidget {
  const CountingMoneyText({
    super.key,
    required this.value,
    required this.style,
    this.maxLines,
    this.overflow,
    super.duration = const Duration(milliseconds: 420),
    super.curve = Curves.easeOutCubic,
  });

  final double value;
  final TextStyle style;
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  ImplicitlyAnimatedWidgetState<CountingMoneyText> createState() =>
      _CountingMoneyTextState();
}

class _CountingMoneyTextState
    extends AnimatedWidgetBaseState<CountingMoneyText> {
  Tween<double>? _value;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _value = visitor(
      _value,
      widget.value,
      (dynamic v) => Tween<double>(begin: v as double),
    ) as Tween<double>?;
  }

  @override
  Widget build(BuildContext context) {
    final amount = _value?.evaluate(animation) ?? widget.value;
    return Text(
      formatMoney(amount),
      style: widget.style,
      maxLines: widget.maxLines,
      overflow: widget.overflow,
    );
  }
}
