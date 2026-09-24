import 'package:shared_preferences/shared_preferences.dart';

class PreferencesService {
  static const String _keyHasSeenOnboarding = 'harvesthub_has_seen_onboarding';
  static const String _keyRememberMe = 'harvesthub_remember_me';
  static const String _keySavedEmail = 'harvesthub_saved_email';
  static const String _keySavedPassword = 'harvesthub_saved_password';

  static PreferencesService? _instance;
  final SharedPreferences _prefs;

  PreferencesService._(this._prefs);

  static Future<PreferencesService> getInstance() async {
    if (_instance == null) {
      final prefs = await SharedPreferences.getInstance();
      _instance = PreferencesService._(prefs);
    }
    return _instance!;
  }

  bool get hasSeenOnboarding => _prefs.getBool(_keyHasSeenOnboarding) ?? false;

  Future<void> setHasSeenOnboarding(bool value) async {
    await _prefs.setBool(_keyHasSeenOnboarding, value);
  }

  bool get rememberMe => _prefs.getBool(_keyRememberMe) ?? true;

  Future<void> setRememberMe(bool value) async {
    await _prefs.setBool(_keyRememberMe, value);
  }

  String? get savedEmail => _prefs.getString(_keySavedEmail);

  Future<void> setSavedEmail(String? email) async {
    if (email != null && email.isNotEmpty) {
      await _prefs.setString(_keySavedEmail, email);
    } else {
      await _prefs.remove(_keySavedEmail);
    }
  }

  String? get savedPassword => _prefs.getString(_keySavedPassword);

  Future<void> setSavedPassword(String? password) async {
    if (password != null && password.isNotEmpty) {
      await _prefs.setString(_keySavedPassword, password);
    } else {
      await _prefs.remove(_keySavedPassword);
    }
  }

  Future<void> saveAuthCredentials({
    required String email,
    required String password,
    required bool remember,
  }) async {
    await setHasSeenOnboarding(true);
    await setRememberMe(remember);
    if (remember) {
      await setSavedEmail(email);
      await setSavedPassword(password);
    } else {
      await setSavedEmail(null);
      await setSavedPassword(null);
    }
  }

  Future<void> clearAuthCredentials() async {
    await setSavedPassword(null);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
