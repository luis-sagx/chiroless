import 'package:flutter/material.dart';
import '../../../../core/services/firebase_service.dart';
import '../../../../core/theme/app_theme.dart';
import '../../data/gamification_service.dart';
import '../../../../models/achievement_model.dart';
import '../../../auth/data/user_service.dart';

class AchievementsPage extends StatefulWidget {
  const AchievementsPage({Key? key}) : super(key: key);

  @override
  State<AchievementsPage> createState() => _AchievementsPageState();
}

class _AchievementsPageState extends State<AchievementsPage> {
  final _firebaseService = FirebaseService();
  final _gamificationService = GamificationService();
  final _userService = UserService();

  bool _isLoading = true;
  List<Achievement> _achievements = [];
  int _userPoints = 0;
  int _userLevel = 1;
  int _currentLevelPoints = 0;
  int _nextLevelPoints = 100;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }

    try {
      final user = _firebaseService.currentUser;
      if (user == null) return;

      // Get user data
      final userData = await _userService.getUser(user.uid);
      final points = userData?.points ?? 0;
      final level = _gamificationService.calculateLevel(points);
      final currentLevelPoints = _gamificationService.pointsForCurrentLevel(
        level,
      );
      final nextLevel = _gamificationService.pointsForNextLevel(level);

      // Get all achievements
      final achievements = await _gamificationService.getUserAchievements(
        user.uid,
      );

      if (mounted) {
        setState(() {
          _userPoints = points;
          _userLevel = level;
          _currentLevelPoints = currentLevelPoints;
          _nextLevelPoints = nextLevel;
          _achievements = achievements;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final unlockedAchievements = _achievements
        .where((a) => a.isUnlocked)
        .toList();
    final unlockedTitles = unlockedAchievements.map((a) => a.title).toSet();
    final lockedAchievements = AchievementTemplates.templates
        .where((template) => !unlockedTitles.contains(template['title']))
        .map(
          (template) => Achievement(
            userId: '',
            title: template['title'] as String,
            description: template['description'] as String,
            icon: template['icon'] as String,
            points: template['points'] as int,
            category: template['category'] as String,
          ),
        )
        .toList();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'Logros y Progreso',
              style: Theme.of(context).textTheme.headlineLarge,
            ),
            const SizedBox(height: 24),

            // Level Card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.primaryGradient,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    blurRadius: 15,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Tu Nivel',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Nivel $_userLevel',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Flexible(
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.white.withValues(
                                        alpha: 0.2,
                                      ),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 3),
                                        Flexible(
                                          child: Text(
                                            '$_userPoints pts',
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.emoji_events,
                          color: Colors.amber,
                          size: 32,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progreso al Nivel ${_userLevel + 1}',
                            style: const TextStyle(
                              color: Colors.white70,
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '$_userPoints / $_nextLevelPoints',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: LinearProgressIndicator(
                          value:
                              ((_userPoints - _currentLevelPoints) /
                                      (_nextLevelPoints - _currentLevelPoints))
                                  .clamp(0.0, 1.0),
                          minHeight: 12,
                          backgroundColor: Colors.white.withValues(alpha: 0.2),
                          valueColor: const AlwaysStoppedAnimation<Color>(
                            Colors.amber,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Unlocked Achievements
            if (unlockedAchievements.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Desbloqueados',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.secondaryColor,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${unlockedAchievements.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...unlockedAchievements.map(
                (achievement) => _buildAchievementCard(achievement, true),
              ),
              const SizedBox(height: 24),
            ],

            // Locked Achievements
            if (lockedAchievements.isNotEmpty) ...[
              Row(
                children: [
                  Text(
                    'Por Desbloquear',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade300,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      '${lockedAchievements.length}',
                      style: TextStyle(
                        color: Colors.grey.shade700,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...lockedAchievements.map(
                (achievement) => _buildAchievementCard(achievement, false),
              ),
            ],

            // Empty State
            if (unlockedAchievements.isEmpty && lockedAchievements.isEmpty) ...[
              const SizedBox(height: 60),
              Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.emoji_events_outlined,
                      size: 80,
                      color: Colors.grey.shade300,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Sin logros aún',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey.shade600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Comienza a usar la app para desbloquear logros',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade500,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement achievement, bool isUnlocked) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUnlocked ? Colors.white : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(16),
        border: isUnlocked
            ? Border.all(color: AppTheme.secondaryColor.withValues(alpha: 0.3))
            : null,
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppTheme.secondaryColor.withValues(alpha: 0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isUnlocked
                  ? AppTheme.secondaryColor.withValues(alpha: 0.1)
                  : Colors.grey.shade300,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getAchievementIcon(achievement.type),
              color: isUnlocked
                  ? AppTheme.secondaryColor
                  : Colors.grey.shade600,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  achievement.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isUnlocked ? Colors.black : Colors.grey.shade600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  achievement.description,
                  style: TextStyle(
                    fontSize: 12,
                    color: isUnlocked
                        ? Colors.grey.shade600
                        : Colors.grey.shade500,
                  ),
                ),
                if (isUnlocked && achievement.unlockedAt != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Desbloqueado: ${_formatDate(achievement.unlockedAt!)}',
                    style: TextStyle(
                      fontSize: 10,
                      color: AppTheme.secondaryColor,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppTheme.secondaryColor
                      : Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.star, color: Colors.white, size: 12),
                    const SizedBox(width: 4),
                    Text(
                      '${achievement.points}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  IconData _getAchievementIcon(String type) {
    switch (type) {
      case 'first_expense':
        return Icons.shopping_cart;
      case 'first_income':
        return Icons.account_balance_wallet;
      case 'streak_7':
      case 'streak_30':
        return Icons.local_fire_department;
      case 'budget_set':
        return Icons.savings;
      case 'expense_50':
      case 'expense_100':
        return Icons.receipt_long;
      case 'savings_goal':
        return Icons.star;
      default:
        return Icons.emoji_events;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
