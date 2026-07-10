import 'package:flutter/material.dart';
import '../services/alert_service.dart';
import '../services/notification_service.dart';
import '../models/alert_model.dart';

class AlertsProvider extends ChangeNotifier {
  final AlertService _service = AlertService();

  List<AlertModel> _alerts = [];
  bool _loading = false;
  bool _firstLoad = true;
  final Set<String> _seenIds = {};

  List<AlertModel> get alerts => _alerts;
  bool get loading => _loading;
  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  void watchAlerts(String uid) {
    _loading = true;
    notifyListeners();
    _service.watchAlerts(uid).listen(
      (list) {
        if (_firstLoad) {
          _seenIds.addAll(list.map((a) => a.id));
          _firstLoad = false;
        } else {
          for (final alert in list) {
            if (!_seenIds.contains(alert.id)) {
              _seenIds.add(alert.id);
              NotificationService.instance.show(title: alert.title, body: alert.body);
            }
          }
        }
        _alerts = list;
        _loading = false;
        notifyListeners();
      },
      onError: (_) {
        _loading = false;
        notifyListeners();
      },
    );
  }

  Future<void> markRead(String uid, String alertId) async {
    await _service.markRead(uid, alertId);
  }

  Future<void> markAllRead(String uid) async {
    await _service.markAllRead(uid);
  }
}
