// lib/screens/main_app/account_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/services/storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

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
          _isOnline = data['isActive'] == true;
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
    }
  }

  Future<void> _fetchUserProfile() async {
    final String? authToken = await StorageService.getAuthToken();
    final prefs = await SharedPreferences.getInstance();

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.getuserprofile),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode({}),
          )
          .timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        await prefs.setString(AppConstants.userProfileKey, response.body);

        if (mounted) {
          setState(() {
            _userProfile = data;
            _isOnline = data['isActive'] == true;
            _isLoading = false;
            _errorMessage = null;
          });
          _fadeController.forward();
        }
      } else {
        final errorData = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = errorData['message'] ??
                'Failed to fetch user profile: ${response.statusCode}';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = _userProfile == null;
          _errorMessage = 'Failed to connect to the server: $error';
        });
      }
    }
  }

  Future<void> _updateOnlineStatus(bool isOnline) async {
    final String? authToken = await StorageService.getAuthToken();
    final prefs = await SharedPreferences.getInstance();

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      final response = await http.put(
        Uri.parse(
            '${AppConstants.userServiceBaseUrl}${AppConstants.apiVersion}/auth/update-online-status'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
        body: jsonEncode({'isActive': isOnline}),
      );

      if (response.statusCode == 200) {
        if (_userProfile != null) {
          _userProfile!['isActive'] = isOnline;
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
      } else {
        if (mounted) {
          setState(() {
            _errorMessage =
                'Failed to update online status: ${response.statusCode}';
          });
        }
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to connect to the server: $error';
        });
      }
    }
  }

  Future<void> _logout() async {
    final String? authToken = await StorageService.getAuthToken();

    try {
      await http.post(
        Uri.parse(
            '${AppConstants.userServiceBaseUrl}${AppConstants.apiVersion}/auth/logout'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      );
    } catch (e) {
      // Ignore errors during logout
    }

    await StorageService.clearAll();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.userProfileKey);

    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _profileImage = File(image.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Profile picture selected. Save to upload.',
            style: TextStyle(color: AppConstants.softWhite),
          ),
          backgroundColor: AppConstants.deepPurple,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
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
                  
                  // Name
                  if (_userProfile != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20.0),
                      child: Text(
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
                      ),
                    ),
                  
                  const SizedBox(height: 32),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: AppConstants.primaryColor,
                            ),
                          )
                        : _errorMessage != null
                            ? Center(
                                child: Column(
                                  children: [
                                    Text(
                                      _errorMessage!,
                                      style: const TextStyle(
                                        color: AppConstants.errorColor,
                                        fontSize: 16,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildGradientButton(
                                      text: 'Retry',
                                      onPressed: _fetchUserProfile,
                                      gradient: LinearGradient(
                                        colors: [
                                          AppConstants.primaryColor,
                                          AppConstants.secondaryColor,
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              )
                            : _userProfile != null
                                ? Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Info Card with Glassmorphism
                                      _buildGlassmorphicCard(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoRow(
                                              Icons.person_outline,
                                              'Account Type',
                                              _getReadableAccountType(
                                                  _userProfile!['role'] ?? 'Unknown'),
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.email_outlined,
                                              'Email',
                                              _userProfile!['email'] ?? 'N/A',
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.phone_outlined,
                                              'Phone',
                                              _formatPhone(_userProfile!['phone'] ?? 'N/A'),
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.cake_outlined,
                                              'Date of Birth',
                                              _userProfile!['dob'] ?? 'N/A',
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.location_on_outlined,
                                              'Location',
                                              _userProfile!['location'] ?? 'N/A',
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.verified_outlined,
                                              'Email Verified',
                                              _userProfile!['emailVerified'] == true
                                                  ? 'Yes'
                                                  : 'No',
                                              valueColor:
                                                  _userProfile!['emailVerified'] == true
                                                      ? AppConstants.successColor
                                                      : AppConstants.mutedGray,
                                            ),
                                            _buildDivider(),
                                            _buildInfoRow(
                                              Icons.verified_user_outlined,
                                              'Phone Verified',
                                              _userProfile!['phoneVerified'] == true
                                                  ? 'Yes'
                                                  : 'No',
                                              valueColor:
                                                  _userProfile!['phoneVerified'] == true
                                                      ? AppConstants.successColor
                                                      : AppConstants.mutedGray,
                                            ),
                                            _buildDivider(),
                                            // Online Status Toggle
                                            Padding(
                                              padding: const EdgeInsets.symmetric(
                                                  vertical: 12.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Container(
                                                        padding: const EdgeInsets.all(8),
                                                        decoration: BoxDecoration(
                                                          color: AppConstants.accentColor
                                                              .withOpacity(0.2),
                                                          borderRadius:
                                                              BorderRadius.circular(8),
                                                        ),
                                                        child: Icon(
                                                          Icons.wifi,
                                                          color: AppConstants.accentColor,
                                                          size: 20,
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      const Text(
                                                        'Online Status',
                                                        style: TextStyle(
                                                          fontSize: 16,
                                                          color: AppConstants.softWhite,
                                                          fontWeight: FontWeight.w500,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  Switch(
                                                    value: _isOnline,
                                                    onChanged: (value) {
                                                      _updateOnlineStatus(value);
                                                    },
                                                    activeColor: AppConstants.accentColor,
                                                    activeTrackColor: AppConstants
                                                        .accentColor
                                                        .withOpacity(0.5),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 24),
                                      
                                      // Edit Profile Button
                                      _buildGradientButton(
                                        text: 'Edit Profile',
                                        icon: Icons.edit_outlined,
                                        onPressed: () {
                                          Navigator.pushNamed(
                                            context,
                                            Routes.editProfile,
                                            arguments: {
                                              'initialData': _userProfile,
                                              'profileImage': _profileImage,
                                            },
                                          ).then((_) {
                                            _fetchUserProfile();
                                            setState(() {
                                              _profileImage = null;
                                            });
                                          });
                                        },
                                        gradient: LinearGradient(
                                          colors: [
                                            AppConstants.primaryColor,
                                            AppConstants.secondaryColor,
                                          ],
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 16),
                                      
                                      // Logout Button
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
                                    ],
                                  )
                                : const Center(
                                    child: Text(
                                      'No profile data available.',
                                      style: TextStyle(
                                        color: AppConstants.softWhite,
                                        fontSize: 16,
                                      ),
                                    ),
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

  Widget _buildGlassmorphicCard({required Widget child}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.7),
            AppConstants.surfaceColor.withOpacity(0.5),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(
          width: 1.5,
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.2),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: child,
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value,
      {Color? valueColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppConstants.primaryColor,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppConstants.mutedGray,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16,
                    color: valueColor ?? AppConstants.softWhite,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      color: AppConstants.mutedGray.withOpacity(0.2),
      thickness: 1,
      height: 1,
    );
  }

  Widget _buildGradientButton({
    required String text,
    required VoidCallback onPressed,
    required Gradient gradient,
    IconData? icon,
  }) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.zero,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
        ),
        onPressed: onPressed,
        child: Ink(
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withOpacity(0.4),
                blurRadius: 15,
                spreadRadius: 1,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            alignment: Alignment.center,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppConstants.softWhite, size: 22),
                  const SizedBox(width: 8),
                ],
                Text(
                  text,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: AppConstants.softWhite,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
