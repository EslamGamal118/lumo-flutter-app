import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:app_badge_plus/app_badge_plus.dart';
import '../../core/services/notification_service.dart';
import '../../data/repositories/notification_repository.dart';

class NotificationProvider extends ChangeNotifier {
  final NotificationService _notificationService;
  final NotificationRepository? _repository;

  NotificationProvider(this._notificationService, [this._repository]);

  bool _notificationsEnabled = true;
  int _unreadCount = 0;
  List<dynamic> _notifications = [];
  bool _isLoading = false;
  String? _errorMessage;

  bool get notificationsEnabled => _notificationsEnabled;
  int get unreadCount => _unreadCount;
  List<dynamic> get notifications => _notifications;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  // Initialize notifications
  Future<void> init() async {
    await _notificationService.initialize();
    await _notificationService.requestPermissions();
    if (_repository != null) {
      await fetchNotifications();
    }
  }

  // Fetch from backend
  Future<void> fetchNotifications() async {
    if (_repository == null) return;
    
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      _notifications = await _repository.getNotifications();
      // Update unread count based on logic (handling both bool and int from backend)
      _unreadCount = _notifications.where((n) {
        final isRead = n['is_read'];
        return isRead == false || isRead == 0 || isRead == null || n['read_at'] == null;
      }).length;
      _updateAppBadge();
    } catch (e) {
      _errorMessage = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Mark all as read
  Future<void> markAllAsRead() async {
    if (_repository == null) return;
    
    try {
      await _repository.markNotificationsAsRead();
      _unreadCount = 0;
      _updateAppBadge();
      notifyListeners();
      // We intentionally do NOT call fetchNotifications() here!
      // This allows the NotificationsScreen to keep the visual "unread highlight" 
      // on previously unread items until the user leaves and refreshes later.
    } catch (e) {
      debugPrint('Failed to mark notifications as read: $e');
    }
  }

  // Delete notifications older than a date
  Future<void> clearNotifications(DateTime date) async {
    if (_repository == null) return;
    
    try {
      await _repository.deleteNotifications(date);
      await fetchNotifications();
    } catch (e) {
      debugPrint('Failed to delete notifications: $e');
    }
  }

  // Toggle notifications
  void toggleNotifications(bool enabled) {
    _notificationsEnabled = enabled;
    notifyListeners();
  }

  // Update unread count manually
  void updateUnreadCount(int count) {
    _unreadCount = count;
    notifyListeners();
  }

  // Increment unread count
  void incrementUnreadCount() {
    _unreadCount++;
    _updateAppBadge();
    notifyListeners();
  }

  // Clear unread count
  void clearUnreadCount() {
    _unreadCount = 0;
    _updateAppBadge();
    notifyListeners();
  }

  /// Updates the app icon badge based on the current unread count.
  void _updateAppBadge() {
    try {
      // AppBadgePlus supports Android and iOS
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        if (_unreadCount > 0) {
          AppBadgePlus.updateBadge(_unreadCount);
        } else {
          AppBadgePlus.updateBadge(0);
        }
      }
    } catch (e) {
      debugPrint('App badger update failed (platform may not support it): $e');
    }
  }

  // Show local notification
  Future<void> showNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    if (!_notificationsEnabled) return;

    await _notificationService.showNotification(
      id: DateTime.now().millisecondsSinceEpoch.remainder(100000),
      title: title,
      body: body,
      payload: payload,
    );
  }

  // Send post like notification (server-side action typically, but kept for compatibility)
  Future<void> sendPostLikeNotification({
    required int postId,
    required int postOwnerId,
    required String likerName,
  }) async {
    debugPrint(
        'Sending like notification for post $postId to owner $postOwnerId');
    // Actual backend handles this when toggleLike is called
  }

  // Send connection accepted notification
  Future<void> sendConnectionAcceptedNotification({
    required int doctorId,
    required String patientName,
  }) async {
    debugPrint('Connection accepted: Backend handles FCM for doctor $doctorId');
    await fetchNotifications();
  }

  // Send follow notification — backend handles actual push to target user
  Future<void> sendFollowNotification({
    required int targetUserId,
    required String followerName,
  }) async {
    // The backend (Laravel) is responsible for sending FCM push notification 
    // to targetUserId when POST /user/{id}/follow is called.
    // On the app side, we just refresh the local notification list for the current user.
    debugPrint('Follow action completed — Backend handles FCM push to user $targetUserId');
    await fetchNotifications();
  }

  // Send comment notification
  Future<void> sendCommentNotification({
    required int postId,
    required int postOwnerId,
    required String commenterName,
  }) async {
    debugPrint('User $commenterName commented on post $postId');
    // Backend handles this
  }

  // Send chat message notification
  Future<void> sendMessageNotification({
    required int targetUserId,
    required String senderName,
    required String messagePreview,
  }) async {
    debugPrint('Message notification from $senderName to $targetUserId');
    await showNotification(
      title: 'رسالة جديدة من $senderName',
      body: messagePreview,
      payload: 'chat_$targetUserId',
    );
  }
}
