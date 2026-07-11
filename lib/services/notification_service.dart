import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'settings_service.dart';

/// Shows a system notification when a new alert arrives while the app
/// is running (foreground or backgrounded). This is a free, local-only
/// substitute for server-push: it cannot wake the app if it has been
/// fully closed by the OS, since there is no backend sending a remote
/// push in that case.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// Set by main.dart once the router exists. The payload passed to
  /// [show] is just a route path (e.g. "/chat/abc123"), so tapping a
  /// notification navigates straight there.
  void Function(String route)? onTapRoute;

  Future<void> init() async {
    if (_initialized) return;
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    await _plugin.initialize(
      const InitializationSettings(android: android, iOS: ios),
      onDidReceiveNotificationResponse: (details) {
        final payload = details.payload;
        if (payload != null && payload.isNotEmpty) {
          onTapRoute?.call(payload);
        }
      },
    );
    await _plugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    _initialized = true;
  }

  Future<void> show({required String title, required String body, String? route}) async {
    if (!SettingsService.instance.notificationsEnabled) return;
    await init();
    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        'alerts_channel',
        'Alerts',
        channelDescription: 'Asset scan and safety alerts',
        importance: Importance.high,
        priority: Priority.high,
      ),
      iOS: DarwinNotificationDetails(),
    );
    await _plugin.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      details,
      payload: route,
    );
  }
}
