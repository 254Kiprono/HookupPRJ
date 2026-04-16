import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/utils/nav.dart';
import 'package:hook_app/models/bnb.dart';

class BnBDetailsScreen extends StatelessWidget {
  final BnB bnb;

  const BnBDetailsScreen({super.key, required this.bnb});

  Widget _buildSessionCard(dynamic session) {
    return Container(
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppConstants.primaryColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(session.sessionType, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text('${session.durationHours} hours', style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12)),
          const SizedBox(height: 8),
          Text(
            'KSh ${session.price.toStringAsFixed(0)}',
            style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, fontSize: 16),
          ),
        ],
      ),
    );
  }

  String _getBnBTypeName(int type) {
    switch (type) {
      case 0:
        return 'Studio';
      case 1:
        return '1 Bedroom';
      case 2:
        return '2 Bedrooms';
      case 3:
        return '3 Bedrooms';
      case 4:
        return '4 Bedrooms';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('BnB Details', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Placeholder Image hero
            Container(
              height: 240,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AppConstants.cardNavy,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 20, offset: const Offset(0, 10)),
                ],
              ),
              child: const Center(child: Icon(Icons.king_bed_rounded, color: AppConstants.primaryColor, size: 80)),
            ),
            const SizedBox(height: 32),
            
            // Title & Status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    bnb.name,
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Sora'),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: (bnb.available ? AppConstants.successColor : AppConstants.errorColor).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: bnb.available ? AppConstants.successColor : AppConstants.errorColor),
                  ),
                  child: Text(
                    bnb.availabilityStatus,
                    style: TextStyle(color: bnb.available ? AppConstants.successColor : AppConstants.errorColor, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            
            // Location Details
            Row(
              children: [
                const Icon(Icons.location_on_rounded, color: AppConstants.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(bnb.location, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 16)),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.map_rounded, color: AppConstants.primaryColor, size: 20),
                const SizedBox(width: 8),
                Text(bnb.address, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 14)),
              ],
            ),
            
            const SizedBox(height: 32),
            const Divider(color: Colors.white10),
            const SizedBox(height: 24),
            
            // Price & Setup
            Text('Property Details', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Base Monthly Rate', style: TextStyle(color: AppConstants.mutedGray)),
                    const SizedBox(height: 4),
                    Text(bnb.formattedPrice, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
                  ],
                ),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AppConstants.cardNavy, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    children: [
                      const Icon(Icons.category_rounded, color: AppConstants.primaryColor, size: 16),
                      const SizedBox(width: 8),
                      Text(_getBnBTypeName(bnb.bnbType), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 32),
            
            // Sessions
            if (bnb.sessions.isNotEmpty) ...[
              const Text('Available Booking Sessions', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: bnb.sessions.map((s) => _buildSessionCard(s)).toList(),
                ),
              ),
              const SizedBox(height: 32),
            ],

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              height: 56,
              child: ElevatedButton(
                onPressed: bnb.available ? () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Booking flow coming soon!')),
                  );
                } : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                ),
                child: const Text('Book Now', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
