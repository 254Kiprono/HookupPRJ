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
      backgroundColor: AppConstants.darkBackground,
      body: SafeArea(
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
                    padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          height: 180,
                          width: 180,
                          decoration: BoxDecoration(
                            color: AppConstants.cardNavy,
                            shape: BoxShape.circle,
                            border: Border.all(color: AppConstants.primaryColor.withOpacity(0.1)),
                          ),
                          child: Icon(item.icon, size: 80, color: AppConstants.primaryColor),
                        ),
                        const SizedBox(height: 48),
                        Text(
                          item.title,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontFamily: 'Sora',
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          item.subtitle,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: AppConstants.mutedGray,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(
                      _items.length,
                      (i) => AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: _index == i ? 24 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _index == i ? AppConstants.primaryColor : AppConstants.mutedGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () async {
                        if (_index == _items.length - 1) {
                          await _finish();
                        } else {
                          _controller.nextPage(duration: const Duration(milliseconds: 400), curve: Curves.easeInOut);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppConstants.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        elevation: 0,
                      ),
                      child: Text(
                        _index == _items.length - 1 ? 'Get Started' : 'Continue',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_index != _items.length - 1)
                    TextButton(
                      onPressed: _finish,
                      child: const Text('Skip introduction', style: TextStyle(color: AppConstants.mutedGray)),
                    ),
                ],
              ),
            ),
          ],
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
