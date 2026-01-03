// lib/screens/main_app/account_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hook_app/screens/main_app/bnbs_browse_screen.dart';
import 'package:hook_app/screens/main_app/orders_screen.dart';
import 'package:hook_app/screens/main_app/wallet_screen.dart';

import 'package:hook_app/screens/main_app/profile_details_screen.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> with TickerProviderStateMixin {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isOnline = false;
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );
    
    _loadCachedProfile();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedProfile = prefs.getString(AppConstants.userProfileKey);

    if (cachedProfile != null && cachedProfile.isNotEmpty) {
      try {
        final data = jsonDecode(cachedProfile);
        setState(() {
          _userProfile = data;
          _isOnline = (data['isActive'] ?? data['is_active']) == true;
          _isLoading = false;
        });
        _fadeController.forward();
      } catch (e) {
        // Ignore error parsing cached profile
      }
    } else {
      setState(() {
        _isLoading = true;
      });
      // Start fade animation even if no cached profile exists
      // This ensures menu items are visible while profile is loading
      _fadeController.forward();
    }
  }

  Future<void> _fetchUserProfile() async {
    final String? authToken = await StorageService.getAuthToken();
    final prefs = await SharedPreferences.getInstance();

    if (authToken == null) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      print('🔍 [ACCOUNT] Fetching user profile...');
      final response = await UserService.getUserProfile();
      
      // Extract user data from response (backend returns {user: {...}})
      final data = response['user'] ?? response;
      
      print('✅ [ACCOUNT] Profile fetched successfully');
      
      // Cache the profile data
      await prefs.setString(AppConstants.userProfileKey, jsonEncode(data));
      
      if (mounted) {
        setState(() {
          _userProfile = data;
          _isOnline = (data['isActive'] ?? data['is_active']) == true;
          _isLoading = false;
          _errorMessage = null;
        });
        _fadeController.forward();
      }
    } catch (e) {
      print('❌ [ACCOUNT] Profile fetch error: $e');
      final roleId = await StorageService.getRoleId();
      print('👤 [ACCOUNT] Current role ID: $roleId');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          // Show a more helpful error message based on error type
          if (e.toString().contains('403') || e.toString().contains('insufficient privileges')) {
            _errorMessage = 'Permission denied (Role ID: $roleId). Profile features may be limited.';
          } else if (e.toString().contains('501') || e.toString().contains('Method Not Allowed')) {
            _errorMessage = 'API method error. Please try again.';
          } else {
            _errorMessage = 'Failed to load profile. Menu items are still available.';
          }
        });
        // Ensure menu items are visible even if profile fetch fails
        _fadeController.forward();
      }
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();

    try {
      // Use the UserService method instead of direct HTTP call
      final response = await UserService.updateActiveStatus(isOnline);
      
      // Update local profile cache
      if (_userProfile != null) {
        _userProfile!['isActive'] = isOnline;
        // Update from response if available
        if (response['user'] != null) {
          _userProfile = response['user'];
        }
        await prefs.setString(
            AppConstants.userProfileKey, jsonEncode(_userProfile));
      }

      if (mounted) {
        setState(() {
          _isOnline = isOnline;
          _errorMessage = null;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Online status ${isOnline ? 'activated' : 'deactivated'}',
              style: const TextStyle(color: AppConstants.softWhite),
            ),
            backgroundColor: AppConstants.deepPurple,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to update online status: $error';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: ${error.toString()}',
              style: const TextStyle(color: AppConstants.softWhite),
            ),
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
  }

  Future<void> _logout() async {
    await StorageService.clearAll();
    if (mounted) {
      Navigator.pushNamedAndRemoveUntil(
        context,
        Routes.login,
        (route) => false,
      );
    }
  }

  Future<void> _pickProfileImage() async {
    try {
      final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
      if (image != null) {
        setState(() {
          _profileImage = File(image.path);
        });
        // Upload image logic would go here
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  String _getReadableAccountType(String role) {
    switch (role) {
      case 'ROLE_BNB_OWNER':
        return 'BNB Provider';
      case 'ROLE_ADMIN':
        return 'Administrator';
      case 'ROLE_CUSTOMER_CARE':
        return 'Customer Care';
      default:
        return role.replaceAll('ROLE_', '');
    }
  }

  String _formatPhone(String phone) {
    if (phone.startsWith('254') && phone.length == 12) {
      return '+254 ${phone.substring(3, 6)} ${phone.substring(6)}';
    }
    return phone;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                children: [
                  // Header Section
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24.0),
                    child: Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: AppConstants.softWhite,
                        shadows: [
                          Shadow(
                            blurRadius: 10.0,
                            color: AppConstants.primaryColor.withOpacity(0.5),
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Avatar Section
                  SizedBox(
                    height: 200,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Glowing background effect
                        if (_isOnline)
                          ScaleTransition(
                            scale: _pulseAnimation,
                            child: Container(
                              width: 140,
                              height: 140,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: AppConstants.accentColor.withOpacity(0.6),
                                    blurRadius: 30,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        
                        // Avatar with border
                        GestureDetector(
                          onTap: _pickProfileImage,
                          child: Container(
                            width: 130,
                            height: 130,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppConstants.primaryColor,
                                  AppConstants.secondaryColor,
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.primaryColor.withOpacity(0.5),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            padding: const EdgeInsets.all(4),
                            child: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: AppConstants.deepPurple,
                              ),
                              child: ClipOval(
                                child: _profileImage != null
                                    ? Image.file(
                                        _profileImage!,
                                        fit: BoxFit.cover,
                                      )
                                    : _userProfile?['profileImage'] != null &&
                                            _userProfile!['profileImage']
                                                .toString()
                                                .isNotEmpty
                                        ? Image.network(
                                            _userProfile!['profileImage'],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: AppConstants.mutedGray,
                                              );
                                            },
                                          )
                                        : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: AppConstants.mutedGray,
                                          ),
                              ),
                            ),
                          ),
                        ),
                        
                        // Camera icon
                        Positioned(
                          bottom: 40,
                          right: MediaQuery.of(context).size.width / 2 - 80,
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: LinearGradient(
                                colors: [
                                  AppConstants.primaryColor,
                                  AppConstants.secondaryColor,
                                ],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: AppConstants.primaryColor.withOpacity(0.5),
                                  blurRadius: 10,
                                  spreadRadius: 1,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.camera_alt,
                              size: 20,
                              color: AppConstants.softWhite,
                            ),
                          ),
                        ),
                        
                        // Online indicator
                        if (_isOnline)
                          Positioned(
                            bottom: 40,
                            left: MediaQuery.of(context).size.width / 2 - 80,
                            child: ScaleTransition(
                              scale: _pulseAnimation,
                              child: Container(
                                width: 24,
                                height: 24,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: AppConstants.accentColor,
                                  border: Border.all(
                                    color: AppConstants.deepPurple,
                                    width: 3,
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppConstants.accentColor.withOpacity(0.8),
                                      blurRadius: 15,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                  
                  // Name or Error Message
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        if (_userProfile != null)
                          Text(
                            _userProfile!['fullName'] ?? 'N/A',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: AppConstants.softWhite,
                              shadows: [
                                Shadow(
                                  blurRadius: 8.0,
                                  color: AppConstants.primaryColor.withOpacity(0.3),
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            textAlign: TextAlign.center,
                          )
                        else if (_errorMessage != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Text(
                              _errorMessage!,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppConstants.errorColor,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Menu List
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Column(
                      children: [
                        _buildMenuItem(
                          icon: Icons.person_outline,
                          title: 'Profile',
                          subtitle: 'Personal information & status',
                          onTap: () {
                            if (_userProfile != null) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => ProfileDetailsScreen(
                                    userProfile: _userProfile!,
                                    isOnline: _isOnline,
                                    isEditable: true,
                                    onStatusChanged: (status) async {
                                      setState(() {
                                        _isOnline = status;
                                        if (_userProfile != null) {
                                          _userProfile!['isActive'] = status;
                                          _userProfile!['is_active'] = status;
                                        }
                                      });
                                      
                                      // Update cache
                                      final prefs = await SharedPreferences.getInstance();
                                      if (_userProfile != null) {
                                        await prefs.setString(
                                          AppConstants.userProfileKey, 
                                          jsonEncode(_userProfile)
                                        );
                                      }
                                    },
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMenuItem(
                          icon: Icons.home_outlined,
                          title: 'BNBs',
                          subtitle: 'Browse available places',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const BnBsBrowseScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMenuItem(
                          icon: Icons.shopping_bag_outlined,
                          title: 'Orders',
                          subtitle: 'View your bookings',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const OrdersScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 16),
                        _buildMenuItem(
                          icon: Icons.account_balance_wallet_outlined,
                          title: 'Wallet',
                          subtitle: 'Manage earnings & withdrawals',
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const WalletScreen(),
                              ),
                            );
                          },
                        ),
                        const SizedBox(height: 32),
                        _buildGradientButton(
                          text: 'Logout',
                          icon: Icons.logout_outlined,
                          onPressed: _logout,
                          gradient: LinearGradient(
                            colors: [
                              AppConstants.secondaryColor,
                              AppConstants.errorColor,
                            ],
                          ),
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppConstants.primaryColor.withOpacity(0.2),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                color: AppConstants.primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppConstants.softWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppConstants.mutedGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: AppConstants.mutedGray.withOpacity(0.5),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradientButton({
    required String text,
    IconData? icon,
    required VoidCallback onPressed,
    required Gradient gradient,
    double width = double.infinity,
    double height = 50,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: gradient.colors.first.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(25),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                const SizedBox(width: 8),
              ],
              Text(
                text,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
