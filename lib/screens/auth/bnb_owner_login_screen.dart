import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hook_app/services/storage_service.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'dart:ui';
import 'package:hook_app/utils/responsive.dart';
import 'package:hook_app/utils/nav.dart';

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
        
        print('[BNB LOGIN] Decoded token: $decodedToken');
        print('[BNB LOGIN] Role from token: $roleId');
        print('[BNB LOGIN] Expected BnB Owner roleID: ${AppConstants.bnbOwnerRoleId}');
        print('[BNB LOGIN] Is BnB Owner: ${roleId == AppConstants.bnbOwnerRoleId}');
        
        // Validate that user is a BnB owner BEFORE saving credentials
        if (roleId != AppConstants.bnbOwnerRoleId) {
          print('[BNB LOGIN] REJECTING - Not a BnB owner (roleID=$roleId)');
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('This login is for BnB owners only. Please use the regular login.'),
              backgroundColor: AppConstants.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        print('[BNB LOGIN] ACCEPTING - User is a BnB owner');
        
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
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppConstants.cardNavy,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.05)),
                  ),
                  child: const Icon(Icons.home_work_rounded, size: 48, color: AppConstants.accentColor),
                ),
                const SizedBox(height: 32),
                const Text(
                  'BnB Provider',
                  style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 32, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Manage your property listings',
                  style: TextStyle(color: AppConstants.mutedGray, fontSize: 16),
                ),
                const SizedBox(height: 48),

                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _emailOrPhoneController,
                        label: 'Email or Phone',
                        icon: Icons.person_outline_rounded,
                        color: AppConstants.accentColor,
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: _passwordController,
                        label: 'Password',
                        icon: Icons.lock_outline_rounded,
                        isPassword: true,
                        color: AppConstants.accentColor,
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _loginBnBOwner,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 18),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            elevation: 0,
                          ),
                          child: _isLoading 
                            ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Text('Login to Dashboard', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 48),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account? ", style: TextStyle(color: AppConstants.mutedGray)),
                    GestureDetector(
                      onTap: () => Navigator.pushNamed(context, Routes.registerBnBOwner),
                      child: const Text('Register', style: TextStyle(color: AppConstants.accentColor, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
    required Color color,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppConstants.mutedGray),
        prefixIcon: Icon(icon, color: color, size: 20),
        filled: true,
        fillColor: AppConstants.cardNavy,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: color),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }
}