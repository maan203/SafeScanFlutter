import 'package:shared_preferences/shared_preferences.dart';

/// App-wide user preferences, persisted locally. Other services (location,
/// notifications) read these before acting, so the Profile screen toggles
/// actually control something instead of just holding local widget state.
class SettingsService {
  SettingsService._();
  static final SettingsService instance = SettingsService._();

  static const _notificationsKey = 'notifications_enabled';
  static const _locationSharingKey = 'location_sharing_enabled';

  bool _notificationsEnabled = true;
  bool _locationSharingEnabled = true;
  bool _initialized = false;

  bool get notificationsEnabled => _notificationsEnabled;
  bool get locationSharingEnabled => _locationSharingEnabled;

  Future<void> init() async {
    if (_initialized) return;
    final prefs = await SharedPreferences.getInstance();
    _notificationsEnabled = prefs.getBool(_notificationsKey) ?? true;
    _locationSharingEnabled = prefs.getBool(_locationSharingKey) ?? true;
    _initialized = true;
  }

  Future<void> setNotificationsEnabled(bool value) async {
    _notificationsEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_notificationsKey, value);
  }

  Future<void> setLocationSharingEnabled(bool value) async {
    _locationSharingEnabled = value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_locationSharingKey, value);
  }
}
