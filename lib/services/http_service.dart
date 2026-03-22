import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/nav.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';

class HttpService {
  static bool _isLoggingOut = false;

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.post(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final response = await http.get(url, headers: headers);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> patch(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.patch(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> delete(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.delete(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  static Future<http.Response> put(Uri url, {Map<String, String>? headers, Object? body}) async {
    final response = await http.put(url, headers: headers, body: body);
    _handleResponse(response);
    return response;
  }

  static void _handleResponse(http.Response response) {
    if (response.statusCode == 401) {
      _logout();
    }
  }

  static void _logout() async {
    if (_isLoggingOut) return;
    _isLoggingOut = true;

    debugPrint('🔒 [AUTH] Token expired (401). Logging out...');

    // Clear storage
    await StorageService.clearAll();

    // Redirect to login using the global navigator key
    final nav = Nav.navigatorKey.currentState;
    if (nav != null) {
      nav.pushNamedAndRemoveUntil(Routes.login, (route) => false);
    }
    
    // Reset the flag after some time
    Future.delayed(const Duration(seconds: 2), () => _isLoggingOut = false);
  }
}
