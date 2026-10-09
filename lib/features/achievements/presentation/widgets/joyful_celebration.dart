import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../../models/achievement_model.dart';
import '../../data/gamification_rules.dart';

class JoyfulCelebration extends StatelessWidget {
  final List<Achievement> missions;
  final int? level;
  final int points;
  final int previousPoints;
  final Animation<double> animation;
  final bool reducedMotion;
  final int dailyPoints;
  const JoyfulCelebration({
    super.key,
    required this.missions,
    required this.level,
    required this.points,
    required this.previousPoints,
    required this.animation,
    required this.reducedMotion,
    this.dailyPoints = 0,
  });

  @override
  Widget build(BuildContext context) {
    final awarded = missions.fold<int>(
      dailyPoints,
      (sum, mission) => sum + mission.points,
    );
    final currentLevel = GamificationRules.levelForPoints(points);
    final progress = GamificationRules.levelProgress(points);
    final startProgress =
        GamificationRules.levelForPoints(previousPoints) == currentLevel
        ? GamificationRules.levelProgress(previousPoints)
        : 0.0;
    return LayoutBuilder(
      builder: (context, bounds) => AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final time = reducedMotion ? 1.0 : animation.value;
          final motion = reducedMotion
              ? 1.0
              : Curves.easeOutBack.transform(time);
          return Stack(
            alignment: Alignment.center,
            children: [
              if (!reducedMotion)
                Positioned.fill(
                  child: IgnorePointer(
                    child: CustomPaint(
                      key: const ValueKey('celebration-confetti'),
                      painter: _ConfettiPainter(time),
                    ),
                  ),
                ),
              Center(
                child: Transform.scale(
                  scale: .85 + .15 * motion,
                  child: Opacity(
                    opacity: time.clamp(0, 1),
                    child: Container(
                      key: const ValueKey('joyful-celebration'),
                      constraints: BoxConstraints(
                        maxWidth: 380,
                        maxHeight: math.max(0, bounds.maxHeight - 40),
                      ),
                      margin: const EdgeInsets.all(20),
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFFBEE),
                        border: Border.all(
                          color: const Color(0xFFE6B949),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x33000000),
                            blurRadius: 24,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Semantics(
                        liveRegion: true,
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Transform.translate(
                                offset: Offset(
                                  0,
                                  reducedMotion
                                      ? 0
                                      : -12 * math.sin(time * math.pi),
                                ),
                                child: const Icon(
                                  Icons.workspace_premium_rounded,
                                  size: 72,
                                  color: Color(0xFFD99516),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                missions.isNotEmpty
                                    ? '¡Misión completada!'
                                    : '¡Subiste al nivel $level!',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w800,
                                  color: Color(0xFF49381A),
                                ),
                              ),
                              for (final mission in missions)
                                Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Text(
                                    mission.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF6D5427),
                                    ),
                                  ),
                                ),
                              if (awarded > 0)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 14,
                                  ),
                                  child: Text(
                                    '+${(awarded * time).round()} puntos',
                                    style: const TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight.w900,
                                      color: Color(0xFF16865C),
                                    ),
                                  ),
                                ),
                              if (missions.isNotEmpty && level != null)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Text(
                                    '¡Subiste al nivel $level!',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF49381A),
                                    ),
                                  ),
                                ),
                              Text(
                                'Nivel $currentLevel · ${GamificationRules.nextLevelThreshold(currentLevel) - points} puntos para avanzar',
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  color: Color(0xFF6D5427),
                                ),
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: LinearProgressIndicator(
                                  value:
                                      startProgress +
                                      (progress - startProgress) * time,
                                  minHeight: 9,
                                  backgroundColor: const Color(0xFFF0E4BD),
                                  color: const Color(0xFFDAA62D),
                                ),
                              ),
                              const SizedBox(height: 12),
                              const Text(
                                '¡Tu constancia merece celebrarse!',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Color(0xFF6D5427)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class DailyRewardBanner extends StatelessWidget {
  final int points;
  const DailyRewardBanner({super.key, required this.points});
  @override
  Widget build(BuildContext context) => Semantics(
    liveRegion: true,
    child: Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFFE3FAED),
        border: Border.all(color: const Color(0xFF9BDDB8)),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0x18000000), blurRadius: 12)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wb_sunny_rounded, color: Color(0xFFD99516)),
          const SizedBox(width: 10),
          Flexible(
            child: Text(
              'Revisión diaria: +$points puntos',
              style: const TextStyle(
                color: Color(0xFF176B47),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _ConfettiPainter extends CustomPainter {
  final double time;
  _ConfettiPainter(this.time);
  static const colors = [
    Color(0xFFECC248),
    Color(0xFF38B99B),
    Color(0xFFF2889F),
    Color(0xFF779DF1),
    Color(0xFFB980E0),
  ];
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (var i = 0; i < 38; i++) {
      final angle = i * 2.399;
      final radius = (70 + (i % 7) * 32) * time;
      final x = size.width / 2 + math.cos(angle) * radius;
      final y =
          size.height / 2 +
          math.sin(angle) * radius -
          100 * time +
          150 * time * time;
      paint.color = colors[i % colors.length].withValues(
        alpha: (1 - time * .45).clamp(0, 1),
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(angle + time * 4);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          const Rect.fromLTWH(-3, -6, 6, 12),
          const Radius.circular(2),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) => oldDelegate.time != time;
}
