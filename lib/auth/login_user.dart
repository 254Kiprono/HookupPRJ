import 'package:flutter/material.dart';
import 'package:hook_app/widgets/auth/auth_header.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:jwt_decoder/jwt_decoder.dart';

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
      print('Login request to: ${AppConstants.login}');
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Login response: $responseData');

        final String? authToken = responseData['token'];
        final String? refreshToken = responseData['refreshToken'];
        final String? role = responseData['role'];
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
            print('Decoded token payload: $decodedToken');
            // Try various possible field names for user ID
            userId = decodedToken['user_id']?.toString() ??
                decodedToken['userId']?.toString() ??
                decodedToken['id']?.toString() ??
                decodedToken['sub']?.toString();
            print('Extracted userId from token: $userId');
            if (userId == null) {
              print('Error: No user ID field found in token payload');
            }
          } catch (e, stackTrace) {
            print('Error decoding token: $e');
            print('Stack trace: $stackTrace');
            userId = null;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.authTokenKey, authToken);
        print('Stored authToken: $authToken');

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
          print('Stored refreshToken: $refreshToken');
        }
        if (role != null && role.isNotEmpty) {
          await prefs.setString(AppConstants.userRoleKey, role);
          print('Stored role: $role');
        }
        if (userId != null && userId.isNotEmpty) {
          final success = await prefs.setString(AppConstants.userIdKey, userId);
          print('Stored userId: $userId, Success: $success');
          // Verify storage by reading back
          final storedUserId = prefs.getString(AppConstants.userIdKey);
          print('Read back userId: $storedUserId');
        } else {
          print('Warning: userId not found in login response or token');
        }

        // Reset failed login attempts on successful login
        await _resetFailedLoginAttempts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Login successful!')),
        );
        Navigator.pushReplacementNamed(context, Routes.home);
      } else {
        await _incrementFailedLoginAttempts();
        final errorData = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorData['message'] ??
                'Login failed. Invalid credentials, confirm and login again.'),
          ),
        );
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
      });
      await _incrementFailedLoginAttempts();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to connect to the server.')),
      );
      print('Login Error: $error');
    }
  }

  Future<void> _handleGoogleSignIn(BuildContext context) async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Google Sign-In request to: ${AppConstants.googleAuth}');
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

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        print('Google Sign-In response: $responseData');

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
            print('Decoded token payload (Google Sign-In): $decodedToken');
            userId = decodedToken['user_id']?.toString() ??
                decodedToken['userId']?.toString() ??
                decodedToken['id']?.toString() ??
                decodedToken['sub']?.toString();
            print('Extracted userId from token (Google Sign-In): $userId');
            if (userId == null) {
              print(
                  'Error: No user ID field found in token payload (Google Sign-In)');
            }
          } catch (e, stackTrace) {
            print('Error decoding token (Google Sign-In): $e');
            print('Stack trace (Google Sign-In): $stackTrace');
            userId = null;
          }
        }

        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(AppConstants.authTokenKey, authToken);
        print('Stored authToken (Google Sign-In): $authToken');

        if (refreshToken != null && refreshToken.isNotEmpty) {
          await prefs.setString(AppConstants.refreshTokenKey, refreshToken);
          print('Stored refreshToken (Google Sign-In): $refreshToken');
        }
        if (role != null && role.isNotEmpty) {
          await prefs.setString(AppConstants.userRoleKey, role);
          print('Stored role (Google Sign-In): $role');
        }
        if (userId != null && userId.isNotEmpty) {
          final success = await prefs.setString(AppConstants.userIdKey, userId);
          print('Stored userId (Google Sign-In): $userId, Success: $success');
          // Verify storage by reading back
          final storedUserId = prefs.getString(AppConstants.userIdKey);
          print('Read back userId (Google Sign-In): $storedUserId');
        } else {
          print(
              'Warning: userId not found in Google Sign-In response or token');
        }

        // Reset failed login attempts on successful Google sign-in
        await _resetFailedLoginAttempts();

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Google sign-in successful!')),
        );
        Navigator.pushReplacementNamed(context, Routes.home);
      } else {
        String errorMessage = 'Google sign-in failed.';
        try {
          final errorData = jsonDecode(response.body);
          errorMessage = errorData['message'] ?? errorMessage;
        } catch (_) {}
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
      print('Google Sign-In Error: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SingleChildScrollView(
        child: Column(
          children: [
            const AuthHeader(
              title: 'Welcome Back',
              subtitle: 'Login to continue your journey',
            ),
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _emailOrPhoneController,
                      decoration: InputDecoration(
                        labelText: 'Email or Phone Number',
                        hintText: 'john@example.com or 07XXXXXXXX',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppConstants.accentColor,
                            width: 2,
                          ),
                        ),
                      ),
                      keyboardType: TextInputType.text,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email or phone number';
                        }
                        final emailRegex =
                            RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
                        final phoneRegex = RegExp(r'^07\d{8}$');
                        if (!emailRegex.hasMatch(value) &&
                            !phoneRegex.hasMatch(value)) {
                          return 'Please enter a valid email or phone number (e.g., 07XXXXXXXX)';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      decoration: InputDecoration(
                        labelText: 'Password',
                        hintText: '••••••••',
                        prefixIcon: const Icon(Icons.lock),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: AppConstants.accentColor,
                            width: 2,
                          ),
                        ),
                      ),
                      obscureText: true,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: () {
                          Navigator.pushNamed(context, Routes.forgotPassword);
                        },
                        child: Text(
                          'Forgot Password?',
                          style: TextStyle(
                            color: AppConstants.accentColor,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed:
                            _isLoading ? null : () => _loginUser(context),
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Login',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      children: const [
                        Expanded(child: Divider()),
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: 8),
                          child: Text('or'),
                        ),
                        Expanded(child: Divider()),
                      ],
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(12)),
                        ),
                        side: BorderSide(color: Colors.grey.shade400),
                      ),
                      onPressed: _isLoading
                          ? null
                          : () => _handleGoogleSignIn(context),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.g_mobiledata, color: Colors.red),
                          SizedBox(width: 8),
                          Text('Continue with Google'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text("Don't have an account?"),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.register);
                          },
                          child: Text(
                            'Sign Up',
                            style: TextStyle(
                              color: AppConstants.accentColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
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
