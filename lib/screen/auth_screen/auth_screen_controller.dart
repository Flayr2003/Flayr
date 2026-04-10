import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flayr/common/controller/base_controller.dart';
import 'package:flayr/common/functions/debounce_action.dart';
import 'package:flayr/common/manager/firebase_notification_manager.dart';
import 'package:flayr/common/manager/logger.dart';
import 'package:flayr/common/manager/session_manager.dart';
import 'package:flayr/common/service/api/common_service.dart';
import 'package:flayr/common/service/api/notification_service.dart';
import 'package:flayr/common/service/api/user_service.dart';
import 'package:flayr/common/service/subscription/subscription_manager.dart';
import 'package:flayr/languages/dynamic_translations.dart';
import 'package:flayr/languages/languages_keys.dart';
import 'package:flayr/model/general/settings_model.dart';
import 'package:flayr/model/user_model/user_model.dart' as user;
import 'package:flayr/screen/dashboard_screen/dashboard_screen.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

// Web Client ID (type 3) from google-services.json
const String _googleWebClientId =
    '28441059803-78ro06cusr82bc0d9ksf3eoo12rvhat1.apps.googleusercontent.com';

class AuthScreenController extends BaseController {
  TextEditingController fullNameController = TextEditingController();
  TextEditingController emailController = TextEditingController();
  TextEditingController forgetEmailController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  TextEditingController confirmPasswordController = TextEditingController();

  RxBool isPasswordVisible = false.obs;
  RxBool isConfirmPasswordVisible = false.obs;
  RxBool isTermsChecked = false.obs;

  @override
  void onInit() {
    super.onInit();
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  void toggleConfirmPasswordVisibility() {
    isConfirmPasswordVisible.value = !isConfirmPasswordVisible.value;
  }

  void toggleTermsCheck() {
    isTermsChecked.value = !isTermsChecked.value;
  }

  Future<void> login() async {
    if (emailController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterEmail.tr);
      return;
    }
    if (passwordController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterPassword.tr);
      return;
    }

    showLoading();
    try {
      final response = await UserService.instance.login(
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        deviceToken: await FirebaseNotificationManager.instance.getDeviceToken() ?? '',
        deviceType: GetPlatform.isAndroid ? 'android' : 'ios',
      );

      hideLoading();
      if (response.status == 200 && response.data != null) {
        _navigateScreen(response.data!);
      } else {
        Get.snackbar(LanguagesKeys.error.tr, response.message ?? '');
      }
    } catch (e) {
      hideLoading();
      Logger.instance.e('Login Error: $e');
      Get.snackbar(LanguagesKeys.error.tr, e.toString());
    }
  }

  Future<void> register() async {
    if (fullNameController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterFullName.tr);
      return;
    }
    if (emailController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterEmail.tr);
      return;
    }
    if (passwordController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterPassword.tr);
      return;
    }
    if (passwordController.text.trim() != confirmPasswordController.text.trim()) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.passwordNotMatch.tr);
      return;
    }
    if (!isTermsChecked.value) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.acceptTerms.tr);
      return;
    }

    showLoading();
    try {
      final response = await UserService.instance.register(
        fullName: fullNameController.text.trim(),
        email: emailController.text.trim(),
        password: passwordController.text.trim(),
        deviceToken: await FirebaseNotificationManager.instance.getDeviceToken() ?? '',
        deviceType: GetPlatform.isAndroid ? 'android' : 'ios',
      );

      hideLoading();
      if (response.status == 200 && response.data != null) {
        _navigateScreen(response.data!);
      } else {
        Get.snackbar(LanguagesKeys.error.tr, response.message ?? '');
      }
    } catch (e) {
      hideLoading();
      Logger.instance.e('Register Error: $e');
      Get.snackbar(LanguagesKeys.error.tr, e.toString());
    }
  }

  Future<void> signInWithGoogle() async {
    showLoading();
    try {
      final userCredential = await _googleSignInProcess();
      if (userCredential != null && userCredential.user != null) {
        final response = await UserService.instance.socialLogin(
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? '',
          identity: userCredential.user!.uid,
          type: 'google',
          deviceToken: await FirebaseNotificationManager.instance.getDeviceToken() ?? '',
          deviceType: GetPlatform.isAndroid ? 'android' : 'ios',
        );

        hideLoading();
        if (response.status == 200 && response.data != null) {
          _navigateScreen(response.data!);
        } else {
          Get.snackbar(LanguagesKeys.error.tr, response.message ?? '');
        }
      } else {
        hideLoading();
      }
    } catch (e) {
      hideLoading();
      Logger.instance.e('Google Sign-In Error: $e');
      Get.snackbar(LanguagesKeys.error.tr, e.toString());
    }
  }

  Future<UserCredential?> _googleSignInProcess() async {
    final GoogleSignIn googleSignIn = GoogleSignIn(
      serverClientId: _googleWebClientId,
    );
    final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
    if (googleUser == null) throw 'Google Sign-In cancelled';

    final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
    final AuthCredential credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  Future<void> appleSignIn() async {
    showLoading();
    try {
      final userCredential = await signInWithApple();
      if (userCredential != null && userCredential.user != null) {
        final response = await UserService.instance.socialLogin(
          email: userCredential.user!.email ?? '',
          fullName: userCredential.user!.displayName ?? '',
          identity: userCredential.user!.uid,
          type: 'apple',
          deviceToken: await FirebaseNotificationManager.instance.getDeviceToken() ?? '',
          deviceType: GetPlatform.isAndroid ? 'android' : 'ios',
        );

        hideLoading();
        if (response.status == 200 && response.data != null) {
          _navigateScreen(response.data!);
        } else {
          Get.snackbar(LanguagesKeys.error.tr, response.message ?? '');
        }
      } else {
        hideLoading();
      }
    } catch (e) {
      hideLoading();
      Logger.instance.e('Apple Sign-In Error: $e');
      Get.snackbar(LanguagesKeys.error.tr, e.toString());
    }
  }

  Future<UserCredential?> signInWithApple() async {
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: [
        AppleIDAuthorizationScope.email,
        AppleIDAuthorizationScope.fullName,
      ],
    );

    final OAuthProvider oAuthProvider = OAuthProvider('apple.com');
    final AuthCredential credential = oAuthProvider.credential(
      idToken: appleCredential.identityToken,
      accessToken: appleCredential.authorizationCode,
    );

    return await FirebaseAuth.instance.signInWithCredential(credential);
  }

  void _navigateScreen(user.User data) {
    SessionManager.instance.setUser(data);
    SessionManager.instance.setAuthToken(data.token);
    Get.offAll(() => DashboardScreen(myUser: data));
  }

  void forgetPassword() async {
    if (forgetEmailController.text.trim().isEmpty) {
      Get.snackbar(LanguagesKeys.error.tr, LanguagesKeys.enterEmail.tr);
      return;
    }

    showLoading();
    try {
      final response = await UserService.instance.forgetPassword(
        email: forgetEmailController.text.trim(),
      );

      hideLoading();
      if (response.status == 200) {
        Get.back();
        Get.snackbar(LanguagesKeys.success.tr, response.message ?? '');
      } else {
        Get.snackbar(LanguagesKeys.error.tr, response.message ?? '');
      }
    } catch (e) {
      hideLoading();
      Logger.instance.e('Forget Password Error: $e');
      Get.snackbar(LanguagesKeys.error.tr, e.toString());
    }
  }
}
