import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/achievement_model.dart';
import '../../data/gamification_rules.dart';
import '../../data/gamification_service.dart';
import 'joyful_celebration.dart';
import 'mission_celebrations.dart';

/// One authenticated shell owns deferred and combined reward presentation.
class GamificationSession extends StatefulWidget {
  final String? userId;
  final int? points;
  final Future<RewardResult> Function() onDailyVisit;
  final Widget child;
  const GamificationSession({
    super.key,
    this.userId,
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
  StreamSubscription<String>? _missionSubscription;
  int? _highestLevel;
  int? _pendingLevel;
  int? _celebratingLevel;
  int _previousPoints = 0;
  int? _confirmedDailyTotal;
  List<Achievement> _missions = [];
  int _pendingDaily = 0;
  int _celebrationDaily = 0;
  int _bannerPoints = 0;
  Timer? _hideTimer;
  Timer? _coalesceTimer;
  bool _ready = false;
  bool _dailyInFlight = false;
  bool _active = true;
  int _sessionEpoch = 0;
  bool get _hasCard => _missions.isNotEmpty || _celebratingLevel != null;
  List<Achievement> get _pendingMissions => widget.userId == null
      ? const []
      : MissionCelebrations.instance.pending(widget.userId!);

  @override
  void initState() {
    super.initState();
    _animation = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    WidgetsBinding.instance.addObserver(this);
    _active =
        WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
    _bindMissions();
    _observePoints();
  }

  void _bindMissions() {
    _missionSubscription = MissionCelebrations.instance.changes.listen((uid) {
      if (uid == widget.userId && mounted) _queuePresentation();
    });
    if (_pendingMissions.isNotEmpty) _queuePresentation();
  }

  @override
  void didUpdateWidget(covariant GamificationSession oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.userId != widget.userId) {
      _sessionEpoch++;
      _missionSubscription?.cancel();
      _hideTimer?.cancel();
      _coalesceTimer?.cancel();
      _highestLevel = null;
      _pendingLevel = _celebratingLevel = null;
      _confirmedDailyTotal = null;
      _missions = [];
      _pendingDaily = _celebrationDaily = _bannerPoints = 0;
      _dailyInFlight = _ready = false;
      _animation.stop();
      _bindMissions();
    }
    if (oldWidget.points != widget.points ||
        oldWidget.userId != widget.userId) {
      _previousPoints = oldWidget.userId == widget.userId
          ? oldWidget.points ?? widget.points ?? 0
          : widget.points ?? 0;
      _confirmedDailyTotal = null;
      _observePoints();
    }
  }

  void _trackLevel(int points) {
    final level = GamificationRules.levelForPoints(points);
    if (_highestLevel == null) {
      _highestLevel = level;
    } else if (level > _highestLevel!) {
      _highestLevel = level;
      _pendingLevel = level;
      _queuePresentation();
    }
  }

  void _observePoints() {
    if (widget.points == null) return;
    final initial = _highestLevel == null;
    _trackLevel(widget.points!);
    if (initial) {
      _previousPoints = widget.points!;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_dailyVisit());
      });
    }
  }

  void _queuePresentation() {
    _coalesceTimer?.cancel();
    _ready = false;
    // The points snapshot can arrive just before its committed unlock result.
    _coalesceTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted) setState(() => _ready = true);
    });
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
    final epoch = _sessionEpoch;
    try {
      final reward = await widget.onDailyVisit();
      if (mounted &&
          epoch == _sessionEpoch &&
          reward.confirmed &&
          reward.pointsAwarded > 0) {
        _pendingDaily += reward.pointsAwarded;
        _confirmedDailyTotal = reward.totalPoints > (widget.points ?? 0)
            ? reward.totalPoints
            : null;
        _trackLevel(reward.totalPoints);
        _queuePresentation();
      }
    } catch (_) {
      // Retry on a later visit; an unconfirmed reward never gets a celebration.
    } finally {
      if (epoch == _sessionEpoch) _dailyInFlight = false;
    }
  }

  void _showPending() {
    if (!mounted ||
        widget.points == null ||
        !_ready ||
        !_active ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      return;
    }
    final missions = _pendingMissions;
    _ready = false;
    if (missions.isEmpty && _pendingLevel == null && _pendingDaily == 0) return;
    _hideTimer?.cancel();
    setState(() {
      if (missions.isNotEmpty || _pendingLevel != null || _hasCard) {
        _missions = [..._missions, ...missions];
        _celebratingLevel = _pendingLevel ?? _celebratingLevel;
        _celebrationDaily += _pendingDaily + _bannerPoints;
        _bannerPoints = 0;
      } else {
        _bannerPoints = _pendingDaily;
      }
      _pendingLevel = null;
      _pendingDaily = 0;
    });
    if (widget.userId != null) {
      MissionCelebrations.instance.acknowledge(widget.userId!, missions);
    }
    if (MediaQuery.disableAnimationsOf(context)) {
      _animation.value = 1;
    } else {
      _animation.forward(from: 0);
    }
    _hideTimer = Timer(
      Duration(
        seconds: 4 + (_missions.isEmpty ? 0 : (_missions.length - 1) * 2),
      ),
      () {
        if (mounted) {
          setState(() {
            _missions = [];
            _celebratingLevel = null;
            _celebrationDaily = _bannerPoints = 0;
          });
        }
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final visible = _active && (ModalRoute.isCurrentOf(context) ?? true);
    if (visible && _ready) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showPending());
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (visible && _hasCard)
          Positioned.fill(
            child: Center(
              child: JoyfulCelebration(
                missions: _missions,
                level: _celebratingLevel,
                points: _confirmedDailyTotal ?? widget.points ?? 0,
                previousPoints: _previousPoints,
                dailyPoints: _celebrationDaily,
                animation: _animation,
                reducedMotion: MediaQuery.disableAnimationsOf(context),
              ),
            ),
          ),
        if (visible && !_hasCard && _bannerPoints > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: DailyRewardBanner(points: _bannerPoints),
            ),
          ),
      ],
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sessionEpoch++;
    _missionSubscription?.cancel();
    _hideTimer?.cancel();
    _coalesceTimer?.cancel();
    _animation.dispose();
    super.dispose();
  }
}
