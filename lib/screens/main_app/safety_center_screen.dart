import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/utils/nav.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Report a User', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        content: const Text(
          'To report someone, please contact support with their profile and a description of the issue. You can also block them from the Blocked Users section.',
          style: TextStyle(color: AppConstants.mutedGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Blocked Users', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        content: const Text(
          'Manage your blocked list. Blocked users cannot message you or see your profile.',
          style: TextStyle(color: AppConstants.mutedGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showShareLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Share Location', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        content: const Text(
          'Share your live location with a trusted contact before meeting. Use your phone\'s native sharing or messaging apps for real-time location sharing.',
          style: TextStyle(color: AppConstants.mutedGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContact(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppConstants.cardNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Emergency Contact', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        content: const Text(
          'Add a trusted emergency contact. In case of an emergency, you can quickly share your location with them.',
          style: TextStyle(color: AppConstants.mutedGray),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK', style: TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showSafetyTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (ctx, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppConstants.cardNavy,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 20),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const Text(
                  'Safety Tips',
                  style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 20),
                _tip('Always meet in well-lit, public places.'),
                _tip('Share your live location with a trusted contact.'),
                _tip('Trust your instincts—leave if something feels wrong.'),
                _tip('Keep personal details private until you\'re comfortable.'),
                _tip('Report suspicious behavior immediately.'),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text('Got it', style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_rounded, size: 20, color: AppConstants.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: Text(text, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 14, height: 1.4)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text(
          'Safety Center',
          style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Header card
          Container(
            padding: const EdgeInsets.all(20),
            margin: const EdgeInsets.only(bottom: 24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor.withOpacity(0.15), AppConstants.cardNavy],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppConstants.primaryColor.withOpacity(0.2)),
            ),
            child: const Row(
              children: [
                Icon(Icons.shield_rounded, color: AppConstants.primaryColor, size: 32),
                SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Your Safety Matters', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold, fontSize: 16)),
                      SizedBox(height: 4),
                      Text('CloseBy is committed to a safe community.', style: TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
                    ],
                  ),
                ),
              ],
            ),
          ),

          _item(context, Icons.report_rounded, 'Report a User', 'Let us know about unsafe behavior.', () => _showReportDialog(context)),
          _item(context, Icons.block_rounded, 'Blocked Users', 'Manage your blocked list.', () => _showBlockedUsers(context)),
          _item(context, Icons.emergency_rounded, 'Emergency Contact', 'Add a trusted contact for emergencies.', () => _showEmergencyContact(context)),
          _item(context, Icons.share_location_rounded, 'Share Location', 'Share your live location with a trusted contact.', () => _showShareLocation(context)),
          _item(context, Icons.policy_rounded, 'Safety Tips', 'Best practices for safe meetings.', () => _showSafetyTips(context)),

          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppConstants.primaryColor.withOpacity(0.15)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, color: AppConstants.primaryColor, size: 18),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'CloseBy is a platform. Always use caution and trust your instincts.',
                    style: TextStyle(color: AppConstants.mutedGray, fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String title, String subtitle, VoidCallback onTap) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppConstants.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AppConstants.primaryColor, size: 22),
        ),
        title: Text(title, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 15, fontFamily: 'Sora')),
        subtitle: Text(subtitle, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
        trailing: const Icon(Icons.chevron_right_rounded, color: AppConstants.mutedGray),
        onTap: onTap,
      ),
    );
  }
}
