import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/models/bnb_session.dart';

class BnBService {
  /// Register a new BnB (BnB owners only)
  static Future<Map<String, dynamic>> registerBnB({
    required String name,
    required String location,
    required String address,
    required double priceKES,
    required bool available,
    required String callNumber, // Now required
    required List<BnBSession> sessions, // Sessions included in registration
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
      Uri.parse(AppConstants.registerBnB),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'name': name,
        'location': location,
        'address': address,
        'price': priceKES, // Backend expects 'price' not 'price_kes'
        'available': available,
        // Proto field is `contact_number` → JSON uses camelCase `contactNumber`
        'contactNumber': callNumber,
        'sessions': sessions.map((s) => s.toJson()).toList(),
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to register BnB: ${response.statusCode} - ${response.body}');
    }
  }

  /// Update an existing BnB
  static Future<Map<String, dynamic>> updateBnB({
    required int bnbId,
    required String name,
    required String location,
    required String address,
    required double priceKES,
    required bool available,
    required int bnbType, // Added to match backend
    required String callNumber, // Now required
    List<BnBSession>? sessions, // Optional sessions for update
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final body = {
      'name': name,
      'location': location,
      'address': address,
      'price': priceKES, // Backend expects 'price' not 'price_kes'
      'available': available,
      // Proto field is `bnb_type` → JSON uses camelCase `bnbType`
      'bnbType': bnbType,
      // Proto field is `contact_number` → JSON uses camelCase `contactNumber`
      'contactNumber': callNumber,
    };

    // Include sessions if provided
    if (sessions != null) {
      body['sessions'] = sessions.map((s) => s.toJson()).toList();
    }

    final response = await http.put(
      Uri.parse('${AppConstants.updateBnB}/$bnbId'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update BnB: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get BnBs by location
  static Future<List<BnB>> getBnBsByLocation(String location) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse('${AppConstants.getBnBsByLocation}/$location'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final bnbsList = data['bnbs'] as List<dynamic>? ?? [];
      return bnbsList.map((json) => BnB.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch BnBs: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get BnB details by ID
  static Future<BnB> getBnBDetails(int bnbId) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse('${AppConstants.getBnBDetails}/$bnbId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return BnB.fromJson(data['bnb'] as Map<String, dynamic>);
    } else {
      throw Exception('Failed to fetch BnB details: ${response.statusCode} - ${response.body}');
    }
  }

  /// Delete a BnB (owner only)
  static Future<void> deleteBnB(int bnbId) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.delete(
      Uri.parse('${AppConstants.deleteBnB}/$bnbId'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to delete BnB: ${response.statusCode} - ${response.body}');
    }
  }

  /// Get all BnBs owned by a specific user
  static Future<List<BnB>> getBnBsByOwner(int ownerId) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final url = '${AppConstants.getBnBsByOwner}/$ownerId';
    print('[BNB SERVICE] Fetching BnBs from: $url');

    final response = await http.get(
      Uri.parse(url),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    ).timeout(const Duration(seconds: 30));

    print('[BNB SERVICE] Response status: ${response.statusCode}');
    print('[BNB SERVICE] Response body: ${response.body}');

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      print('[BNB SERVICE] Decoded data: $data');
      final bnbsList = data['bnbs'] as List<dynamic>? ?? [];
      print('[BNB SERVICE] Found ${bnbsList.length} BnBs');
      return bnbsList.map((json) => BnB.fromJson(json as Map<String, dynamic>)).toList();
    } else {
      throw Exception('Failed to fetch owner BnBs: ${response.statusCode} - ${response.body}');
    }
  }

}
