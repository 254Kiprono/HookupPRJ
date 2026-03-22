import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/utils/responsive.dart';
import 'dart:ui'; // For BackdropFilter

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginTag extends StatelessWidget {
  final String label;

  const _LoginTag({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Text(
        label,
        style: const TextStyle(
          color: AppConstants.softWhite,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailOrPhoneController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  int _failedLoginAttempts = 0;
  DateTime? _lastFailedAttempt;

  // Initialize GoogleSignIn
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['email', 'profile'],
  );

  @override
  void initState() {
    super.initState();
    _loadFailedLoginAttempts();
  }

  Future<void> _loadFailedLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _failedLoginAttempts = prefs.getInt('failedLoginAttempts') ?? 0;
      final lastFailedTimestamp = prefs.getInt('lastFailedAttempt');
      if (lastFailedTimestamp != null) {
        _lastFailedAttempt =
            DateTime.fromMillisecondsSinceEpoch(lastFailedTimestamp);
      }
    });

    // Check if block period (1 hour) has expired
    if (_failedLoginAttempts >= 10 && _lastFailedAttempt != null) {
      final timeSinceLastAttempt =
          DateTime.now().difference(_lastFailedAttempt!);
      if (timeSinceLastAttempt.inHours >= 1) {
        // Reset attempts after 1 hour
        await _resetFailedLoginAttempts();
      }
    }
  }

  Future<void> _incrementFailedLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _failedLoginAttempts++;
      _lastFailedAttempt = DateTime.now();
    });
    await prefs.setInt('failedLoginAttempts', _failedLoginAttempts);
    await prefs.setInt(
        'lastFailedAttempt', _lastFailedAttempt!.millisecondsSinceEpoch);
  }

  Future<void> _resetFailedLoginAttempts() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _failedLoginAttempts = 0;
      _lastFailedAttempt = null;
    });
    await prefs.setInt('failedLoginAttempts', 0);
    await prefs.remove('lastFailedAttempt');
  }

  Future<void> _loginUser(BuildContext context) async {
    if (_failedLoginAttempts >= 10) {
      final timeSinceLastAttempt =
          DateTime.now().difference(_lastFailedAttempt!);
      final remainingMinutes = 60 - timeSinceLastAttempt.inMinutes;
      if (remainingMinutes > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Too many failed attempts. Please try again in $remainingMinutes minute${remainingMinutes == 1 ? '' : 's'}.',
            ),
            backgroundColor: AppConstants.errorColor,
          ),
        );
        return;
      } else {
        await _resetFailedLoginAttempts();
      }
    }

    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final response = await http
          .post(
            Uri.parse(AppConstants.login),
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: jsonEncode({
              "email_or_phone": _emailOrPhoneController.text.trim(),
              "password": _passwordController.text,
            }),
          )
          .timeout(const Duration(seconds: 10));

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final String? authToken = responseData['token'];
        final String? refreshToken = responseData['refreshToken'];

        if (authToken == null || authToken.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Login successful, but token not received.')),
          );
          return;
        }

        // === DECODE JWT TOKEN TO EXTRACT ROLE ===
        Map<String, dynamic> decodedToken = JwtDecoder.decode(authToken);
        int? roleId = decodedToken['role_id'] as int?;
        String? userId = decodedToken['user_id']?.toString() ??
            decodedToken['userId']?.toString() ??
            decodedToken['id']?.toString() ??
            decodedToken['sub']?.toString();

        print('[LOGIN] Decoded token: $decodedToken');
        print('[LOGIN] Role from token: $roleId');
        print(
            '[LOGIN] Expected BnB Owner roleID: ${AppConstants.bnbOwnerRoleId}');

        // Block BnB owners from using regular login
        if (roleId == AppConstants.bnbOwnerRoleId) {
          print(
              '[LOGIN] Blocking BnB owner (roleID=$roleId) from regular login');
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content:
                  Text('BnB owners must use the BnB Owner Login button below.'),
              backgroundColor: AppConstants.errorColor,
              duration: Duration(seconds: 4),
            ),
          );
          return;
        }

        print('[LOGIN] Role check passed, user is not a BnB owner');

        // Now save credentials
        await StorageService.saveAuthToken(authToken);

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await StorageService.saveRefreshToken(refreshToken);
        }

        if (roleId != null) {
          await StorageService.saveUserRole(roleId.toString());
        }

        if (userId != null && userId.isNotEmpty) {
          print('[LOGIN] Saving userId: "$userId"');
          await StorageService.saveUserId(userId);
        }

        // Reset failed login attempts on successful login
        await _resetFailedLoginAttempts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        // Use loading screen for role-based navigation
        Navigator.pushReplacementNamed(context, Routes.loading);
      } else {
        await _incrementFailedLoginAttempts();
        if (!mounted) return;
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                errorData['message'] ?? 'Login failed. Invalid credentials.'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      await _incrementFailedLoginAttempts();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to the server.')),
      );
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
      if (googleUser == null) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;
      final String? idToken = googleAuth.idToken;

      if (idToken == null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Google sign-in failed: No ID token received.')),
        );
        return;
      }

      final response = await http
          .post(
            // Use dedicated Google sign-in endpoint
            Uri.parse(AppConstants.googleSignIn),
            headers: {
              'Content-Type': 'application/json',
              'Cache-Control': 'no-cache',
            },
            body: jsonEncode({"id_token": idToken}),
          )
          .timeout(const Duration(seconds: 10));

      setState(() {
        _isLoading = false;
      });

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);

        final String? authToken = responseData['token'];
        // gRPC gateway maps `refresh_token` -> `refreshToken`
        final String? refreshToken =
            responseData['refreshToken'] ?? responseData['refresh_token'];
        final String? roleString = responseData['role'];
        String? userId = responseData['userId'];

        if (authToken == null || authToken.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Google sign-in successful, but token not received.')),
          );
          return;
        }

        // Decode the JWT token to extract user_id and numeric role if not provided
        String? numericRoleId;
        if (userId == null || userId.isEmpty) {
          try {
            final decodedToken = JwtDecoder.decode(authToken);
            userId = decodedToken['user_id']?.toString() ??
                decodedToken['userId']?.toString() ??
                decodedToken['id']?.toString() ??
                decodedToken['sub']?.toString();
            final roleId = decodedToken['role_id'];
            if (roleId != null) {
              numericRoleId = roleId.toString();
            }
          } catch (e) {
            userId = null;
          }
        }

        // Persist session using StorageService for consistency
        await StorageService.saveAuthToken(authToken);
        if (refreshToken != null && refreshToken.isNotEmpty) {
          await StorageService.saveRefreshToken(refreshToken);
        }
        // Prefer numeric role ID from token; if missing, fall back to role string
        if (numericRoleId != null && numericRoleId.isNotEmpty) {
          await StorageService.saveUserRole(numericRoleId);
        } else if (roleString != null && roleString.isNotEmpty) {
          await StorageService.saveUserRole(roleString);
        }
        if (userId != null && userId.isNotEmpty) {
          await StorageService.saveUserId(userId);
        }

        // Reset failed login attempts on successful Google sign-in
        await _resetFailedLoginAttempts();

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in successful!')),
        );
        // Use loading screen for role-based navigation
        Navigator.pushReplacementNamed(context, Routes.loading);
      } else {
        String errorMessage = 'Google sign-in failed.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage)),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to the server.')),
      );
    }
  }

  @override

  Widget build(BuildContext context) {
    final isDesktop = Responsive.isDesktop(context);
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Stack(
        children: [
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppConstants.primaryColor.withOpacity(0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),
          SafeArea(
            child: isDesktop
                ? Row(
                    children: [
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 64),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: AppConstants.cardNavy,
                                  borderRadius: BorderRadius.circular(24),
                                  border: Border.all(
                                      color: Colors.white.withOpacity(0.05)),
                                ),
                                child: const Icon(Icons.favorite_rounded,
                                    size: 48,
                                    color: AppConstants.primaryColor),
                              ),
                              const SizedBox(height: 28),
                              const Text(
                                'CloseBy',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontFamily: 'Sora',
                                    fontSize: 40,
                                    fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              const Text(
                                'Trusted local services, discreet and professional.',
                                style: TextStyle(
                                    color: AppConstants.mutedGray, fontSize: 16),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: const [
                                  _LoginTag(label: 'Verified profiles'),
                                  _LoginTag(label: 'Secure payments'),
                                  _LoginTag(label: 'Live availability'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      Expanded(
                        child: Center(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(horizontal: 32),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 460),
                              child: _buildLoginForm(context),
                            ),
                          ),
                        ),
                      ),
                    ],
                  )
                : Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: _buildLoginForm(context),
                      ),
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginForm(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppConstants.cardNavy,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: const Icon(Icons.favorite_rounded,
              size: 48, color: AppConstants.primaryColor),
        ),
        const SizedBox(height: 32),
        const Text(
          'Welcome Back',
          style: TextStyle(
              color: Colors.white,
              fontFamily: 'Sora',
              fontSize: 32,
              fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Sign in to explore local services',
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
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _passwordController,
                label: 'Password',
                icon: Icons.lock_outline_rounded,
                isPassword: true,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pushNamed(context, Routes.forgotPassword),
                  child: const Text('Forgot Password?',
                      style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.w600)),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : () => _loginUser(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    elevation: 0,
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In',
                          style: TextStyle(
                              fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          children: [
            Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text('OR CONTINUE WITH',
                  style: TextStyle(
                      color: Colors.white.withOpacity(0.3),
                      fontSize: 12,
                      fontWeight: FontWeight.bold)),
            ),
            Expanded(child: Divider(color: Colors.white.withOpacity(0.05))),
          ],
        ),
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: _isLoading ? null : () => _handleGoogleSignIn(context),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              side: BorderSide(color: Colors.white.withOpacity(0.1)),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.g_mobiledata_rounded,
                    size: 28, color: Colors.white),
                const SizedBox(width: 8),
                const Text('Google',
                    style: TextStyle(
                        color: Colors.white, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("New here? ",
                style: TextStyle(color: AppConstants.mutedGray)),
            GestureDetector(
              onTap: () => Navigator.pushNamed(context, Routes.register),
              child: const Text('Create Account',
                  style: TextStyle(
                      color: AppConstants.primaryColor,
                      fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 24),
        TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, Routes.bnbOwnerLogin),
          icon: const Icon(Icons.home_work_rounded, size: 18),
          label: const Text('BnB Owner Access'),
          style: TextButton.styleFrom(foregroundColor: AppConstants.accentColor),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool isPassword = false,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: isPassword,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AppConstants.mutedGray),
        prefixIcon: Icon(icon, color: AppConstants.primaryColor, size: 20),
        filled: true,
        fillColor: AppConstants.cardNavy,
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withOpacity(0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: AppConstants.primaryColor),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
      ),
      validator: (v) => v == null || v.isEmpty ? 'Required' : null,
    );
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}

//Test the newbuild