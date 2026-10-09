import 'dart:async';
import 'package:flutter/material.dart';
import '../../data/gamification_rules.dart';
import '../../data/gamification_service.dart';

/// Lives in the authenticated shell so all tabs share one celebration queue.
class GamificationSession extends StatefulWidget {
  final int? points;
  final Future<RewardResult> Function() onDailyVisit;
  final Widget child;
  const GamificationSession({
    super.key,
    required this.points,
    required this.onDailyVisit,
    required this.child,
  });
  @override
  State<GamificationSession> createState() => _GamificationSessionState();
}

class _GamificationSessionState extends State<GamificationSession>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _animation;
  int? _highestLevel;
  int? _pendingLevel;
  int? _celebratingLevel;
  String? _dailyFeedback;
  Timer? _hideTimer;
  bool _dailyInFlight = false;
  bool _active = true;

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _observePoints();
  }

  @override
  void didUpdateWidget(covariant GamificationSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.points != widget.points) _observePoints();
  }

  void _observePoints() {
    final points = widget.points;
    if (points == null) return;
    final level = GamificationRules.levelForPoints(points);
    if (_highestLevel == null) {
      _highestLevel = level;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_dailyVisit());
      });
    } else if (level > _highestLevel!) {
      _highestLevel = level;
      _pendingLevel = level;
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!mounted) return;
    setState(() => _active = state == AppLifecycleState.resumed);
    if (_active) unawaited(_dailyVisit());
  }

  Future<void> _dailyVisit() async {
    if (!_active || widget.points == null || _dailyInFlight) return;
    _dailyInFlight = true;
    try {
      final reward = await widget.onDailyVisit();
      if (mounted && reward.confirmed && reward.pointsAwarded > 0) {
        setState(
          () => _dailyFeedback =
              'Revisión diaria: +${reward.pointsAwarded} puntos',
        );
      }
    } catch (_) {
      // A later resume retries; never show a reward before its confirmation.
    } finally {
      _dailyInFlight = false;
    }
  }

  void _showPending() {
    if (!mounted || !_active || !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    if (_dailyFeedback != null) {
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(_dailyFeedback!)));
      _dailyFeedback = null;
    }
    if (_pendingLevel == null) return;
    _hideTimer?.cancel();
    setState(() {
      _celebratingLevel = _pendingLevel;
      _pendingLevel = null;
    });
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      if (mounted) setState(() => _celebratingLevel = null);
    });
  }

  @override
  Widget build(BuildContext context) {
    final visible = _active && (ModalRoute.isCurrentOf(context) ?? true);
    if (visible && (_pendingLevel != null || _dailyFeedback != null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPending());
    }
    return Stack(
      children: [
        widget.child,
        if (visible && _celebratingLevel != null)
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: FadeTransition(
                  opacity: _animation,
                  child: ScaleTransition(
                    scale: Tween<double>(begin: .7, end: 1).animate(
                      CurvedAnimation(
                        parent: _animation,
                        curve: Curves.easeOutBack,
                      ),
                    ),
                    child: Semantics(
                      liveRegion: true,
                      child: Container(
                        margin: const EdgeInsets.all(24),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 28,
                          vertical: 24,
                        ),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primary,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: const [
                            BoxShadow(color: Colors.black26, blurRadius: 20),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.auto_awesome,
                              color: Colors.amber,
                              size: 48,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '¡Subiste al nivel $_celebratingLevel!',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Tu constancia suma. ¡Sigue avanzando!',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hideTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }
}
