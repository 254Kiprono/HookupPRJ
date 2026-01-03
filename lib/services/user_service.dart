import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

class UserService {
  /// Get the current user's profile
  /// Backend extracts userID and roleID from JWT token via AuthInterceptor
  /// Endpoint requires POST method (gRPC-Gateway), but body can be empty since backend gets userID/roleID from token
  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await StorageService.getAuthToken();
    final roleId = await StorageService.getRoleId();
    
    if (token == null) throw Exception('No auth token found');

    print('🔍 [USER_SERVICE] Fetching profile - RoleID: $roleId');
    print('🔍 [USER_SERVICE] Using POST method (endpoint requires POST, backend extracts userID/roleID from JWT token)');

    final userId = await StorageService.getUserId();
    
    // Use POST method (endpoint requires POST per gRPC-Gateway)
    // Sending user_id explicitly to resolve potential extraction issues on backend
    // The backend error 'invalid value for string field userId: 1' indicates it expects a STRING value.
    final Map<String, dynamic> body = {};
    if (userId != null) {
      body['user_id'] = userId; // Send as string, do NOT parse to int
    }

    final response = await http.post(
      Uri.parse('${AppConstants.userServiceBaseUrl}/v1/auth/get-userprofile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      print('✅ [USER_SERVICE] Profile fetched successfully');
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      final errorBody = response.body;
      print('❌ [USER_SERVICE] Profile fetch failed: ${response.statusCode} - $errorBody');
      throw Exception('Failed to fetch user profile: ${response.statusCode} - $errorBody');
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

  /// Update user active/online status
  static Future<Map<String, dynamic>> updateActiveStatus(bool isActive) async {
    final token = await StorageService.getAuthToken();
    final userId = await StorageService.getUserId();
    
    if (token == null) throw Exception('No auth token found');

    final response = await http.patch(
      Uri.parse('${AppConstants.userServiceBaseUrl}/v1/auth/update-userprofile'),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'user_id': userId,
        'is_active': isActive,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to update active status: ${response.statusCode} - ${response.body}');
    }
  }
  /// Update user location
  static Future<void> updateUserLocation(double latitude, double longitude, {String? county}) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
      Uri.parse(AppConstants.updateLocation),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'latitude': latitude,
        'longitude': longitude,
        if (county != null) 'county': county,
      }),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode != 200) {
      throw Exception('Failed to update location: ${response.statusCode} - ${response.body}');
    }
  }

  /// Search nearby users
  static Future<Map<String, dynamic>> searchNearbyUsers({
    double? latitude,
    double? longitude,
    double? radiusKm,
    String? county,
    String? gender,
    int? minAge,
    int? maxAge,
    int? page,
    int? limit,
  }) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final Map<String, dynamic> body = {};
    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;
    if (radiusKm != null) body['radius_km'] = radiusKm;
    if (county != null) body['county'] = county;
    if (gender != null) body['gender'] = gender;
    if (minAge != null) body['min_age'] = minAge;
    if (maxAge != null) body['max_age'] = maxAge;
    if (page != null) body['page'] = page;
    if (limit != null) body['limit'] = limit;

    final response = await http.post(
      Uri.parse(AppConstants.searchNearbyUsers),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to search users: ${response.statusCode} - ${response.body}');
    }
  }

  /// Google Sign Up
  static Future<Map<String, dynamic>> googleSignUp(String idToken, {
    String? location,
    String? bio,
    String? interests,
    String? gender,
    String? address,
    int? role,
  }) async {
    final Map<String, dynamic> body = {'id_token': idToken};
    if (location != null) body['location'] = location;
    if (bio != null) body['bio'] = bio;
    if (interests != null) body['interests'] = interests;
    if (gender != null) body['gender'] = gender;
    if (address != null) body['address'] = address;
    if (role != null) body['role'] = role;

    final response = await http.post(
      Uri.parse(AppConstants.googleSignUp),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(body),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to sign up with Google: ${response.statusCode} - ${response.body}');
    }
  }

  /// Google Sign In
  static Future<Map<String, dynamic>> googleSignIn(String idToken) async {
    final response = await http.post(
      Uri.parse(AppConstants.googleSignIn),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id_token': idToken}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Failed to sign in with Google: ${response.statusCode} - ${response.body}');
    }
  }

  /// Logout
  static Future<void> logout() async {
    final token = await StorageService.getAuthToken();
    if (token == null) return;

    try {
      await http.post(
        Uri.parse(AppConstants.logout),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 10));
    } catch (e) {
      // Ignore errors during logout
    } finally {
      await StorageService.clearAll();
    }
  }
}
