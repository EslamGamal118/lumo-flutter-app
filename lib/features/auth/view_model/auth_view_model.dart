import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../../data/models/auth/auth_models.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/auth_repository.dart';

/// Auth ViewModel
///
/// Complete authentication state management.
/// Delegates to [AuthRepository] for all REST API calls.
class AuthViewModel extends ChangeNotifier {
  final AuthRepository _authRepository;

  AuthViewModel(this._authRepository);

  bool _isLoading = false;
  String? _errorMessage;
  UserModel? _currentUser;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserModel? get currentUser => _currentUser;
  bool get isAuthenticated => _authRepository.isLoggedIn;

  // ─────────────────────────────────────────────
  //  Login
  // ─────────────────────────────────────────────

  Future<bool> login(String phone, String password) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final fcmToken = await _getFcmToken();

      final request = LoginRequest(
        phone: phone,
        password: password,
        fcmToken: fcmToken,
      );

      final AuthResponse response = await _authRepository.login(request);

      if (response.user != null) {
        _currentUser = response.user;
      }

      _errorMessage = null;
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      debugPrint('Login error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  Register
  // ─────────────────────────────────────────────

  Future<bool> register({
    required String name,
    required String email,
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String role,
    String? childName,
    int? childAge,
    String? doctorNumber,
    String? clinicLocation,
  }) async {
    _setLoading(true);
    _errorMessage = null;

    try {
      final request = RegisterRequest(
        name: name,
        email: email,
        phone: phone,
        password: password,
        passwordConfirmation: passwordConfirmation,
        role: role,
        childName: childName,
        childAge: childAge,
        doctorNumber: doctorNumber,
        clinicLocation: clinicLocation,
      );

      final AuthResponse response = await _authRepository.register(request);

      if (response.user != null) {
        _currentUser = response.user;
      }

      return true;
    } catch (e) {
      _errorMessage = e.toString();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  Logout
  // ─────────────────────────────────────────────

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {}
    _currentUser = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  Future<String?> _getFcmToken() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM token retrieval skipped: Firebase not initialized.');
      return null;
    }
    try {
      return await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 3));
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }
}
