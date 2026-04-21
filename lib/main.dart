import 'dart:async';
import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flayr/common/manager/firebase_notification_manager.dart';
import 'package:flayr/common/controller/theme_controller.dart';
import 'package:flayr/common/manager/logger.dart';
import 'package:flayr/common/manager/session_manager.dart';
import 'package:flayr/common/service/auth/firebase_user_sync_service.dart';
import 'package:flayr/common/service/subscription/subscription_manager.dart';
import 'package:flayr/common/widget/restart_widget.dart';
import 'package:flayr/languages/dynamic_translations.dart';
import 'package:flayr/languages/local_fallback_translations.dart';
import 'package:flayr/utilities/theme_res.dart';
import 'package:flayr/screen/splash_screen/splash_screen.dart';

import 'common/service/network_helper/network_helper.dart';

/// Helper: run a future with a timeout. If it fails or times out, log and continue.
/// This prevents ANY initialization step from hanging the app forever.
Future<void> _safeRun(String name, Future<void> Function() fn,
    {Duration timeout = const Duration(seconds: 8)}) async {
  try {
    await fn().timeout(timeout, onTimeout: () {
      Loggers.warning('$name timed out after ${timeout.inSeconds}s - continuing anyway');
      return;
    });
  } catch (e, st) {
    Loggers.error('$name failed: $e\n$st');
  }
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  Loggers.success("Handling a background message: ${message.data}");
  try {
    await Firebase.initializeApp().timeout(const Duration(seconds: 10));
  } catch (_) {}
  if (Platform.isIOS) {
    FirebaseNotificationManager.instance.showNotification(message);
  }
}

void _registerAppDependencies() {
  if (!Get.isRegistered<DynamicTranslations>()) {
    final dynamicTranslations = DynamicTranslations();
    dynamicTranslations.addTranslations(LocalFallbackTranslations.values);
    dynamicTranslations.addTranslations({
      'en': {
        'Developed by': 'Developed by',
        'No One Can live': 'No One Can live',
        'No users in livestream': 'No users in livestream',
        'To : ': 'To : ',
        'None': 'None',
      },
      'ar': {
        'Developed by': 'تم التطوير بواسطة',
        'No One Can live': 'لا يوجد أحد في البث المباشر',
        'No users in livestream': 'لا يوجد مستخدمون في البث المباشر',
        'To : ': 'إلى : ',
        'None': 'بدون',
      },
    });
    Get.put(dynamicTranslations, permanent: true);
  }

  if (!Get.isRegistered<ThemeController>()) {
    Get.put(ThemeController(), permanent: true);
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force dark system UI
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: Colors.black,
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  // Register core dependencies first (fast, non-blocking)
  _registerAppDependencies();

  // GetStorage MUST succeed for SessionManager - give it a reasonable timeout
  await _safeRun('GetStorage.init', () async {
    await GetStorage.init('shortzz');
  }, timeout: const Duration(seconds: 8));

  // Firebase is critical but should never hang indefinitely
  await _safeRun('Firebase.initializeApp', () async {
    await Firebase.initializeApp();
  }, timeout: const Duration(seconds: 10));

  // FCM background handler registration is synchronous
  try {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  } catch (e) {
    Loggers.error('FCM bg handler register failed: $e');
  }

  // Fire-and-forget: notifications init (never awaited, never blocks)
  FirebaseNotificationManager.instance
      .init()
      .catchError((e) => Loggers.error("FCM Init Error: $e"));

  // Fire-and-forget: auth state listener
  try {
    FirebaseAuth.instance.authStateChanges().listen((_) {
      FirebaseUserSyncService.syncCurrentSessionUserFromFirebase();
    });
  } catch (e) {
    Loggers.error('authStateChanges listen failed: $e');
  }

  // Fire-and-forget with timeout: user sync
  FirebaseUserSyncService.syncCurrentSessionUserFromFirebase()
      .timeout(const Duration(seconds: 5), onTimeout: () {
    Loggers.warning("User sync timed out");
    return null;
  }).catchError((e) {
    Loggers.error('User sync error: $e');
    return null;
  });

  // RevenueCat / Subscription - bounded by timeout to prevent hang
  await _safeRun('SubscriptionManager.initPlatformState', () async {
    await SubscriptionManager.shared.initPlatformState();
  }, timeout: const Duration(seconds: 8));

  // Audio session - bounded by timeout
  await _safeRun('AudioSession.configure', () async {
    final session = await AudioSession.instance;
    await session.configure(const AudioSessionConfiguration.speech());
  }, timeout: const Duration(seconds: 5));

  // Google Mobile Ads - fire and forget (already non-blocking)
  try {
    MobileAds.instance.initialize();
  } catch (e) {
    Loggers.error('MobileAds init failed: $e');
  }

  // Google Sign-In init - bounded by timeout
  await _safeRun('GoogleSignIn.initialize', () async {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '28441059803-78ro06cusr82bc0d9ksf3eoo12rvhat1.apps.googleusercontent.com',
    );
    Loggers.info('GoogleSignIn initialized at startup');
  }, timeout: const Duration(seconds: 8));

  // Network helper (synchronous)
  try {
    NetworkHelper().initialize();
  } catch (e) {
    Loggers.error('NetworkHelper init failed: $e');
  }

  // Re-register dependencies (idempotent, safe)
  _registerAppDependencies();

  // ALWAYS call runApp, even if everything above failed.
  runApp(const RestartWidget(child: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    Get.find<ThemeController>();

    return GetMaterialApp(
      builder: (context, child) {
        final languageCode = Get.locale?.languageCode ??
            SessionManager.instance.getLang();
        return Directionality(
          textDirection: languageCode == 'ar'
              ? TextDirection.rtl
              : TextDirection.ltr,
          child: ScrollConfiguration(behavior: MyBehavior(), child: child!),
        );
      },
      translations: Get.find<DynamicTranslations>(),
      locale: Locale(SessionManager.instance.getLang()),
      fallbackLocale: Locale(SessionManager.instance.getFallbackLang()),
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('en'),
        Locale('ar'),
      ],
      themeMode: ThemeMode.dark,
      darkTheme: ThemeRes.darkTheme(context),
      theme: ThemeRes.darkTheme(context),
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}

class MyBehavior extends ScrollBehavior {
  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child;
  }
}
