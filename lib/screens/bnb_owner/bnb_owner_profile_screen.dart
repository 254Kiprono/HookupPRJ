import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:hook_app/screens/bnb_owner/edit_profile_screen.dart';

class BnBOwnerProfileScreen extends StatefulWidget {
  const BnBOwnerProfileScreen({super.key});

  @override
  State<BnBOwnerProfileScreen> createState() => _BnBOwnerProfileScreenState();
}

class _BnBOwnerProfileScreenState extends State<BnBOwnerProfileScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final profile = await UserService.getUserProfile();
      print('[PROFILE DEBUG] Loaded profile data: $profile'); // Debug log
      if (mounted) {
        setState(() {
          _userData = profile;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading profile: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load profile: $e')),
        );
      }
    }
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
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                    : SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 30),
                            _buildProfileDetails(),
                            const SizedBox(height: 30),
                            _buildActionButtons(),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(
              Icons.arrow_back,
              color: AppConstants.softWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          const Text(
            'My Profile',
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader() {
    // Robust name resolution logic
    String getDisplayName() {
      if (_userData == null) return 'BnB Owner';

      // Support both snake_case and camelCase keys from backend
      final String? fullName =
          (_userData!['full_name'] ?? _userData!['fullName']) as String?;
      final String? firstName =
          (_userData!['first_name'] ?? _userData!['firstName']) as String?;
      final String? lastName =
          (_userData!['last_name'] ?? _userData!['lastName']) as String?;
      
      // 1. Prioritize full_name
      if (fullName != null && fullName.trim().isNotEmpty) {
        return fullName;
      }

      // 2. Try combining first and last name
      if (firstName != null && firstName.trim().isNotEmpty) {
        if (lastName != null && lastName.trim().isNotEmpty) {
          return '$firstName $lastName';
        }
        return firstName; // First name only
      }

      return 'Name Not Set';
    }

    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppConstants.primaryColor, AppConstants.accentColor],
            ),
            boxShadow: [
              BoxShadow(
                color: AppConstants.primaryColor.withOpacity(0.4),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: (_userData?['profile_image'] ?? _userData?['profileImage']) != null &&
                  ((_userData?['profile_image'] ?? _userData?['profileImage']) as String).isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    // Support both snake_case and camelCase keys
                    (_userData!['profile_image'] ?? _userData!['profileImage']) as String,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => const Icon(
                      Icons.person,
                      size: 50,
                      color: AppConstants.softWhite,
                    ),
                  ),
                )
              : const Icon(
                  Icons.person,
                  size: 50,
                  color: AppConstants.softWhite,
                ),
        ),
        const SizedBox(height: 16),
        Text(
          getDisplayName(),
          style: const TextStyle(
            color: AppConstants.softWhite,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.2),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppConstants.primaryColor),
          ),
          child: const Text(
            'Verified Owner',
            style: TextStyle(
              color: AppConstants.primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileDetails() {
    // Format phone number to 07 format
    String formatPhone(String? phone) {
      if (phone == null || phone.isEmpty) return 'Not set';
      // Remove +254 or 254 prefix and replace with 0
      if (phone.startsWith('+254')) {
        return '0${phone.substring(4)}';
      } else if (phone.startsWith('254')) {
        return '0${phone.substring(3)}';
      }
      return phone;
    }

    // Format DOB to DD/MM/YYYY
    String formatDOB(String? dob) {
      if (dob == null || dob.isEmpty) return 'Not set';
      try {
        final date = DateTime.parse(dob);
        return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
      } catch (e) {
        return dob; // Return as-is if parsing fails
      }
    }

    // Check verification status safely
    bool isVerified(String keyPrefix) {
      if (_userData == null) return false;
      // Check various possible keys (snake_case and camelCase)
      return _userData!['${keyPrefix}_verified'] == true || 
             _userData!['is_${keyPrefix}_verified'] == true ||
             _userData!['verified_$keyPrefix'] == true ||
             _userData!['${keyPrefix}Verified'] == true ||
             _userData!['is${keyPrefix[0].toUpperCase()}${keyPrefix.substring(1)}Verified'] == true;
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.2),
        ),
      ),
      child: Column(
        children: [
          _buildDetailItem(
            Icons.person, 
            'Full Name', 
            (_userData?['full_name'] ??
                    _userData?['fullName'] ??
                    _userData?['first_name'] ??
                    _userData?['firstName'] ??
                    'Not set') as String,
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(
            Icons.email, 
            'Email', 
            _userData?['email'] ?? 'Not set',
            isVerified: isVerified('email'),
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(
            Icons.phone, 
            'Phone', 
            formatPhone(_userData?['phone']),
            isVerified: isVerified('phone') || isVerified('mobile'),
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(
            Icons.location_on, 
            'Location', 
            _userData?['location'] ?? 'Not set',
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(
            Icons.cake, 
            'Date of Birth', 
            formatDOB(_userData?['dob']),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value, {bool isVerified = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.mutedGray, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: AppConstants.mutedGray.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        value,
                        style: const TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isVerified) ...[
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.check_circle,
                        color: AppConstants.successColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      const Text(
                        'Verified',
                        style: TextStyle(
                          color: AppConstants.successColor,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildGradientButton(
          onPressed: () async {
            if (_userData != null) {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => EditProfileScreen(userData: _userData!),
                ),
              );
              if (result == true) {
                _loadProfile(); // Refresh profile if changes were saved
              }
            }
          },
          label: 'Edit Profile',
          icon: Icons.edit,
          gradient: const LinearGradient(
            colors: [AppConstants.primaryColor, AppConstants.accentColor],
          ),
        ),
        const SizedBox(height: 16),
        _buildGradientButton(
          onPressed: () async {
            await StorageService.clearAll();
            if (mounted) {
              Navigator.pushNamedAndRemoveUntil(
                context, 
                '/login', // Or whatever your login route is
                (route) => false,
              );
            }
          },
          label: 'Logout',
          icon: Icons.logout,
          gradient: LinearGradient(
            colors: [AppConstants.errorColor, AppConstants.errorColor.withOpacity(0.7)],
          ),
        ),
      ],
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String label,
    required IconData icon,
    required Gradient gradient,
  }) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: AppConstants.softWhite),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
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
