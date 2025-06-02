import 'package:flutter/material.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppConstants {
  static const String appName = 'HookUp';

  // Colors
  static const Color primaryColor = Color(0xFF6E48AA);
  static const Color secondaryColor = Color(0xFF9D50BB);
  static const Color accentColor = Color(0xFFE91E63);

  // Assets
  static const String logoPath = 'assets/images/logo.png';

  // API Endpoints
  static const String userServiceBaseUrl =
      'https://hk-userservice.devsinkenya.com';
  static const String messagingServiceBaseUrl =
      'https://message-service.devsinkenya.com';
  static const String apiVersion = '/v1';

  // Authentication Endpoints (User Service)
  static const String login = '$userServiceBaseUrl$apiVersion/auth/login';
  static const String register = '$userServiceBaseUrl$apiVersion/auth/register';
  static const String forgotPassword =
      '$userServiceBaseUrl$apiVersion/auth/request-passreset';
  static const String verifyOTP =
      '$userServiceBaseUrl$apiVersion/auth/verify-otp';
  static const String resetPassword =
      '$userServiceBaseUrl$apiVersion/auth/reset-password';
  static const String resendOTP =
      '$userServiceBaseUrl$apiVersion/auth/request-passreset';
  static const String getuserprofile =
      '$userServiceBaseUrl$apiVersion/auth/get-userprofile';
  static const String googleAuth = '$userServiceBaseUrl$apiVersion/auth/google';

  // User Service Search Endpoints
  static const String searchProviders =
      '$userServiceBaseUrl$apiVersion/location/search-providers';
  static const String searchBnBs = '$userServiceBaseUrl$apiVersion/bnbs/search';

  // Messaging Endpoints (Messaging Service) - Aligned with .proto
  static const String conversations =
      '$messagingServiceBaseUrl$apiVersion/conversations';
  static const String messages = '$messagingServiceBaseUrl$apiVersion/messages';
  static const String sendMessage =
      '$messages/send'; // Matches POST /v1/messages/send
  static const String deleteMessage =
      '$messages/{message_id}'; // Matches DELETE /v1/messages/{message_id}
  static const String bookingInitiate =
      '$messagingServiceBaseUrl$apiVersion/booking/initiate'; // Matches POST /v1/booking/initiate
  static const String bookingRespond =
      '$messagingServiceBaseUrl$apiVersion/booking/respond'; // Matches POST /v1/booking/respond
  static const String notificationsSms =
      '$messagingServiceBaseUrl$apiVersion/notifications/sms'; // Matches POST /v1/notifications/sms
  static const String bookings = '$messagingServiceBaseUrl$apiVersion/bookings';
  static const String bookingHistory =
      '$messagingServiceBaseUrl$apiVersion/bookings/history';

  // WebSocket Endpoint
  static const String websocketUrl =
      'wss://message-service.devsinkenya.com/v1/stream';

  // SharedPreferences Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String otpVerificationId = 'otp_verification_id';
  static const String userProfileKey = 'user_profile';
}

class TokenUtils {
  static Future<int?> extractUserId(String token) async {
    try {
      if (token.isEmpty) return null;
      if (JwtDecoder.isExpired(token)) return null;

      final decoded = JwtDecoder.decode(token);
      print('Token claims: $decoded'); // Debug logging

      // Try multiple possible user ID claims (priority order)
      final dynamic id = decoded['user_id'] ?? // Matches your Go backend
          decoded['userId'] ?? // Alternative camelCase
          decoded['sub']; // Standard JWT claim

      // Handle both int and string user IDs
      if (id is int) return id;
      if (id is String) return int.tryParse(id);
      return null;
    } catch (e) {
      print('Token extraction error: $e');
      return null;
    }
  }

  static Future<String?> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.login), // Use your refresh endpoint if available
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'] as String?;
      }
      return null;
    } catch (e) {
      print('Error refreshing token: $e');
      return null;
    }
  }
}
