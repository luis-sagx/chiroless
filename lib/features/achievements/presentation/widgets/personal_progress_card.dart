import 'package:flutter/material.dart';
import '../../../../models/user_model.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/gamification_rules.dart';

class PersonalProgressCard extends StatelessWidget {
  final AppUser user;
  final VoidCallback? onTap;
  final DateTime? now;
  const PersonalProgressCard({
    super.key,
    required this.user,
    this.onTap,
    this.now,
  });
  @override
  Widget build(BuildContext context) {
    final level = GamificationRules.levelForPoints(user.points);
    final remaining = GamificationRules.nextLevelThreshold(level) - user.points;
    final streak = GamificationRules.activeStreak(
      user.currentStreak,
      user.lastTxDate,
      now ?? DateTime.now(),
    );
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.primaryGradient,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Tu progreso financiero',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                Text(
                  'Nivel $level · ${GamificationRules.levelName(user.points)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${user.points} pts',
                  style: const TextStyle(
                    color: Colors.amber,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: GamificationRules.levelProgress(user.points),
                minHeight: 8,
                color: Colors.amber,
                backgroundColor: Colors.white24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$remaining puntos para el siguiente nivel',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(
              '$streak días de racha',
              style: const TextStyle(color: Colors.white),
            ),
            const Text(
              'La racha cuenta los días en que registras movimientos reales.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            const SizedBox(height: 8),
            const Text(
              'Revisión diaria: +10 puntos al abrir la app, una vez al día.',
              style: TextStyle(color: Colors.white70, fontSize: 12),
            ),
            if (onTap != null)
              const Padding(
                padding: EdgeInsets.only(top: 12),
                child: Text(
                  'Ver mis próximos objetivos →',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
