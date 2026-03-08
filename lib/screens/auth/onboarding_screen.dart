import 'package:flutter/material.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/storage_service.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _index = 0;

  final List<_OnboardingItem> _items = const [
    _OnboardingItem(
      title: 'Discover Nearby Hosts',
      subtitle: 'Find trusted providers and BnBs close to you.',
      icon: Icons.location_on,
    ),
    _OnboardingItem(
      title: 'Book Instantly',
      subtitle: 'Request bookings in seconds with transparent pricing.',
      icon: Icons.flash_on,
    ),
    _OnboardingItem(
      title: 'Safe & Discreet',
      subtitle: 'Safety tools and privacy-first design built in.',
      icon: Icons.shield,
    ),
  ];

  Future<void> _finish() async {
    await StorageService.setOnboardingSeen(true);
    if (!mounted) return;
    // Flow: Onboarding -> Login
    Navigator.pushReplacementNamed(context, Routes.login);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        color: AppConstants.lightBackground,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _items.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (context, i) {
                    final item = _items[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 28, vertical: 24),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            height: 140,
                            width: 140,
                            decoration: BoxDecoration(
                              color:
                                  AppConstants.primaryColor.withOpacity(0.08),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(item.icon,
                                size: 72, color: AppConstants.primaryColor),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            item.title,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                                  color: AppConstants.secondaryColor,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            item.subtitle,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: AppConstants.mutedGray,
                                ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip'),
                    ),
                    Row(
                      children: List.generate(
                        _items.length,
                        (i) => Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: _index == i ? 22 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: _index == i
                                ? AppConstants.primaryColor
                                : AppConstants.mutedGray.withOpacity(0.4),
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    ElevatedButton(
                      onPressed: () async {
                        if (_index == _items.length - 1) {
                          await _finish();
                        } else {
                          _controller.nextPage(
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeOut);
                        }
                      },
                      child: Text(
                          _index == _items.length - 1 ? 'Get Started' : 'Next'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingItem {
  final String title;
  final String subtitle;
  final IconData icon;

  const _OnboardingItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
