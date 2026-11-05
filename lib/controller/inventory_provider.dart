import 'package:flutter/material.dart';
import '../services/api_service.dart';
import '../models/inventory_model.dart';
class InventoryProvider extends ChangeNotifier {
  List<InventoryItem> _inventory = [];
  bool _isLoading = false;
  String _error = '';
  List<InventoryItem> get inventory => _inventory;
  bool get isLoading => _isLoading;
  String get error => _error;
  List<InventoryItem> get lowStockAlerts {
    return _inventory
        .where((item) => item.closingStock < item.threshold)
        .toList();
  }
  List<InventoryItem> get materialInventory =>
      _inventory.where((item) => item.category == 'material').toList();
  List<InventoryItem> get labourInventory =>
      _inventory.where((item) => item.category == 'labour').toList();
  List<InventoryItem> get equipmentInventory =>
      _inventory.where((item) => item.category == 'equipment').toList();
  Future<void> addToInventory({
    required String materialName,
    required double quantity,
    required String unit,
    required String projectId,
    required String category,
    double threshold = 10,
  }) async {
    try {
      await ApiService.addInventoryItem(
        materialName: materialName,
        purchased: quantity,
        unit: unit,
        projectId: projectId,
        category: category,
        threshold: threshold,
      );
      await loadInventory(projectId);
    } catch (e) {
      _error = 'Could not add to inventory: $e';
      notifyListeners();
    }
  }
  /// True when the last load failed (the previous items, if any, are kept).
  bool get hasError => _error.isNotEmpty;
  String? _projectId;
  String? get projectId => _projectId;

  /// Re-runs the last [loadInventory].
  Future<void> retry() async {
    final id = _projectId;
    if (id != null) await loadInventory(id);
  }

  Future<void> loadInventory(String projectId) async {
    // Items from another project must not be shown as this project's when the load fails.
    if (_projectId != null && _projectId != projectId) _inventory = [];
    _projectId = projectId;
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      // Throws on non-200 / network errors: keep the previous items instead of [].
      final rawData = await ApiService.fetchInventory(projectId);
      if (_projectId != projectId) return; // a newer load for another project won
      _inventory = rawData.map((json) => InventoryItem.fromJson(json)).toList();
    } catch (e) {
      if (_projectId != projectId) return;
      debugPrint('loadInventory error: $e');
      _error = "Couldn't load inventory. Check your connection and try again.";
    } finally {
      if (_projectId == projectId) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }
  Future<void> performSearch(
    String query,
    String category, {
    String projectId = '',
  }) async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final rawData = await ApiService.searchMaterials(
        query: query,
        category: category,
        projectId: projectId,
      );
      debugPrint('RAW INVENTORY JSON');
      debugPrint(rawData.toString());
      _inventory = rawData.map((json) => InventoryItem.fromJson(json)).toList();
    } catch (e) {
      _error = 'Search failed: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
  void clear() {
    _projectId = null;
    _inventory = [];
    _isLoading = false;
    _error = '';
    notifyListeners();
  }
}
