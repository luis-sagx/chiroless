import 'dart:async';
import '../../data/gamification_service.dart';

/// Financial persistence has already succeeded when this helper is used.
/// A timeout does not cancel a Firestore write; streams can confirm it later.
Future<RewardResult?> confirmReward(
  Future<RewardResult> reward, {
  Duration wait = const Duration(seconds: 4),
}) async {
  try {
    return await reward.timeout(wait);
  } catch (_) {
    return null;
  }
}

String savedActionFeedback(String saved, RewardResult? reward) {
  if (reward == null || !reward.confirmed) {
    return '$saved. Puntos por confirmar; tu movimiento ya está guardado.';
  }
  if (reward.pointsAwarded == 0) return saved;
  return '$saved. +${reward.pointsAwarded} puntos';
}

Future<void> refreshAchievements(
  GamificationService service,
  String uid,
) async {
  try {
    await service.checkAndUnlockAchievements(uid);
  } catch (_) {
    /* Streams and next registration can retry the check. */
  }
}
