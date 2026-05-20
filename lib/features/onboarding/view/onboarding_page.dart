import 'package:flutter/material.dart';

import '../../../core/theme/app_text_styles.dart';

/// Onboarding Page Component
///
/// Features:
/// - Beautiful illustration placeholder
/// - Animated entrance
/// - Responsive layout
/// - RTL support
/// - Custom styling
class OnboardingPage extends StatefulWidget {
  final String title;
  final String description;
  final String imagePath;
  final int currentPage;
  final int totalPages;

  const OnboardingPage({
    super.key,
    required this.title,
    required this.description,
    required this.imagePath,
    required this.currentPage,
    required this.totalPages,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _setupAnimations();
    _controller.forward();
  }

  void _setupAnimations() {
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDarkMode = Theme.of(context).brightness == Brightness.dark;
    String finalImagePath = widget.imagePath;
    if (isDarkMode && finalImagePath.endsWith('.png')) {
      finalImagePath = finalImagePath.replaceFirst('.png', '_dark.png');
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Image
              Container(
                width: double.infinity,
                constraints: const BoxConstraints(maxHeight: 350),
                child: Image.asset(
                  finalImagePath,
                  fit: BoxFit.contain, // Fit to space rather than cropping
                  errorBuilder: (context, error, stackTrace) => Container(
                    width: double.infinity,
                    height: 350,
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Icon(Icons.image, size: 100),
                  ),
                ),
              ),

              const SizedBox(height: 48),

              // Text Content
              Text(
                widget.title,
                style: AppTextStyles.h2.copyWith(
                  color: Theme.of(context).textTheme.displayLarge?.color,
                  fontSize: 24,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              Text(
                widget.description,
                style: AppTextStyles.body.copyWith(
                  color: Theme.of(context).hintColor,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
