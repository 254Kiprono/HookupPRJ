import 'package:flutter/material.dart';
import 'package:hook_app/auth/login_user.dart';
import 'package:hook_app/screens/auth/register_screen.dart';
import 'package:hook_app/screens/auth/forgot_password_screen.dart';
import 'package:hook_app/screens/auth/verify_reset_code_screen.dart';
import 'package:hook_app/screens/auth/reset_password_screen.dart';
import 'package:hook_app/screens/loading_screen.dart';
import 'package:hook_app/screens/main_app/subscription_screen.dart';
import 'package:hook_app/screens/main_app/safety_center_screen.dart';
import 'package:hook_app/screens/auth/safety_notice_screen.dart';
import 'package:hook_app/screens/auth/onboarding_screen.dart';
import 'package:hook_app/screens/auth/verification_screen.dart';
import 'package:hook_app/screens/main_app/home_screen.dart';
import 'package:hook_app/screens/main_app/search_screen.dart';
import 'package:hook_app/screens/main_app/provider_detail_screen.dart';
import 'package:hook_app/screens/main_app/booking_screen.dart';
import 'package:hook_app/screens/main_app/bookings_screen.dart';
import 'package:hook_app/screens/main_app/messages_screen.dart';
import 'package:hook_app/screens/main_app/account_screen.dart';
import 'package:hook_app/screens/main_app/edit_profile_screen.dart';
import 'package:hook_app/screens/main_app/gallery_video_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_owner_dashboard_screen.dart';
import 'package:hook_app/screens/bnb_owner/register_bnb_screen.dart';
import 'package:hook_app/screens/bnb_owner/manage_bnb_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_booking_history_screen.dart';
import 'package:hook_app/screens/auth/register_bnb_owner_screen.dart';
import 'package:hook_app/screens/auth/bnb_owner_login_screen.dart';
import 'package:hook_app/models/bnb.dart';

class PremiumPageRoute extends PageRouteBuilder {
  final Widget page;
  PremiumPageRoute({required this.page})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 150),
        );
}

class Routes {
  static const String loading = '/';
  static const String onboarding = '/onboarding';
  static const String safetyNotice = '/safety-notice';
  static const String verification = '/verification';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String verifyResetCode = '/verify-reset-code';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String search = '/search';
  static const String providerDetail = '/provider-detail';
  static const String booking = '/booking';
  static const String bookings = '/bookings';
  static const String messages = '/messages';
  static const String account = '/account';
  static const String editProfile = '/edit-profile';
  static const String galleryVideo = '/gallery-video';
  static const String safetyCenter = '/safety-center';
  static const String subscription = '/subscription';

  // BnB Owner Routes
  static const String bnbOwnerLogin = '/bnb-owner-login';
  static const String bnbDashboard = '/bnb-dashboard';
  static const String registerBnB = '/register-bnb';
  static const String registerBnBOwner = '/register-bnb-owner';
  static const String manageBnB = '/manage-bnb';
  static const String bnbBookingHistory = '/bnb-booking-history';

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loading:
        return PremiumPageRoute(page: const LoadingScreen());
      case onboarding:
        return PremiumPageRoute(page: const OnboardingScreen());
      case safetyNotice:
        return PremiumPageRoute(page: const SafetyNoticeScreen());
      case login:
        return PremiumPageRoute(page: const LoginScreen());
      case verification:
        final args = settings.arguments as Map<String, dynamic>;
        return PremiumPageRoute(
          page: VerificationScreen(
            verificationType: args['type'] ?? 'email',
            contact: args['contact'],
            userId: args['userId'],
          ),
        );
      case bnbOwnerLogin:
        return PremiumPageRoute(page: const BnBOwnerLoginScreen());
      case register:
        return PremiumPageRoute(page: const RegisterScreen());
      case registerBnBOwner:
        return PremiumPageRoute(page: const RegisterBnBOwnerScreen());
      case forgotPassword:
        final args = settings.arguments as String?;
        return PremiumPageRoute(page: ForgotPasswordScreen(contactInfo: args));
      case verifyResetCode:
        final String contactInfo = settings.arguments as String;
        return PremiumPageRoute(page: VerifyResetCodeScreen(contactInfo: contactInfo));
      case resetPassword:
        final args = settings.arguments as Map<String, dynamic>;
        return PremiumPageRoute(page: ResetPasswordScreen(contactInfo: args['contactInfo'], resetCode: args['resetCode']));
      case home:
        return PremiumPageRoute(page: const HomeScreen());
      case search:
        return PremiumPageRoute(page: const SearchScreen());
      case providerDetail:
        return PremiumPageRoute(page: const ProviderDetailScreen());
      case booking:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final providerId = args['providerId'] as int?;
        final providerName =
            (args['providerName'] ?? args['name'] ?? 'Provider').toString();
        final priceRaw = args['price'] ?? args['hourlyRate'] ?? 0;
        final price = (priceRaw is num) ? priceRaw.toDouble() : 0.0;
        if (providerId == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing booking providerId')),
            ),
          );
        }
        return PremiumPageRoute(
          page: BookingScreen(
            providerId: providerId,
            providerName: providerName,
            price: price,
          ),
        );
      case bookings:
        return PremiumPageRoute(page: const BookingsScreen());
      case messages:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        final otherUserId = args['otherUserId'] as int?;
        final otherUserName =
            (args['otherUserName'] ?? args['name'] ?? 'Unknown').toString();
        if (otherUserId == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Missing otherUserId for chat')),
            ),
          );
        }
        return PremiumPageRoute(
          page: MessagesScreen(
            otherUserId: otherUserId,
            otherUserName: otherUserName,
          ),
        );
      case account:
        return PremiumPageRoute(page: const AccountScreen());
      case editProfile:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return PremiumPageRoute(page: EditProfileScreen(arguments: args));
      case galleryVideo:
        final args = settings.arguments as Map<String, dynamic>? ?? {};
        return PremiumPageRoute(page: GalleryVideoScreen(userProfile: args));
      case safetyCenter:
        return PremiumPageRoute(page: const SafetyCenterScreen());
      case subscription:
        return PremiumPageRoute(page: const SubscriptionScreen());
      case bnbDashboard:
        return PremiumPageRoute(page: const BnBOwnerDashboardScreen());
      case registerBnB:
        return PremiumPageRoute(page: const RegisterBnBScreen());
      case manageBnB:
        final bnb = settings.arguments as BnB;
        return PremiumPageRoute(page: ManageBnBScreen(bnb: bnb));
      case bnbBookingHistory:
        return PremiumPageRoute(page: const BnBBookingHistoryScreen());
      default:
        // Use default for others to keep logic simple for now
        return MaterialPageRoute(
          builder: (_) => Scaffold(
            body: Center(
              child: Text('No route defined for ${settings.name}'),
            ),
          ),
        );
    }
  }
}
