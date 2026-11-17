import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

/// Wraps each shell branch page (inside that branch's nested [Navigator]).
///
/// [PopScope] must live here — not on [ShellScaffold] — or Android back never
/// sees `canPop: false` and the Activity finishes instead.
class ShellTabBackScope extends StatefulWidget {
  const ShellTabBackScope({
    super.key,
    required this.child,
    required this.tabPath,
    this.isHome = false,
  });

  final Widget child;
  final String tabPath;
  final bool isHome;

  @override
  State<ShellTabBackScope> createState() => _ShellTabBackScopeState();
}

class _ShellTabBackScopeState extends State<ShellTabBackScope>
    with WidgetsBindingObserver {
  DateTime? _lastBackAt;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  bool get _isCurrentTab {
    if (!mounted) return false;
    final loc =
        GoRouter.of(context).routerDelegate.currentConfiguration.uri.path;
    return loc == widget.tabPath;
  }

  @override
  Future<bool> didPopRoute() async {
    if (!_isCurrentTab) return false;
    await _onBack();
    return true;
  }

  Future<void> _onBack() async {
    if (_busy) return;
    _busy = true;
    try {
      if (!widget.isHome) {
        if (mounted) context.go('/home');
        return;
      }

      final now = DateTime.now();
      final last = _lastBackAt;
      if (last == null || now.difference(last) > const Duration(seconds: 2)) {
        _lastBackAt = now;
        if (!mounted) return;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            const SnackBar(
              content: Text('Press back again to exit'),
              duration: Duration(seconds: 2),
            ),
          );
        return;
      }

      await SystemNavigator.pop();
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (!_isCurrentTab) return;
        _onBack();
      },
      child: widget.child,
    );
  }
}
