import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hook_app/services/storage_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:ui';

class BnBOwnerLoginScreen extends StatefulWidget {
  const BnBOwnerLoginScreen({super.key});

  @override
  State<BnBOwnerLoginScreen> createState() => _BnBOwnerLoginScreenState();
}

class _BnBOwnerLoginScreenState extends State<BnBOwnerLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginBnBOwner() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse(AppConstants.login),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email_or_phone': _emailOrPhoneController.text.trim(),
          'password': _passwordController.text,
        }),
      ).timeout(const Duration(seconds: 10));

      setState(() => _isLoading = false);

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final String? authToken = responseData['token'];
        final String? refreshToken = responseData['refreshToken'];

        if (authToken == null || authToken.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Login successful, but token not received.')),
          );
          return;
        }

        // Decode JWT token to extract role
        Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
        int? roleId = decodedToken['role_id'] as int?;
        String? userId = decodedToken['user_id']?.toString() ?? 
                        decodedToken['userId']?.toString() ??
                        decodedToken['id']?.toString() ??
                        decodedToken['sub']?.toString();
        
        print('🏠 [BNB LOGIN] Decoded token: $decodedToken');
        print('🏠 [BNB LOGIN] Role from token: $roleId');
        print('🏠 [BNB LOGIN] Expected BnB Owner roleID: ${AppConstants.bnbOwnerRoleId}');
        print('🏠 [BNB LOGIN] Is BnB Owner: ${roleId == AppConstants.bnbOwnerRoleId}');
        
        // Validate that user is a BnB owner BEFORE saving credentials
        if (roleId != AppConstants.bnbOwnerRoleId) {
          print('❌ [BNB LOGIN] REJECTING - Not a BnB owner (roleID=$roleId)');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This login is for BnB owners only. Please use the regular login.'),
              backgroundColor: AppConstants.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        print('✅ [BNB LOGIN] ACCEPTING - User is a BnB owner');
        
        // Save credentials only after validation passes
        await StorageService.saveAuthToken(authToken);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await StorageService.saveRefreshToken(refreshToken);
        }
        if (roleId != null) {
          await StorageService.saveUserRole(roleId.toString());
        }
        if (userId != null && userId.isNotEmpty) {
          await StorageService.saveUserId(userId);
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Welcome back, BnB Owner!')),
        );
        Navigator.pushReplacementNamed(context, Routes.loading);
      } else {
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ?? 'Login failed. Invalid credentials.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } catch (error) {
      setState(() => _isLoading = false);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to the server.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Gradient
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppConstants.midnightPurple,
                  AppConstants.deepPurple,
                  AppConstants.darkBackground,
                ],
              ),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Header
                Padding(
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
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Row(
                            children: [
                              Icon(Icons.home_work, color: AppConstants.accentColor, size: 32),
                              SizedBox(width: 8),
                              Text(
                                'BnB Owner Login',
                                style: TextStyle(
                                  color: AppConstants.softWhite,
                                  fontSize: 24,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage your properties',
                            style: TextStyle(
                              color: AppConstants.mutedGray.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Form
                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(24),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: BackdropFilter(
                          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.white.withOpacity(0.2)),
                            ),
                            child: Form(
                              key: _formKey,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  TextFormField(
                                    controller: _emailOrPhoneController,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Email or Phone',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.person_outline, color: AppConstants.accentColor),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppConstants.accentColor),
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.2),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 20),
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: true,
                                    style: const TextStyle(color: Colors.white),
                                    decoration: InputDecoration(
                                      labelText: 'Password',
                                      labelStyle: const TextStyle(color: Colors.white70),
                                      prefixIcon: const Icon(Icons.lock_outline, color: AppConstants.accentColor),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: BorderSide(color: Colors.white.withOpacity(0.3)),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppConstants.accentColor),
                                      ),
                                      filled: true,
                                      fillColor: Colors.black.withOpacity(0.2),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Required';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 32),
                                  SizedBox(
                                    width: double.infinity,
                                    child: ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: AppConstants.accentColor,
                                        foregroundColor: Colors.black87,
                                        padding: const EdgeInsets.symmetric(vertical: 16),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        elevation: 8,
                                      ),
                                      onPressed: _isLoading ? null : _loginBnBOwner,
                                      child: _isLoading
                                          ? const SizedBox(
                                              height: 24,
                                              width: 24,
                                              child: CircularProgressIndicator(
                                                color: Colors.black87,
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Text(
                                              'LOGIN AS BNB OWNER',
                                              style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.2,
                                              ),
                                            ),
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.pushNamed(context, Routes.registerBnBOwner);
                                    },
                                    child: const Text(
                                      'Don\'t have a BnB account? Register',
                                      style: TextStyle(color: AppConstants.accentColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
