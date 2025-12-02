import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/models/bnb_session.dart';

class ManageSessionsScreen extends StatefulWidget {
  final BnB bnb;

  const ManageSessionsScreen({super.key, required this.bnb});

  @override
  State<ManageSessionsScreen> createState() => _ManageSessionsScreenState();
}

class _ManageSessionsScreenState extends State<ManageSessionsScreen> {
  List<BnBSession> _sessions = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    // Load sessions from the BnB object
    _sessions = List.from(widget.bnb.sessions);
  }

  Future<void> _saveSessions() async {
    setState(() => _isLoading = true);
    
    try {
      await BnBService.updateBnB(
        bnbId: widget.bnb.bnbId,
        name: widget.bnb.name,
        location: widget.bnb.location,
        address: widget.bnb.address,
        priceKES: widget.bnb.priceKES,
        available: widget.bnb.available,
        bnbType: widget.bnb.bnbType,
        callNumber: widget.bnb.callNumber ?? '',
        sessions: _sessions,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Sessions updated successfully!'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        Navigator.pop(context, true); // Return true to indicate changes were made
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating sessions: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _showAddSessionDialog() async {
    int? selectedDuration;
    final priceController = TextEditingController();

    final sessionDurations = [
      {'duration': 1, 'label': '1 Hour'},
      {'duration': 2, 'label': '2 Hours'},
      {'duration': 6, 'label': '6 Hours'},
      {'duration': 12, 'label': 'Half Day (12 hrs)'},
      {'duration': 24, 'label': 'Full Day (24 hrs)'},
    ];

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppConstants.deepPurple,
          title: const Text('Add Session', style: TextStyle(color: AppConstants.softWhite)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  value: selectedDuration,
                  dropdownColor: AppConstants.deepPurple,
                  decoration: InputDecoration(
                    labelText: 'Session Duration',
                    labelStyle: const TextStyle(color: AppConstants.softWhite),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppConstants.primaryColor),
                    ),
                  ),
                  items: sessionDurations.map((sd) {
                    return DropdownMenuItem<int>(
                      value: sd['duration'] as int,
                      child: Text(sd['label'] as String, style: const TextStyle(color: AppConstants.softWhite)),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setDialogState(() {
                      selectedDuration = value;
                    });
                  },
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: priceController,
                  style: const TextStyle(color: AppConstants.softWhite),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Price (KES)',
                    labelStyle: const TextStyle(color: AppConstants.softWhite),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: AppConstants.primaryColor.withOpacity(0.5)),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(color: AppConstants.primaryColor),
                    ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: AppConstants.mutedGray)),
            ),
            TextButton(
              onPressed: () {
                if (selectedDuration == null || priceController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill all fields')),
                  );
                  return;
                }

                // Check if session duration already exists
                if (_sessions.any((s) => s.duration == selectedDuration)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Session duration already exists')),
                  );
                  return;
                }

                setState(() {
                  _sessions.add(BnBSession(
                    duration: selectedDuration!,
                    price: double.parse(priceController.text),
                    currency: 'KES',
                  ));
                });

                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Session added. Click Save to update.')),
                );
              },
              child: const Text('Add', style: TextStyle(color: AppConstants.primaryColor)),
            ),
          ],
        ),
      ),
    );
  }

  void _deleteSession(int index) {
    setState(() {
      _sessions.removeAt(index);
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Session removed. Click Save to update.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.midnightPurple,
              AppConstants.deepPurple,
              AppConstants.darkBackground,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: _sessions.isEmpty
                    ? _buildEmptyState()
                    : _buildSessionsList(),
              ),
              if (_sessions.isNotEmpty) _buildSaveButton(),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddSessionDialog,
        backgroundColor: AppConstants.primaryColor,
        icon: const Icon(Icons.add, color: AppConstants.softWhite),
        label: const Text('Add Session', style: TextStyle(color: AppConstants.softWhite)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.arrow_back, color: AppConstants.softWhite, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Manage Sessions',
                  style: TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.bnb.name,
                  style: const TextStyle(
                    color: AppConstants.mutedGray,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 80, color: AppConstants.mutedGray.withOpacity(0.5)),
          const SizedBox(height: 16),
          const Text(
            'No sessions yet',
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Add session types with different prices',
            style: TextStyle(color: AppConstants.mutedGray, fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _sessions.length,
      itemBuilder: (context, index) {
        final session = _sessions[index];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.deepPurple.withOpacity(0.8),
                AppConstants.surfaceColor.withOpacity(0.6),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.3),
              width: 1.5,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            leading: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.access_time,
                color: AppConstants.primaryColor,
              ),
            ),
            title: Text(
              session.displayName,
              style: const TextStyle(
                color: AppConstants.softWhite,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(
                  '${session.duration} hours',
                  style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  session.formattedPrice,
                  style: const TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            trailing: IconButton(
              onPressed: () => _deleteSession(index),
              icon: const Icon(Icons.delete, color: AppConstants.errorColor),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSaveButton() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppConstants.successColor, AppConstants.accentColor],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppConstants.successColor.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: _isLoading ? null : _saveSessions,
            borderRadius: BorderRadius.circular(16),
            child: Center(
              child: _isLoading
                  ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        color: AppConstants.softWhite,
                        strokeWidth: 2,
                      ),
                    )
                  : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.save, color: AppConstants.softWhite),
                        SizedBox(width: 8),
                        Text(
                          'Save Changes',
                          style: TextStyle(
                            color: AppConstants.softWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
