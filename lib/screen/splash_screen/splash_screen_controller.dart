import 'dart:async';
import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:flayr/common/controller/base_controller.dart';
import 'package:flayr/common/extensions/string_extension.dart';
import 'package:flayr/common/manager/logger.dart';
import 'package:flayr/common/manager/session_manager.dart';
import 'package:flayr/common/service/api/common_service.dart';
import 'package:flayr/common/service/auth/firebase_user_sync_service.dart';
import 'package:flayr/common/service/api/user_service.dart';
import 'package:flayr/common/service/network_helper/network_helper.dart';
import 'package:flayr/common/widget/no_internet_sheet.dart';
import 'package:flayr/languages/dynamic_translations.dart';
import 'package:flayr/model/general/settings_model.dart';
import 'package:flayr/screen/auth_screen/login_screen.dart';
import 'package:flayr/screen/dashboard_screen/dashboard_screen.dart';
import 'package:flayr/screen/on_boarding_screen/on_boarding_screen.dart';
import 'package:flayr/screen/select_language_screen/select_language_screen.dart';

class SplashScreenController extends BaseController {
  StreamSubscription? _subscription;
  bool isOnline = true;
  bool _navigated = false;

  // HARD SAFETY NET: no matter what happens, we will navigate away from splash
  // within this time window. Prevents the app from being stuck on splash forever.
  static const Duration _hardMaxSplashTime = Duration(seconds: 35);

  @override
  void onReady() {
    super.onReady();

    // Start the main flow
    fetchSettings();

    // Watchdog: force-navigate after hard timeout if flow hasn't completed
    Future.delayed(_hardMaxSplashTime, () {
      if (!_navigated) {
        Loggers.warning('Splash watchdog fired - forcing navigation');
        _navigateToNext();
      }
    });

    try {
      _subscription = NetworkHelper().onConnectionChange.listen((status) {
        isOnline = status;
        if (isOnline) {
          if (Get.currentRoute == '/NoInternetSheet') {
            Get.back();
          }
        } else {
          // Don't show no-internet sheet while still on splash
          if (_navigated) {
            Get.to(() => const NoInternetSheet(),
                transition: Transition.downToUp);
          }
        }
      });
    } catch (e) {
      Loggers.error('Network listener error: $e');
    }
  }

  @override
  void onClose() {
    super.onClose();
    _subscription?.cancel();
  }

  Future<void> fetchSettings() async {
    // Minimum splash time for branding
    await Future.delayed(const Duration(milliseconds: 2000));

    try {
      bool success = await CommonService.instance
          .fetchGlobalSettings()
          .timeout(const Duration(seconds: 10), onTimeout: () => false);

      if (success) {
        final translations = Get.find<DynamicTranslations>();
        var setting = SessionManager.instance.getSettings();
        var languages = setting?.languages ?? [];

        List<Language> downloadLanguages =
            languages.where((element) => element.status == 1).toList();

        if (downloadLanguages.isNotEmpty) {
          try {
            var downloadedFiles = await downloadAndParseLanguages(downloadLanguages)
                .timeout(const Duration(seconds: 10), onTimeout: () => {});
            if (downloadedFiles.isNotEmpty) {
              translations.addTranslations(downloadedFiles);
            }
          } catch (e) {
            Loggers.error('Language download failed: $e');
          }
        }

        var defaultLang = languages
            .firstWhereOrNull((element) => element.isDefault == 1);
        if (defaultLang != null) {
          SessionManager.instance.setFallbackLang(defaultLang.code ?? 'en');
        }
      }
    } catch (e) {
      Loggers.error('Settings fetch error: $e');
    }

    _navigateToNext();
  }

  void _navigateToNext() {
    if (_navigated) return;
    _navigated = true;

    try {
      var setting = SessionManager.instance.getSettings();

      if (SessionManager.instance.isLogin()) {
        // User-details fetch with timeout so we never hang here either
        UserService.instance
            .fetchUserDetails(userId: SessionManager.instance.getUserID())
            .timeout(const Duration(seconds: 10), onTimeout: () => null)
            .then((value) async {
          try {
            if (value != null) {
              final syncedUser =
                  FirebaseUserSyncService.enrichUserWithFirebaseData(
                appUser: value,
                persistInSession: true,
              );
              Get.off(() => DashboardScreen(myUser: syncedUser ?? value));
            } else {
              Get.off(() => const LoginScreen());
            }
          } catch (e) {
            Loggers.error('Navigation after user fetch failed: $e');
            Get.off(() => const LoginScreen());
          }
        }).catchError((e) {
          Loggers.error('User fetch error: $e');
          Get.off(() => const LoginScreen());
        });
      } else {
        bool isLanguageSelect = SessionManager.instance
            .getBool(SessionKeys.isLanguageScreenSelect);
        bool onBoardingShow = SessionManager.instance
            .getBool(SessionKeys.isOnBoardingScreenSelect);

        if (isLanguageSelect == false) {
          Get.off(() => const SelectLanguageScreen(
              languageNavigationType: LanguageNavigationType.fromStart));
        } else if (onBoardingShow == false &&
            (setting?.onBoarding ?? []).isNotEmpty) {
          Get.off(() => const OnBoardingScreen());
        } else {
          Get.off(() => const LoginScreen());
        }
      }
    } catch (e, st) {
      Loggers.error('_navigateToNext fatal: $e\n$st');
      // Last resort: force login screen
      try {
        Get.off(() => const LoginScreen());
      } catch (_) {}
    }
  }

  Future<Map<String, Map<String, String>>> downloadAndParseLanguages(
      List<Language> languages) async {
    final languageData = <String, Map<String, String>>{};

    for (final language in languages) {
      if ((language.code ?? '').isEmpty ||
          (language.csvFile ?? '').isEmpty) {
        continue;
      }
      await downloadAndProcessLanguage(language, languageData);
    }

    return languageData;
  }

  Future<void> downloadAndProcessLanguage(
      Language language, Map<String, Map<String, String>> languageData) async {
    try {
      final response = await http
          .get(Uri.parse(language.csvFile?.addBaseURL() ?? ''))
          .timeout(const Duration(seconds: 5));
      if (response.statusCode == 200) {
        final csvContent = utf8.decode(response.bodyBytes);
        final parsedMap = _parseCsvToMap(csvContent);
        languageData[language.code!] = parsedMap;
        Loggers.info('Downloaded and parsed: ${language.code}');
      }
    } catch (e) {
      Loggers.error('Error downloading ${language.code}: $e');
    }
  }

  Map<String, String> _parseCsvToMap(String csvContent) {
    try {
      final rows = const CsvToListConverter().convert(csvContent);
      final map = <String, String>{};

      for (final row in rows) {
        if (row.length < 2) continue;
        final key = row[0].toString().trim();
        final value = row[1].toString().trim();
        if (key.isEmpty || value.isEmpty) continue;
        if (key.toLowerCase() == 'key' && value.toLowerCase() == 'value') {
          continue;
        }
        map[key] = value;
      }
      return map;
    } catch (e) {
      Loggers.error('CSV parse error: $e');
      return <String, String>{};
    }
  }
}
