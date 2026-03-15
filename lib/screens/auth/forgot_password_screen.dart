import 'package:flutter/material.dart';
import 'package:hook_app/widgets/auth/auth_header.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hook_app/utils/nav.dart';

class ForgotPasswordScreen extends StatefulWidget {
  final String? contactInfo;

  const ForgotPasswordScreen({super.key, this.contactInfo});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _contactController = TextEditingController();
  bool _isEmail = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.contactInfo != null) {
      _contactController.text = widget.contactInfo!;
      _isEmail = widget.contactInfo!.contains('@');
    }
  }

  String _formatPhoneForBackend(String phone) {
    phone = phone.trim();
    if (phone.startsWith('0') && phone.length == 10) {
      return '254${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _sendResetRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final String formattedContact = _isEmail
          ? _contactController.text.trim()
          : _formatPhoneForBackend(_contactController.text);

      final response = await http.post(
        Uri.parse(AppConstants.forgotPassword),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email_or_phone': formattedContact}),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      String? message;
      try {
        final body = jsonDecode(response.body);
        message = body['message']?.toString();
      } catch (_) {}

      final bool isSuccessStatus =
          response.statusCode >= 200 && response.statusCode < 300;
      final bool isSuccessMessage = message != null &&
          message.toLowerCase().contains('password reset request sent');

      if (isSuccessStatus || isSuccessMessage) {
        Navigator.pushReplacementNamed(
          context,
          Routes.verifyResetCode,
          arguments: _contactController.text.trim(),
        );
      } else {
        String error = 'Failed to send reset code';
        if (message != null && message.isNotEmpty) {
          error = message;
        } else {
          try {
            final body = jsonDecode(response.body);
            error = body['message'] ?? body['error'] ?? error;
          } catch (_) {}
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${error.toString()} (HTTP ${response.statusCode})'),
          ),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: ${e.toString()}')),
      );
    }
  }

  @override
  void dispose() {
    _contactController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const AuthHeader(
            title: 'Reset Password',
            subtitle: 'Enter your phone number or email to reset',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  children: <Widget>[
                    const SizedBox(height: 32),
                    TextFormField(
                      controller: _contactController,
                      decoration: InputDecoration(
                        labelText: 'Phone Number or Email',
                        hintText: '0712345678 or james@example.com',
                        prefixIcon: const Icon(Icons.phone),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: const BorderSide(
                            color: AppConstants.primaryColor,
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
                        final phoneRegex = RegExp(r'^0\d{9}$');
                        if (!emailRegex.hasMatch(value) &&
                            !phoneRegex.hasMatch(value)) {
                          return 'Please enter a valid email or phone (e.g. 0712345678)';
                        }
                        return null;
                      },
                      onChanged: (value) =>
                          setState(() => _isEmail = value.contains('@')),
                    ),
                    const SizedBox(height: 32),
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
                        onPressed: _isLoading ? null : _sendResetRequest,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Send Reset Code',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Nav.safePop(context),
                      child: const Text(
                        'Back to Account',
                        style: TextStyle(
                          color: AppConstants.primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}