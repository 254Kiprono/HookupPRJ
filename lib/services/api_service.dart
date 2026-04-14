import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hook_app/services/http_service.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/provider.dart';
import 'package:hook_app/models/bnb.dart';

class ApiService {
  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    // Use POST method
    final response = await HttpService.post(
      Uri.parse(AppConstants.getuserprofile),
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({}),
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      return jsonDecode(response.body);
    } else {
      throw Exception('Failed to fetch profile: ${response.statusCode}');
    }
  }

  static Future<List<Provider>> searchProviders(String region,
      {double? latitude, double? longitude}) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final Map<String, dynamic> body = {
      'county': region,
      'limit': 50,
    };

    if (latitude != null) body['latitude'] = latitude;
    if (longitude != null) body['longitude'] = longitude;

    // Updated to match backend SearchNearbyUsers endpoint (POST /v1/users/search-nearby)
    final response = await HttpService.post(
      Uri.parse(AppConstants.searchProviders),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(body),

    );

    if (response.statusCode == 200) {
      try {
        final dynamic body = jsonDecode(response.body);
        final List<dynamic> userList =
            (body is Map && body.containsKey('users')) ? body['users'] : [];

        return userList.map((u) {
          final profile = u['user'] ?? {};
          // Ensure we handle ID conversion from string if backend changed
          final idRaw = profile['user_id'] ?? profile['id'] ?? 0;
          final int idValue = idRaw is int ? idRaw : int.tryParse(idRaw.toString()) ?? 0;
          
          return Provider(
            id: idValue,
            name: (profile['full_name'] ?? profile['name'] ?? 'Provider').toString(),
            price: double.tryParse((profile['hourly_rate'] ?? 0.0).toString()) ?? 0.0,
            isActive: profile['is_active'] as bool? ?? true,
            distance: (u['distance_km'] ?? 0.0).toString() + ' km',
            profileImage: profile['profile_image'] as String?,
            bio: profile['bio'] as String?,
            locationName: profile['region_name'] as String?,
          );
        }).toList();
      } catch (parseError) {
        debugPrint('[API] searchProviders Mapping Error: $parseError');
        return [];
      }
    } else if (response.statusCode == 403) {
      debugPrint('[API] 403 Forbidden - Unauthorized for search');
      return [];
    } else {
      debugPrint('[API] searchProviders failed: ${response.statusCode}');
      return [];
    }
  }

  static Future<List<BnB>> searchBnBs(String region) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    // Updated to match backend GetBnBsByLocation (GET /v1/bnb/location/{location})
    final response = await HttpService.get(
      Uri.parse('${AppConstants.searchBnBs}/$region'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final dynamic body = jsonDecode(response.body);
      final List<dynamic> bnbList = (body is Map && body.containsKey('bnbs')) ? body['bnbs'] : [];
      return bnbList.map((json) => BnB.fromJson(json)).toList();
    } else {
      print('[API] searchBnBs failed: ${response.statusCode}');
      return [];
    }
  }
}
