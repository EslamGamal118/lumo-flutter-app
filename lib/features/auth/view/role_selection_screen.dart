
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/router/route_names.dart';
import '../../../core/enums/user_role.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: 2),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: -10, end: 10).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _navigateToSignup(BuildContext context, UserRole role) {
    Navigator.pushNamed(
      context,
      RouteNames.signup,
      arguments: {'role': role},
    );
  }
  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.primary),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Floating Robot Mascot
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.translate(
                          offset: Offset(0, _animation.value),
                          child: child,
                        );
                      },
                      child: Container(
                        width: 160,
                        height: 160,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Padding(
                            padding: EdgeInsets.all(24.0),
                            child: Image.asset(
                              'assets/images/ai_avatar.png', // Robot image
                              fit: BoxFit.contain,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.smart_toy, size: 80, color: AppColors.primary),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 24),

                    // LUMO Branding
                    Text(
                      'LUMO',
                      style: GoogleFonts.poppins(
                        fontSize: 32,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 4.0,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 24),

                    // Main Title
                    Text(
                      (isAr ? 'ابدأ رحلة دعم طفلك 🤍' : 'Start your child\'s support journey 🤍'),
                      style: GoogleFonts.cairo(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: theme.textTheme.titleLarge?.color ?? Colors.black87,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 8),

                    // Sub-title
                    Text(
                      (isAr ? 'تحليل ذكي • متابعة دقيقة • تعاون مع الأطباء' : 'Intelligent analysis • Careful follow-up • Collaborate with doctors'),
                      style: GoogleFonts.cairo(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: 48),

                    // Role Cards
                    _RoleCard(
                      title: (isAr ? 'أنا أحد الوالدين' : '- I am a parent.'),
                      subtitle: (isAr ? 'متابعة نمو طفلك والحصول على استشارات' : 'Monitor your child\'s growth and get counseling'),
                      icon: Icons.family_restroom,
                      onTap: () => _navigateToSignup(context, UserRole.parent),
                    ),
                    SizedBox(height: 16),
                    _RoleCard(
                      title: (isAr ? 'أنا طبيب' : 'I\'m a doctor of medicine.'),
                      subtitle: (isAr ? 'راقب الحالات وتعاون مع الأهالي' : 'Monitor cases and cooperate with parents'),
                      icon: Icons.medical_services,
                      onTap: () => _navigateToSignup(context, UserRole.doctor),
                    ),
                    SizedBox(height: 48),

                    // Footer
                    Text(
                      (isAr ? 'الشروط والأحكام • سياسة الخصوصية • المساعدة' : 'Terms and Conditions • Privacy Policy • Help'),
                      style: GoogleFonts.cairo(
                        fontSize: 12, // slightly bigger than 11 for readability
                        fontWeight: FontWeight.normal,
                        color: theme.disabledColor,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ),
          ),
    );
  }
}

class _RoleCard extends StatefulWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_RoleCard> createState() => _RoleCardState();
}

class _RoleCardState extends State<_RoleCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          decoration: BoxDecoration(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _isHovered ? AppColors.primary : theme.dividerColor,
              width: _isHovered ? 2 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: _isHovered ? 0.08 : 0.04),
                blurRadius: _isHovered ? 16 : 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  widget.icon,
                  size: 28,
                  color: AppColors.primary,
                ),
              ),
              SizedBox(width: 20),
              // Texts
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      widget.title,
                      style: AppTextStyles.h3.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      widget.subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: theme.textTheme.bodyMedium?.color ?? Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: 16,
                color: theme.dividerColor,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
