import 'package:flutter/material.dart';
import '../services/asset_service.dart';
import '../models/asset_model.dart';

class AssetsProvider extends ChangeNotifier {
  final AssetService _service = AssetService();

  List<AssetModel> _assets = [];
  bool _loading = false;
  String? _error;

  List<AssetModel> get assets => _assets;
  bool get loading => _loading;
  String? get error => _error;
  List<AssetModel> get activeAssets => _assets.where((a) => a.isActive).toList();

  void watchAssets(String uid) {
    _loading = true;
    notifyListeners();
    _service.watchAssets(uid).listen(
      (list) {
        _assets = list;
        _loading = false;
        _error = null;
        notifyListeners();
      },
      onError: (e) {
        _loading = false;
        _error = e.toString();
        notifyListeners();
      },
    );
  }

  Future<bool> addAsset(String uid, AssetModel asset) async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      await _service.addAsset(uid, asset);
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> deleteAsset(String uid, String assetId) async {
    try {
      await _service.deleteAsset(uid, assetId);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> toggleActive(String uid, String assetId, bool isActive) async {
    try {
      await _service.toggleActive(uid, assetId, isActive);
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  AssetModel? getById(String id) {
    try {
      return _assets.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }
}
