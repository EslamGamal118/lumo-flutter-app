import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/providers/auth_provider.dart';
import '../../../shared/mixins/form_validation_mixin.dart';

class OtpVerificationScreen extends StatefulWidget {
  final String phone;
  final bool isPasswordReset;
  final String? password; // للـ auto-login بعد التحقق من OTP التسجيل

  const OtpVerificationScreen({
    super.key,
    required this.phone,
    this.isPasswordReset = false,
    this.password,
  });

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen>
    with FormValidationMixin {
  final List<TextEditingController> _controllers =
      List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(4, (_) => FocusNode());
  bool _isLoading = false;

  @override
  void dispose() {
    for (var controller in _controllers) {
      controller.dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _handleVerify() async {
    if (_otp.length < 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('يرجى إدخال رمز التحقق كاملاً')),
      );
      return;
    }

    setState(() => _isLoading = true);

    final authProvider = context.read<AuthProvider>();

    final response = widget.isPasswordReset
        ? await authProvider.verifyResetOtp(phone: widget.phone, otp: _otp)
        : await authProvider.verifyOtp(phone: widget.phone, otp: _otp);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response != null && response.status) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.primary,
        ),
      );

      if (widget.isPasswordReset) {
        Navigator.pushReplacementNamed(
          context,
          RouteNames.resetPassword,
          arguments: {
            'phone': widget.phone,
            'otp': _otp,
          },
        );
      } else {
        // تسجيل دخول تلقائي بعد التحقق من OTP
        final password = widget.password;
        if (password != null && password.isNotEmpty) {
          setState(() => _isLoading = true);
          final loginSuccess = await authProvider.login(
            phone: widget.phone,
            password: password,
          );
          if (!mounted) return;
          setState(() => _isLoading = false);

          if (loginSuccess) {
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.mainLayout,
              (route) => false,
            );
          } else {
            // لو فشل الـ login، روح لـ login screen
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('تم التحقق، يرجى تسجيل الدخول(isAr ? '),
                backgroundColor: AppColors.primary,
              ),
            );
            Navigator.pushNamedAndRemoveUntil(
              context,
              RouteNames.login,
              (route) => false,
            );
          }
        } else {
          // Fallback: روح login screen
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.login,
            (route) => false,
          );
        }
      }
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? 'رمز التحقق غير صحيح'),
          backgroundColor: AppColors.destructive,
        ),
      );
    }
  }

  Future<void> _handleResend() async {
    setState(() => _isLoading = true);
    final authProvider = context.read<AuthProvider>();
    final response = await authProvider.resendOtp(phone: widget.phone);

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (response != null && response.status) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(response.message),
          backgroundColor: AppColors.primary,
        ),
      );
    } else {
      final isAr = Localizations.localeOf(context).languageCode == 'ar';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.errorMessage ?? (isAr ? 'فشل إعادة إرسال الرمز' : 'Resend Code')),
          backgroundColor: AppColors.destructive,
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
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 48),
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Icon(
                        Icons.arrow_back_ios_rounded,
                        size: 24,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  SizedBox(height: 24),
                  Text(
                    (isAr ? 'رمز التحقق' : 'Verification Code'),
                    style: AppTextStyles.h1.copyWith(
                      color: Theme.of(context).textTheme.displayLarge?.color,
                      fontSize: 30,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 8),
                  Text(
                    'لقد أرسلنا رمز التحقق المكون من 4 أرقام إلى رقم الهاتف ${widget.phone}',
                    style: AppTextStyles.body.copyWith(
                      color: Theme.of(context).hintColor,
                    ),
                    textAlign: TextAlign.right,
                  ),
                  SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(4, (index) {
                      return SizedBox(
                        width: 60,
                        child: TextField(
                          controller: _controllers[index],
                          focusNode: _focusNodes[index],
                          textAlign: TextAlign.center,
                          keyboardType: TextInputType.number,
                          maxLength: 1,
                          style: AppTextStyles.h2
                              .copyWith(color: AppColors.primary),
                          decoration: InputDecoration(
                            counterText: '',
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide:
                                  BorderSide(color: Colors.grey.shade300),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: BorderSide(
                                  color: AppColors.primary, width: 2),
                            ),
                          ),
                          onChanged: (value) {
                            if (value.isNotEmpty && index < 3) {
                              _focusNodes[index + 1].requestFocus();
                            } else if (value.isEmpty && index > 0) {
                              _focusNodes[index - 1].requestFocus();
                            }
                            if (_otp.length == 4) {
                              _handleVerify();
                            }
                          },
                        ),
                      );
                    }),
                  ),
                  SizedBox(height: 48),
                  AppButton(
                    text: (isAr ? 'تحقق' : 'Verify'),
                    onPressed: _handleVerify,
                    isLoading: _isLoading,
                  ),
                  SizedBox(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      TextButton(
                        onPressed: _isLoading ? null : _handleResend,
                        child: Text(
                          (isAr ? 'إعادة إرسال الرمز' : 'Resend Code'),
                          style: AppTextStyles.body.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        (isAr ? 'لم يصلك الرمز؟' : "Don't have your code? "),
                        style: AppTextStyles.body
                            .copyWith(color: Theme.of(context).hintColor),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
