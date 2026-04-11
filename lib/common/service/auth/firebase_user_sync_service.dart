import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;
import 'package:flayr/common/manager/session_manager.dart';
import 'package:flayr/model/user_model/user_model.dart' as app_model;

class FirebaseUserSyncService {
  FirebaseUserSyncService._();

  static Future<app_model.User?> syncCurrentSessionUserFromFirebase() async {
    final appUser = SessionManager.instance.getUser();
    if (appUser == null) return null;

    final merged = enrichUserWithFirebaseData(
      appUser: appUser,
      firebaseUser: firebase_auth.FirebaseAuth.instance.currentUser,
      persistInSession: true,
    );

    return merged;
  }

  static app_model.User? enrichUserWithFirebaseData({
    required app_model.User? appUser,
    firebase_auth.User? firebaseUser,
    bool persistInSession = false,
  }) {
    if (appUser == null || firebaseUser == null) return appUser;

    final cloned = app_model.User.fromJson(appUser.toJson());

    if (_hasValue(firebaseUser.displayName)) {
      cloned.fullname = firebaseUser.displayName?.trim();
    }

    if (_hasValue(firebaseUser.email)) {
      cloned.userEmail = firebaseUser.email?.trim();
    }

    if (_hasValue(firebaseUser.photoURL)) {
      cloned.profilePhoto = firebaseUser.photoURL?.trim();
    }

    if (_hasValue(firebaseUser.uid)) {
      cloned.identity = firebaseUser.uid;
    }

    if (persistInSession) {
      SessionManager.instance.setUser(cloned);
    }

    return cloned;
  }

  static bool _hasValue(String? value) {
    return value != null && value.trim().isNotEmpty;
  }
}
