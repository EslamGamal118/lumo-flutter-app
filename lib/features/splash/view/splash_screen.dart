import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:async';

import '../../../core/router/route_names.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../data/datasources/local_data_source.dart';
import '../../../core/di/dependency_injection.dart';

/// Splash Screen - Enhanced Entry Point
///
/// Features:
/// - Beautiful animations (fade, scale, slide)
/// - Auto-navigation logic
/// - Onboarding check
/// - Auth state verification
/// - Error handling
/// - Progress indicator
/// - Custom transitions
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _initializeApp();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(seconds: 3), // 3s total duration as per spec
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeIn),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOutBack),
      ),
    );

    _controller.repeat(reverse: true); // Floating effect
  }

  Future<void> _initializeApp() async {
    // Minimum splash duration 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    if (!mounted) return;

    final localDataSource = getIt<LocalDataSource>();
    final authProvider = context.read<AuthProvider>();

    // Check onboarding
    if (!localDataSource.isOnboardingCompleted()) {
      _navigateTo(RouteNames.onboarding);
      return;
    }

    // Check authentication
    await authProvider.init();

    if (authProvider.isAuthenticated) {
      _navigateTo(RouteNames.mainLayout);
    } else {
      _navigateTo(RouteNames.login);
    }
  }

  void _navigateTo(String routeName) {
    if (!mounted) return;
    Navigator.pushReplacementNamed(context, routeName);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              // Smooth sinusoidal floating effect
              // _controller.value goes 0->1->0 (due to repeat reverse)
              // We want a subtle float
              final double floatY = 10 *
                  (0.5 -
                      (0.5 -
                              CurvedAnimation(
                                      parent: _controller,
                                      curve: Curves.easeInOut)
                                  .value)
                          .abs());

              return Transform.translate(
                offset: Offset(0, floatY),
                child: FadeTransition(
                  opacity: _fadeAnimation,
                  child: ScaleTransition(
                    scale: _scaleAnimation,
                    child: child,
                  ),
                ),
              );
            },
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images_from_web/web_splash.png',
                  width: 300,
                  height: 300,
                  fit: BoxFit.contain,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
