import 'package:flutter/material.dart';
import '../services/alert_service.dart';
import '../models/alert_model.dart';

class AlertsProvider extends ChangeNotifier {
  final AlertService _service = AlertService();

  List<AlertModel> _alerts = [];
  bool _loading = false;

  List<AlertModel> get alerts => _alerts;
  bool get loading => _loading;
  int get unreadCount => _alerts.where((a) => !a.isRead).length;

  void watchAlerts(String uid) {
    _loading = true;
    notifyListeners();
    _service.watchAlerts(uid).listen(
      (list) {
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
