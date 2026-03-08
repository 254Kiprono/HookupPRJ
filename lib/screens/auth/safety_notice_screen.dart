import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

class SafetyNoticeScreen extends StatefulWidget {
  const SafetyNoticeScreen({super.key});

  @override
  State<SafetyNoticeScreen> createState() => _SafetyNoticeScreenState();
}

class _SafetyNoticeScreenState extends State<SafetyNoticeScreen> {
  bool _agreed = false;
  bool _ageConfirmed = false;

  Future<void> _accept() async {
    if (!_agreed || !_ageConfirmed) return;
    await StorageService.setSafetyAccepted(true);
    if (!mounted) return;
    // Go to loading - it will redirect to login (no token) or home (has token)
    Navigator.pushReplacementNamed(context, Routes.loading);
  }

  bool get _canProceed => _agreed && _ageConfirmed;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Notice'),
        backgroundColor: AppConstants.lightBackground,
        foregroundColor: AppConstants.secondaryColor,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'IMPORTANT SAFETY NOTICE',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AppConstants.secondaryColor,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 12),
              _bullet('Always meet in well-lit, public places.'),
              _bullet('CloseBy does not run criminal background checks.'),
              _bullet('Share your live location with a trusted contact.'),
              _bullet(
                  'Any illegal activity or underage use leads to a permanent ban.'),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Checkbox(
                          value: _agreed,
                          onChanged: (v) =>
                              setState(() => _agreed = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                              'I have read and agree to the safety notice.'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Checkbox(
                          value: _ageConfirmed,
                          onChanged: (v) => setState(
                              () => _ageConfirmed = v ?? false),
                        ),
                        const Expanded(
                          child: Text(
                            'I confirm I am 23 years or older.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _canProceed ? _accept : null,
                  child: const Text('I Agree'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bullet(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('•  '),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
