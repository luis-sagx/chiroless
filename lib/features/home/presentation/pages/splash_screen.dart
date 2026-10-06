import 'package:flutter/material.dart';
import '../../../../core/theme/app_theme.dart';
import 'home_page.dart';
import '../../../auth/presentation/pages/login_page.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum StartupRoute { home, login }

/// Resuelve la sesión antes de consultar almacenamiento local. Solo el primer
/// inicio sin sesión conserva una bienvenida corta.
class StartupGate {
  const StartupGate({
    required this.hasSession,
    required this.hasSeenWelcome,
    required this.markWelcomeSeen,
    this.welcomeDuration = const Duration(milliseconds: 700),
  });

  static const welcomeKey = 'has_seen_startup_welcome';

  final Future<bool> Function() hasSession;
  final Future<bool> Function() hasSeenWelcome;
  final Future<void> Function() markWelcomeSeen;
  final Duration welcomeDuration;

  factory StartupGate.firebase({Stream<User?> Function()? authStateChanges}) =>
      StartupGate(
        hasSession: () async =>
            await (authStateChanges ?? FirebaseAuth.instance.authStateChanges)
                .call()
                .first !=
            null,
        hasSeenWelcome: () async {
          final preferences = await SharedPreferences.getInstance();
          return preferences.getBool(welcomeKey) ?? false;
        },
        markWelcomeSeen: () async {
          final preferences = await SharedPreferences.getInstance();
          await preferences.setBool(welcomeKey, true);
        },
      );

  Future<StartupRoute> resolve() async {
    bool signedIn;
    try {
      signedIn = await hasSession();
    } catch (_) {
      // Un error de autenticación no debe dejar la pantalla de inicio fija.
      return StartupRoute.login;
    }
    if (signedIn) return StartupRoute.home;

    try {
      if (!await hasSeenWelcome()) {
        await markWelcomeSeen();
        await Future<void>.delayed(welcomeDuration);
      }
    } catch (_) {
      // La persistencia de la bienvenida no debe bloquear el inicio de sesión.
    }
    return StartupRoute.login;
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, this.gate});

  final StartupGate? gate;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 350),
      vsync: this,
    );

    _opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scale = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.forward();
    _checkAuthAndNavigate();
  }

  Future<void> _checkAuthAndNavigate() async {
    final route = await (widget.gate ?? StartupGate.firebase()).resolve();
    if (!mounted) return;
    if (route == StartupRoute.home) {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
    } else {
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const LoginPage()));
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) {
            return Opacity(
              opacity: _opacity.value,
              child: Transform.scale(
                scale: _scale.value,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Logo de la App
                    Container(
                      width: 150,
                      height: 150,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.2),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'lib/assets/logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Nombre de la App
                    Text(
                      'Chiroless',
                      style: TextStyle(
                        fontFamily:
                            'Montserrat', // Asegúrate de tener fuentes si quieres algo específico, sino usa la por defecto
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryColor,
                        letterSpacing: 1.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Slogan
                    Text(
                      'Eleva tus finanzas al siguiente nivel',
                      style: TextStyle(
                        fontSize: 16,
                        color: AppTheme.secondaryColor,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
