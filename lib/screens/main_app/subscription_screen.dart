import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/screens/auth/verification_screen.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:hook_app/services/payment_service.dart';
import 'package:hook_app/utils/nav.dart';

class SubscriptionScreen extends StatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _isLoading = true;
  bool _isRefreshing = false;
  bool _emailVerified = false;
  bool _phoneVerified = false;
  bool _hasActiveSubscription = false;
  String? _email;
  String? _phone;
  String? _errorMessage;
  String? _selectedPlan;
  String _paymentMethod = 'mpesa';
  String? _activePlan;
  String? _subscriptionStatus;

  @override
  void initState() {
    super.initState();
    _loadCachedProfile();
    _loadVerificationStatus();
    _loadSubscriptionStatus();
  }

  Future<void> _loadCachedProfile() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getString(AppConstants.userProfileKey);
    if (cached == null || cached.isEmpty) {
      setState(() {
        _isLoading = false;
      });
      return;
    }
    try {
      final data = jsonDecode(cached) as Map<String, dynamic>;
      setState(() {
        _email = (data['email'] ?? '').toString();
        _phone = (data['phone'] ?? '').toString();
        _emailVerified = _asBool(
          data['emailVerified'] ??
              data['email_verified'] ??
              data['is_email_verified'],
        );
        _phoneVerified = _asBool(
          data['phoneVerified'] ??
              data['phone_verified'] ??
              data['is_phone_verified'],
        );
        _isLoading = false;
      });
    } catch (_) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _loadVerificationStatus() async {
    try {
      setState(() {
        _isRefreshing = true;
      });
      final response = await UserService.getUserProfile();
      final data = response['user'] ?? response;
      if (data is Map<String, dynamic>) {
        setState(() {
          _email = (data['email'] ?? '').toString();
          _phone = (data['phone'] ?? '').toString();
          _emailVerified = _asBool(
            data['emailVerified'] ??
                data['email_verified'] ??
                data['is_email_verified'],
          );
          _phoneVerified = _asBool(
            data['phoneVerified'] ??
                data['phone_verified'] ??
                data['is_phone_verified'],
          );
          _isLoading = false;
          _isRefreshing = false;
        });
      } else {
        setState(() {
          _errorMessage = 'Invalid profile data';
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load profile: $e';
        _isLoading = false;
        _isRefreshing = false;
      });
    }
  }

  Future<void> _loadSubscriptionStatus() async {
    try {
      final userIdStr = await StorageService.getUserId();
      final token = await StorageService.getAuthToken();
      if (userIdStr == null || token == null) return;

      final uri = Uri.parse(
        '${AppConstants.walletServiceBaseUrl}${AppConstants.apiVersion}/wallet/$userIdStr/subscription',
      );

      final response = await http.get(
        uri,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(const Duration(seconds: 20));

      Map<String, dynamic>? data;
      if (response.body.isNotEmpty) {
        final decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          data = decoded;
        }
      }

      final status = data?['status']?.toString().toUpperCase();
      final plan = data?['plan_name']?.toString();
      final isActive = status == 'ACTIVE';

      setState(() {
        _subscriptionStatus = status;
        _activePlan = plan;
        _hasActiveSubscription = isActive;
      });
    } catch (_) {
      // Silent fail: subscription status is optional UI hint
    }
  }

  Future<void> _pollSubscriptionStatus() async {
    const attempts = 6;
    for (var i = 0; i < attempts; i++) {
      await Future.delayed(const Duration(seconds: 5));
      await _loadSubscriptionStatus();
      if (_hasActiveSubscription) return;
    }
  }

  Future<void> _sendVerificationCode(String type) async {
    final token = await StorageService.getAuthToken();
    if (token == null || token.isEmpty) {
      setState(() => _errorMessage = 'No auth token found');
      return;
    }

    final userId = await StorageService.getUserId();
    final uri = type == 'email'
        ? Uri.parse(AppConstants.sendEmailVerification)
        : Uri.parse(AppConstants.sendPhoneVerification);

    try {
      final response = await http
          .post(
            uri,
            headers: {
              'Content-Type': 'application/json',
              'Authorization': 'Bearer $token',
            },
            body: jsonEncode({'user_id': userId}),
          )
          .timeout(const Duration(seconds: 20));

      if (!mounted) return;

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              type == 'email'
                  ? 'Verification email sent'
                  : 'Verification SMS sent',
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to send code'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to send code: $e')),
        );
      }
    }
  }

  bool get _canSubscribe => _emailVerified && _phoneVerified;

  bool _asBool(dynamic v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final s = v.toLowerCase();
      return s == 'true' || s == '1' || s == 'yes';
    }
    return false;
  }

  Future<void> _startVerificationFlow(String type) async {
    if (type == 'email' && _emailVerified) return;
    if (type == 'phone' && _phoneVerified) return;

    await _sendVerificationCode(type);
    if (!mounted) return;
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => VerificationScreen(
          verificationType: type,
          contact: type == 'email' ? _email : _phone,
          onVerified: _loadVerificationStatus,
        ),
      ),
    );

    if (result != null) {
      await _loadVerificationStatus();
      if (!mounted) return;
      if (type == 'email' && _emailVerified && !_phoneVerified) {
        await _startVerificationFlow('phone');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Subscription',
          style: TextStyle(
            color: Colors.white,
            fontFamily: 'Sora',
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
        : ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        children: [
          _buildSubscriptionHeader(),
          const SizedBox(height: 32),
          
          if (_errorMessage != null)
            _buildErrorTip(),
          
          if (_hasActiveSubscription)
            _buildActiveBanner(),

          _verificationItem(
            title: 'Email Address',
            subtitle: _email ?? 'Loading...',
            verified: _emailVerified,
            icon: Icons.alternate_email,
            onVerify: () => _startVerificationFlow('email'),
          ),
          const SizedBox(height: 12),
          _verificationItem(
            title: 'Phone Number',
            subtitle: _phone ?? 'Loading...',
            verified: _phoneVerified,
            icon: Icons.phone_iphone,
            onVerify: () => _startVerificationFlow('phone'),
          ),
          
          const SizedBox(height: 32),
          const Text(
            'SELECT A PLAN',
            style: TextStyle(
              color: AppConstants.mutedGray,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              fontFamily: 'Sora',
            ),
          ),
          const SizedBox(height: 16),
          _planCard('Weekly', 'KSh ${AppConstants.subWeeklyPrice}', 'Try for 7 days', Icons.calendar_view_week),
          _planCard('2 Weeks', 'KSh ${AppConstants.subTwoWeeksPrice}', 'Popular choice', Icons.calendar_month),
          _planCard('Monthly', 'KSh ${AppConstants.subMonthlyPrice}', 'Best value for pros', Icons.stars),
          _planCard('Test Plan', 'KSh 1', 'Quick verification (Dev)', Icons.bug_report),
          
          const SizedBox(height: 32),
          const Text(
            'PAYMENT METHOD',
            style: TextStyle(
              color: AppConstants.mutedGray,
              fontSize: 12,
              letterSpacing: 1.2,
              fontWeight: FontWeight.bold,
              fontFamily: 'Sora',
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _paymentMethodCard('mpesa', 'M-Pesa', Icons.account_balance_wallet)),
              const SizedBox(width: 16),
              Expanded(child: _paymentMethodCard('card', 'Card', Icons.credit_card)),
            ],
          ),
          
          const SizedBox(height: 48),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: _canSubscribe && !_isRefreshing && _selectedPlan != null && _paymentMethod == 'mpesa'
                  ? (_hasActiveSubscription ? null : _handleSubscription)
                  : null,
              child: _isRefreshing 
                ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _hasActiveSubscription
                      ? 'SUBSCRIPTION ACTIVE'
                      : !_canSubscribe 
                      ? 'COMPLETE VERIFICATION' 
                      : _selectedPlan == null 
                        ? 'SELECT A PLAN' 
                        : 'SUBSCRIBE NOW',
                    style: const TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold),
                  ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSubscriptionHeader() {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.workspace_premium_rounded, color: AppConstants.primaryColor, size: 40),
        ),
        const SizedBox(height: 16),
        const Text(
          'Unlock Full Access',
          style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 22, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        const Text(
          'Connect with more clients near you',
          style: TextStyle(color: AppConstants.mutedGray, fontSize: 14),
        ),
      ],
    );
  }

  Widget _buildErrorTip() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppConstants.errorColor.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppConstants.errorColor.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: AppConstants.errorColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: AppConstants.errorColor, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveBanner() {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.successColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.successColor.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: AppConstants.successColor, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Current Plan: ${_activePlan ?? 'Active'}',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Text(
                  'You have full access to all features.',
                  style: TextStyle(color: AppConstants.mutedGray, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscription() async {
    setState(() => _isRefreshing = true);
    try {
      final userIdStr = await StorageService.getUserId();
      final userId = int.tryParse(userIdStr ?? '') ?? 0;
      if (userId == 0) throw Exception('User ID not found');

      double amount = 0;
      if (_selectedPlan == 'Test Plan') amount = 1;
      if (_selectedPlan == 'Weekly') amount = AppConstants.subWeeklyPrice.toDouble();
      if (_selectedPlan == '2 Weeks') amount = AppConstants.subTwoWeeksPrice.toDouble();
      if (_selectedPlan == 'Monthly') amount = AppConstants.subMonthlyPrice.toDouble();
      
      String cleanPhone = _phone ?? '';
      cleanPhone = cleanPhone.replaceAll(RegExp(r'\D'), '');
      if (cleanPhone.startsWith('0')) {
        cleanPhone = '254${cleanPhone.substring(1)}';
      } else if (cleanPhone.length == 9) {
        cleanPhone = '254$cleanPhone';
      } else if (cleanPhone.startsWith('7') || cleanPhone.startsWith('1')) {
        cleanPhone = '254$cleanPhone';
      }

      final String selectedPlanName = _selectedPlan?.toUpperCase().replaceAll(' ', '_') ?? 'UNKNOWN';
      final String requestId = 'SUB_${selectedPlanName}_${DateTime.now().millisecondsSinceEpoch}';

      await PaymentService.initiateMpesaPayment(
        msisdn: cleanPhone,
        amount: amount,
        requestId: requestId,
        category: 'SUBSCRIPTION',
        clientId: userId,
      );

      setState(() => _isRefreshing = false);

      _showSuccessDialog(
        'STK Push Sent',
        'A payment request has been sent to your phone ($cleanPhone). Please enter your M-Pesa PIN to complete.',
      );

      _pollSubscriptionStatus();
    } catch (e) {
      if (mounted) {
        setState(() => _isRefreshing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Payment Error: $e'), 
            backgroundColor: AppConstants.errorColor,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _verificationItem({
    required String title, 
    required String subtitle, 
    required bool verified, 
    required IconData icon,
    required VoidCallback onVerify,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: verified ? AppConstants.successColor : AppConstants.mutedGray, size: 20),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15)),
                Text(subtitle, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
              ],
            ),
          ),
          if (verified)
            const Icon(Icons.verified_rounded, color: AppConstants.successColor, size: 24)
          else
            TextButton(
              onPressed: onVerify,
              style: TextButton.styleFrom(
                foregroundColor: AppConstants.primaryColor,
                textStyle: const TextStyle(fontWeight: FontWeight.bold),
              ),
              child: const Text('Verify'),
            ),
        ],
      ),
    );
  }

  Widget _planCard(String title, String price, String desc, IconData icon) {
    final isSelected = _selectedPlan == title;
    return GestureDetector(
      onTap: () => setState(() => _selectedPlan = title),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? AppConstants.primaryColor.withOpacity(0.05) : AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppConstants.primaryColor : Colors.white.withOpacity(0.05),
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: isSelected ? AppConstants.primaryColor : AppConstants.mutedGray, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Sora')),
                  Text(desc, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
                ],
              ),
            ),
            Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
          ],
        ),
      ),
    );
  }

  Widget _paymentMethodCard(String value, String label, IconData icon) {
    final isSelected = _paymentMethod == value;
    final bool isComingSoon = value == 'card';
    
    return Opacity(
      opacity: isComingSoon ? 0.4 : 1.0,
      child: GestureDetector(
        onTap: isComingSoon ? null : () => setState(() => _paymentMethod = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 20),
          decoration: BoxDecoration(
            color: isSelected ? AppConstants.primaryColor.withOpacity(0.05) : AppConstants.cardNavy,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? AppConstants.primaryColor : Colors.white.withOpacity(0.05),
              width: 1.5,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, color: isSelected ? AppConstants.primaryColor : AppConstants.mutedGray, size: 28),
              const SizedBox(height: 8),
              Text(
                isComingSoon ? '$label\nSoon' : label, 
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppConstants.mutedGray, 
                  fontSize: 12, 
                  fontFamily: 'Sora',
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                )
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppConstants.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(title, style: const TextStyle(color: Colors.white, fontFamily: 'Sora')),
        content: Text(message, style: const TextStyle(color: AppConstants.mutedGray)),
        actions: [
          TextButton(
            onPressed: () => Nav.safePop(context), 
            child: const Text('OK', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
