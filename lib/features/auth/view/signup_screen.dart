import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/router/route_names.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/enums/user_role.dart';
import '../../../shared/widgets/app_button.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/mixins/form_validation_mixin.dart';
import '../../../shared/providers/auth_provider.dart';
import 'package:provider/provider.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';

/// Signup Screen
///
/// User registration with role-specific fields
/// Features:
/// - Common fields (name, email, password, phone)
/// - Parent fields (child name, age)
/// - Doctor fields (specialization, license, experience)
/// - Complete validation
/// - Loading state
class SignupScreen extends StatefulWidget {
  final UserRole? selectedRole;

  const SignupScreen({super.key, this.selectedRole});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> with FormValidationMixin {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _phoneController = TextEditingController();

  // Parent fields
  final _childNameController = TextEditingController();
  final _childAgeController = TextEditingController();

  // Doctor fields
  final _clinicLocationController = TextEditingController();
  final _licenseNumberController = TextEditingController();

  File? _userImage;
  File? _childImage;
  final _imagePicker = ImagePicker();

  bool _isLoading = false;
  late UserRole _selectedRole;

  @override
  void initState() {
    super.initState();
    _selectedRole = widget.selectedRole ?? UserRole.parent;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _phoneController.dispose();
    _childNameController.dispose();
    _childAgeController.dispose();
    _clinicLocationController.dispose();
    _licenseNumberController.dispose();
    super.dispose();
  }

  Future<void> _pickImage({required bool isChild}) async {
    try {
      final pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 70,
      );
      if (pickedFile != null) {
        setState(() {
          if (isChild) {
            _childImage = File(pickedFile.path);
          } else {
            _userImage = File(pickedFile.path);
          }
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل اختيار الصورة: $e')),
        );
      }
    }
  }

  Future<void> _handleSignup() async {
    if (!validateForm()) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    if (_selectedRole.isParent && _childImage == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text((isAr ? 'الرجاء إرفاق صورة الطفل (إجباري)' : 'Please attach a photo of the child (mandatory)')),
          backgroundColor: AppColors.destructive,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final authProvider = context.read<AuthProvider>();

      final success = await authProvider.register(
        name: _nameController.text.trim(),
        email: _emailController.text.trim(),
        phone: _phoneController.text.trim(),
        password: _passwordController.text,
        passwordConfirmation: _confirmPasswordController.text,
        role: _selectedRole.isParent ? 'patient' : 'doctor',
        childName:
            _selectedRole.isParent ? _childNameController.text.trim() : null,
        childAge: _selectedRole.isParent
            ? int.tryParse(_childAgeController.text)
            : null,
        doctorNumber: _selectedRole.isDoctor
            ? _licenseNumberController.text.trim()
            : null,
        clinicLocation: _selectedRole.isDoctor
            ? _clinicLocationController.text.trim()
            : null,
        userImageUrl: _userImage?.path,
        childImageUrl: _childImage?.path,
      );

      if (!mounted) return;

      if (success) {
        // ── Case 1: Backend returned token + user directly ──
        if (authProvider.isAuthenticated && authProvider.currentUser != null) {
          if (!mounted) return;
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.mainLayout,
            (route) => false,
          );
          return;
        }

        // ── Case 2: Try auto-login with the same credentials ──
        final loginSuccess = await authProvider.login(
          phone: _phoneController.text.trim(),
          password: _passwordController.text,
        );

        if (!mounted) return;

        if (loginSuccess && authProvider.currentUser != null) {
          // Auto-login succeeded → go to main app
          Navigator.pushNamedAndRemoveUntil(
            context,
            RouteNames.mainLayout,
            (route) => false,
          );
          return;
        }

        // ── Case 3: Auto-login failed (OTP required) → send to OTP screen ──
        Navigator.pushNamed(
          context,
          RouteNames.otpVerification,
          arguments: {
            'phone': _phoneController.text.trim(),
            'password': _passwordController.text,
            'isPasswordReset': false,
          },
        );
      } else {
        if (!mounted) return;
        _showErrorSnackBar(authProvider.errorMessage ?? (isAr ? 'فشل إنشاء الحساب' : 'Signup failed'));
      }
    } catch (e) {
      if (!mounted) return;

      _showErrorSnackBar(e.toString());
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Widget _buildPhotoInputField({
    required File? imageFile,
    required VoidCallback onTap,
    required String label,
    required String hint,
    required IconData prefixIcon,
  }) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: AppTextStyles.label,
          ),
          SizedBox(height: 8),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color:
                    imageFile != null ? AppColors.primary : AppColors.secondary,
                width: imageFile != null ? 2.0 : 1.0,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  prefixIcon,
                  color: AppColors.mutedForeground,
                  size: 24,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    imageFile != null ? (isAr ? 'تم رفع الصورة بنجاح' : 'Image is uploaded success') : hint,
                    style: AppTextStyles.body.copyWith(
                      color: imageFile != null
                          ? Theme.of(context).textTheme.bodyLarge?.color
                          : AppColors.mutedForeground,
                    ),
                  ),
                ),
                if (imageFile != null) ...[
                  SizedBox(width: 12),
                  ClipOval(
                    child: Image.file(
                      imageFile,
                      width: 32,
                      height: 32,
                      fit: BoxFit.cover,
                    ),
                  ),
                ] else ...[
                  SizedBox(width: 12),
                  Icon(
                    Icons.camera_alt_outlined,
                    size: 24,
                    color: AppColors.mutedForeground,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
          child: Form(
            key: formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: 20),

                // Header with Logo
                Center(
                  child: Hero(
                    tag: 'app_logo',
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Theme.of(context).dividerColor,
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color:
                                Theme.of(context).brightness == Brightness.light
                                    ? AppColors.primary.withValues(alpha: 0.15)
                                    : Colors.black.withValues(alpha: 0.3),
                            blurRadius: 20,
                            offset: Offset(0, 8),
                          ),
                        ],
                      ),
                      child: ClipOval(
                        child: Image.asset(
                          'assets/images/lumo-logo.png',
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 24),

                Text(
                  (isAr ? 'إنشاء حساب' : 'Create account'),
                  style: AppTextStyles.h1.copyWith(
                    color: Theme.of(context).textTheme.displayLarge?.color,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'التسجيل ك${_selectedRole.isDoctor ? (isAr ? "طبيب" : "DOCTOR") : (isAr ? "مستخدم" : "Users")}',
                  style: AppTextStyles.body.copyWith(
                    color: Theme.of(context).hintColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 32),

                // Common fields
                AppTextField(
                  controller: _nameController,
                  label: (isAr ? 'الاسم الكامل' : '_ Full name'),
                  hint: (isAr ? 'أدخل اسمك الكامل' : 'Enter your full name'),
                  prefixIcon: Icons.person_outline,
                  validator: validateName,
                ),
                SizedBox(height: 20),
                _buildPhotoInputField(
                  imageFile: _userImage,
                  onTap: () => _pickImage(isChild: false),
                  label: (isAr ? 'الصورة الشخصية' : 'Personal photo'),
                  hint: (isAr ? 'أضف صورتك الشخصية (اختياري)' : 'Add your profile photo (optional)'),
                  prefixIcon: _selectedRole.isDoctor
                      ? Icons.medical_services_outlined
                      : Icons.person_outline,
                ),
                SizedBox(height: 20),
                AppTextField(
                  controller: _emailController,
                  label: (isAr ? 'البريد الإلكتروني' : 'Email'),
                  hint: (isAr ? 'أدخل بريدك الإلكتروني' : 'Enter your email'),
                  prefixIcon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  validator: validateEmail,
                ),
                SizedBox(height: 20),
                AppTextField(
                  controller: _phoneController,
                  label: (isAr ? 'رقم الجوال' : 'Mobile No.'),
                  hint: (isAr ? 'أدخل رقم الجوال' : 'Enter your Mobile'),
                  prefixIcon: Icons.phone_android_outlined,
                  keyboardType: TextInputType.phone,
                  validator: validatePhone,
                ),
                SizedBox(height: 20),
                AppTextField(
                  controller: _passwordController,
                  label: (isAr ? 'كلمة المرور' : 'PASSWORD'),
                  hint: (isAr ? 'أنشئ كلمة مرور' : 'Create a password'),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: validatePassword,
                ),
                SizedBox(height: 20),
                AppTextField(
                  controller: _confirmPasswordController,
                  label: (isAr ? 'تأكيد كلمة المرور' : 'تأكيد كلمة المرور'),
                  hint: (isAr ? 'أكد كلمة المرور' : 'Confirm your password'),
                  prefixIcon: Icons.lock_outline,
                  obscureText: true,
                  validator: (value) => validateConfirmPassword(
                    value,
                    _passwordController.text,
                  ),
                ),

                // Role-specific fields
                if (_selectedRole.isParent) ...[
                  SizedBox(height: 24),
                  Divider(),
                  SizedBox(height: 24),
                  AppTextField(
                    controller: _childNameController,
                    label: (isAr ? 'اسم الطفل' : 'Child’s Name'),
                    hint: (isAr ? 'أدخل اسم الطفل فقط' : 'Enter child name'),
                    prefixIcon: Icons.favorite_border,
                    inputFormatters: [
                      FilteringTextInputFormatter.deny(RegExp(r'\s')),
                    ],
                    validator: validateChildName,
                  ),
                  SizedBox(height: 20),
                  _buildPhotoInputField(
                    imageFile: _childImage,
                    onTap: () => _pickImage(isChild: true),
                    label: (isAr ? 'صورة الطفل' : 'the child picture'),
                    hint: (isAr ? 'أضف صورة الطفل (إجباري)' : 'Add child\'s photo (mandatory)'),
                    prefixIcon: Icons.child_care_outlined,
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: _childAgeController,
                    label: (isAr ? 'عمر الطفل' : 'Age of child'),
                    hint: (isAr ? 'أدخل عمر الطفل' : 'Child Age'),
                    prefixIcon: Icons.calendar_today_outlined,
                    keyboardType: TextInputType.number,
                    validator: validateAge,
                  ),
                ],

                if (_selectedRole.isDoctor) ...[
                  SizedBox(height: 20),
                  AppTextField(
                    controller: _licenseNumberController,
                    label: (isAr ? 'رقم الطبيب / الترخيص' : 'Doctor Number/ License'),
                    hint: (isAr ? 'أدخل رقم الطبيب' : 'Enter Doctor Number'),
                    prefixIcon: Icons.credit_card_outlined,
                    keyboardType: TextInputType.number,
                    validator: validateLicenseNumber,
                  ),
                  SizedBox(height: 20),
                  AppTextField(
                    controller: _clinicLocationController,
                    label: (isAr ? 'موقع العيادة' : 'Practice location'),
                    hint: (isAr ? 'أدخل موقع العيادة' : 'Enter clinic location'),
                    prefixIcon: Icons.location_on_outlined,
                    validator: (value) => value == null || value.isEmpty ? (isAr ? 'يرجى إدخال موقع العيادة' : 'Please enter clinic location') : null,
                  ),
                ],

                SizedBox(height: 40),
                AppButton(
                  text: (isAr ? 'إنشاء حساب' : 'Create account'),
                  onPressed: _handleSignup,
                  isLoading: _isLoading,
                ),
                SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      (isAr ? 'لديك حساب بالفعل؟ ' : 'Already signed up?'),
                      style: AppTextStyles.body.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        Navigator.pushNamed(context, RouteNames.login);
                      },
                      child: Text(
                        (isAr ? 'تسجيل الدخول' : 'Logging'),
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

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.error_outline, color: Colors.white),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.destructive,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
        duration: Duration(seconds: 4),
      ),
    );
  }
}
