import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/provider.dart';
import 'package:hook_app/models/bnb.dart';

class ApiService {
  static Future<Map<String, dynamic>> getUserProfile() async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.post(
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

  static Future<List<Provider>> searchProviders(String region) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse('${AppConstants.searchProviders}?region=$region'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data
          .map((json) => Provider.fromJson(json))
          .where((provider) => provider.isActive)
          .toList();
    } else {
      throw Exception('Failed to fetch providers: ${response.statusCode}');
    }
  }

  static Future<List<BnB>> searchBnBs(String region) async {
    final token = await StorageService.getAuthToken();
    if (token == null) throw Exception('No auth token found');

    final response = await http.get(
      Uri.parse('${AppConstants.searchBnBs}?region=$region'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as List<dynamic>;
      return data.map((json) => BnB.fromJson(json)).toList();
    } else {
      throw Exception('Failed to fetch BnBs: ${response.statusCode}');
    }
  }
}
