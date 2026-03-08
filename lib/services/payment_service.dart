import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

class PaymentService {
  /// Initiate an M-Pesa STK push for a subscription or booking
  /// This uses the standard Payment-Service (/pyts/send-request)
  static Future<Map<String, dynamic>> initiateMpesaPayment({
    required String msisdn,
    required double amount,
    required String requestId,
    required String category, // 'SUBSCRIPTION' or 'BOOKING'
    required int clientId,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');
    final referralCode = await StorageService.getReferralCode();

    try {
      final response = await http.post(
        Uri.parse(AppConstants.initiatePayment),
        headers: {
          'Content-Type': 'application/json',
          'User-Token': token,
        },
        body: jsonEncode({
          'msisdn': msisdn,
          'amount': amount,
          'request_id': requestId,
          'client_id': clientId,
          'category': category,
          if (referralCode != null && referralCode.trim().isNotEmpty)
            'referral_code': referralCode.trim(),
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        final error = jsonDecode(response.body);
        throw Exception(error['error'] ?? 'Failed to initiate payment: ${response.statusCode}');
      }
    } catch (e) {
      print('❌ [PAYMENT] Error initiating M-Pesa: $e');
      rethrow;
    }
  }
}
