import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/api_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hook_app/screens/auth/verification_screen.dart';

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  String? _errorMessage;
  bool _isCheckingAuth = true;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _animation = Tween<double>(begin: 0.9, end: 1.1).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );

    _checkAuth();
  }

  Future<void> _checkAuth() async {
    if (!_isCheckingAuth) return;

    // Don't set _isCheckingAuth = false here, wait until done

    final String? authToken = await StorageService.getAuthToken();
    final String? userId = await StorageService.getUserId();
    print('[LOADING] Auth token present: ${authToken != null}');
    print('[LOADING] User ID present: ${userId != null}');
    
    if (authToken == null || authToken.isEmpty) {
      // Don't clearAll() - we need onboarding_seen and safety_accepted to persist
      // (clearAll is only for explicit logout)
      print('[LOADING] No auth token');

      final bool onboardingSeen = await StorageService.isOnboardingSeen();
      if (!onboardingSeen) {
        if (mounted) {
          Navigator.pushReplacementNamed(context, Routes.onboarding);
        }
        return;
      }
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      // Fetch profile to verify if account is active
      print('[LOADING] Fetching user profile...');
      final profile = await ApiService.getUserProfile();
      final bool isActive = profile['is_active'] ?? true;
      final String? authProvider = profile['auth_provider'];
      final String? mEmail = profile['email'];

      final bool emailVerified = profile['email_verified'] ?? true;
      if (!isActive && !emailVerified) {
        print('[LOADING] Account not active/verified. Navigating to VerificationScreen.');
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => VerificationScreen(
                verificationType: 'email',
                contact: mEmail ?? 'your email',
                onVerified: () {
                  Navigator.pushReplacementNamed(
                    context,
                    profile['role'] == AppConstants.bnbOwnerRoleId 
                      ? Routes.bnbDashboard 
                      : Routes.home
                  );
                },
              ),
            ),
          );
        }
        return;
      }

      final roleId = await StorageService.getRoleId();
      final roleString = await StorageService.getUserRole();
// lib/models/active_user.dart

      print('[LOADING] Role ID (parsed): $roleId');
      print('[LOADING] Role String (raw): "$roleString"');

      if (mounted) {
        if (roleId == AppConstants.bnbOwnerRoleId || profile['role'] == AppConstants.bnbOwnerRoleId) {
          print('[LOADING] --> Navigating to BnB Dashboard');
          Navigator.pushReplacementNamed(context, Routes.bnbDashboard);
        } else {
          print('[LOADING] --> Navigating to Home Screen');
          Navigator.pushReplacementNamed(context, Routes.home);
        }
      }
    } catch (error) {
      print('[LOADING] Error fetching profile: $error');
      // If fetching fails, we can optionally fall back to Home, but safer to block or retry
      if (mounted) {
        setState(() {
          _errorMessage = 'Error verifying account: $error\nPlease try again.';
          _isCheckingAuth = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<bool> _checkLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        // Location services are not enabled.
        return false;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          return false;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        return false;
      }

      return true;
    } catch (e) {
      print('[LOADING] Location check error: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
          ),
        ),
        child: Center(
          child: _errorMessage != null
              ? Padding(
                  padding: const EdgeInsets.all(20.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.white, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        'Authentication Failed',
                        style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _errorMessage = null;
                            _isCheckingAuth = true;
                          });
                          _checkAuth();
                        },
                        child: const Text('Retry'),
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        onPressed: () => Geolocator.openLocationSettings(),
                        icon: const Icon(Icons.settings),
                        label: const Text('Open Settings'),
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.white24),
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: () async {
                          await StorageService.clearAll();
                          if (mounted) {
                            Navigator.pushReplacementNamed(
                                context, Routes.login);
                          }
                        },
                        child: const Text('Go to Login',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AnimatedBuilder(
                      animation: _animation,
                      builder: (context, child) {
                        return Transform.scale(
                          scale: _animation.value,
                          child: child,
                        );
                      },
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(60),
                        ),
                        child: const Icon(
                          Icons.location_on,
                          color: AppConstants.primaryColor,
                          size: 48,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'CloseBy',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Connecting you with amazing experiences',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      strokeWidth: 2,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}
