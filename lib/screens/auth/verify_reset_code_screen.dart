import 'package:flutter/material.dart';
import 'package:hook_app/widgets/auth/auth_header.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class VerifyResetCodeScreen extends StatefulWidget {
  final String contactInfo;

  const VerifyResetCodeScreen({super.key, required this.contactInfo});

  @override
  State<VerifyResetCodeScreen> createState() => _VerifyResetCodeScreenState();
}

class _VerifyResetCodeScreenState extends State<VerifyResetCodeScreen> {
  final TextEditingController _codeController = TextEditingController();
  bool _isLoading = false;
  late final bool _isEmail;

  @override
  void initState() {
    super.initState();
    _isEmail = widget.contactInfo.contains('@');
  }

  String _formatPhoneForBackend(String phone) {
    phone = phone.trim();
    if (phone.startsWith('0') && phone.length == 10) {
      return '254${phone.substring(1)}';
    }
    return phone;
  }

  Future<void> _verifyCode() async {
    if (_codeController.text.length != 6) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid 6-digit code')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final String formattedContact = _isEmail
          ? widget.contactInfo
          : _formatPhoneForBackend(widget.contactInfo);

      final response = await http.post(
        Uri.parse(AppConstants.verifyResetCode),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email_or_phone': formattedContact,
          'reset_code': _codeController.text.trim(),
        }),
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        Navigator.pushReplacementNamed(
          context,
          Routes.resetPassword,
          arguments: {
            'contactInfo': widget.contactInfo,
            'resetCode': _codeController.text.trim(),
          },
        );
      } else {
        String error = 'Invalid or expired code';
        try {
          final body = jsonDecode(response.body);
          error = body['message'] ?? body['error'] ?? error;
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
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
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: <Widget>[
          const AuthHeader(
            title: 'Verify Code',
            subtitle: 'Enter the verification code sent to you',
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _codeController,
                    decoration: InputDecoration(
                      labelText: 'Verification Code',
                      hintText: '123456',
                      prefixIcon: const Icon(Icons.vpn_key),
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
                    keyboardType: TextInputType.number,
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
                      onPressed: _isLoading ? null : _verifyCode,
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Verify Code',
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
          ),
        ],
      ),
    );
  }
}
