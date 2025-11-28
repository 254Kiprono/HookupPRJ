import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/app/routes.dart';

class BnBOwnerDashboardScreen extends StatefulWidget {
  const BnBOwnerDashboardScreen({super.key});

  @override
  State<BnBOwnerDashboardScreen> createState() => _BnBOwnerDashboardScreenState();
}

class _BnBOwnerDashboardScreenState extends State<BnBOwnerDashboardScreen> {
  List<BnB> _bnbs = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBnBs();
  }

  Future<void> _loadBnBs() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = await StorageService.getUserId();
      print('📋 [BNB DASHBOARD] Retrieved userId from storage: "$userId"');
      
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found in storage');
      }

      // Try to parse userId
      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        throw Exception('Invalid user ID format: "$userId" is not a valid number');
      }

      print('📋 [BNB DASHBOARD] Fetching BnBs for owner ID: $userIdInt');
      final bnbs = await BnBService.getBnBsByOwner(userIdInt);
      
      print('📋 [BNB DASHBOARD] Successfully loaded ${bnbs.length} BnBs');
      setState(() {
        _bnbs = bnbs;
        _isLoading = false;
      });
    } catch (e) {
      print('📋 [BNB DASHBOARD] Error loading BnBs: $e');
      
      // If it's a fetch error or 404, treat as empty list (no BnBs available)
      // Don't show error message to user
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('404') ||
          e.toString().contains('ClientException')) {
        setState(() {
          _bnbs = []; // Empty list
          _isLoading = false;
          _error = null; // No error - just empty
        });
      } else {
        // Real errors (auth, network, etc) - show error
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
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
              _buildStatsCard(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorWidget()
                        : _buildBnBList(),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'bookingHistory',
            onPressed: () {
              Navigator.pushNamed(context, Routes.bnbBookingHistory);
            },
            backgroundColor: AppConstants.accentColor,
            child: const Icon(Icons.receipt_long, color: AppConstants.softWhite),
          ),
          const SizedBox(height: 16),
          FloatingActionButton.extended(
            heroTag: 'addBnB',
            onPressed: () async {
              await Navigator.pushNamed(context, Routes.registerBnB);
              _loadBnBs(); // Refresh after returning
            },
            backgroundColor: AppConstants.primaryColor,
            icon: const Icon(Icons.add, color: AppConstants.softWhite),
            label: const Text(
              'Add BnB',
              style: TextStyle(
                color: AppConstants.softWhite,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'BnB Dashboard',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Manage your properties',
                style: TextStyle(
                  color: AppConstants.softWhite.withOpacity(0.7),
                  fontSize: 14,
                ),
              ),
            ],
          ),
          IconButton(
            onPressed: () async {
              await StorageService.clearAll();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, Routes.login);
              }
            },
            icon: const Icon(
              Icons.logout,
              color: AppConstants.primaryColor,
              size: 28,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final totalBnBs = _bnbs.length;
    final activeBnBs = _bnbs.where((bnb) => bnb.available).length;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.8),
            AppConstants.surfaceColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('Total', totalBnBs.toString(), Icons.home),
          Container(
            width: 1,
            height: 40,
            color: AppConstants.mutedGray.withOpacity(0.3),
          ),
          _buildStatItem('Active', activeBnBs.toString(), Icons.check_circle),
          Container(
            width: 1,
            height: 40,
            color: AppConstants.mutedGray.withOpacity(0.3),
          ),
          _buildStatItem('Inactive', (totalBnBs - activeBnBs).toString(), Icons.cancel),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon) {
    return Column(
      children: [
        Icon(icon, color: AppConstants.primaryColor, size: 28),
        const SizedBox(height: 8),
        Text(
          value,
          style: const TextStyle(
            color: AppConstants.softWhite,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: AppConstants.softWhite.withOpacity(0.7),
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildBnBList() {
    if (_bnbs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work,
              size: 80,
              color: AppConstants.mutedGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No BnBs yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppConstants.softWhite.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Tap the button below to add your first property',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadBnBs,
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bnbs.length,
        itemBuilder: (context, index) {
          return _buildBnBCard(_bnbs[index]);
        },
      ),
    );
  }

  Widget _buildBnBCard(BnB bnb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.8),
            AppConstants.surfaceColor.withOpacity(0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bnb.available 
              ? AppConstants.primaryColor.withOpacity(0.5)
              : AppConstants.mutedGray.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () async {
            await Navigator.pushNamed(
              context, 
              Routes.manageBnB,
              arguments: bnb,
            );
            _loadBnBs(); // Refresh after returning
          },
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        bnb.name,
                        style: const TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: bnb.available 
                            ? AppConstants.successColor.withOpacity(0.2)
                            : AppConstants.mutedGray.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: bnb.available 
                              ? AppConstants.successColor
                              : AppConstants.mutedGray,
                          width: 1,
                        ),
                      ),
                      child: Text(
                        bnb.availabilityStatus,
                        style: TextStyle(
                          color: bnb.available 
                              ? AppConstants.successColor
                              : AppConstants.mutedGray,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    const Icon(
                      Icons.location_on,
                      size: 16,
                      color: AppConstants.primaryColor,
                    ),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        bnb.location,
                        style: TextStyle(
                          color: AppConstants.softWhite.withOpacity(0.8),
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 20,
                          color: AppConstants.accentColor,
                        ),
                        Text(
                          bnb.formattedPrice,
                          style: const TextStyle(
                            color: AppConstants.accentColor,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          ' /night',
                          style: TextStyle(
                            color: AppConstants.softWhite.withOpacity(0.6),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    if (bnb.callNumber != null)
                      Row(
                        children: [
                          const Icon(
                            Icons.phone,
                            size: 14,
                            color: AppConstants.primaryColor,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            bnb.callNumber!,
                            style: TextStyle(
                              color: AppConstants.softWhite.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.error_outline,
            size: 80,
            color: AppConstants.errorColor,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading BnBs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.softWhite.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _error ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _loadBnBs,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppConstants.primaryColor,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(color: AppConstants.softWhite),
            ),
          ),
        ],
      ),
    );
  }
}
