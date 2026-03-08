import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class StorageService {
  static const _storage = FlutterSecureStorage();

  static const String _authTokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _userIdKey = 'user_id';
  static const String _userRoleKey = 'user_role';
  static const String _onboardingSeenKey = 'onboarding_seen';
  static const String _safetyAcceptedKey = 'safety_accepted';
  static const String _referralCodeKey = 'referral_code';

  static Future<void> saveAuthToken(String token) async {
    await _storage.write(key: _authTokenKey, value: token);
  }

  static Future<String?> getAuthToken() async {
    return await _storage.read(key: _authTokenKey);
  }

  static Future<void> saveRefreshToken(String token) async {
    await _storage.write(key: _refreshTokenKey, value: token);
  }

  static Future<String?> getRefreshToken() async {
    return await _storage.read(key: _refreshTokenKey);
  }

  static Future<void> saveUserId(String userId) async {
    await _storage.write(key: _userIdKey, value: userId);
  }

  static Future<String?> getUserId() async {
    return await _storage.read(key: _userIdKey);
  }

  static Future<void> saveUserRole(String role) async {
    await _storage.write(key: _userRoleKey, value: role);
  }

  static Future<String?> getUserRole() async {
    return await _storage.read(key: _userRoleKey);
  }

  static Future<int?> getRoleId() async {
    final role = await _storage.read(key: _userRoleKey);
    if (role == null) return null;
    return int.tryParse(role);
  }

  static Future<void> setOnboardingSeen(bool seen) async {
    await _storage.write(key: _onboardingSeenKey, value: seen ? '1' : '0');
  }

  static Future<bool> isOnboardingSeen() async {
    final v = await _storage.read(key: _onboardingSeenKey);
    return v == '1';
  }

  static Future<void> setSafetyAccepted(bool accepted) async {
    await _storage.write(key: _safetyAcceptedKey, value: accepted ? '1' : '0');
  }

  static Future<bool> isSafetyAccepted() async {
    final v = await _storage.read(key: _safetyAcceptedKey);
    return v == '1';
  }

  static Future<void> saveReferralCode(String code) async {
    if (code.trim().isEmpty) return;
    await _storage.write(key: _referralCodeKey, value: code.trim());
  }

  static Future<String?> getReferralCode() async {
    return await _storage.read(key: _referralCodeKey);
  }

  static Future<void> clearReferralCode() async {
    await _storage.delete(key: _referralCodeKey);
  }

  static Future<void> clearAll() async {
    await _storage.deleteAll();
  }
}
