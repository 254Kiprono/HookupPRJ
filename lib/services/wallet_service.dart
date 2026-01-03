import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/wallet_transaction.dart';

class WalletService {
  /// Get wallet balance from backend
  static Future<Map<String, dynamic>> getWalletBalance() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    try {
      final uri = Uri.parse('${AppConstants.getWalletBalance}/$userId/balance');
      
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout');
        },
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return {
          'user_id': data['userId'] ?? data['user_id'] ?? userId,
          'balance': (data['balance'] as num?)?.toDouble() ?? 0.0,
          'last_updated': data['lastUpdated'] ?? data['last_updated'],
        };
      } else if (response.statusCode == 401) {
        throw Exception('Unauthorized: Please login again');
      } else if (response.statusCode == 403) {
        throw Exception('Forbidden: Insufficient permissions');
      } else {
        throw Exception('Failed to fetch wallet balance: ${response.statusCode}');
      }
    } on http.ClientException catch (e) {
      print('❌ [WALLET] Network error: ${e.message}');
      // Return zero balance instead of throwing to prevent app crash
      return {
        'user_id': userId,
        'balance': 0.0,
        'last_updated': null,
        'error': 'Network error: ${e.message}',
      };
    } on FormatException catch (e) {
      print('❌ [WALLET] Invalid response format: $e');
      return {
        'user_id': userId,
        'balance': 0.0,
        'last_updated': null,
        'error': 'Invalid response format',
      };
    } catch (e) {
      print('❌ [WALLET] Error fetching balance: $e');
      // If endpoint fails, return zero balance
      return {
        'user_id': userId,
        'balance': 0.0,
        'last_updated': null,
        'error': e.toString(),
      };
    }
  }

  /// Get payment history (all transactions)
  static Future<List<WalletTransaction>> getTransactions({
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.getPaymentHistory}/$userId/payment-history?limit=$limit&offset=$offset'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final transactionsList = data['transactions'] as List<dynamic>? ?? [];
        return transactionsList
            .map((json) => WalletTransaction.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        // If endpoint doesn't exist yet, return empty list
        return [];
      }
    } catch (e) {
      // Endpoint might not exist yet, return empty list
      return [];
    }
  }

  /// Get withdrawal history
  static Future<List<WalletTransaction>> getWithdrawalHistory({
    int limit = 50,
    int offset = 0,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    try {
      final response = await http.get(
        Uri.parse('${AppConstants.getWithdrawHistory}/$userId/withdrawals?limit=$limit&offset=$offset'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final historyList = data['history'] as List<dynamic>? ?? [];
        return historyList
            .map((json) => WalletTransaction.fromJson(json as Map<String, dynamic>))
            .toList();
      } else {
        return [];
      }
    } catch (e) {
      return [];
    }
  }

  /// Create an earning entry when a booking is paid
  static Future<WalletTransaction> createEarning({
    required String bookingId,
    required String bnbId,
    required String bnbName,
    required String clientName,
    required double amount,
    String? reference,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.bookingServiceBaseUrl}/v1/wallet/earnings'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'booking_id': bookingId,
          'bnb_id': bnbId,
          'bnb_name': bnbName,
          'client_name': clientName,
          'amount': amount,
          'reference': reference ?? 'EARN-${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return WalletTransaction.fromJson(data['transaction'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to create earning: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // If backend endpoint doesn't exist, create a local transaction record
      // In production, this should always go through the backend
      return WalletTransaction(
        transactionId: 'EARN-${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.earning,
        amount: amount,
        status: TransactionStatus.completed,
        timestamp: DateTime.now(),
        reference: reference,
        bnbId: bnbId,
        bnbName: bnbName,
        clientName: clientName,
        bookingId: bookingId,
        description: '$bnbName – paid by $clientName',
      );
    }
  }

  /// Request a withdrawal
  static Future<Map<String, dynamic>> requestWithdrawal({
    required double amount,
    required String phoneNumber,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    try {
      final response = await http.post(
        Uri.parse(AppConstants.withdraw),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'user_id': userId,
          'amount': amount,
          'phone_number': phoneNumber,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        return jsonDecode(response.body) as Map<String, dynamic>;
      } else {
        throw Exception('Failed to request withdrawal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// Get earnings from completed bookings
  /// This will be called when a booking status changes to 'paid' or 'completed'
  static Future<List<WalletTransaction>> getEarningsFromBookings(
    List<Map<String, dynamic>> bookings,
  ) async {
    final List<WalletTransaction> earnings = [];

    for (var booking in bookings) {
      final status = booking['status']?.toString().toUpperCase() ?? '';
      final isPaid = status == 'PAID' || status == 'COMPLETED';
      
      if (isPaid && booking['include_bnb'] == true && booking['bnb_price'] != null) {
        final amount = (booking['bnb_price'] as num?)?.toDouble() ?? 0.0;
        if (amount > 0) {
          earnings.add(
            WalletTransaction(
              transactionId: 'EARN-${booking['booking_id'] ?? DateTime.now().millisecondsSinceEpoch}',
              type: TransactionType.earning,
              amount: amount,
              status: TransactionStatus.completed,
              timestamp: booking['completed_at'] != null
                  ? DateTime.tryParse(booking['completed_at'].toString()) ?? DateTime.now()
                  : booking['updated_at'] != null
                      ? DateTime.tryParse(booking['updated_at'].toString()) ?? DateTime.now()
                      : DateTime.now(),
              bookingId: booking['booking_id']?.toString(),
              bnbId: booking['bnb_id']?.toString(),
              bnbName: booking['bnb_name']?.toString(),
              clientName: booking['payer_name']?.toString() ?? booking['client_name']?.toString(),
              description: '${booking['bnb_name'] ?? 'BnB'} – paid by ${booking['payer_name'] ?? booking['client_name'] ?? 'Client'}',
            ),
          );
        }
      }
    }

    return earnings;
  }
}






