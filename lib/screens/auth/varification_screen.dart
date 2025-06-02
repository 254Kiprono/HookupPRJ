// lib/screens/auth/verification_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerificationScreen extends StatefulWidget {
  final String verificationType; // 'email' or 'phone'
  final String? contact; // Email address or phone number
  final VoidCallback onVerified;

  const VerificationScreen({
    super.key,
    required this.verificationType,
    required this.contact,
    required this.onVerified,
  });

  @override
  State<VerificationScreen> createState() => _VerificationScreenState();
}

class _VerificationScreenState extends State<VerificationScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _verifyCode(String code) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

    if (authToken == null || authToken.isEmpty) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'No authentication token found.';
      });
      return;
    }

    try {
      final String url = widget.verificationType == 'email'
          ? AppConstants.verifyOTP // Use pre-defined constant
          : AppConstants
              .verifyOTP; // Note: Currently same endpoint; adjust if different
      final response = await http
          .post(
            Uri.parse(url),
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $authToken',
            },
            body: jsonEncode(widget.verificationType == 'email'
                ? {'code': code}
                : {'otp': code}),
          )
          .timeout(const Duration(seconds: 30));

      print('Verification response status code: ${response.statusCode}');
      print('Verification response body: ${response.body}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text(data['message'] ?? 'Verification successful!')),
        );
        widget.onVerified();
        Navigator.pop(context);
      } else {
        final errorData = jsonDecode(response.body);
        setState(() {
          _isLoading = false;
          _errorMessage = errorData['message'] ??
              'Verification failed. Status: ${response.statusCode}';
        });
      }
    } catch (error) {
      print('Error during verification: $error');
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error verifying code: $error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            'Verify ${widget.verificationType == 'email' ? 'Email' : 'Phone'}'),
        backgroundColor: AppConstants.primaryColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Enter the ${widget.verificationType == 'email' ? 'code' : 'OTP'} sent to your ${widget.verificationType == 'email' ? 'email' : 'phone'} (${widget.contact ?? 'N/A'}):',
              style: const TextStyle(fontSize: 16),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _codeController,
              decoration: const InputDecoration(
                labelText: 'Code/OTP',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                style: const TextStyle(color: Colors.red, fileSize: 14),
              ),
            ],
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
                onPressed: _isLoading
                    ? null
                    : () => _verifyCode(_codeController.text.trim()),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                        'Verify',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
