import 'dart:convert';
import 'package:buildtrack_mobile/services/api_service.dart';
const String kStarterMonthlyId = 'buildtrack_starter_monthly';
const String kGrowthMonthlyId = 'buildtrack_growth_monthly';
const String kProMonthlyId = 'buildtrack_pro_monthly';
const String kBusinessMonthlyId = 'buildtrack_business_monthly';
const String kEnterpriseMonthlyId = 'buildtrack_enterprise_monthly';
const Map<String, double> kPlanAmounts = {
  kStarterMonthlyId: 1,
  kGrowthMonthlyId: 999,
  kProMonthlyId: 1499,
  kBusinessMonthlyId: 2499,
  kEnterpriseMonthlyId: 4999,
};
const Map<String, String> kPlanNames = {
  kStarterMonthlyId: 'starter',
  kGrowthMonthlyId: 'growth',
  kProMonthlyId: 'pro',
  kBusinessMonthlyId: 'business',
  kEnterpriseMonthlyId: 'enterprise',
};
class BillingService {
  static Future<Map<String, dynamic>?> initiatePayment(String productId) async {
    try {
      final planName = kPlanNames[productId];
      if (planName == null) return null;
      final response = await ApiService.post('/subscriptions/initiate', {
        'plan': planName,
        'isRecurring': true,
      });
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['success'] == true) {
          return data['paymentParams'] as Map<String, dynamic>;
        }
        return null;
      } else if (response.statusCode == 422) {
        final data = json.decode(response.body) as Map<String, dynamic>;
        if (data['requiresPhone'] == true) {
          throw Exception(data['message'] ?? 'Please update your profile with a valid phone number to continue.');
        }
        throw Exception(data['message'] ?? 'Could not initiate payment.');
      }
      return null;
    } catch (e) {
      if (e is Exception) rethrow;
      return null;
    }
  }
  /// Throws on a network error or non-200, so a failed check never looks
  /// like "no subscription" (that showed paid users as Free).
  static Future<Map<String, dynamic>?> fetchStatus() async {
    final response = await ApiService.get('/subscriptions/status', timeout: const Duration(seconds: 20));
    if (response.statusCode == 200) {
      return json.decode(response.body) as Map<String, dynamic>;
    }
    throw Exception('Subscription status failed (HTTP ${response.statusCode})');
  }

  static Future<bool> cancelSubscription() async {
    try {
      final response = await ApiService.post('/subscriptions/cancel', {});
      if (response.statusCode == 200) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
