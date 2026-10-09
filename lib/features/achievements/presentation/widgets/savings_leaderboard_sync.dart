import 'dart:async';
import 'package:flutter/material.dart';
import '../../../../models/savings_leaderboard_model.dart';
import '../../data/savings_leaderboard_service.dart';

class SavingsLeaderboardSync extends StatefulWidget {
  final String userId;
  final SavingsLeaderboardService? service;
  final DateTime Function()? now;
  final Widget child;
  const SavingsLeaderboardSync({
    super.key,
    required this.userId,
    this.service,
    this.now,
    required this.child,
  });
  @override
  State<SavingsLeaderboardSync> createState() => _SavingsLeaderboardSyncState();
}

class _SavingsLeaderboardSyncState extends State<SavingsLeaderboardSync>
    with WidgetsBindingObserver {
  late SavingsLeaderboardService _service;
  final List<StreamSubscription<dynamic>> _subscriptions = [];
  Timer? _debounce;
  Timer? _rollover;
  String _month = '';
  SavingsParticipation _participation = const SavingsParticipation();
  bool _incomeReady = false,
      _expenseReady = false,
      _busy = false,
      _dirty = false;
  int _generation = 0;
  DateTime get _now => widget.now?.call() ?? DateTime.now();
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _service = widget.service ?? SavingsLeaderboardService();
    _start();
    _rollover = Timer.periodic(
      const Duration(minutes: 1),
      (_) => _checkMonth(),
    );
  }

  @override
  void didUpdateWidget(covariant SavingsLeaderboardSync old) {
    super.didUpdateWidget(old);
    if (old.userId != widget.userId || old.service != widget.service) {
      _service = widget.service ?? SavingsLeaderboardService();
      _start();
    }
  }

  void _checkMonth() {
    if (SavingsLeaderboardRules.monthKey(_now) != _month) {
      _start();
    } else {
      _schedule();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkMonth();
  }

  void _start() {
    _generation++;
    _debounce?.cancel();
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    _subscriptions.clear();
    _incomeReady = false;
    _expenseReady = false;
    _dirty = false;
    _participation = const SavingsParticipation();
    _month = SavingsLeaderboardRules.monthKey(_now);
    final generation = _generation;
    bool current() => mounted && generation == _generation;
    _subscriptions.add(
      _service
          .watchParticipation(widget.userId)
          .listen(
            (value) {
              if (!current()) return;
              final changed =
                  value.enabled != _participation.enabled ||
                  value.alias != _participation.alias;
              _participation = value;
              if (changed) _schedule();
            },
            onError: (Object error) {
              if (current()) {
                _participation = const SavingsParticipation();
                _debounce?.cancel();
              }
            },
          ),
    );
    for (final income in [true, false]) {
      _subscriptions.add(
        _service
            .watchTransactions(widget.userId, _month, income: income)
            .listen(
              (_) {
                if (!current()) return;
                if (income) {
                  _incomeReady = true;
                } else {
                  _expenseReady = true;
                }
                _schedule();
              },
              onError: (Object error) {
                if (!current()) return;
                if (income) {
                  _incomeReady = false;
                } else {
                  _expenseReady = false;
                }
                _debounce?.cancel();
              },
            ),
      );
    }
  }

  void _schedule() {
    if (!_participation.enabled || !_incomeReady || !_expenseReady) return;
    _dirty = true;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 250), _flush);
  }

  Future<void> _flush() async {
    if (!mounted ||
        _busy ||
        !_dirty ||
        !_participation.enabled ||
        !_incomeReady ||
        !_expenseReady) {
      return;
    }
    _dirty = false;
    _busy = true;
    final generation = _generation;
    final uid = widget.userId;
    final month = _month;
    final service = _service;
    try {
      await service.synchronizeMonth(
        uid,
        month,
        isCurrent: () => mounted && generation == _generation,
      );
    } catch (_) {
      /* Preserve published data. A fresh snapshot/resume retries. */
    } finally {
      _busy = false;
      if (mounted && (_dirty || generation != _generation)) _schedule();
    }
  }

  @override
  void dispose() {
    _generation++;
    WidgetsBinding.instance.removeObserver(this);
    _debounce?.cancel();
    _rollover?.cancel();
    for (final sub in _subscriptions) {
      unawaited(sub.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
