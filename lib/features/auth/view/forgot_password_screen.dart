import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/mixins/form_validation_mixin.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen>
    with FormValidationMixin {
  final _phoneController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _handleSendCode() async {
    if (_phoneController.text.trim().isEmpty) return;

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.forgotPassword(
      phone: _phoneController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response != null && response.status) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );

      Navigator.pushNamed(
        context,
        RouteNames.otpVerification,
        arguments: {
          'phone': _phoneController.text.trim(),
          'isPasswordReset': true,
        },
      );
    } else {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? (isAr ? 'فشل إرسال رمز التحقق' : 'Failed to send a verification code')),
          backgroundColor: AppColors.destructive,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFE3F2FD), Colors.white],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 48, 24, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.pop(context),
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(height: 24),
                    Text(
                      (isAr ? 'نسيت كلمة المرور؟' : 'Forgot Password?'),
                      style: AppTextStyles.h1.copyWith(
                        color: Theme.of(context).textTheme.displayLarge?.color,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      (isAr ? 'أدخل رقم هاتفك وسنرسل لك رمز التحقق' : 'Enter your phone number and we\'ll send you a verification code'),
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                  ],
                ),
              ),

              Expanded(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppTextField(
                        controller: _phoneController,
                        label: (isAr ? 'رقم الهاتف' : 'Phone'),
                        hint: '+966 50 123 4567',
                        prefixIcon: Icons.phone_outlined,
                        keyboardType: TextInputType.phone,
                      ),
                      SizedBox(height: 24),

                      AppButton(
                        text:
                            _isLoading ? (isAr ? 'جاري الإرسال...' : 'Sending...') : (isAr ? 'إرسال رمز التحقق' : 'Send OTP'),
                        onPressed:
                            _phoneController.text.trim().isEmpty && !_isLoading
                                ? null
                                : _handleSendCode,
                        isLoading: _isLoading,
                      ),

                      SizedBox(height: 32),

                      Container(
                        padding: EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Color(0xFFE3F2FD),
                          ),
                        ),
                        child: Text(
                          (isAr ? 'سيتم إرسال رمز التحقق عبر رسالة نصية إلى رقم هاتفك. قد يستغرق الأمر بضع دقائق.' : 'The verification code will be sent via text message to your phone number. It may take a few minutes.'),
                          style: AppTextStyles.bodySmall.copyWith(
                            color: Theme.of(context).hintColor,
                          ),
                          textAlign: TextAlign.right,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
