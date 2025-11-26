import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/api_service.dart';

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

    final String? authToken = await StorageService.getAuthToken();
    print('🔐 [LOADING] Auth token present: ${authToken != null}');

    if (authToken == null || authToken.isEmpty) {
      await StorageService.clearAll();
      print('❌ [LOADING] No auth token, redirecting to login');
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      await ApiService.getUserProfile();
      print('✅ [LOADING] User profile fetched successfully');
      
      final roleId = await StorageService.getRoleId();
      final roleString = await StorageService.getUserRole();
      
      print('👤 [LOADING] Role ID (parsed): $roleId');
      print('👤 [LOADING] Role String (raw): "$roleString"');
      print('🎯 [LOADING] Expected BnB Owner Role ID: ${AppConstants.bnbOwnerRoleId}');
      print('🔍 [LOADING] Is BnB Owner: ${roleId == AppConstants.bnbOwnerRoleId}');
      
      if (mounted) {
        if (roleId == AppConstants.bnbOwnerRoleId) {
          print('🏠 [LOADING] ➡️ Navigating to BnB Dashboard');
          Navigator.pushReplacementNamed(context, Routes.bnbDashboard);
        } else {
          print('❤️ [LOADING] ➡️ Navigating to Home Screen');
          Navigator.pushReplacementNamed(context, Routes.home);
        }
      }
    } catch (error) {
      print('❌ [LOADING] Error: $error');
      await StorageService.clearAll();
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
        decoration: const BoxDecoration(
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
                  child: const Icon(
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
