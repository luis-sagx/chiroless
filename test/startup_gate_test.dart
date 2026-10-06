import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:financial_control/features/home/presentation/pages/splash_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Firebase startup treats a null auth state as signed out', () async {
    final gate = StartupGate.firebase(
      authStateChanges: () => Stream<User?>.value(null),
    );

    expect(await gate.hasSession(), isFalse);
  });

  test('signed-in startup skips local welcome storage', () async {
    final gate = StartupGate(
      hasSession: () async => true,
      hasSeenWelcome: () => throw StateError('Must not read preferences'),
      markWelcomeSeen: () => throw StateError('Must not write preferences'),
    );

    expect(await gate.resolve(), StartupRoute.home);
  });

  test('first signed-out startup waits through the welcome', () async {
    final waiting = Completer<void>();
    var recorded = false;
    final gate = StartupGate(
      hasSession: () async => false,
      hasSeenWelcome: () async => false,
      markWelcomeSeen: () async {
        recorded = true;
        await waiting.future;
      },
      welcomeDuration: Duration.zero,
    );

    final route = gate.resolve();
    await Future<void>.delayed(Duration.zero);
    expect(recorded, isTrue);
    waiting.complete();
    expect(await route, StartupRoute.login);
  });

  test('returning signed-out startup has no welcome delay', () async {
    var recorded = false;
    final gate = StartupGate(
      hasSession: () async => false,
      hasSeenWelcome: () async => true,
      markWelcomeSeen: () async => recorded = true,
      welcomeDuration: const Duration(days: 1),
    );

    expect(await gate.resolve(), StartupRoute.login);
    expect(recorded, isFalse);
  });

  test('startup keeps splash until session resolution finishes', () async {
    final session = Completer<bool>();
    final gate = StartupGate(
      hasSession: () => session.future,
      hasSeenWelcome: () async => true,
      markWelcomeSeen: () async {},
    );

    final route = gate.resolve();
    var finished = false;
    route.then((_) => finished = true);
    await Future<void>.delayed(Duration.zero);
    expect(finished, isFalse);
    session.complete(true);
    expect(await route, StartupRoute.home);
  });

  test(
    'authentication error opens login instead of leaving splash stuck',
    () async {
      final gate = StartupGate(
        hasSession: () => Future<bool>.error(StateError('Auth unavailable')),
        hasSeenWelcome: () async => true,
        markWelcomeSeen: () async {},
      );

      expect(await gate.resolve(), StartupRoute.login);
    },
  );
}
