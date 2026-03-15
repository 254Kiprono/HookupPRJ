import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';

class ProviderDetailScreen extends StatelessWidget {
  final int? providerId;
  final String? name;
  final int? age;
  final double? distanceKm;
  final double? price;
  final String? imageUrl;
  final String? bio;
  final bool isOnline;

  const ProviderDetailScreen({
    super.key,
    this.providerId,
    this.name,
    this.age,
    this.distanceKm,
    this.price,
    this.imageUrl,
    this.bio,
    this.isOnline = false,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = name ?? 'Provider';
    final displayAge = age != null ? ', $age' : '';
    final displayDistance = distanceKm != null
        ? '${distanceKm!.toStringAsFixed(1)} km away'
        : 'Nearby';
    final displayPrice = price != null
        ? 'KSh ${price!.toStringAsFixed(0)}/hr'
        : 'Custom pricing';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: imageUrl != null && imageUrl!.isNotEmpty
                ? Image.network(imageUrl!, height: 240, fit: BoxFit.cover)
                : Container(
                    height: 240,
                    color: AppConstants.surfaceColor,
                    child: const Icon(Icons.person,
                        size: 80, color: AppConstants.mutedGray),
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Text(
                '$displayName$displayAge',
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppConstants.primaryColor),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_user,
                        size: 14, color: AppConstants.primaryColor),
                    const SizedBox(width: 4),
                    Text('Verified',
                        style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppConstants.primaryColor)),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (isOnline)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppConstants.successColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text('Active',
                      style: TextStyle(color: Colors.white, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Icon(Icons.location_on,
                  size: 16, color: AppConstants.primaryColor),
              const SizedBox(width: 4),
              Text(displayDistance,
                  style: TextStyle(color: AppConstants.mutedGray)),
            ],
          ),
          const SizedBox(height: 12),
          Text(
              bio ??
                  'Verified host on CloseBy. Book confidently with transparent pricing.',
              style: const TextStyle(height: 1.4)),
          const SizedBox(height: 16),
          _sectionTitle('Video'),
          const SizedBox(height: 8),
          Container(
            height: 180,
            decoration: BoxDecoration(
              color: AppConstants.surfaceColor,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.play_circle_fill,
                  size: 64, color: AppConstants.primaryColor),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Pricing'),
          const SizedBox(height: 8),
          Card(
            child: ListTile(
              title: const Text('Standard Rate'),
              subtitle: const Text('Flexible durations available'),
              trailing: Text(displayPrice,
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          const SizedBox(height: 16),
          _sectionTitle('Safety'),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
                'Meet in public places first. Use Share Location before meeting.'),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content:
                            Text('Chat unlocks after the booking is accepted.'),
                      ),
                    );
                  },
                  icon: const Icon(Icons.message),
                  label: const Text('Chat (Locked)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pushNamed(context, Routes.booking, arguments: {
                      'providerId': providerId ?? 0,
                      'providerName': displayName,
                      'price': price ?? 0,
                    });
                  },
                  child: const Text('Request Booking'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold));
  }
}
