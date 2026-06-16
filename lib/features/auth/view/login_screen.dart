import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/mixins/form_validation_mixin.dart';

/// Login Screen
///
/// User authentication screen
/// Features:
/// - Email/Password login
/// - Form validation
/// - Forgot password link
/// - Signup link
/// - Loading state
/// - Error handling
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with FormValidationMixin {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!validateForm()) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.login(
      phone: _phoneController.text.trim(),
      password: _passwordController.text,
    );

    if (!mounted) return;
    
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    setState(() => _isLoading = false);

    if (success) {
      // ✅ Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((isAr ? 'تم تسجيل الدخول بنجاح' : 'Login Successful')),
          backgroundColor: Colors.green,
        ),
      );

      // If login was successful but user is null, it means OTP is required (unverified account)
      if (authProvider.currentUser == null) {
        Navigator.pushNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phone': _phoneController.text.trim(),
            'isPasswordReset': false,
          },
        );
      } else {
        Navigator.pushNamedAndRemoveUntil(
          context,
          RouteNames.mainLayout,
          (route) => false,
        );
      }
    } else {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? (isAr ? 'فشل تسجيل الدخول' : 'Login Failure')),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 48.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 40),

                // Logo
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Image.asset(
                      'assets/images/app_logo.png',
                      width: 300,
                      height: 300,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),
                SizedBox(height: 24),

                Text(
                  (isAr ? 'مرحباً بعودتك' : '- Hey.'),
                  style: AppTextStyles.h1.copyWith(
                    color: Theme.of(context).textTheme.displayLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  (isAr ? 'سجل الدخول لمتابعة رحلتك الصحية' : 'Log in to continue your wellness journey'),
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 48),

                // Phone field
                AppTextField(
                  controller: _phoneController,
                  label: (isAr ? 'رقم الجوال' : 'Mobile No.'),
                  hint: (isAr ? 'أدخل رقم الجوال' : 'Enter your Mobile'),
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  validator: validatePhone,
                ),
                SizedBox(height: 20),

                // Password field
                AppTextField(
                  controller: _passwordController,
                  label: (isAr ? 'كلمة المرور' : 'PASSWORD'),
                  hint: (isAr ? 'أدخل كلمة المرور' : 'enter_password'),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                SizedBox(height: 12),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, RouteNames.forgotPassword);
                    },
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text(
                      (isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?'),
                      style: AppTextStyles.body.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 32),

                // Login button
                AppButton(
                  text: (isAr ? 'تسجيل الدخول' : 'Logging'),
                  onPressed: _handleLogin,
                  isLoading: _isLoading,
                ),
                SizedBox(height: 24),

                // Sign up link
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (isAr ? 'ليس لديك حساب؟ ' : 'Don\'t have account?'),
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.roleSelection);
                      },
                      child: Text(
                        (isAr ? 'إنشاء حساب' : 'Create account'),
                        style: AppTextStyles.body.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
