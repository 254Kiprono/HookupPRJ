import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/booking.dart';

class BookingService {
  /// Create a new booking (with optional BnB)
  /// Backend extracts client_id from JWT token, but we include it in request body for clarity
  static Future<Map<String, dynamic>> createBooking({
    required String providerId,
    required double price,
    required bool includeBnb,
    String? bnbId,
    double? bnbPrice,
    required String payerName,
    required String clientPhone,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    // Build request body matching backend proto format
    final requestBody = {
      'client_id': userId,
      'provider_id': providerId,
      'price': price,
      'include_bnb': includeBnb,
      'payer_name': payerName,
      'client_phone': clientPhone,
    };

    // Only include bnb_id and bnb_price if BnB is included
    if (includeBnb) {
      if (bnbId == null || bnbId.isEmpty) {
        throw Exception('BnB ID is required when include_bnb is true');
      }
      if (bnbPrice == null || bnbPrice <= 0) {
        throw Exception('BnB price must be greater than zero when include_bnb is true');
      }
      requestBody['bnb_id'] = bnbId;
      requestBody['bnb_price'] = bnbPrice;
    }

    final response = await http.post(
      Uri.parse(AppConstants.createBooking),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(requestBody),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200 || response.statusCode == 201) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = response.body;
      throw Exception('Failed to create booking: ${response.statusCode} - $errorBody');
    }
  }

  /// Update booking status
  /// Backend expects status as BookingStatus enum value
  static Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    // Map BookingStatus enum to backend enum string
    String statusStr;
    switch (status) {
      case BookingStatus.pending:
        statusStr = 'PENDING';
        break;
      case BookingStatus.paid:
        statusStr = 'PAID';
        break;
      case BookingStatus.completed:
        statusStr = 'COMPLETED';
        break;
      case BookingStatus.cancelled:
        statusStr = 'CANCELLED';
        break;
      case BookingStatus.paymentPending:
        statusStr = 'PAYMENT_PENDING';
        break;
      case BookingStatus.servicePending:
        statusStr = 'SERVICE_PENDING';
        break;
    }

    final response = await http.patch(
      Uri.parse('${AppConstants.updateBookingStatus}/$bookingId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': statusStr,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200 && response.statusCode != 204) {
      throw Exception('Failed to update booking status: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get a specific booking by ID
  static Future<Booking> getBooking(String bookingId) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse('${AppConstants.getBooking}/$bookingId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      return Booking.fromJson(data);
    } else {
      throw Exception('Failed to fetch booking: ${response.statusCode} - ${response.body}');
    }
  }

  /// List all bookings for the current user
  static Future<List<Booking>> listBookings() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse(AppConstants.listBookings),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final bookingsList = data['bookings'] as List<dynamic>? ?? [];
      return bookingsList.map((json) => Booking.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch bookings: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get booking history for BnB owners (filtered by BnB if provided)
  /// Backend extracts user ID from JWT token and verifies BnB ownership
  static Future<List<Booking>> getBookingsByBnbOwner({String? bnbId}) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    // Build URL with optional bnb_id query parameter
    final uri = bnbId != null && bnbId.isNotEmpty
        ? Uri.parse('${AppConstants.getBookingsByBnbOwner}?bnb_id=$bnbId')
        : Uri.parse(AppConstants.getBookingsByBnbOwner);

    try {
      final response = await http.get(
        uri,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        // Backend returns ListBookingsResponse with 'bookings' array
        final bookingsList = data['bookings'] as List<dynamic>? ?? [];
        return bookingsList.map((json) => Booking.fromJson(json as Map<String, dynamic>)).toList();
      } else {
        // Try to parse error response
        String errorMessage = 'Failed to fetch BnB bookings';
        try {
          final errorData = jsonDecode(response.body);
          if (errorData is Map<String, dynamic>) {
            errorMessage = errorData['message']?.toString() ?? errorMessage;
          }
        } catch (_) {
          // If error body is not JSON, use raw body
          errorMessage = response.body.isNotEmpty ? response.body : errorMessage;
        }
        
        throw Exception('Failed to fetch BnB bookings: ${response.statusCode} - $errorMessage');
      }
    } catch (e) {
      // Re-throw with more context if it's a timeout or network error
      if (e.toString().contains('TimeoutException') || e.toString().contains('SocketException')) {
        throw Exception('Network error: Unable to connect to booking service. Please check your internet connection.');
      }
      rethrow;
    }
  }
}
