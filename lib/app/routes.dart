import 'package:flutter/material.dart';
import 'package:hook_app/auth/login_user.dart'; // Assuming this is LoginScreen
import 'package:hook_app/screens/auth/register_screen.dart';
import 'package:hook_app/screens/auth/forgot_password_screen.dart';
import 'package:hook_app/screens/auth/reset_password_screen.dart';
import 'package:hook_app/screens/loading_screen.dart';
import 'package:hook_app/screens/main_app/home_screen.dart';
import 'package:hook_app/screens/main_app/search_screen.dart';
import 'package:hook_app/screens/main_app/provider_detail_screen.dart';
import 'package:hook_app/screens/main_app/booking_screen.dart'; // Import BookingScreen
import 'package:hook_app/screens/main_app/bookings_screen.dart'; // Import BookingsScreen
import 'package:hook_app/screens/main_app/messages_screen.dart';
import 'package:hook_app/screens/main_app/account_screen.dart'; // Already imported
import 'package:hook_app/screens/main_app/edit_profile_screen.dart'; // Fixed import

class Routes {
  static const String loading = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';
  static const String resetPassword = '/reset-password';
  static const String home = '/home';
  static const String search = '/search';
  static const String providerDetail = '/provider-detail';
  static const String booking = '/booking'; // For creating a booking
  static const String bookings = '/bookings'; // For viewing booking history
  static const String messages = '/messages';
  static const String account = '/account';
  static const String editProfile = '/edit-profile'; // Added new route

  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case loading:
        return MaterialPageRoute(builder: (_) => const LoadingScreen());
      case login:
        return MaterialPageRoute(builder: (_) => const LoginScreen());
      case register:
        return MaterialPageRoute(builder: (_) => const RegisterScreen());
      case forgotPassword:
        final args = settings.arguments as String?;
        return MaterialPageRoute(
          builder: (_) => ForgotPasswordScreen(contactInfo: args),
        );
      case resetPassword:
        if (settings.arguments == null || settings.arguments is! String) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Invalid arguments for reset password')),
            ),
          );
        }
        final String contactInfo = settings.arguments as String;
        return MaterialPageRoute(
          builder: (_) => ResetPasswordScreen(contactInfo: contactInfo),
        );
      case home:
        return MaterialPageRoute(builder: (_) => const HomeScreen());
      case search:
        return MaterialPageRoute(builder: (_) => const SearchScreen());
      case providerDetail:
        return MaterialPageRoute(builder: (_) => const ProviderDetailScreen());
      case booking:
        if (settings.arguments == null ||
            settings.arguments is! Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Invalid arguments for BookingScreen')),
            ),
          );
        }
        final args = settings.arguments as Map<String, dynamic>;
        final providerId = args['providerId'] as int?;
        final providerName = args['providerName'] as String?;
        final price = args['price'] as double?;
        if (providerId == null || providerName == null || price == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(child: Text('Invalid arguments for BookingScreen')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => BookingScreen(
            providerId: providerId,
            providerName: providerName,
            price: price,
          ),
        );
      case bookings:
        return MaterialPageRoute(builder: (_) => const BookingsScreen());
      case messages:
        if (settings.arguments == null ||
            settings.arguments is! Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                  child: Text(
                      'otherUserId and otherUserName are required for MessagesScreen')),
            ),
          );
        }
        final args = settings.arguments as Map<String, dynamic>;
        final otherUserId = args['otherUserId'] as int?;
        final otherUserName =
            args['otherUserName'] as String?; // Extract otherUserName
        if (otherUserId == null) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                  child: Text('otherUserId is required for MessagesScreen')),
            ),
          );
        }
        return MaterialPageRoute(
          builder: (_) => MessagesScreen(
            otherUserId: otherUserId,
            otherUserName:
                otherUserName ?? 'Unknown', // Pass with default if null
          ),
        );
      case account:
        return MaterialPageRoute(builder: (_) => const AccountScreen());
      case editProfile:
        if (settings.arguments == null ||
            settings.arguments is! Map<String, dynamic>) {
          return MaterialPageRoute(
            builder: (_) => const Scaffold(
              body: Center(
                  child: Text('Invalid arguments for EditProfileScreen')),
            ),
          );
        }
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => EditProfileScreen(arguments: args),
        );
      default:
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
