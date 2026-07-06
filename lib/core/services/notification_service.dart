import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../di/dependency_injection.dart';
import '../../data/repositories/auth_repository.dart';
import '../../app.dart';
import '../router/route_names.dart';

class NotificationService {
  final FlutterLocalNotificationsPlugin _flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> initialize() async {
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open notification',
    );

    const initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
      linux: linuxSettings,
    );

    await _flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationTapped,
    );

    // Initialize FCM setup
    await setupFcm();
  }

  Future<void> setupFcm() async {
    if (Firebase.apps.isEmpty) {
      debugPrint('FCM setup skipped: Firebase not initialized.');
      return;
    }

    // 1. Request permissions (essential for iOS and Android 13+)
    await requestPermissions();

    // 2. Fetch and send the initial token to the backend
    try {
      final String? token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        debugPrint('FCM Token generated: $token');
        await _sendTokenToServer(token);
      }
    } catch (e) {
      debugPrint('Error getting initial FCM token: $e');
    }

    // 3. Monitor token changes and send the new token to backend
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) {
      debugPrint('FCM Token refreshed: $newToken');
      _sendTokenToServer(newToken);
    }).onError((error) {
      debugPrint('Error onTokenRefresh: $error');
    });

    // 4. Listen for foreground notifications
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint('FCM Foreground Message Received: ${message.messageId}');
      
      // Extract notification details
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        // Show an elegant Local Notification using flutter_local_notifications
        showNotification(
          id: notification.hashCode,
          title: notification.title ?? 'إشعار جديد',
          body: notification.body ?? '',
          payload: message.data.toString(),
        );
      }
    });
  }

  Future<void> _sendTokenToServer(String token) async {
    try {
      if (getIt.isRegistered<AuthRepository>()) {
        final authRepo = getIt<AuthRepository>();
        if (authRepo.isLoggedIn) {
          await authRepo.updateFcmToken(token);
          debugPrint('FCM token successfully sent to Laravel backend.');
        }
      }
    } catch (e) {
      debugPrint('Failed to send FCM token to backend: $e');
    }
  }

  void _onNotificationTapped(NotificationResponse response) {
    final payload = response.payload;
    if (payload != null && payload.contains(':')) {
      final parts = payload.split(':');
      if (parts.length >= 2) {
        handleNavigation(parts[0], parts[1]);
      }
    }
  }

  static void handleRemoteMessage(RemoteMessage message) {
    if (message.data.containsKey('type') && message.data.containsKey('id')) {
      handleNavigation(message.data['type'], message.data['id'].toString());
    } else if (message.data.containsKey('payload')) {
      final payload = message.data['payload'].toString();
      if (payload.contains(':')) {
        final parts = payload.split(':');
        if (parts.length >= 2) {
          handleNavigation(parts[0], parts[1]);
        }
      }
    }
  }

  static void handleNavigation(String type, String id) {
    final context = globalNavigatorKey.currentContext;
    if (context != null) {
      switch (type) {
        case 'chat':
          Navigator.pushNamed(context, RouteNames.chatRoom, arguments: {
            'chatRoomId': id,
          });
          break;
        case 'post':
          final postId = int.tryParse(id);
          if (postId != null) {
            Navigator.pushNamed(context, RouteNames.postDetail, arguments: postId);
          }
          break;
        case 'profile':
          final userId = int.tryParse(id);
          if (userId != null) {
            Navigator.pushNamed(context, RouteNames.profile, arguments: {
              'userId': userId,
            });
          }
          break;
        // Additional types like 'connection_request' or 'analysis' can be added here
        case 'session_completed':
          // Navigate to the analysis tab (index 1 in MainLayout)
          Navigator.pushNamed(context, RouteNames.mainLayout);
          break;
      }
    } else {
      debugPrint('Global Navigator context is null. Cannot navigate to $type:$id');
    }
  }

  // Show simple notification
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'lumo_ai_channel',
      'Lumo AI Notifications',
      channelDescription: 'Notifications for Lumo AI app',
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const linuxDetails = LinuxNotificationDetails(
      icon: null, // Default system icon
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
      linux: linuxDetails,
    );

    await _flutterLocalNotificationsPlugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: notificationDetails,
      payload: payload,
    );
  }

  // Cancel notification
  Future<void> cancelNotification(int id) async {
    await _flutterLocalNotificationsPlugin.cancel(id: id);
  }

  // Cancel all notifications
  Future<void> cancelAllNotifications() async {
    await _flutterLocalNotificationsPlugin.cancelAll();
  }

  // Get pending notifications
  Future<List<PendingNotificationRequest>> getPendingNotifications() async {
    return await _flutterLocalNotificationsPlugin.pendingNotificationRequests();
  }

  // Request permissions (FCM & Local)
  Future<bool> requestPermissions() async {
    // 1. Local Notifications permissions for iOS
    await _flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // 2. FCM permissions for iOS & Android 13+
    if (Firebase.apps.isNotEmpty) {
      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        announcement: false,
        badge: true,
        carPlay: false,
        criticalAlert: false,
        provisional: false,
        sound: true,
      );
      return settings.authorizationStatus == AuthorizationStatus.authorized;
    }
    return false;
  }

  // Predefined notification types
  Future<void> showNewMessageNotification({
    required String senderName,
    required String message,
    required String chatRoomId,
  }) async {
    await showNotification(
      id: chatRoomId.hashCode & 0x7FFFFFFF,
      title: 'رسالة جديدة من $senderName',
      body: message,
      payload: 'chat:$chatRoomId',
    );
  }

  Future<void> showNewPostLikeNotification({
    required String userName,
    required String postId,
  }) async {
    await showNotification(
      id: postId.hashCode & 0x7FFFFFFF,
      title: 'إعجاب جديد',
      body: 'أعجب $userName بمنشورك',
      payload: 'post:$postId',
    );
  }

  Future<void> showNewCommentNotification({
    required String userName,
    required String comment,
    required String postId,
  }) async {
    await showNotification(
      id: DateTime.now().millisecondsSinceEpoch & 0x7FFFFFFF,
      title: 'تعليق جديد من $userName',
      body: comment,
      payload: 'post:$postId',
    );
  }

  Future<void> showNewFollowerNotification({
    required String userName,
    required String userId,
  }) async {
    await showNotification(
      id: userId.hashCode & 0x7FFFFFFF,
      title: 'متابع جديد',
      body: 'بدأ $userName بمتابعتك',
      payload: 'profile:$userId',
    );
  }

  Future<void> showDoctorConnectionRequestNotification({
    required String doctorName,
    required String requestId,
  }) async {
    await showNotification(
      id: requestId.hashCode & 0x7FFFFFFF,
      title: 'طلب اتصال من طبيب',
      body: 'الدكتور $doctorName يريد الاتصال بك',
      payload: 'connection_request:$requestId',
    );
  }

  Future<void> showNewAnalysisNotification({
    required String doctorName,
    required String analysisId,
  }) async {
    await showNotification(
      id: analysisId.hashCode & 0x7FFFFFFF,
      title: 'تحليل جديد',
      body: 'قام الدكتور $doctorName بإضافة تحليل جديد',
      payload: 'analysis:$analysisId',
    );
  }

  /// Shows a notification when a session analysis is completed by the robot/AI.
  /// Works for both doctor and parent roles.
  Future<void> showSessionCompletedNotification({
    required int sessionIndex,
    required String sessionId,
    String? patientName,
  }) async {
    final title = '✅ تحليل جلسة مكتمل';
    final body = patientName != null && patientName.isNotEmpty
        ? 'تم اكتمال تحليل الجلسة #$sessionIndex للمريض $patientName'
        : 'تم اكتمال تحليل الجلسة #$sessionIndex — يمكنك الاطلاع على النتائج الآن';

    await showNotification(
      id: sessionId.hashCode & 0x7FFFFFFF,
      title: title,
      body: body,
      payload: 'session_completed:$sessionId',
    );
  }
}
