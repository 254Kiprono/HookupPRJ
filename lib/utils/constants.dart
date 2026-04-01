import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class AppConstants {
  static const String appName = 'CloseBy';

  // Colors - CloseBy (Calm, Trustworthy, Discreet)
  // Primary Colors
  static const Color primaryColor = Color(0xFF0F766E); // Teal
  static const Color secondaryColor = Color(0xFF0B1220); // Deep Navy
  static const Color accentColor = Color(0xFF99F6E4); // Mint Accent
  static const Color tealLight = Color(0xFF14B8A6);
  static const Color tealDark = Color(0xFF0D5F58);
  static const Color deepNavy = Color(0xFF0B1220);
  static const Color cardNavy = Color(0xFF1A2332); // For cards and navigation

  // Background Colors
  static const Color darkBackground = Color(0xFF0B1220); // Deep Navy
  static const Color midnightPurple =
      Color(0xFF0B1220); // Alias for legacy usage
  static const Color deepPurple = Color(0xFF0F172A); // Dark Slate
  static const Color lightBackground = Color(0xFFF7F9FA); // Soft Light
  static const Color surfaceColor = Color(0xFF111827); // Surface for cards

  // Support Colors
  static const Color softRose = Color(0xFFCCFBF1); // Soft mint highlight
  static const Color neonGlow = Color(0xFF0F766E); // Teal emphasis
  static const Color mutedGray =
      Color(0xFF94A3B8); // Muted gray for secondary text
  static const Color errorColor = Color(0xFFEF4444); // Error red
  static const Color successColor = Color(0xFF10B981); // Success green
  static const Color softWhite = Color(0xFFF7F9FA); // Text on dark backgrounds

  // Assets
  static const String logoPath = 'assets/images/logo.png';

  // API Endpoints
  static const String userServiceBaseUrl =
      'https://identity-service.close-by.chat';
  static const String messagingServiceBaseUrl =
      'https://chat-service.close-by.chat';
  static const String bnbServiceBaseUrl = 'https://bnb-service.close-by.chat';
  static const String bookingServiceBaseUrl =
      'https://booking-service.close-by.chat';
  static const String paymentServiceBaseUrl =
      'https://payment-service.close-by.chat';
  static const String apiVersion = '/v1';

  // Authentication Endpoints (User Service)
  static const String login = '$userServiceBaseUrl$apiVersion/auth/login';
  static const String register = '$userServiceBaseUrl$apiVersion/auth/register';
  static const String forgotPassword =
      '$userServiceBaseUrl$apiVersion/auth/request-passreset';
  static const String verifyOTP =
      '$userServiceBaseUrl$apiVersion/auth/verify-otp';
  static const String verifyEmail =
      '$userServiceBaseUrl$apiVersion/auth/verify-email';
  static const String verifyPhone =
      '$userServiceBaseUrl$apiVersion/auth/verify-phone';
  static const String sendEmailVerification =
      '$userServiceBaseUrl$apiVersion/auth/send-email-verification';
  static const String sendPhoneVerification =
      '$userServiceBaseUrl$apiVersion/auth/send-phone-verification';
  static const String googleSignUp =
      '$userServiceBaseUrl$apiVersion/auth/google-signup';
  static const String googleSignIn =
      '$userServiceBaseUrl$apiVersion/auth/google-signin';
  static const String logout = '$userServiceBaseUrl$apiVersion/auth/logout';
  static const String updateLocation =
      '$userServiceBaseUrl$apiVersion/auth/update-location';
  static const String searchNearbyUsers =
      '$userServiceBaseUrl$apiVersion/users/search-nearby';
  static const String resetPassword =
      '$userServiceBaseUrl$apiVersion/auth/reset-password';
  static const String verifyResetCode =
      '$userServiceBaseUrl$apiVersion/auth/verify-reset-code';
  static const String resendOTP =
      '$userServiceBaseUrl$apiVersion/auth/request-passreset';
  static const String getuserprofile =
      '$userServiceBaseUrl$apiVersion/auth/get-userprofile';
  static const String mediaUpload =
      '$userServiceBaseUrl$apiVersion/media/upload';
  static const String mediaProxy =
      '$userServiceBaseUrl$apiVersion/media/proxy';

  // User Service Search Endpoints
  static const String searchProviders =
      '$userServiceBaseUrl$apiVersion/users/search-nearby';
  static const String searchBnBs = '$bnbServiceBaseUrl$apiVersion/bnb/location';

  // BnB Service Endpoints
  static const String registerBnB =
      '$bnbServiceBaseUrl$apiVersion/bnb/register';
  static const String updateBnB =
      '$bnbServiceBaseUrl$apiVersion/bnb'; // + /{bnb_id}
  static const String getBnBsByLocation =
      '$bnbServiceBaseUrl$apiVersion/bnb/location'; // + /{location}
  static const String getBnBDetails =
      '$bnbServiceBaseUrl$apiVersion/bnb'; // + /{bnb_id}
  static const String deleteBnB =
      '$bnbServiceBaseUrl$apiVersion/bnb'; // + /{bnb_id}
  static const String getBnBsByOwner =
      '$bnbServiceBaseUrl$apiVersion/bnb/owner'; // + /{owner_id}

  // Booking Service Endpoints
  static const String createBooking =
      '$bookingServiceBaseUrl$apiVersion/bookings';
  static const String updateBookingStatus =
      '$bookingServiceBaseUrl$apiVersion/bookings'; // + /{booking_id}
  static const String getBooking =
      '$bookingServiceBaseUrl$apiVersion/bookings'; // + /{booking_id}
  static const String listBookings =
      '$bookingServiceBaseUrl$apiVersion/bookings';
  static const String getBookingsByBnbOwner =
      '$bookingServiceBaseUrl$apiVersion/bnb/bookings';

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

  // Wallet Service Endpoints
  static const String walletServiceBaseUrl =
      'https://wallet-service.close-by.chat';
  static const String getWalletBalance =
      '$walletServiceBaseUrl$apiVersion/wallet'; // + /{user_id}/balance
  static const String withdraw =
      '$walletServiceBaseUrl$apiVersion/wallet/withdraw';
  static const String getWithdrawHistory =
      '$walletServiceBaseUrl$apiVersion/wallet'; // + /{user_id}/withdrawals
  static const String getPaymentHistory =
      '$walletServiceBaseUrl$apiVersion/wallet'; // + /{user_id}/payment-history
  
  // Payment Service Endpoints
  static const String initiatePayment = '$paymentServiceBaseUrl/pyts/send-request';
  
  // WebSocket Endpoint
  static const String websocketUrl =
      'wss://chat-service.close-by.chat/v1/stream'; // Use wss:// for Flutter WebSocket connection through proxy

  // SharedPreferences Keys
  static const String authTokenKey = 'auth_token';
  static const String refreshTokenKey = 'refresh_token';
  static const String userRoleKey = 'user_role';
  static const String userIdKey = 'user_id';
  static const String otpVerificationId = 'otp_verification_id';
  static const String userProfileKey = 'user_profile';

  // Role Constants
  static const int bnbOwnerRoleId = 4;
  static const int regularUserRoleId = 1; 
  static const int customerCareRoleId = 3; 

  // Subscription Plans (in KSh)
  static const int subWeeklyPrice = 200;
  static const int subTwoWeeksPrice = 500;
  static const int subMonthlyPrice = 800;
  
  static String getProxiedUrl(String url) {
    if (kIsWeb &&
        url.isNotEmpty &&
        !url.contains('/media/proxy?url=') &&
        (url.contains('r2.dev') ||
         url.contains('cloudflarestorage.com') ||
         url.contains('placeholder.com') ||
         url.contains('via.placeholder.com'))) {
      final String encodedUrl = Uri.encodeComponent(url);
      final String proxied = '$mediaProxy?url=$encodedUrl';
      debugPrint('🔗 Proxying Media: $url -> $proxied');
      return proxied;
    }
    return url;
  }
}

class TokenUtils {
  static Future<int?> extractUserId(String token) async {
    try {
      if (token.isEmpty) return null;
      if (JwtDecoder.isExpired(token)) return null;

      final decoded = JwtDecoder.decode(token);

      // Try multiple possible user
      final dynamic id = decoded['user_id'] ?? 
          decoded['userId'] ?? 
          decoded['sub']; 

      if (id is int) return id;
      if (id is double) return id.toInt();
      if (id is String) return int.tryParse(id);
      return null;
    } catch (e) {
      return null;
    }
  }

  /// Identity `profile_id` claim (aligned with backend JWT). Null if absent / legacy token.
  static Future<int?> extractProfileId(String token) async {
    try {
      if (token.isEmpty) return null;
      if (JwtDecoder.isExpired(token)) return null;
      final decoded = JwtDecoder.decode(token);
      final dynamic raw = decoded['profile_id'] ?? decoded['profileId'];
      if (raw == null) return null;
      if (raw is int) return raw;
      if (raw is double) return raw.toInt();
      if (raw is String) return int.tryParse(raw);
      return null;
    } catch (e) {
      return null;
    }
  }

  static Future<String?> refreshToken(String refreshToken) async {
    try {
      final response = await http.post(
        Uri.parse(AppConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'refresh_token': refreshToken}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return data['access_token'] as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }
}
