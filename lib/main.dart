import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'core/services/notification_service.dart';
import 'core/services/shortcut_service.dart';
import 'features/home/presentation/pages/splash_screen.dart';
import 'shared/widgets/double_back_to_exit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await EnvConfig.load();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') rethrow;
  }

  await FirebaseAppCheck.instance.activate(
    providerAndroid: kDebugMode
        ? AndroidDebugProvider()
        : AndroidPlayIntegrityProvider(),
    providerApple: AppleAppAttestProvider(),
  );

  runApp(const MyApp());

  unawaited(_initNotifications());
  unawaited(_initShortcuts());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService().init();
    await NotificationService().scheduleDailyReminder();
  } catch (e) {
    print('Error inicializando notificaciones: $e');
  }
}

Future<void> _initShortcuts() async {
  try {
    await ShortcutService.init();
  } catch (e) {
    print('Error inicializando accesos directos: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  static final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      navigatorKey: _navigatorKey,
      debugShowCheckedModeBanner: false,
      title: 'Chiroless',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
      builder: (context, child) => DoubleBackToExit(
        navigatorKey: _navigatorKey,
        child: child ?? const SizedBox.shrink(),
      ),
    );
  }
}
