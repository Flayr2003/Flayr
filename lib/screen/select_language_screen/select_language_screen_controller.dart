import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:flayr/common/controller/base_controller.dart';
import 'package:flayr/common/manager/ads_manager.dart';
import 'package:flayr/common/manager/logger.dart';
import 'package:flayr/common/manager/session_manager.dart';
import 'package:flayr/common/widget/eula_sheet.dart';
import 'package:flayr/model/general/settings_model.dart';
import 'package:flayr/screen/select_language_screen/select_language_screen.dart';

class SelectLanguageScreenController extends BaseController {
  Rx<Language?> selectedLanguage = Rx(null);
  RxList<Language> languages = <Language>[].obs;
  LanguageNavigationType languageNavigationType;

  Setting? get setting => SessionManager.instance.getSettings();
  SelectLanguageScreenController(this.languageNavigationType);

  @override
  void onInit() {
    super.onInit();
    initLanguage();
  }

  @override
  void onReady() {
    super.onReady();
    if (languageNavigationType == LanguageNavigationType.fromStart) {
      openEULASheet();
    }
    AdsManager.instance.requestConsentInfoUpdate();
  }

  Future<void> openEULASheet() async {
    if (Platform.isIOS) {
      bool shouldOpen = SessionManager.instance.shouldOpenEULASheet;

      await Future.delayed(const Duration(milliseconds: 250));
      Loggers.info('message  $shouldOpen');
      if (shouldOpen) {
        Get.bottomSheet(const EulaSheet(),
            isScrollControlled: true, enableDrag: false);
      }
    }
  }

  void initLanguage() {
    final items = SessionManager.instance.getSettings()?.languages ?? [];
    final activeLanguages = items.where((element) => element.status == 1).toList();

    final hasEn = activeLanguages.any((element) => element.code == 'en');
    final hasAr = activeLanguages.any((element) => element.code == 'ar');

    if (!hasEn) {
      activeLanguages.add(Language(
        code: 'en',
        title: 'English',
        localizedTitle: 'English',
        status: 1,
        isDefault: 1,
      ));
    }

    if (!hasAr) {
      activeLanguages.add(Language(
        code: 'ar',
        title: 'Arabic',
        localizedTitle: 'العربية',
        status: 1,
        isDefault: 0,
      ));
    }

    activeLanguages.sort((a, b) => (a.code ?? '').compareTo(b.code ?? ''));

    languages.assignAll(activeLanguages);

    final currentLangCode = SessionManager.instance.getLang();
    selectedLanguage.value =
        languages.firstWhereOrNull((element) => element.code == currentLangCode) ??
            (languages.isNotEmpty ? languages.first : null);
  }

  void onLanguageChange(Language? value) {
    if (value == null) return;

    selectedLanguage.value = value;
    final langCode = value.code ?? 'en';
    SessionManager.instance.setLang(langCode);
    Get.updateLocale(Locale(langCode));
  }
}
