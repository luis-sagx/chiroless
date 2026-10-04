import 'dart:async';

import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/config/env_config.dart';
import 'core/services/notification_service.dart';
import 'features/home/presentation/pages/splash_screen.dart';

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

  runApp(const MyApp());

  unawaited(_initNotifications());
}

Future<void> _initNotifications() async {
  try {
    await NotificationService().init();
    await NotificationService().scheduleDailyReminder();
  } catch (e) {
    print('Error inicializando notificaciones: $e');
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Sagx UP',
      theme: AppTheme.lightTheme,
      home: const SplashScreen(),
    );
  }
}
