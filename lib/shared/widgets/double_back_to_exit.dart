import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Requires a second Android system Back action to exit at the root route.
class DoubleBackToExit extends StatefulWidget {
  const DoubleBackToExit({
    super.key,
    required this.child,
    required this.navigatorKey,
  });

  final Widget child;
  final GlobalKey<NavigatorState> navigatorKey;

  @override
  State<DoubleBackToExit> createState() => _DoubleBackToExitState();
}

class _DoubleBackToExitState extends State<DoubleBackToExit>
    with WidgetsBindingObserver {
  static const _exitWindow = Duration(seconds: 2);

  Timer? _resetTimer;
  bool _backPressedOnce = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _resetTimer?.cancel();
    super.dispose();
  }

  @override
  Future<bool> didPopRoute() async {
    if (defaultTargetPlatform != TargetPlatform.android ||
        widget.navigatorKey.currentState?.canPop() != false) {
      return false;
    }

    if (_backPressedOnce) {
      _resetTimer?.cancel();
      _backPressedOnce = false;
      await SystemNavigator.pop();
      return true;
    }

    _backPressedOnce = true;
    _resetTimer?.cancel();
    _resetTimer = Timer(_exitWindow, () => _backPressedOnce = false);
    ScaffoldMessenger.maybeOf(context)?.showSnackBar(
      const SnackBar(
        content: Text('Presiona atrás otra vez para salir'),
        duration: _exitWindow,
      ),
    );
    return true;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
