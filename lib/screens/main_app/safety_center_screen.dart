import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';

class SafetyCenterScreen extends StatelessWidget {
  const SafetyCenterScreen({super.key});

  void _showReportDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Report a User'),
        content: const Text(
          'To report someone, please contact support with their profile and a description of the issue. You can also block them from the Blocked Users section.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showBlockedUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Blocked Users'),
        content: const Text(
          'Manage your blocked list. Blocked users cannot message you or see your profile.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showShareLocation(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Share Location'),
        content: const Text(
          'Share your live location with a trusted contact before meeting. Use your phone\'s native sharing or messaging apps for real-time location sharing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showEmergencyContact(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Emergency Contact'),
        content: const Text(
          'Add a trusted emergency contact. In case of an emergency, you can quickly share your location with them.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSafetyTips(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 1,
        expand: false,
        builder: (ctx, scrollController) => SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Safety Tips',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppConstants.secondaryColor),
              ),
              const SizedBox(height: 16),
              _tip('Always meet in well-lit, public places.'),
              _tip('Share your live location with a trusted contact.'),
              _tip('Trust your instincts—leave if something feels wrong.'),
              _tip('Keep personal details private until you\'re comfortable.'),
              _tip('Report suspicious behavior immediately.'),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tip(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.check_circle, size: 20, color: AppConstants.primaryColor),
          const SizedBox(width: 12),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Safety Center'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _item(
            context,
            Icons.report,
            'Report a User',
            'Let us know about unsafe behavior.',
            () => _showReportDialog(context),
          ),
          _item(
            context,
            Icons.block,
            'Blocked Users',
            'Manage your blocked list.',
            () => _showBlockedUsers(context),
          ),
          _item(
            context,
            Icons.emergency,
            'Emergency Contact',
            'Add a trusted contact for emergencies.',
            () => _showEmergencyContact(context),
          ),
          _item(
            context,
            Icons.share_location,
            'Share Location',
            'Share your live location with a trusted contact.',
            () => _showShareLocation(context),
          ),
          _item(
            context,
            Icons.policy,
            'Safety Tips',
            'Best practices for safe meetings.',
            () => _showSafetyTips(context),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Text(
                'CloseBy is a platform. Always use caution and trust your instincts.'),
          ),
        ],
      ),
    );
  }

  Widget _item(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: Icon(icon, color: AppConstants.primaryColor),
        title: Text(title),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
