// lib/screens/auth/profile_setup_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/widgets/auth/auth_header.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? authToken = prefs.getString(AppConstants.authTokenKey);

      if (authToken == null || authToken.isEmpty) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'No authentication token found. Please log in again.';
        });
        return;
      }

      final String url =
          AppConstants.getuserprofile; // Use pre-defined constant
      print('Fetching user profile from: $url');

      final response = await http.get(
        Uri.parse(url),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _userProfile = data;
          _isLoading = false;
        });
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _errorMessage =
              errorData['message'] ?? 'Failed to fetch user profile.';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to the server: $error';
      });
      print('Profile Fetch Error: $error');
    }
  }

  String _getReadableRole(String role) {
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
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(
              title: 'My Profile',
              subtitle: 'View and manage your account details',
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            children: [
                              Text(
                                _errorMessage!,
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 16),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _fetchUserProfile,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppConstants.accentColor,
                                  padding: const EdgeInsets.symmetric(
                                      vertical: 12, horizontal: 24),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                child: const Text(
                                  'Retry',
                                  style: TextStyle(
                                      fontSize: 16, color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        )
                      : _userProfile != null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Profile Info Card
                                Card(
                                  elevation: 4,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _userProfile!['fullName'] ?? 'N/A',
                                          style: const TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.person,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Role: ${_getReadableRole(_userProfile!['role'] ?? 'Unknown')}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.email,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Email: ${_userProfile!['email'] ?? 'N/A'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.phone,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Phone: ${_formatPhone(_userProfile!['phone'] ?? 'N/A')}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.cake,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Date of Birth: ${_userProfile!['dob'] ?? 'N/A'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.verified,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Email Verified: ${_userProfile!['emailVerified'] == true ? 'Yes' : 'No'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.verified_user,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Phone Verified: ${_userProfile!['phoneVerified'] == true ? 'Yes' : 'No'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.account_circle,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Account Status: ${_userProfile!['isActive'] == true ? 'Active' : 'Inactive'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Icon(Icons.calendar_today,
                                                color:
                                                    AppConstants.primaryColor),
                                            const SizedBox(width: 8),
                                            Text(
                                              'Created At: ${_userProfile!['createdAt']?.substring(0, 10) ?? 'N/A'}',
                                              style:
                                                  const TextStyle(fontSize: 16),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                // Edit Profile Button
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor:
                                          AppConstants.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                          vertical: 16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      // TODO: Implement edit profile navigation
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                            content: Text(
                                                'Edit Profile functionality coming soon!')),
                                      );
                                    },
                                    child: const Text(
                                      'Edit Profile',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : const Center(
                              child: Text('No profile data available.')),
            ),
          ],
        ),
      ),
    );
  }
}
