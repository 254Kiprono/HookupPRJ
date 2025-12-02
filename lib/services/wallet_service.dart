import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/wallet_transaction.dart';

class WalletService {
  /// Get wallet balance (total earnings - withdrawals)
  static Future<Map<String, dynamic>> getWalletBalance() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    // For now, calculate from transactions
    // In production, this should be a dedicated endpoint
    final transactions = await getTransactions();
    
    double totalEarnings = 0.0;
    double totalWithdrawals = 0.0;
    
    for (var txn in transactions) {
      if (txn.status == TransactionStatus.completed) {
        if (txn.type == TransactionType.earning) {
          totalEarnings += txn.amount;
        } else {
          totalWithdrawals += txn.amount;
        }
      }
    }
    
    return {
      'total_earnings': totalEarnings,
      'total_withdrawals': totalWithdrawals,
      'balance': totalEarnings - totalWithdrawals,
    };
  }

  /// Get all wallet transactions
  static Future<List<WalletTransaction>> getTransactions() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    // TODO: Replace with actual API endpoint when backend is ready
    // For now, return empty list - will be populated from bookings
    try {
      final response = await http.get(
        Uri.parse('${AppConstants.bookingServiceBaseUrl}/v1/wallet/transactions'),
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
  static Future<WalletTransaction> requestWithdrawal({
    required double amount,
    required String withdrawalMethod,
    String? accountDetails,
    String? reference,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    try {
      final response = await http.post(
        Uri.parse('${AppConstants.bookingServiceBaseUrl}/v1/wallet/withdrawals'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({
          'amount': amount,
          'withdrawal_method': withdrawalMethod,
          'account_details': accountDetails,
          'reference': reference ?? 'WD-${DateTime.now().millisecondsSinceEpoch}',
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200 || response.statusCode == 201) {
        final data = jsonDecode(response.body);
        return WalletTransaction.fromJson(data['transaction'] as Map<String, dynamic>);
      } else {
        throw Exception('Failed to request withdrawal: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      // If backend endpoint doesn't exist, create a local transaction record
      return WalletTransaction(
        transactionId: 'WD-${DateTime.now().millisecondsSinceEpoch}',
        type: TransactionType.withdrawal,
        amount: amount,
        status: TransactionStatus.pending,
        timestamp: DateTime.now(),
        reference: reference,
        withdrawalMethod: withdrawalMethod,
        accountDetails: accountDetails,
        description: 'Withdrawal request',
      );
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

