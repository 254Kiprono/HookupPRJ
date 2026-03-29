// lib/screens/main_app/account_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'package:hook_app/screens/main_app/orders_screen.dart';
import 'package:hook_app/screens/main_app/wallet_screen.dart';
import 'package:hook_app/screens/main_app/safety_center_screen.dart';
import 'package:hook_app/screens/main_app/subscription_screen.dart';
import 'package:hook_app/screens/main_app/gallery_video_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_owner_dashboard_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_bookings_screen.dart';
import 'package:hook_app/utils/responsive.dart';

import 'package:hook_app/screens/main_app/profile_details_screen.dart';
import 'package:hook_app/widgets/web_image.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen>
    with TickerProviderStateMixin, AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;
  XFile? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isOnline = false;
  bool _isBnBOwner = false;
  bool _isUploading = false;
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
          final roleStr = (data['role'] ?? data['roleName'] ?? '').toString();
          _isBnBOwner = roleStr == 'ROLE_BNB_OWNER';
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
      if (data is Map<String, dynamic>) {
        final String fullName =
            (data['fullName'] ?? data['full_name'] ?? data['name'] ?? '')
                .toString()
                .trim();
        if (fullName.isNotEmpty && data['fullName'] == null) {
          data['fullName'] = fullName;
        }
      }

      print('✅ [ACCOUNT] Profile fetched successfully');

      // Cache the profile data
      await prefs.setString(AppConstants.userProfileKey, jsonEncode(data));

      if (mounted) {
        if (_isLoading) {
          setState(() {
            _isLoading = false;
          });
        }
        
        setState(() {
          _userProfile = data;
          _isOnline = (data['isActive'] ?? data['is_active']) == true;
          final roleStr = (data['role'] ?? data['roleName'] ?? '').toString();
          _isBnBOwner = roleStr == 'ROLE_BNB_OWNER';
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
          if (e.toString().contains('403') ||
              e.toString().contains('insufficient privileges')) {
            _errorMessage =
                'Permission denied (Role ID: $roleId). Profile features may be limited.';
          } else if (e.toString().contains('501') ||
              e.toString().contains('Method Not Allowed')) {
            _errorMessage = 'API method error. Please try again.';
          } else {
            _errorMessage =
                'Failed to load profile. Menu items are still available.';
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
    await UserService.logout();
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
          _profileImage = image;
        });
        // Upload picked image to server
        await _uploadProfileImage(image.path);
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to pick image: $e')),
      );
    }
  }

  Future<void> _uploadProfileImage(String path) async {
    setState(() {
      _isUploading = true;
    });

    try {
      print('📤 [ACCOUNT] Starting profile image upload: $path');
      final result = await UserService.uploadMedia(path, type: 'profile');
      final String? imageUrl = result['url'];

      if (imageUrl != null) {
        print('✅ [ACCOUNT] Upload success, updating profile with URL: $imageUrl');
        
        // Update user profile with the new image URL
        await UserService.updateUserProfile(profileImage: imageUrl);
        
        // Refresh local profile
        await _fetchUserProfile();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile photo updated successfully')),
          );
        }
      }
    } catch (e) {
      print('❌ [ACCOUNT] Upload failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to upload photo: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
        });
      }
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
    super.build(context);
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Profile', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: Colors.white),
            onPressed: () {},
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            const SizedBox(height: 20),
            _buildProfileHeader(),
            const SizedBox(height: 32),
            _buildOnlineToggle(),
            const SizedBox(height: 32),
            _buildMenuSection(),
            const SizedBox(height: 40),
            _buildLogoutButton(),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    final String fullName = _userProfile != null 
        ? (_userProfile!['fullName'] ?? _userProfile!['full_name'] ?? 'User').toString()
        : 'Loading...';
    
    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3), width: 3),
                boxShadow: [
                  BoxShadow(color: AppConstants.primaryColor.withOpacity(0.1), blurRadius: 20, spreadRadius: 5),
                ],
              ),
              child: ClipOval(
                child: _profileImage != null
                    ? Image.file(File(_profileImage!.path), fit: BoxFit.cover)
                    : _userProfile?['profileImage'] != null && _userProfile!['profileImage'].toString().isNotEmpty
                        ? platformAwareImage(_userProfile!['profileImage'], fit: BoxFit.cover)
                        : const Icon(Icons.person, size: 60, color: AppConstants.mutedGray),
              ),
            ),
              Positioned(
                bottom: 0,
                right: 0,
                child: GestureDetector(
                  onTap: _isUploading ? null : _pickProfileImage,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: const BoxDecoration(
                        color: AppConstants.primaryColor,
                        shape: BoxShape.circle),
                    child: _isUploading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 18),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 16),
        Text(fullName, style: const TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(color: AppConstants.primaryColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
          child: Text(
            _isBnBOwner ? 'BNB Provider' : 'Service Member',
            style: const TextStyle(color: AppConstants.primaryColor, fontSize: 12, fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  Widget _buildGalleryPreview() {
    if (_userProfile == null) return const SizedBox();

    final galleryRaw = _userProfile!['photo_gallery'] ?? _userProfile!['photoGallery'];
    List<String> _galleryUrls = [];
    if (galleryRaw != null) {
      if (galleryRaw is List) {
        _galleryUrls = List<String>.from(
          galleryRaw.where((e) => e != null && e.toString().trim().isNotEmpty),
        );
      } else if (galleryRaw is String && galleryRaw.isNotEmpty) {
        try {
          final decoded = jsonDecode(galleryRaw);
          if (decoded is List) {
            _galleryUrls = List<String>.from(
              decoded.where((e) => e != null && e.toString().trim().isNotEmpty),
            );
          }
        } catch (_) {}
      }
    }

    if (_galleryUrls.isEmpty) return const SizedBox();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'My Photos',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
            fontFamily: 'Sora',
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            itemCount: _galleryUrls.length,
            itemBuilder: (context, index) {
              return Container(
                margin: const EdgeInsets.only(right: 12),
                width: 100,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: AppConstants.cardNavy,
                  border: Border.all(color: Colors.white.withOpacity(0.05)),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: platformAwareImage(
                    _galleryUrls[index],
                    fit: BoxFit.cover,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildOnlineToggle() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: _isOnline ? AppConstants.successColor.withOpacity(0.1) : AppConstants.mutedGray.withOpacity(0.1), shape: BoxShape.circle),
            child: Icon(Icons.circle, color: _isOnline ? AppConstants.successColor : AppConstants.mutedGray, size: 12),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Online Status', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                Text(_isOnline ? 'You are visible to others' : 'You are currently hidden', style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12)),
              ],
            ),
          ),
          Switch.adaptive(
            value: _isOnline,
            onChanged: _updateOnlineStatus,
            activeColor: AppConstants.primaryColor,
          ),
        ],
      ),
    );
  }

  Widget _buildMenuSection() {
    return Column(
      children: [
        _buildMenuItem(
            icon: Icons.person_outline_rounded,
            title: 'Personal Details',
            onTap: () {
              if (_userProfile != null) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => ProfileDetailsScreen(
                      userProfile: _userProfile!,
                      isOnline: _isOnline,
                      isEditable: true,
                      onStatusChanged: (value) {
                        setState(() => _isOnline = value);
                      },
                    ),
                  ),
                );
              }
            }),
        const SizedBox(height: 12),
        _buildMenuItem(
          icon: Icons.photo_library_outlined,
          title: 'Gallery & Video',
          onTap: () async {
            if (_userProfile != null) {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => GalleryVideoScreen(userProfile: _userProfile!),
                ),
              );
              // Removed redundant _fetchUserProfile(); here to prevent flickering
            }
          },
        ),
        const SizedBox(height: 12),
        if (_isBnBOwner) ...[
          _buildMenuItem(icon: Icons.home_work_outlined, title: 'Manage BnBs', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BnBOwnerDashboardScreen()))),
          const SizedBox(height: 12),
          _buildMenuItem(icon: Icons.receipt_long_outlined, title: 'Booking Orders', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const BnBBookingsScreen()))),
          const SizedBox(height: 12),
        ],
        _buildMenuItem(icon: Icons.account_balance_wallet_outlined, title: 'Wallet & Payouts', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const WalletScreen()))),
        const SizedBox(height: 12),
        _buildMenuItem(icon: Icons.verified_user_outlined, title: 'Subscription', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubscriptionScreen()))),
        const SizedBox(height: 12),
        _buildMenuItem(icon: Icons.shield_outlined, title: 'Safety & Privacy', onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SafetyCenterScreen()))),
      ],
    );
  }

  Widget _buildMenuItem({required IconData icon, required String title, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppConstants.primaryColor, size: 22),
            const SizedBox(width: 16),
            Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15))),
            const Icon(Icons.chevron_right_rounded, color: AppConstants.mutedGray, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildLogoutButton() {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: _logout,
        icon: const Icon(Icons.logout_rounded, color: AppConstants.errorColor, size: 20),
        label: const Text('Sign Out', style: TextStyle(color: AppConstants.errorColor, fontWeight: FontWeight.bold, fontSize: 16)),
        style: TextButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: AppConstants.errorColor.withOpacity(0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}
