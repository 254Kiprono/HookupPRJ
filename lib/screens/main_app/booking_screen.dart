// lib/screens/main_app/booking_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hook_app/screens/main_app/messages_screen.dart';

class BookingScreen extends StatefulWidget {
  final int providerId;
  final String providerName;
  final double price;

  const BookingScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.price,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeBnB = false;
  String? _bnbId;
  double _bnbPrice = 0.0;
  String? _userFullName;
  String? _userPhone;
  int? _userId;

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

    final prefs = await SharedPreferences.getInstance();
    final String? authToken = prefs.getString(AppConstants.authTokenKey);

    if (authToken == null || authToken.isEmpty) {
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
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
        setState(() {
          _userFullName = data['fullName'] ?? 'User';
          _userPhone = data['phone'] ?? 'N/A';
          _userId = data['id'] as int?;
          _isLoading = false;
        });
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Failed to fetch user profile. Status: ${response.statusCode}';
        });
      }
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to connect to the server: $error';
      });
    }
  }

  Future<void> _createBooking() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final request = {
      'client_id': _userId.toString(),
      'provider_id': widget.providerId.toString(),
      'price': widget.price,
      'client_phone': _userPhone ?? '',
      'payer_name': _userFullName ?? 'User',
      'include_bnb': _includeBnB,
      'bnb_id': _includeBnB && _bnbId != null ? _bnbId : '',
      'bnb_price': _includeBnB && _bnbPrice != 0.0 ? _bnbPrice : 0,
    };

    try {
      final prefs = await SharedPreferences.getInstance();
      final authToken = prefs.getString(AppConstants.authTokenKey);
      final response = await http.post(
        Uri.parse(AppConstants.bookings),
        headers: {
          'Authorization': 'Bearer $authToken',
          'Content-Type': 'application/json',
        },
        body: jsonEncode(request),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        if (responseData['status'] == 'PAYMENT_PENDING') {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
                content: Text(
                    'Booking initiated for ${widget.providerName}. Awaiting payment...')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) =>
                  MessagesScreen(otherUserId: widget.providerId),
            ),
          );
        }
      } else {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Error initiating booking: ${response.statusCode} - ${response.body}';
        });
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error initiating booking: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Book ${widget.providerName}'),
        backgroundColor: AppConstants.primaryColor,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _fetchUserProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Booking Details',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 16),
                      Text('Provider: ${widget.providerName}'),
                      Text('Price: ${widget.price} KES/hr'),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Checkbox(
                            value: _includeBnB,
                            onChanged: (value) {
                              setState(() {
                                _includeBnB = value ?? false;
                                if (!_includeBnB) {
                                  _bnbId = null;
                                  _bnbPrice = 0.0;
                                }
                              });
                            },
                          ),
                          const Text('Include BnB in booking'),
                        ],
                      ),
                      if (_includeBnB) ...[
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'BnB ID (Temporary)',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (value) {
                            _bnbId = value;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          decoration: const InputDecoration(
                            labelText: 'BnB Price (Temporary)',
                            border: OutlineInputBorder(),
                          ),
                          keyboardType: TextInputType.number,
                          onChanged: (value) {
                            _bnbPrice = double.tryParse(value) ?? 0.0;
                          },
                        ),
                      ],
                      const SizedBox(height: 24),
                      Center(
                        child: ElevatedButton(
                          onPressed: _createBooking,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.primaryColor,
                            padding: const EdgeInsets.symmetric(
                                vertical: 12, horizontal: 24),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          child: const Text(
                            'Confirm Booking',
                            style: TextStyle(fontSize: 16, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
    );
  }
}
