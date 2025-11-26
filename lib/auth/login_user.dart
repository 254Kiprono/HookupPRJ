import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jwt_decoder/jwt_decoder.dart';
import 'package:hook_app/services/storage_service.dart';
import 'dart:ui'; // For BackdropFilter

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
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
        final dynamic roleData = responseData['role']; // Can be int or string
        String? userId = responseData['userId'];

        if (authToken == null || authToken.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Login successful, but token not received.')),
          );
          return;
        }

        // Decode the JWT token to extract user_id if not provided in response
        if (userId == null || userId.isEmpty) {
          try {
            final decodedToken = JwtDecoder.decode(authToken);
            userId = decodedToken['user_id']?.toString() ??
                decodedToken['userId']?.toString() ??
                decodedToken['id']?.toString() ??
                decodedToken['sub']?.toString();
          } catch (e, stackTrace) {
            userId = null;
          }
        }

        await StorageService.saveAuthToken(authToken);

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await StorageService.saveRefreshToken(refreshToken);
        }
        
        // Save role - convert to string if it's an int
        if (roleData != null) {
          String roleString = roleData.toString();
          print('🔑 [LOGIN] Saving role: "$roleString" (type: ${roleData.runtimeType})');
          await StorageService.saveUserRole(roleString);
        } else {
          print('⚠️ [LOGIN] No role received from backend');
        }
        
        if (userId != null && userId.isNotEmpty) {
          print('👤 [LOGIN] Saving userId: "$userId"');
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
            content: Text(errorData['message'] ??
                'Login failed. Invalid credentials.'),
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
            Uri.parse(AppConstants.googleAuth),
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
        final String? refreshToken = responseData['refreshToken'];
        final String? role = responseData['role'];
        String? userId = responseData['userId'];

        if (authToken == null || authToken.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content:
                    Text('Google sign-in successful, but token not received.')),
          );
          return;
        }

        // Decode the JWT token to extract user_id if not provided in response
        if (userId == null || userId.isEmpty) {
          try {
            final decodedToken = JwtDecoder.decode(authToken);
            userId = decodedToken['user_id']?.toString() ??
                decodedToken['userId']?.toString() ??
                decodedToken['id']?.toString() ??
                decodedToken['sub']?.toString();
          } catch (e, stackTrace) {
            userId = null;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.authTokenKey, authToken);

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
        }
        if (role != null && role.isNotEmpty) {
          await prefs.setString(AppConstants.userRoleKey, role);
        }
        if (userId != null && userId.isNotEmpty) {
          await prefs.setString(AppConstants.userIdKey, userId);
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
                  Color(0xFF2C0E18), // Darker Wine
                  AppConstants.primaryColor, // Deep Wine
                  Color(0xFF121212), // Dark Charcoal
                ],
              ),
            ),
          ),
          // Subtle Pattern or Overlay (Optional)
          Container(
            color: Colors.black.withOpacity(0.3),
          ),
          // Content
          Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Logo / Branding
                  const Icon(
                    Icons.favorite_rounded,
                    size: 64,
                    color: AppConstants.secondaryColor,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    AppConstants.appName.toUpperCase(),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 2.0,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Premium Social Discovery',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Colors.white70,
                          letterSpacing: 1.0,
                        ),
                  ),
                  const SizedBox(height: 48),

                  // Glassmorphism Form Container
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                      child: Container(
                        padding: const EdgeInsets.all(32),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              TextFormField(
                                controller: _emailOrPhoneController,
                                style: const TextStyle(color: Colors.white),
                                decoration: InputDecoration(
                                  labelText: 'Email or Phone',
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.person_outline,
                                      color: AppConstants.secondaryColor),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppConstants.secondaryColor),
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
                                  labelStyle:
                                      const TextStyle(color: Colors.white70),
                                  prefixIcon: const Icon(Icons.lock_outline,
                                      color: AppConstants.secondaryColor),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                        color: Colors.white.withOpacity(0.3)),
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: const BorderSide(
                                        color: AppConstants.secondaryColor),
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
                              const SizedBox(height: 12),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.pushNamed(
                                        context, Routes.forgotPassword);
                                  },
                                  child: const Text(
                                    'Forgot Password?',
                                    style: TextStyle(
                                      color: AppConstants.secondaryColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppConstants.secondaryColor,
                                    foregroundColor: Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                        vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    elevation: 8,
                                    shadowColor: AppConstants.secondaryColor
                                        .withOpacity(0.5),
                                  ),
                                  onPressed: _isLoading
                                      ? null
                                      : () => _loginUser(context),
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
                                          'LOGIN',
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            letterSpacing: 1.2,
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
                  const SizedBox(height: 32),
                  Row(
                    children: [
                      Expanded(
                          child: Divider(color: Colors.white.withOpacity(0.2))),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12),
                        ),
                      ),
                      Expanded(
                          child: Divider(color: Colors.white.withOpacity(0.2))),
                    ],
                  ),
                  const SizedBox(height: 32),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: BorderSide(color: Colors.white.withOpacity(0.3)),
                      padding: const EdgeInsets.symmetric(
                          vertical: 16, horizontal: 24),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed:
                        _isLoading ? null : () => _handleGoogleSignIn(context),
                    icon: const Icon(Icons.g_mobiledata, size: 28),
                    label: const Text('Continue with Google'),
                  ),
                  const SizedBox(height: 48),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an account? ",
                        style: TextStyle(color: Colors.white.withOpacity(0.7)),
                      ),
                      GestureDetector(
                        onTap: () {
                          Navigator.pushNamed(context, Routes.register);
                        },
                        child: const Text(
                          'Sign Up',
                          style: TextStyle(
                            color: AppConstants.secondaryColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // BnB Owner Registration Link
                  GestureDetector(
                    onTap: () {
                      Navigator.pushNamed(context, Routes.registerBnBOwner);
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                      decoration: BoxDecoration(
                        border: Border.all(color: AppConstants.accentColor.withOpacity(0.5), width: 1.5),
                        borderRadius: BorderRadius.circular(12),
                        gradient: LinearGradient(
                          colors: [
                            AppConstants.accentColor.withOpacity(0.1),
                            AppConstants.primaryColor.withOpacity(0.1),
                          ],
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.home_work, color: AppConstants.accentColor, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Have a BnB? Register as Owner',
                            style: TextStyle(
                              color: AppConstants.accentColor.withOpacity(0.9),
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _emailOrPhoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}
