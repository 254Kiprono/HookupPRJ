import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/utils/nav.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';

class _CacheEntry {
  final http.Response response;
  final DateTime timestamp;

  _CacheEntry(this.response) : timestamp = DateTime.now();

  bool get isExpired => DateTime.now().difference(timestamp) > const Duration(seconds: 30);
}

class HttpService {
  static bool _isLoggingOut = false;
  
  // High-performance In-Memory Cache
  static final Map<String, _CacheEntry> _cache = {};

  static Future<http.Response> post(Uri url, {Map<String, String>? headers, Object? body}) async {
    final cacheKey = 'POST_${url.toString()}_${body.hashCode}';
    
    // Serve from cache if valid
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      debugPrint('⚡ [CACHE] Serving: ${url.path}');
      return _cache[cacheKey]!.response;
    }

    final response = await http.post(url, headers: headers, body: body);
    _handleResponse(response);
    
    // Cache successful responses ONLY if they contain data (don't cache empty results for search)
    if (response.statusCode == 200) {
      bool shouldCache = true;
      try {
          final data = jsonDecode(response.body);
          if (data is Map) {
              if (data.containsKey('users') && (data['users'] as List).isEmpty) shouldCache = false;
              if (data.containsKey('bnbs') && (data['bnbs'] as List).isEmpty) shouldCache = false;
          }
      } catch (_) {}
      
      if (shouldCache) {
          _cache[cacheKey] = _CacheEntry(response);
      }
    }
    
    return response;
  }

  static Future<http.Response> get(Uri url, {Map<String, String>? headers}) async {
    final cacheKey = 'GET_${url.toString()}';
    
    if (_cache.containsKey(cacheKey) && !_cache[cacheKey]!.isExpired) {
      debugPrint('⚡ [CACHE] Serving: ${url.path}');
      return _cache[cacheKey]!.response;
    }

    final response = await http.get(url, headers: headers);
    _handleResponse(response);
    
    if (response.statusCode == 200) {
      _cache[cacheKey] = _CacheEntry(response);
    }
    
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
