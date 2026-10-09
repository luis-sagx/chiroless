import 'package:flutter/material.dart';
import '../../data/gamification_rules.dart';

class CompactLevelIndicator extends StatelessWidget {
  final int points;
  final VoidCallback onTap;
  const CompactLevelIndicator({
    super.key,
    required this.points,
    required this.onTap,
  });
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Nivel ${GamificationRules.levelForPoints(points)} · $points pts ›',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(color: Colors.white70, fontSize: 12),
      ),
    ),
  );
}
