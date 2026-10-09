import 'dart:async';
import '../../../../models/achievement_model.dart';

/// Only newly committed unlock results enter this queue, never snapshots of
/// existing achievements. Pending results survive a form or shell closing.
class MissionCelebrations {
  static final instance = MissionCelebrations();
  final _changes = StreamController<String>.broadcast(sync: true);
  final Map<String, Map<String, Achievement>> _pending = {};
  final Map<String, Set<String>> _seen = {};
  Stream<String> get changes => _changes.stream;
  List<Achievement> pending(String userId) =>
      List.unmodifiable(_pending[userId]?.values ?? const <Achievement>[]);
  String _identity(Achievement mission) =>
      mission.id ?? (mission.type.isEmpty ? mission.title : mission.type);

  void publish(String userId, List<Achievement> achievements) {
    var changed = false;
    final seen = _seen.putIfAbsent(userId, () => {});
    for (final mission in achievements) {
      if (mission.userId != userId ||
          !mission.isUnlocked ||
          mission.points <= 0) {
        continue;
      }
      final identity = _identity(mission);
      if (!seen.add(identity)) continue;
      _pending.putIfAbsent(userId, () => {})[identity] = mission;
      changed = true;
    }
    if (changed) _changes.add(userId);
  }

  void acknowledge(String userId, Iterable<Achievement> missions) {
    for (final mission in missions) {
      _pending[userId]?.remove(_identity(mission));
    }
    if (_pending[userId]?.isEmpty ?? false) _pending.remove(userId);
  }
}
