import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

class UserService {
  /// Get the current user's profile
  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await StorageService.getAuthToken();
    final userId = await StorageService.getUserId();
    
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
      Uri.parse('${AppConstants.userServiceBaseUrl}/v1/auth/get-userprofile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId ?? '', // Send user_id if available, though backend extracts from token
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to fetch user profile: ${response.statusCode} - ${response.body}');
    }
  }
  /// Update user profile
  static Future<Map<String, dynamic>> updateUserProfile({
    String? fullName,
    String? email,
    String? phone,
    String? dob,
    String? location,
    String? address,
    String? profileImage,
  }) async {
    final token = await StorageService.getAuthToken();
    final userId = await StorageService.getUserId();
    
    if (token == null) throw Exception('No auth token found');

    final Map<String, dynamic> body = {
      'user_id': userId,
    };

    if (fullName != null) body['full_name'] = fullName;
    if (email != null) body['email'] = email;
    if (phone != null) body['phone'] = phone;
    if (dob != null) body['dob'] = dob;
    if (location != null) body['location'] = location;
    if (address != null) body['address'] = address;
    if (profileImage != null) body['profile_image'] = profileImage;

    final response = await http.patch(
      Uri.parse('${AppConstants.userServiceBaseUrl}/v1/auth/update-userprofile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update profile: ${response.statusCode} - ${response.body}');
    }
  }
}
