import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/screens/bnb_owner/manage_bnb_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_owner_profile_screen.dart';
import 'package:hook_app/screens/bnb_owner/bnb_wallet_screen.dart';

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
      print('[BNB DASHBOARD] Retrieved userId from storage: "$userId"');
      
      if (userId == null || userId.isEmpty) {
        throw Exception('User ID not found in storage');
      }

      // Try to parse userId
      final userIdInt = int.tryParse(userId);
      if (userIdInt == null) {
        throw Exception('Invalid user ID format: "$userId" is not a valid number');
      }

      print('[BNB DASHBOARD] Fetching BnBs for owner ID: $userIdInt');
      final bnbs = await BnBService.getBnBsByOwner(userIdInt);
      
      print('[BNB DASHBOARD] Successfully loaded ${bnbs.length} BnBs');
      setState(() {
        _bnbs = bnbs;
        _isLoading = false;
      });
    } catch (e) {
      print('[BNB DASHBOARD] Error loading BnBs: $e');
      
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
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'My Dashboard',
          style: TextStyle(
            color: AppConstants.softWhite,
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_circle, color: AppConstants.softWhite),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BnBOwnerProfileScreen()),
              );
            },
          ),
        ],
      ),
      drawer: _buildDrawer(),
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
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(
                    color: AppConstants.primaryColor,
                  ),
                )
              : _error != null
                  ? _buildErrorWidget()
                  : Column(
                      children: [
                        _buildAnalyticsCards(),
                        Expanded(child: _buildBnBList()),
                      ],
                    ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.pushNamed(context, Routes.registerBnB);
          if (result == true) {
            _loadBnBs(); // Refresh list after successful registration
          }
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
    );
  }

  Widget _buildDrawer() {
    return Drawer(
      backgroundColor: AppConstants.deepPurple,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Icon(Icons.admin_panel_settings, size: 48, color: AppConstants.softWhite),
                const SizedBox(height: 12),
                const Text(
                  'BnB Owner Portal',
                  style: TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Manage your properties',
                  style: TextStyle(
                    color: AppConstants.softWhite.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard, color: AppConstants.softWhite),
            title: const Text('Dashboard', style: TextStyle(color: AppConstants.softWhite)),
            onTap: () => Navigator.pop(context),
          ),
          ListTile(
            leading: const Icon(Icons.account_balance_wallet, color: AppConstants.softWhite),
            title: const Text('My Wallet', style: TextStyle(color: AppConstants.softWhite)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BnBWalletScreen()),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.person, color: AppConstants.softWhite),
            title: const Text('Profile', style: TextStyle(color: AppConstants.softWhite)),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const BnBOwnerProfileScreen()),
              );
            },
          ),
          const Divider(color: AppConstants.mutedGray),
          ListTile(
            leading: const Icon(Icons.logout, color: AppConstants.errorColor),
            title: const Text('Logout', style: TextStyle(color: AppConstants.errorColor)),
            onTap: () async {
              await StorageService.clearAll();
              if (mounted) {
                Navigator.pushNamedAndRemoveUntil(
                  context, 
                  '/login', 
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards() {
    final activeCount = _bnbs.where((b) => b.available).length;
    final inactiveCount = _bnbs.length - activeCount;
    // Mock revenue for now
    const totalRevenue = 45000; 

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          _buildStatCard(
            'Active BnBs',
            activeCount.toString(),
            Icons.check_circle,
            AppConstants.successColor,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Inactive',
            inactiveCount.toString(),
            Icons.remove_circle,
            AppConstants.mutedGray,
          ),
          const SizedBox(width: 12),
          _buildStatCard(
            'Total Revenue',
            'KES $totalRevenue',
            Icons.attach_money,
            AppConstants.accentColor,
            width: 160,
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color, {double width = 120}) {
    return Container(
      width: width,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(
            value,
            style: const TextStyle(
              color: AppConstants.softWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: AppConstants.softWhite.withOpacity(0.6),
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBnBList() {
    if (_bnbs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.home_work_outlined,
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
              'Add your first property to start earning',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.6),
              ),
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
          final bnb = _bnbs[index];
          return Card(
            margin: const EdgeInsets.only(bottom: 16),
            color: AppConstants.surfaceColor.withOpacity(0.5),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: AppConstants.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ManageBnBScreen(bnb: bnb),
                  ),
                ).then((_) => _loadBnBs()); // Refresh list on return
              },
              borderRadius: BorderRadius.circular(16),
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
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: bnb.available
                                ? AppConstants.successColor.withOpacity(0.2)
                                : AppConstants.mutedGray.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: bnb.available
                                  ? AppConstants.successColor
                                  : AppConstants.mutedGray,
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
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.location_on,
                          size: 16,
                          color: AppConstants.primaryColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          bnb.location,
                          style: TextStyle(
                            color: AppConstants.softWhite.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          Icons.attach_money,
                          size: 16,
                          color: AppConstants.accentColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'KES ${bnb.priceKES.toStringAsFixed(0)} / night', // Changed from price
                          style: const TextStyle(
                            color: AppConstants.accentColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
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
