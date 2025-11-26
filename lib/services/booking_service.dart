import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/booking.dart';

class BookingService {
  /// Create a new booking (with optional BnB)
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

    final response = await http.post(
      Uri.parse(AppConstants.createBooking),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'client_id': userId,
        'provider_id': providerId,
        'price': price,
        'include_bnb': includeBnb,
        'bnb_id': bnbId ?? '',
        'bnb_price': bnbPrice ?? 0.0,
        'payer_name': payerName,
        'client_phone': clientPhone,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to create booking: ${response.statusCode} - ${response.body}');
    }
  }

  /// Update booking status
  static Future<void> updateBookingStatus({
    required String bookingId,
    required BookingStatus status,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.patch(
      Uri.parse('${AppConstants.updateBookingStatus}/$bookingId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'status': status.toString().split('.').last.toUpperCase(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
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
  static Future<List<Booking>> getBookingsByBnbOwner({String? bnbId}) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final userId = await StorageService.getUserId();
    if (userId == null) throw Exception('No user ID found');

    final queryParams = bnbId != null ? '?bnb_id=$bnbId' : '';

    final response = await http.get(
      Uri.parse('${AppConstants.getBookingsByBnbOwner}$queryParams'),
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
      throw Exception('Failed to fetch BnB bookings: ${response.statusCode} - ${response.body}');
    }
  }
}
