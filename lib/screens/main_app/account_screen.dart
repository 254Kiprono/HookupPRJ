// lib/screens/main_app/account_screen.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key});

  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  Map<String, dynamic>? _userProfile;
  bool _isLoading = true; // Only used when no cached data is available
  String? _errorMessage;
  File? _profileImage;
  final ImagePicker _picker = ImagePicker();
  bool _isOnline = false;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile(); // Load cached data first
    _fetchUserProfile(); // Trigger background refresh
  }

  // Load cached profile from SharedPreferences
  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? cachedProfile = prefs.getString(AppConstants.userProfileKey);

    if (cachedProfile != null && cachedProfile.isNotEmpty) {
      try {
        final data = jsonDecode(cachedProfile);
        setState(() {
          _userProfile = data;
          _isOnline = data['isActive'] == true;
          _isLoading = false; // No loading if cached data is available
        });
      } catch (e) {
        print('Error parsing cached profile: $e');
      }
    } else {
      setState(() {
        _isLoading = true; // Show loading if no cached data
      });
    }
  }

  // Fetch user profile from server and cache it
  Future<void> _fetchUserProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      print('Fetching profile from: ${AppConstants.getuserprofile}');
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
        print('Profile data received: $data');

        // Cache the new profile data
        await prefs.setString(AppConstants.userProfileKey, response.body);

        // Only update state if the widget is still mounted
        if (mounted) {
          setState(() {
            _userProfile = data;
            _isOnline = data['isActive'] == true;
            _isLoading = false;
            _errorMessage = null;
          });
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
        print('Fetch error response: ${response.body}');
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading =
              _userProfile == null; // Keep loading only if no cached data
          _errorMessage = 'Failed to connect to the server: $error';
        });
      }
      print('Profile Fetch Error: $error');
    }
  }

  // Update online status
  Future<void> _updateOnlineStatus(bool isOnline) async {
    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

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
        // Update cached profile
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
                    'Online status ${isOnline ? 'activated' : 'deactivated'}')),
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

  // Logout
  Future<void> _logout() async {
    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

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

    // Clear cached data
    await prefs.remove(AppConstants.authTokenKey);
    await prefs.remove(AppConstants.userProfileKey);

    if (mounted) {
      Navigator.pushReplacementNamed(context, Routes.login);
    }
  }

  // Pick profile image
  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image != null && mounted) {
      setState(() {
        _profileImage = File(image.path);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                'Profile picture selected. Save to upload to Cloudinary.')),
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
            colors: [Colors.blueAccent, Colors.purpleAccent],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              children: [
                Container(
                  height: 100,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: AppConstants.primaryColor.withOpacity(0.7),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(30),
                      bottomRight: Radius.circular(30),
                    ),
                  ),
                  child: const Center(
                    child: Text(
                      'Account',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  height: 150,
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      Positioned(
                        top: 0,
                        child: Column(
                          children: [
                            GestureDetector(
                              onTap: _pickProfileImage,
                              child: CircleAvatar(
                                radius: 60,
                                backgroundColor: Colors.white,
                                child: CircleAvatar(
                                  radius: 55,
                                  backgroundImage: _profileImage != null
                                      ? FileImage(_profileImage!)
                                          as ImageProvider
                                      : _userProfile?['profileImage'] != null &&
                                              _userProfile!['profileImage']
                                                  .toString()
                                                  .isNotEmpty
                                          ? NetworkImage(
                                                  _userProfile!['profileImage'])
                                              as ImageProvider
                                          : NetworkImage(
                                                  'https://via.placeholder.com/150')
                                              as ImageProvider,
                                  onBackgroundImageError:
                                      (exception, stackTrace) {
                                    print(
                                        'Failed to load profile image: $exception');
                                  },
                                  child: Align(
                                    alignment: Alignment.bottomRight,
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: AppConstants.accentColor,
                                      child: const Icon(
                                        Icons.camera_alt,
                                        size: 15,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (_userProfile != null)
                              Text(
                                _userProfile!['fullName'] ?? 'N/A',
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
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
                                    Card(
                                      elevation: 8,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            _buildInfoRow(
                                              Icons.person,
                                              'Acc Type: ${_getReadableAccountType(_userProfile!['role'] ?? 'Unknown')}',
                                            ),
                                            _buildInfoRow(
                                              Icons.email,
                                              'Email: ${_userProfile!['email'] ?? 'N/A'}',
                                            ),
                                            _buildInfoRow(
                                              Icons.phone,
                                              'Phone: ${_formatPhone(_userProfile!['phone'] ?? 'N/A')}',
                                            ),
                                            _buildInfoRow(
                                              Icons.cake,
                                              'Date of Birth: ${_userProfile!['dob'] ?? 'N/A'}',
                                            ),
                                            _buildInfoRow(
                                              Icons.location_on,
                                              'Location: ${_userProfile!['location'] ?? 'N/A'}',
                                            ),
                                            _buildInfoRow(
                                              Icons.verified,
                                              'Email Verified: ${_userProfile!['emailVerified'] == true ? 'Yes' : 'No'}',
                                            ),
                                            _buildInfoRow(
                                              Icons.verified_user,
                                              'Phone Verified: ${_userProfile!['phoneVerified'] == true ? 'Yes' : 'No'}',
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                      vertical: 8.0),
                                              child: Row(
                                                mainAxisAlignment:
                                                    MainAxisAlignment
                                                        .spaceBetween,
                                                children: [
                                                  Row(
                                                    children: [
                                                      Icon(Icons.wifi,
                                                          color: AppConstants
                                                              .primaryColor,
                                                          size: 24),
                                                      const SizedBox(width: 12),
                                                      const Text(
                                                        'Online Status',
                                                        style: TextStyle(
                                                            fontSize: 16,
                                                            color:
                                                                Colors.black87),
                                                      ),
                                                    ],
                                                  ),
                                                  Switch(
                                                    value: _isOnline,
                                                    onChanged: (value) {
                                                      _updateOnlineStatus(
                                                          value);
                                                    },
                                                    activeColor: AppConstants
                                                        .primaryColor,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor:
                                              AppConstants.primaryColor,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
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
                                    const SizedBox(height: 16),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.redAccent,
                                          padding: const EdgeInsets.symmetric(
                                              vertical: 16),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                        onPressed: _logout,
                                        child: const Text(
                                          'Logout',
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
                                  child: Text('No profile data available.'),
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        children: [
          Icon(icon, color: AppConstants.primaryColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}
