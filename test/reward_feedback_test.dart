import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:financial_control/features/achievements/data/gamification_service.dart';
import 'package:financial_control/features/achievements/presentation/widgets/reward_feedback.dart';

void main() {
  test(
    'slow reward releases saved action and can still confirm later',
    () async {
      final pending = Completer<RewardResult>();
      final result = await confirmReward(
        pending.future,
        wait: const Duration(milliseconds: 1),
      );
      expect(result, isNull);
      final feedback = savedActionFeedback('Ingreso guardado', result);
      expect(feedback, contains('Ingreso guardado'));
      expect(feedback, contains('por confirmar'));
      expect(feedback, isNot(contains('+15')));
      pending.complete(const RewardResult(confirmed: true, pointsAwarded: 15));
      expect((await pending.future).confirmed, isTrue);
    },
  );
  test('only confirmed reward is displayed as earned points', () {
    expect(
      savedActionFeedback(
        'Gasto guardado',
        const RewardResult(confirmed: true, pointsAwarded: 10),
      ),
      contains('+10 puntos'),
    );
    expect(
      savedActionFeedback(
        'Gasto guardado',
        const RewardResult(confirmed: false, pointsAwarded: 10),
      ),
      isNot(contains('+10')),
    );
    expect(
      savedActionFeedback(
        'Presupuesto guardado',
        const RewardResult(confirmed: true),
      ),
      'Presupuesto guardado',
    );
  });
}
