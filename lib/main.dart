import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'dart:ui';
import 'package:provider/provider.dart';
import 'firebase_options.dart';

import 'app.dart';
import 'core/di/dependency_injection.dart';
import 'core/utils/initializer.dart';
import 'shared/providers/auth_provider.dart';
import 'shared/providers/notification_provider.dart';
import 'shared/providers/user_provider.dart';
import 'shared/providers/theme_provider.dart';
import 'shared/providers/locale_provider.dart';
import 'shared/providers/patient_provider.dart';
import 'shared/providers/community_provider.dart';
import 'features/community/view_model/community_view_model.dart';
import 'features/session/view_model/session_view_model.dart';
import 'features/profile/view_model/profile_view_model.dart';
import 'features/ai_helper/view_model/ai_view_model.dart';
import 'features/chat/view_model/chat_view_model.dart';
import 'features/home/view_model/main_layout_view_model.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'core/utils/debug_logger.dart';
import 'core/services/connectivity_service.dart';
import 'core/services/notification_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  debugPrint("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // #region agent log
  DebugLogger.log(
    runId: 'baseline',
    hypothesisId: 'Z',
    location: 'main.dart:main',
    message: 'App main() started',
    data: const {},
  );
  // #endregion
  // #region agent log
  debugPrint('[ae3196][Z] main() started');
  // #endregion
  // #region agent log
  // Using print() to ensure stdout on desktop.
  // ignore: avoid_print
  print('[ae3196][Z] main() started (print)');
  // #endregion

  bool isFirebaseSupported = true;
  if (!kIsWeb && (defaultTargetPlatform == TargetPlatform.linux || defaultTargetPlatform == TargetPlatform.windows)) {
    isFirebaseSupported = false;
  }

  if (isFirebaseSupported) {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      // Add Firebase Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };
    } catch (e) {
      debugPrint('Firebase initialization failed: $e');
    }
  } else {
    debugPrint('Firebase is not supported or configured for this platform. Skipping initialization.');
  }

  // Setup dependency injection
  await DependencyInjection.init();

  // Initialize app services
  await AppInitializer.initialize();

  // Setup timeago locales
  timeago.setLocaleMessages('ar', timeago.ArMessages());
  timeago.setLocaleMessages('en', timeago.EnMessages());

  // Set preferred orientations
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  final themeProvider = getIt<ThemeProvider>();

  // Set system UI overlay style
  SystemChrome.setSystemUIOverlayStyle(
    SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: themeProvider.isDarkMode
          ? const Color(0xFF0F172A)
          : Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  // ── Handle notification tap when app was terminated ──
  if (Firebase.apps.isNotEmpty) {
    // Register background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    FirebaseMessaging.instance.getInitialMessage().then((message) {
      if (message != null) {
        debugPrint('App opened from terminated via notification: ${message.data}');
        // Delay navigation slightly to ensure the Navigator is fully mounted
        Future.delayed(const Duration(milliseconds: 800), () {
          NotificationService.handleRemoteMessage(message);
        });
      }
    });

    // ── Handle notification tap when app was in background ──
    FirebaseMessaging.onMessageOpenedApp.listen((message) {
      debugPrint('App opened from background via notification: ${message.data}');
      NotificationService.handleRemoteMessage(message);
    });
  }

  runApp(
    MultiProvider(
      providers: [
        // ── Core Providers (Global — مطلوبين في كل الـ app) ──
        ChangeNotifierProvider(create: (_) => getIt<AuthProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<UserProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<NotificationProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ThemeProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<ConnectivityService>()),
        ChangeNotifierProvider(create: (_) => getIt<LocaleProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<PatientProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CommunityProvider>()),
        ChangeNotifierProvider(create: (_) => getIt<CommunityViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<SessionViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<ProfileViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<AIViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<ChatViewModel>()),
        ChangeNotifierProvider(create: (_) => getIt<MainLayoutViewModel>()),

      ],
      // ✅ شلنا Consumer<UserProvider> الزيادة — مكانش بيستخدم userProvider
      child: const LumoAIApp(),
    ),
  );
}
