import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;

class LoadingScreen extends StatefulWidget {
  const LoadingScreen({super.key});

  @override
  State<LoadingScreen> createState() => _LoadingScreenState();
}

class _LoadingScreenState extends State<LoadingScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
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

    setState(() {
      _isCheckingAuth = false;
    });

    // Simulate loading delay
    await Future.delayed(const Duration(seconds: 3));

    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);
    print('LoadingScreen - Retrieved authToken: $authToken');

    if (authToken == null || authToken.isEmpty) {
      print('LoadingScreen - No token found, redirecting to login');
      if (mounted) {
        await prefs.clear(); // Clear any stale data
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    // Validate the token by attempting to fetch the user profile
    try {
      final String url = AppConstants.getuserprofile;
      print('LoadingScreen - Validating token by fetching profile from: $url');
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        print('LoadingScreen - Token is valid, navigating to home');
        if (mounted) {
          Navigator.pushReplacementNamed(context, Routes.home);
        }
      } else {
        print(
            'LoadingScreen - Token validation failed with status: ${response.statusCode}, redirecting to login');
        await prefs.clear(); // Clear invalid token
        if (mounted) {
          Navigator.pushReplacementNamed(context, Routes.login);
        }
      }
    } catch (error) {
      print(
          'LoadingScreen - Token validation error: $error, redirecting to login');
      await prefs.clear(); // Clear on any error
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
          ),
        ),
        child: Center(
          child: Column(
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
                  child: Icon(
                    Icons.favorite,
                    color: AppConstants.primaryColor,
                    size: 48,
                  ),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                'HookUp',
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
