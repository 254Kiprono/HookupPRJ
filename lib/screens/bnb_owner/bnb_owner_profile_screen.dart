import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';

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
          child: _userData?['profile_image'] != null && _userData!['profile_image'].isNotEmpty
              ? ClipOval(
                  child: Image.network(
                    _userData!['profile_image'],
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
          _userData?['full_name'] ?? _userData?['email'] ?? 'BnB Owner',
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
      // Remove +254 or 254 prefix and replace with 07
      if (phone.startsWith('+254')) {
        return '07${phone.substring(4)}';
      } else if (phone.startsWith('254')) {
        return '07${phone.substring(3)}';
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

    // Get verification status text
    String getVerificationStatus(bool? verified) {
      return verified == true ? 'Verified' : 'Not Verified';
    }

    // Get verification color
    Color getVerificationColor(bool? verified) {
      return verified == true ? AppConstants.successColor : AppConstants.errorColor;
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
          _buildDetailItem(Icons.person, 'Full Name', _userData?['full_name'] ?? 'Not set'),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(Icons.email, 'Email', _userData?['email'] ?? 'Not set'),
          const Divider(color: AppConstants.mutedGray),
          _buildVerificationItem(
            Icons.verified, 
            'Email Verification', 
            getVerificationStatus(_userData?['email_verified']),
            getVerificationColor(_userData?['email_verified']),
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(Icons.phone, 'Phone', formatPhone(_userData?['phone'])),
          const Divider(color: AppConstants.mutedGray),
          _buildVerificationItem(
            Icons.verified, 
            'Phone Verification', 
            getVerificationStatus(_userData?['phone_verified']),
            getVerificationColor(_userData?['phone_verified']),
          ),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(Icons.location_on, 'Location', _userData?['location'] ?? 'Not set'),
          const Divider(color: AppConstants.mutedGray),
          _buildDetailItem(Icons.cake, 'Date of Birth', formatDOB(_userData?['dob'])),
        ],
      ),
    );
  }

  Widget _buildDetailItem(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.mutedGray, size: 20),
          const SizedBox(width: 16),
          Column(
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
              Text(
                value,
                style: const TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildVerificationItem(IconData icon, String label, String value, Color valueColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.mutedGray, size: 20),
          const SizedBox(width: 16),
          Column(
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
              Text(
                value,
                style: TextStyle(
                  color: valueColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        _buildGradientButton(
          onPressed: () {
            // TODO: Implement edit profile
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Edit Profile coming soon!')),
            );
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
