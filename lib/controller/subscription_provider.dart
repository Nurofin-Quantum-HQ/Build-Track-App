import 'package:flutter/material.dart';
import 'package:buildtrack_mobile/services/billing_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum SubscriptionPlan { free, starter, growth, pro, business, enterprise }

extension SubscriptionPlanX on SubscriptionPlan {
  String get label {
    switch (this) {
      case SubscriptionPlan.free:
        return 'Free';
      case SubscriptionPlan.starter:
        return 'Starter';
      case SubscriptionPlan.growth:
        return 'Growth';
      case SubscriptionPlan.pro:
        return 'Pro';
      case SubscriptionPlan.business:
        return 'Business';
      case SubscriptionPlan.enterprise:
        return 'Enterprise';
    }
  }

  String get badge {
    switch (this) {
      case SubscriptionPlan.free:
        return 'FREE';
      case SubscriptionPlan.starter:
        return 'STARTER';
      case SubscriptionPlan.growth:
        return 'GROWTH';
      case SubscriptionPlan.pro:
        return 'PRO';
      case SubscriptionPlan.business:
        return 'BUSINESS';
      case SubscriptionPlan.enterprise:
        return 'ENTERPRISE';
    }
  }

  int get maxUsers {
    switch (this) {
      case SubscriptionPlan.free:
        return 2;
      case SubscriptionPlan.starter:
        return 5;
      case SubscriptionPlan.growth:
        return 8;
      case SubscriptionPlan.pro:
        return 15;
      case SubscriptionPlan.business:
        return 25;
      case SubscriptionPlan.enterprise:
        return 999999;
    }
  }

  int get maxProjects {
    switch (this) {
      case SubscriptionPlan.free:
        return 1;
      case SubscriptionPlan.starter:
        return 2;
      case SubscriptionPlan.growth:
        return 4;
      case SubscriptionPlan.pro:
        return 6;
      case SubscriptionPlan.business:
        return 12;
      case SubscriptionPlan.enterprise:
        return -1;
    }
  }

  static SubscriptionPlan fromString(String? value) {
    switch (value?.toLowerCase().trim()) {
      case 'starter':
        return SubscriptionPlan.starter;
      case 'growth':
        return SubscriptionPlan.growth;
      case 'pro':
        return SubscriptionPlan.pro;
      case 'business':
        return SubscriptionPlan.business;
      case 'enterprise':
        return SubscriptionPlan.enterprise;
      default:
        return SubscriptionPlan.free;
    }
  }
}

enum SubscriptionStatus { active, expired, unknown }

class SubscriptionProvider extends ChangeNotifier {
  SubscriptionPlan _currentPlan = SubscriptionPlan.free;
  SubscriptionStatus _status = SubscriptionStatus.unknown;
  bool _isPurchasing = false;
  bool _isLoading = false;
  String _error = '';
  DateTime? _expiryDate;
  SubscriptionPlan get currentPlan => _currentPlan;
  SubscriptionStatus get status => _status;
  bool get isPurchasing => _isPurchasing;
  bool get isLoading => _isLoading;
  String get error => _error;
  DateTime? get expiryDate => _expiryDate;
  DateTime? get renewalDate => _expiryDate;
  bool get isPaid => _currentPlan != SubscriptionPlan.free;
  Map<String, dynamic>? _pendingPaymentParams;
  Map<String, dynamic>? get pendingPaymentParams => _pendingPaymentParams;
  Future<void> fetchStatus() async {
    await _loadPersistedSubscription();
    if (_currentPlan != SubscriptionPlan.free ||
        _status != SubscriptionStatus.unknown) {
      _isLoading = false;
      notifyListeners();
      _fetchStatusFromNetwork();
      return;
    }
    _isLoading = true;
    _error = '';
    notifyListeners();
    await _fetchStatusFromNetwork();
  }

  Future<void> _fetchStatusFromNetwork() async {
    try {
      final data = await BillingService.fetchStatus();
      if (data != null && data['hasSubscription'] == true) {
        _currentPlan = SubscriptionPlanX.fromString(data['plan']?.toString());
        if (data['endDate'] != null) {
          _expiryDate = DateTime.tryParse(data['endDate'].toString());
        } else {
          _expiryDate = null;
        }
        if (_expiryDate != null && _expiryDate!.isAfter(DateTime.now())) {
          _status = SubscriptionStatus.active;
        } else if (_expiryDate != null) {
          _status = SubscriptionStatus.expired;
        } else {
          _status = SubscriptionStatus.active;
        }
      } else {
        _currentPlan = SubscriptionPlan.free;
        _expiryDate = null;
        _status = SubscriptionStatus.unknown;
      }
      _error = '';
      await _persistSubscription();
    } catch (e) {
      _error = 'Could not fetch subscription status';
      _status = SubscriptionStatus.unknown;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<Map<String, dynamic>?> purchase(String productId) async {
    if (_isPurchasing) return null;
    _isPurchasing = true;
    _error = '';
    notifyListeners();
    try {
      final params = await BillingService.initiatePayment(productId);
      if (params == null) {
        _error = 'Could not initiate payment. Please try again.';
        return null;
      }
      _pendingPaymentParams = params;
      return params;
    } catch (e) {
      _error = 'Payment initiation failed: ${e.toString()}';
      return null;
    } finally {
      _isPurchasing = false;
      notifyListeners();
    }
  }

  Future<void> restore() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      await fetchStatus();
      if (_currentPlan == SubscriptionPlan.free) {
        _error = '';
      }
    } catch (e) {
      _error = 'Restore failed. Please try again.';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> cancelPlan() async {
    _isLoading = true;
    _error = '';
    notifyListeners();
    try {
      final success = await BillingService.cancelSubscription();
      await fetchStatus();
      return success;
    } catch (e) {
      _error = 'Cancellation failed: ${e.toString()}';
      return false;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> handlePaymentResult(bool success) async {
    _pendingPaymentParams = null;
    if (success) {
      await fetchStatus();
    } else {
      _error = 'Payment was not completed. Please try again.';
      notifyListeners();
    }
  }

  void clearError() {
    _error = '';
    notifyListeners();
  }

  void clear() {
    _currentPlan = SubscriptionPlan.free;
    _status = SubscriptionStatus.unknown;
    _expiryDate = null;
    _error = '';
    _pendingPaymentParams = null;
    notifyListeners();
  }

  Future<void> _persistSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('buildtrack_subscription_plan', _currentPlan.name);
      await prefs.setString('buildtrack_subscription_status', _status.name);
      if (_expiryDate != null) {
        await prefs.setString(
          'buildtrack_subscription_expiry',
          _expiryDate!.toIso8601String(),
        );
      } else {
        await prefs.remove('buildtrack_subscription_expiry');
      }
    } catch (e) {
      debugPrint('Persist subscription error: $e');
    }
  }

  Future<void> _loadPersistedSubscription() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final planStr = prefs.getString('buildtrack_subscription_plan');
      final statusStr = prefs.getString('buildtrack_subscription_status');
      final expiryStr = prefs.getString('buildtrack_subscription_expiry');
      if (planStr != null) {
        _currentPlan = SubscriptionPlan.values.firstWhere(
          (e) => e.name == planStr,
          orElse: () => SubscriptionPlan.free,
        );
      }
      if (statusStr != null) {
        _status = SubscriptionStatus.values.firstWhere(
          (e) => e.name == statusStr,
          orElse: () => SubscriptionStatus.unknown,
        );
      }
      if (expiryStr != null) {
        _expiryDate = DateTime.tryParse(expiryStr);
      }
    } catch (e) {
      debugPrint('Load persisted subscription error: $e');
    }
  }
}
