import 'dart:io' show Platform, SocketException;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

import '../../data/models/auth/auth_models.dart';
import '../../data/models/user_model.dart';
import '../../data/models/doctor_model.dart';
import '../../data/models/parent_model.dart';
import '../../data/repositories/auth_repository.dart';
import '../../data/repositories/profile_repository.dart';
import '../../data/datasources/local_data_source.dart';
import '../../core/di/dependency_injection.dart';
import '../../core/services/notification_service.dart';
import 'notification_provider.dart';
import '../../core/network/api_exception.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final LocalDataSource _localDataSource;

  AuthProvider(
      this._authRepository, this._profileRepository, this._localDataSource);

  UserModel? _currentUser;
  bool _isLoading = false;
  String? _errorMessage;

 
  VoidCallback? _onSessionChangeCallback;

  UserModel? get currentUser => _currentUser;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  bool get isAuthenticated => _authRepository.isLoggedIn;

 
  void setSessionChangeCallback(VoidCallback callback) {
    _onSessionChangeCallback = callback;
  }

  // ─────────────────────────────────────────────
  //  Initialize — restore session from stored token
  // ─────────────────────────────────────────────

  Future<void> init() async {
    _setLoading(true);
    _errorMessage = null;
    notifyListeners();

    if (!_authRepository.isLoggedIn) {
      _setLoading(false);
      return;
    }

    // ── Priority 1: Restore from local cache ──
    final cachedUserJson = _localDataSource.getCurrentUser();
    if (cachedUserJson != null) {
      try {
        _currentUser = UserModel.fromJson(cachedUserJson);
      } catch (e) {
        debugPrint('Cached user corrupt: $e');
        await logout();
        await _localDataSource.clearAll();
        _setLoading(false);
        notifyListeners();
        return;
      }
    }

    // ── Priority 2: Refresh from API ──
    final userIdStr = _localDataSource.getCurrentUserId();
  
    if (userIdStr != null || _authRepository.isLoggedIn) {
      final userId = int.tryParse(userIdStr ?? '0') ?? 0;
      try {
        final refreshed = await _profileRepository
            .getUserProfile(userId)
            .timeout(const Duration(seconds: 10));
        if (refreshed != null) {
          UserModel updatedRefreshed = refreshed;
          // The backend getProfile endpoint might return 0 for counters.
          // Fetch actual lists to set the exact true count.
          try {
            final followersList = await _profileRepository.getFollowers(userId);
            final followingList = await _profileRepository.getFollowing(userId);
            
            if (updatedRefreshed is DoctorModel) {
              updatedRefreshed = updatedRefreshed.copyWith(
                followersCount: followersList.length,
                followingCount: followingList.length,
              );
            } else if (updatedRefreshed is ParentModel) {
              updatedRefreshed = updatedRefreshed.copyWith(
                followersCount: followersList.length,
                followingCount: followingList.length,
              );
            } else {
               updatedRefreshed = updatedRefreshed.copyWith(
                followersCount: followersList.length,
                followingCount: followingList.length,
              );
            }
          } catch (e) {
            debugPrint('Failed to fetch exact follow lists: $e');
            // If it fails, fallback to keeping local cache counts so we don't zero it
            if (_currentUser != null) {
               if (updatedRefreshed is DoctorModel) {
                  updatedRefreshed = updatedRefreshed.copyWith(
                    followersCount: _currentUser?.followersCount,
                    followingCount: _currentUser?.followingCount,
                  );
                } else if (updatedRefreshed is ParentModel) {
                  updatedRefreshed = updatedRefreshed.copyWith(
                    followersCount: _currentUser?.followersCount,
                    followingCount: _currentUser?.followingCount,
                  );
                } else {
                  updatedRefreshed = updatedRefreshed.copyWith(
                    followersCount: _currentUser?.followersCount,
                    followingCount: _currentUser?.followingCount,
                  );
                }
            }
          }

          _currentUser = updatedRefreshed;
          await _localDataSource.saveCurrentUser(updatedRefreshed.toJson());
          notifyListeners(); // Force UI update with fresh counts
        }
      } on SocketException {
        debugPrint('Auth init: offline, using cached data');
        // Do nothing else, keep using _currentUser from cache if available
      } catch (e) {
        // ✅ بدل string matching — بنتحقق من نوع الـ exception
        final isUnauthenticated = _isUnauthenticatedError(e);
        if (isUnauthenticated) {
          debugPrint('Token expired. Forcing logout.');
          await logout();
          await _localDataSource.clearAll();
          _setLoading(false);
          notifyListeners();
          return;
        }
        debugPrint('Profile refresh failed (keeping cache): $e');
      }
    }

    if (_currentUser != null) {
      _setupFcmListeners();
    }

    // ── Priority 3: Last resort ──
    if (_currentUser == null) {
      await logout();
    }

    _setLoading(false);
    notifyListeners();
  }

  bool _isUnauthenticatedError(Object e) {
    if (e is ApiException) {
      return e.statusCode == 401;
    }
    // Fallback للـ DioException أو غيره
    final msg = e.toString().toLowerCase();
    return msg.contains('401') || msg.contains('unauthenticated');
  }

  String _mapErrorToMessage(Object e) {
    if (e is ApiException) {
      if (e.statusCode == 401) {
        return 'رقم الهاتف أو كلمة المرور غير صحيحة';
      }
      if (e.statusCode == 422) {
        // إذا كان هناك رسالة من الباك اند نستخدمها، وإلا رسالة افتراضية
        return e.message.isNotEmpty ? e.message : 'البيانات المدخلة غير صحيحة أو مستخدمة مسبقاً';
      }
      return e.message.isNotEmpty ? e.message : 'حدث خطأ في الاتصال بالسيرفر';
    }
    
    final msg = e.toString().toLowerCase();
    if (msg.contains('401') || msg.contains('unauthenticated')) {
      return 'رقم الهاتف أو كلمة المرور غير صحيحة';
    }
    if (msg.contains('422')) {
      return 'البيانات المدخلة غير صحيحة أو مستخدمة مسبقاً';
    }
    if (msg.contains('network') || msg.contains('socket') || msg.contains('timeout')) {
      return 'فشل الاتصال بالإنترنت، يرجى المحاولة لاحقاً';
    }
    
    return 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً';
  }

  void _setupFcmListeners() {
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM listeners skipped: Firebase not initialized.');
      return;
    }
    // ── Listen for token refresh ──
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      try {
        await _authRepository.updateFcmToken(newToken);
      } catch (e) {
        debugPrint('FCM token refresh failed: $e');
      }
    });

    // ── Handle foreground messages ──
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      if (notification != null) {
        final title = notification.title ?? 'إشعار جديد';
        final body = notification.body ?? '';
        final type = message.data['type']?.toString();

        final t = (type ?? '').toLowerCase();
        final isConnectionNotification = t.contains('connection') || t.contains('request');
        final isSessionCompleted = t == 'session_completed';

        if (isConnectionNotification || isSessionCompleted) {
          // Show system notification (status bar)
          getIt<NotificationService>().showNotification(
            id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
            title: title,
            body: body,
            payload: isSessionCompleted ? 'session_completed:${message.data['id']}' : null,
          );

          // Show in-app banner + refresh list
          getIt<NotificationProvider>().handleForegroundFcmMessage(
            title: title,
            body: body,
            type: type,
          );
        } else {
          // Refresh notification list silently without showing notification/banner
          getIt<NotificationProvider>().fetchNotifications();
        }
      }
    });
  }

  // ─────────────────────────────────────────────
  //  Login
  // ─────────────────────────────────────────────

  Future<bool> login({
    required String phone,
    required String password,
    VoidCallback? onSuccess,
  }) async {
    if (_isLoading) return false;
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

      if (!response.status) {
        _errorMessage = response.message;
        return false;
      }

      if (response.user != null) {
        _currentUser = response.user;
        await _localDataSource.saveCurrentUser(_currentUser!.toJson());
        _setupFcmListeners();
        notifyListeners();
        if (onSuccess != null) onSuccess();
      }

      // Final safety: wipe error message before returning true
      _errorMessage = null;
      return true;
    } catch (e) {
      // Use the mapped message, but also store the literal exception for diagnostics if it's unexpected
      final mapped = _mapErrorToMessage(e);
      _errorMessage = (mapped == 'حدث خطأ غير متوقع، يرجى المحاولة لاحقاً')
          ? 'Error: ${e.toString()}'
          : mapped;
      
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
    String? userImageUrl,
    String? childImageUrl,
    VoidCallback? onSuccess,
  }) async {
    if (_isLoading) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      // ✅ Include FCM token on registration — matches login() behaviour
      final fcmToken = await _getFcmToken();

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
        avatarFilePath: userImageUrl,
        childPhotoPath: childImageUrl,
        fcmToken: fcmToken,
      );

      final AuthResponse response = await _authRepository.register(request);

      if (!response.status) {
        if (response.message.toLowerCase().contains('registration successful')) {
          _errorMessage = null;
          return true;
        }
        _errorMessage = response.message;
        return false;
      }

      if (response.user != null) {
        _currentUser = response.user;
        await _localDataSource.saveCurrentUser(_currentUser!.toJson());
        notifyListeners();
        if (onSuccess != null) onSuccess();
      }
      return true;
    } catch (e) {
      final mappedError = _mapErrorToMessage(e);
      final rawError = e.toString().toLowerCase();
      // Handle backend returning successful registration message as a 4xx HTTP error
      if (mappedError.toLowerCase().contains('registration successful') || rawError.contains('registration successful')) {
         _errorMessage = null;
         return true;
      }
      
      _errorMessage = mappedError;
      debugPrint('Register error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  OTP
  // ─────────────────────────────────────────────

  Future<MessageResponse?> verifyOtp({
    required String phone,
    required String otp,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authRepository.verifyOtp(
        VerifyOtpRequest(phone: phone, otp: otp),
      );
      // ✅ Do NOT call init() here — there is no persisted token yet at this
      // point (the backend only returns a token on the subsequent login call).
      // Calling init() would hit the isLoggedIn guard and return immediately,
      // wasting time and causing loading-state flicker on the OTP screen.
      // The OTP screen itself handles the auto-login after this returns.
      return response;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MessageResponse?> resendOtp({required String phone}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authRepository.resendOtp(
        ResendOtpRequest(phone: phone),
      );
      return response;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  Forgot / Reset Password
  // ─────────────────────────────────────────────

  Future<MessageResponse?> forgotPassword({required String email}) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authRepository.forgotPassword(
        ForgotPasswordRequest(email: email),
      );
      return response;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MessageResponse?> verifyResetOtp({
    required String phone,
    required String otp,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authRepository.verifyResetOtp(
        VerifyOtpRequest(phone: phone, otp: otp),
      );
      return response;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  Future<MessageResponse?> resetPassword({
    required String phone,
    required String password,
    required String passwordConfirmation,
    required String otp,
  }) async {
    _setLoading(true);
    _errorMessage = null;
    try {
      final response = await _authRepository.resetPassword(
        ResetPasswordRequest(
          phone: phone,
          password: password,
          passwordConfirmation: passwordConfirmation,
          otp: otp,
        ),
      );
      return response;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  Update Profile
  // ─────────────────────────────────────────────

  Future<bool> updateProfile({
    String? name,
    String? phone,
    String? bio,
    String? avatarFilePath,
    String? childName,
    int? childAge,
    String? childMedicalCondition,
    String? childPhotoUrl,
  }) async {
    if (_currentUser == null) return false;
    _setLoading(true);
    _errorMessage = null;

    try {
      final updatedUser = await _profileRepository.updateProfile(
        userId: _currentUser!.id,
        name: name,
        phone: phone,
        bio: bio,
        avatarFilePath: avatarFilePath,
        childName: childName,
        childAge: childAge,
        childMedicalCondition: childMedicalCondition,
        childPhotoUrl: childPhotoUrl,
      );
      _currentUser = updatedUser;
      await _localDataSource.saveCurrentUser(updatedUser.toJson());
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
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
    } catch (_) {
      // Ensure local state is cleared even if the API call fails
    }

    // ✅ بننادي الـ callback اللي اتسجل من بره لتصفير الـ ViewModels
    try {
      _onSessionChangeCallback?.call();
    } catch (e) {
      debugPrint('Session change callback error (logout): $e');
    }

    _currentUser = null;
    notifyListeners();
  }

  // ─────────────────────────────────────────────
  //  Helpers
  // ─────────────────────────────────────────────

  /// Update current user locally in memory and cache
  void updateCurrentUserLocally(UserModel updatedUser) {
    _currentUser = updatedUser;
    _localDataSource.saveCurrentUser(updatedUser.toJson());
    notifyListeners();
  }

  void updateFollowingCount(bool increment) {
    if (_currentUser == null) return;

    final currentCount = _currentUser!.followingCount ?? 0;
    int newCount = increment ? currentCount + 1 : currentCount - 1;
    if (newCount < 0) newCount = 0;

    if (_currentUser is DoctorModel) {
      _currentUser = (_currentUser as DoctorModel).copyWith(followingCount: newCount);
    } else if (_currentUser is ParentModel) {
      _currentUser = (_currentUser as ParentModel).copyWith(followingCount: newCount);
    } else {
      _currentUser = _currentUser!.copyWith(followingCount: newCount);
    }

    _localDataSource.saveCurrentUser(_currentUser!.toJson());
    notifyListeners();
  }

  void updateFollowersCount(bool increment) {
    if (_currentUser == null) return;

    final currentCount = _currentUser!.followersCount ?? 0;
    int newCount = increment ? currentCount + 1 : currentCount - 1;
    if (newCount < 0) newCount = 0;

    if (_currentUser is DoctorModel) {
      _currentUser =
          (_currentUser as DoctorModel).copyWith(followersCount: newCount);
    } else if (_currentUser is ParentModel) {
      _currentUser =
          (_currentUser as ParentModel).copyWith(followersCount: newCount);
    } else {
      _currentUser = _currentUser!.copyWith(followersCount: newCount);
    }

    _localDataSource.saveCurrentUser(_currentUser!.toJson());
    notifyListeners();
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    _setLoading(true);
    clearError();

    try {
      await _authRepository.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
        confirmPassword: confirmPassword,
      );
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      debugPrint('Change password error: $e');
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ─────────────────────────────────────────────
  //  Follow / Unfollow
  // ─────────────────────────────────────────────

  /// Follows a user, updates counts, and sends a notification.
  /// Returns the updated [UserModel] of the user who was followed on success.
  Future<UserModel?> followUser(UserModel userToFollow) async {
    if (_currentUser == null) return null;
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. تحديث البيانات في الباك اند (Firebase & REST)
      try {
        await _profileRepository.followUser(_currentUser!.id, userToFollow.id);
        await _profileRepository.toggleFollow(userToFollow.id);
      } catch (e) {
        debugPrint('Backend follow sync failed: $e');
      }

      // 2. تحديث عدد من يتابعهم الـ current user فقط (following)
      //    لا نمس followersCount للـ current user لأنه يتحكم فيه الـ target user
      updateFollowingCount(true);

      // 3. إرسال إشعار للمستخدم الذي تمت متابعته.
      try {
        final notificationProvider = getIt<NotificationProvider>();
        await notificationProvider.sendFollowNotification(
          targetUserId: userToFollow.id,
          followerName: _currentUser!.name,
        );
      } catch (e) {
        debugPrint('Could not send follow notification: $e');
      }

      // 4. إرجاع موديل محدّث ليستخدمه الـ ViewModel في تحديث الواجهة.
      final updatedUserToFollow = _updateUserCountersLocally(userToFollow, 1);
      return updatedUserToFollow;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      debugPrint('Follow user error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// Unfollows a user and updates counts.
  /// Returns the updated [UserModel] of the user who was unfollowed on success.
  Future<UserModel?> unfollowUser(UserModel userToUnfollow) async {
    if (_currentUser == null) return null;
    _setLoading(true);
    _errorMessage = null;

    try {
      // 1. تحديث البيانات في الباك اند (Firebase & REST)
      try {
        await _profileRepository.unfollowUser(_currentUser!.id, userToUnfollow.id);
        await _profileRepository.toggleFollow(userToUnfollow.id);
      } catch (e) {
        debugPrint('Backend unfollow sync failed: $e');
      }

      // 2. تحديث عدد من يتابعهم الـ current user فقط (following)
      updateFollowingCount(false);

      // 3. إرجاع موديل محدّث ليستخدمه الـ ViewModel في تحديث الواجهة.
      final updatedUserToUnfollow = _updateUserCountersLocally(userToUnfollow, -1);
      return updatedUserToUnfollow;
    } catch (e) {
      _errorMessage = _mapErrorToMessage(e);
      debugPrint('Unfollow user error: $e');
      return null;
    } finally {
      _setLoading(false);
    }
  }

  /// دالة مساعدة لتحديث العدادات باستخدام copyWith
  UserModel _updateUserCountersLocally(UserModel user, int followersChange) {
    final currentCount = user.followersCount ?? 0;
    int newCount = currentCount + followersChange;
    if (newCount < 0) newCount = 0;

    if (user is DoctorModel) {
      return user.copyWith(followersCount: newCount);
    } else if (user is ParentModel) {
      return user.copyWith(followersCount: newCount);
    } else {
      return user.copyWith(followersCount: newCount);
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<String?> _getFcmToken() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM token retrieval skipped: Firebase not initialized.');
      return null;
    }

    if (kIsWeb) {
      try {
        return await FirebaseMessaging.instance
            .getToken()
            .timeout(const Duration(seconds: 3));
      } catch (e) {
        debugPrint('Failed to get FCM token (Web): $e');
        return null;
      }
    }

    // ✅ Desktop platforms — بنرجع null بدل dummy token
    if (Platform.isLinux || Platform.isWindows) {
      debugPrint('FCM not supported on desktop. Skipping token.');
      return null;
    }

    try {
      return await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 5));
    } catch (e) {
      debugPrint('Failed to get FCM token: $e');
      return null;
    }
  }
}
