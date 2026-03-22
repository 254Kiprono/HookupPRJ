// lib/widgets/common/provider_card.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/widgets/web_image.dart';

class ProviderCard extends StatelessWidget {
  final String name;
  final String price;
  final double rating;
  final String distance;
  final String imageUrl;
  final bool isFavorite;

  const ProviderCard({
    super.key,
    required this.name,
    required this.price,
    required this.rating,
    required this.distance,
    required this.imageUrl,
    required this.isFavorite,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Stack(
            children: [
              ClipRRect(
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(16)),
                child: SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: platformAwareImage(imageUrl),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite
                        ? AppConstants.errorColor
                        : AppConstants.mutedGray,
                    size: 16,
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 12,
                      child: ClipOval(child: platformAwareImage('https://via.placeholder.com/50')),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      name,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.star,
                        color: AppConstants.accentColor, size: 14),
                    const Icon(Icons.star,
                        color: AppConstants.accentColor, size: 14),
                    const Icon(Icons.star,
                        color: AppConstants.accentColor, size: 14),
                    const Icon(Icons.star,
                        color: AppConstants.accentColor, size: 14),
                    rating >= 4.5
                        ? Icon(Icons.star,
                            color: Colors.amber.shade400, size: 14)
                        : const Icon(Icons.star_half,
                            color: AppConstants.accentColor, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      '(${rating.toStringAsFixed(0)})',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      distance,
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      price,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppConstants.primaryColor,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
