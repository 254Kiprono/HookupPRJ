import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

/// StorageService: uses FlutterSecureStorage on mobile, SharedPreferences on Web
/// This is required because FlutterSecureStorage has known issues on Flutter Web.
class StorageService {
  // Mobile-only secure storage
  static const _secureStorage = FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // Keys
  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _profileIdKey = 'profile_id';
  static const String _userRoleKey = 'user_role';
  static const String _onboardingSeenKey = 'onboarding_seen';
  static const String _safetyAcceptedKey = 'safety_accepted';
  static const String _referralCodeKey = 'referral_code';

  // ─── Internal helpers ────────────────────────────────────────────────────────

  static Future<void> _write(String key, String value) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(key, value);
    } else {
      await _secureStorage.write(key: key, value: value);
    }
  }

  static Future<String?> _read(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(key);
    } else {
      return await _secureStorage.read(key: key);
    }
  }

  static Future<void> _delete(String key) async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(key);
    } else {
      await _secureStorage.delete(key: key);
    }
  }

  static Future<void> _deleteAll() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_authTokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_userIdKey);
      await prefs.remove(_profileIdKey);
      await prefs.remove(_userRoleKey);
      await prefs.remove(_onboardingSeenKey);
      await prefs.remove(_safetyAcceptedKey);
      await prefs.remove(_referralCodeKey);
    } else {
      await _secureStorage.deleteAll();
    }
  }

  // ─── Public API ──────────────────────────────────────────────────────────────

  static Future<void> saveAuthToken(String token) async {
    await _write(_authTokenKey, token);
    await syncProfileIdFromAccessToken(token);
  }

  /// Persists identity `profile_id` from JWT (same claim as backend microservices).
  static Future<void> syncProfileIdFromAccessToken(String token) async {
    try {
      if (token.isEmpty) return;
      if (JwtDecoder.isExpired(token)) return;
      final d = JwtDecoder.decode(token);
      final raw = d['profile_id'] ?? d['profileId'];
      if (raw == null) {
        await _delete(_profileIdKey);
        return;
      }
      await saveProfileId(raw.toString());
    } catch (_) {
      // ignore malformed token
    }
  }

  static Future<String?> getAuthToken() async {
    final token = await _read(_authTokenKey);
    if (token == null || token.isEmpty) return null;
    if (JwtDecoder.isExpired(token)) {
      await clearAuth();
      return null;
    }
    return token;
  }

  static Future<void> saveRefreshToken(String token) async =>
      _write(_refreshTokenKey, token);

  static Future<String?> getRefreshToken() async => _read(_refreshTokenKey);

  static Future<void> saveUserId(String userId) async =>
      _write(_userIdKey, userId);

  static Future<String?> getUserId() async => _read(_userIdKey);

  static Future<void> saveProfileId(String profileId) async =>
      _write(_profileIdKey, profileId);

  /// Identity profile_id (from JWT); null if legacy session or not yet issued.
  static Future<String?> getProfileId() async => _read(_profileIdKey);

  static Future<void> saveUserRole(String role) async =>
      _write(_userRoleKey, role);

  static Future<String?> getUserRole() async => _read(_userRoleKey);

  static Future<int?> getRoleId() async {
    final role = await _read(_userRoleKey);
    if (role == null) return null;
    return int.tryParse(role);
  }

  static Future<void> setOnboardingSeen(bool seen) async =>
      _write(_onboardingSeenKey, seen ? '1' : '0');

  static Future<bool> isOnboardingSeen() async {
    final v = await _read(_onboardingSeenKey);
    return v == '1';
  }

  static Future<void> setSafetyAccepted(bool accepted) async =>
      _write(_safetyAcceptedKey, accepted ? '1' : '0');

  static Future<bool> isSafetyAccepted() async {
    final v = await _read(_safetyAcceptedKey);
    return v == '1';
  }

  static Future<void> saveReferralCode(String code) async {
    if (code.trim().isEmpty) return;
    await _write(_referralCodeKey, code.trim());
  }

  static Future<String?> getReferralCode() async => _read(_referralCodeKey);

  static Future<void> clearReferralCode() async => _delete(_referralCodeKey);

  static Future<void> saveJson(String key, dynamic value) async {
    try {
      final jsonStr = jsonEncode(value);
      await _write(key, jsonStr);
    } catch (e) {
      debugPrint('⚠️ [STORAGE] Failed to save JSON for $key: $e');
    }
  }

  static Future<dynamic> getJson(String key) async {
    try {
      final jsonStr = await _read(key);
      if (jsonStr == null || jsonStr.isEmpty) return null;
      return jsonDecode(jsonStr);
    } catch (e) {
      debugPrint('⚠️ [STORAGE] Failed to get JSON for $key: $e');
      return null;
    }
  }

  static Future<void> clearAuth() async {
    await _delete(_authTokenKey);
    await _delete(_refreshTokenKey);
    await _delete(_userIdKey);
    await _delete(_profileIdKey);
    await _delete(_userRoleKey);
  }

  static Future<void> clearAll() async => _deleteAll();
}
