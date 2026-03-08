// lib/screens/main_app/home_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/widgets/common/app_bar.dart';
import 'package:hook_app/widgets/bottom_nav_bar.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/screens/main_app/search_screen.dart';
import 'package:hook_app/screens/main_app/bnbs_browse_screen.dart';
import 'package:hook_app/screens/sms/conversations_screen.dart';
import 'package:hook_app/screens/main_app/account_screen.dart';
import 'package:hook_app/screens/main_app/subscription_screen.dart';
import 'package:hook_app/screens/main_app/wallet_screen.dart';
import 'package:hook_app/screens/main_app/safety_center_screen.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/api_service.dart';
import 'package:hook_app/services/dummy_data_service.dart';
import 'package:hook_app/services/location_service.dart';
import 'package:hook_app/models/active_user.dart';
import 'package:hook_app/utils/responsive.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _NavItem {
  final String label;
  final IconData icon;
  final int index;

  _NavItem(this.label, this.icon, this.index);
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  String? _userFullName;
  String? _userGender;
  String? _userLocation;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedIndex = 0;

  // Map and location state
  List<ActiveUser> _activeUsers = [];
  Position? _currentPosition;
  int? _selectedUserIndex;
  late AnimationController _pulseController;

  // Filter state
  double _maxDistance = 50.0; // Increased default to ensure users are visible
  RangeValues _ageRange = const RangeValues(21, 35);
  bool _onlineOnly = false;

  @override
  void initState() {
    super.initState();

    // Initialize pulse animation for markers
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    // _pages initialization removed from here

    _checkLoginAndFetchProfile();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _checkLoginAndFetchProfile() async {
    print('🔍 [HOME] Starting _checkLoginAndFetchProfile');

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    print('🔍 [HOME] Getting auth token...');
    final String? authToken = await StorageService.getAuthToken();
    print('🔍 [HOME] Auth token: ${authToken != null ? "EXISTS" : "NULL"}');

    if (authToken == null || authToken.isEmpty) {
      print('⚠️ [HOME] No auth token - loading dummy data for demo');
      setState(() {
        _userFullName = 'Guest User';
        _userGender = 'male';
        _userLocation = 'Nairobi';
        _isLoading = false;
      });
      await _loadActiveUsers();
      print('✅ [HOME] Dummy data loaded for guest');
      return;
    }

    try {
      print('🔍 [HOME] Fetching user profile from API...');
      final data = await ApiService.getUserProfile().timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          print('⏱️ [HOME] API timeout - using defaults');
          return {'fullName': 'User', 'gender': 'male'};
        },
      );

      final String fullName =
          (data['fullName'] ?? data['full_name'] ?? data['name'] ?? 'User')
              .toString()
              .trim();
      final String firstName =
          fullName.isEmpty ? 'User' : fullName.split(' ').first;

      print(
          '✅ [HOME] Profile received: $fullName, gender: ${data['gender'] ?? data['gender']}');

      setState(() {
        _userFullName = firstName;
        _userGender = data['gender'] ?? data['gender'] ?? 'male';
        _userLocation = data['location'] ?? data['region'] ?? 'Nairobi';
        _isLoading = false;
      });

      print('🔍 [HOME] Loading active users...');
      await _loadActiveUsers();
      print('✅ [HOME] All data loaded successfully!');
    } catch (error) {
      print('❌ [HOME] Profile API error: $error');
      print('🔍 [HOME] Loading dummy data as fallback...');

      setState(() {
        _userFullName = 'User';
        _userGender = 'male';
        _userLocation = 'Nairobi';
        _isLoading = false;
      });

      await _loadActiveUsers();
      print('✅ [HOME] Fallback data loaded');
    }
  }

  Future<void> _loadActiveUsers() async {
    print('Loading active users...');

    Position? position;
    try {
      final hasPermission =
          await LocationService.requestLocationPermission();
      if (hasPermission) {
        position = await LocationService.getCurrentLocation();
      }
    } catch (_) {}
    position ??= LocationService.getDefaultLocation();
    if (mounted) {
      setState(() {
        _currentPosition = position;
      });
    }

    final region = _userLocation ?? 'Nairobi';

    try {
      // Try real provider search first
      final loc = position ?? LocationService.getDefaultLocation();
      final providers = await ApiService.searchProviders(region);
      final users = providers.map((p) {
        return ActiveUser(
          id: p.id,
          name: p.name,
          age: 25,
          gender: 'female',
          latitude: loc.latitude,
          longitude: loc.longitude,
          profileImage: 'https://via.placeholder.com/300',
          bio: 'Verified host on CloseBy',
          distance:
              double.tryParse(p.distance.replaceAll(RegExp(r'[^0-9.]'), '')) ??
                  2.0,
          isOnline: p.isActive,
          lastActive: DateTime.now(),
        );
      }).toList();

      if (mounted) {
        setState(() {
          _activeUsers = users;
        });
      }
      return;
    } catch (e) {
      // Fallback to dummy data
    }

    final loc = position ?? LocationService.getDefaultLocation();
    final users = DummyDataService.generateActiveUsers(
      userGender: _userGender ?? 'male',
      centerLat: loc.latitude,
      centerLon: loc.longitude,
      count: 20,
    );

    if (mounted) {
      setState(() {
        _activeUsers = users;
      });
    }
  }

  List<ActiveUser> get _filteredUsers {
    return _activeUsers.where((user) {
      if (user.distance > _maxDistance) return false;
      if (user.age < _ageRange.start || user.age > _ageRange.end) return false;
      if (_onlineOnly && !user.isOnline) return false;
      return true;
    }).toList();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Widget _buildHomeContent() {
    if (_activeUsers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    final filteredUsers = _filteredUsers;

    return Container(
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
      child: ResponsivePage(
        child: Column(
          children: [
            // Filter chips
            _buildFilterChips(),

            // Map placeholder with user grid
            Expanded(
              child: _buildUserGrid(filteredUsers),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip(
              icon: Icons.location_on,
              label: '${_maxDistance.toInt()} km',
              onTap: () => _showDistanceFilter(),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              icon: Icons.cake,
              label: '${_ageRange.start.toInt()}-${_ageRange.end.toInt()}',
              onTap: () => _showAgeFilter(),
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              icon: Icons.circle,
              label: _onlineOnly ? 'Online' : 'All',
              isActive: _onlineOnly,
              onTap: () {
                setState(() {
                  _onlineOnly = !_onlineOnly;
                });
              },
            ),
            const SizedBox(width: 8),
            _buildFilterChip(
              icon: Icons.refresh,
              label: 'Reset',
              onTap: () {
                setState(() {
                  _maxDistance = 10.0;
                  _ageRange = const RangeValues(21, 35);
                  _onlineOnly = false;
                });
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isActive = false,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isActive
              ? LinearGradient(
                  colors: [AppConstants.primaryColor, AppConstants.accentColor],
                )
              : null,
          color: isActive ? null : AppConstants.deepPurple.withOpacity(0.5),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AppConstants.primaryColor.withOpacity(0.3),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: AppConstants.softWhite, size: 16),
            const SizedBox(width: 4),
            Text(
              label,
              style: const TextStyle(
                color: AppConstants.softWhite,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserGrid(List<ActiveUser> users) {
    if (users.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 80,
              color: AppConstants.mutedGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No users found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppConstants.softWhite.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Try adjusting your filters',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    final crossAxisCount = Responsive.gridCount(
      context,
      mobile: 2,
      tablet: 3,
      desktop: 5,
    );
    final aspectRatio = Responsive.isDesktop(context) ? 0.8 : 0.75;

    return GridView.builder(
      padding: EdgeInsets.symmetric(
        horizontal: Responsive.isDesktop(context) ? 24 : 16,
        vertical: 16,
      ),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: aspectRatio,
      ),
      itemCount: users.length,
      itemBuilder: (context, index) {
        return _buildUserCard(users[index], index);
      },
    );
  }

  Widget _buildUserCard(ActiveUser user, int index) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseValue = _pulseController.value;

        return GestureDetector(
          onTap: () {
            setState(() {
              _selectedUserIndex = index;
            });
            _showUserDetails(user);
          },
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  AppConstants.deepPurple.withOpacity(0.8),
                  AppConstants.surfaceColor.withOpacity(0.6),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                width: 2,
                color: user.isOnline
                    ? AppConstants.primaryColor
                        .withOpacity(0.5 + pulseValue * 0.5)
                    : AppConstants.mutedGray.withOpacity(0.3),
              ),
              boxShadow: user.isOnline
                  ? [
                      BoxShadow(
                        color: AppConstants.primaryColor
                            .withOpacity(0.3 + pulseValue * 0.3),
                        blurRadius: 15 + pulseValue * 10,
                        spreadRadius: 2 + pulseValue * 3,
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Stack(
                children: [
                  // Profile image
                  Positioned.fill(
                    child: Image.network(
                      user.profileImage,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppConstants.deepPurple,
                          child: const Icon(
                            Icons.person,
                            size: 80,
                            color: AppConstants.softWhite,
                          ),
                        );
                      },
                    ),
                  ),

                  // Gradient overlay
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.black.withOpacity(0.8),
                          ],
                          stops: const [0.5, 1.0],
                        ),
                      ),
                    ),
                  ),

                  // Online indicator
                  if (user.isOnline)
                    Positioned(
                      top: 12,
                      right: 12,
                      child: Container(
                        width: (12 + pulseValue * 4).toDouble(),
                        height: (12 + pulseValue * 4).toDouble(),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppConstants.successColor,
                          boxShadow: [
                            BoxShadow(
                              color: AppConstants.successColor.withOpacity(0.6),
                              blurRadius: (8 + pulseValue * 4).toDouble(),
                              spreadRadius: (2 + pulseValue * 2).toDouble(),
                            ),
                          ],
                        ),
                      ),
                    ),

                  // User info
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '${user.name}, ${user.age}',
                            style: const TextStyle(
                              color: AppConstants.softWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                size: 14,
                                color: AppConstants.primaryColor,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                '${user.distance} km away',
                                style: TextStyle(
                                  color:
                                      AppConstants.softWhite.withOpacity(0.8),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showUserDetails(ActiveUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.7,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppConstants.deepPurple.withOpacity(0.95),
              AppConstants.darkBackground.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          border: Border.all(
            color: AppConstants.primaryColor.withOpacity(0.3),
            width: 2,
          ),
        ),
        child: Column(
          children: [
            // Handle bar
            Container(
              margin: const EdgeInsets.only(top: 12),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppConstants.mutedGray.withOpacity(0.5),
                borderRadius: BorderRadius.circular(2),
              ),
            ),

            // Profile image
            Container(
              margin: const EdgeInsets.all(20),
              height: 200,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppConstants.primaryColor,
                  width: 3,
                ),
                boxShadow: [
                  BoxShadow(
                    color: AppConstants.primaryColor.withOpacity(0.3),
                    blurRadius: 20,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(17),
                child: Image.network(
                  user.profileImage,
                  fit: BoxFit.cover,
                  width: double.infinity,
                ),
              ),
            ),

            // User info
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '${user.name}, ${user.age}',
                        style: const TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (user.isOnline)
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: AppConstants.successColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'Online',
                            style: TextStyle(
                              color: AppConstants.softWhite,
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
                        size: 18,
                        color: AppConstants.primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${user.distance} km away',
                        style: TextStyle(
                          color: AppConstants.softWhite.withOpacity(0.8),
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.bio,
                    style: TextStyle(
                      color: AppConstants.softWhite.withOpacity(0.9),
                      fontSize: 16,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, Routes.providerDetail,
                                arguments: {
                                  'providerId': user.id,
                                  'name': user.name,
                                  'age': user.age,
                                  'distanceKm': user.distance,
                                  'price': 0.0,
                                  'imageUrl': user.profileImage,
                                  'bio': user.bio,
                                  'isOnline': user.isOnline,
                                });
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppConstants.deepPurple,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                              side: BorderSide(
                                color:
                                    AppConstants.primaryColor.withOpacity(0.5),
                                width: 1.5,
                              ),
                            ),
                          ),
                          child: const Text(
                            'View Profile',
                            style: TextStyle(
                              color: AppConstants.softWhite,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [
                                AppConstants.primaryColor,
                                AppConstants.accentColor,
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.pop(context);
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Chat unlocks after booking is accepted. Request a booking from the profile.',
                                  ),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                              Navigator.pushNamed(context, Routes.providerDetail,
                                  arguments: {
                                    'providerId': user.id,
                                    'name': user.name,
                                    'age': user.age,
                                    'distanceKm': user.distance,
                                    'price': 0.0,
                                    'imageUrl': user.profileImage,
                                    'bio': user.bio,
                                    'isOnline': user.isOnline,
                                  });
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.message,
                                    size: 18, color: AppConstants.softWhite),
                                SizedBox(width: 8),
                                Text(
                                  'Message',
                                  style: TextStyle(
                                    color: AppConstants.softWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showDistanceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.deepPurple.withOpacity(0.95),
                AppConstants.darkBackground.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Maximum Distance: ${_maxDistance.toInt()} km',
                style: const TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Slider(
                value: _maxDistance,
                min: 1,
                max: 50,
                divisions: 49,
                activeColor: AppConstants.primaryColor,
                inactiveColor: AppConstants.mutedGray,
                onChanged: (value) {
                  setModalState(() {
                    _maxDistance = value;
                  });
                  setState(() {
                    _maxDistance = value;
                  });
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: AppConstants.softWhite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAgeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.deepPurple.withOpacity(0.95),
                AppConstants.darkBackground.withOpacity(0.95),
              ],
            ),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Age Range: ${_ageRange.start.toInt()}-${_ageRange.end.toInt()}',
                style: const TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              RangeSlider(
                values: _ageRange,
                min: 18,
                max: 60,
                divisions: 42,
                activeColor: AppConstants.primaryColor,
                inactiveColor: AppConstants.mutedGray,
                onChanged: (values) {
                  setModalState(() {
                    _ageRange = values;
                  });
                  setState(() {
                    _ageRange = values;
                  });
                },
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  padding:
                      const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(color: AppConstants.softWhite),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (Responsive.isDesktop(context)) {
      return _buildDesktopScaffold();
    }

    return Scaffold(
      appBar: _selectedIndex == 0 && !_isLoading && _errorMessage == null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(120.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.primaryColor.withOpacity(0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CustomAppBar(
                  title: 'Hello, ${_userFullName ?? 'User'}',
                  subtitle: 'Find trusted services nearby',
                  showProfile: true,
                  primaryColor: Theme.of(context).primaryColor,
                  secondaryColor: Theme.of(context).colorScheme.secondary,
                ),
              ),
            )
          : _selectedIndex == 0 && _isLoading
              ? null
              : _selectedIndex == 0 && _errorMessage != null
                  ? null
                  : _selectedIndex == 3 && !_isLoading && _errorMessage == null
                      ? PreferredSize(
                          preferredSize: const Size.fromHeight(120.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  AppConstants.primaryColor,
                                  AppConstants.primaryColor.withOpacity(0.8),
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: CustomAppBar(
                              title: 'Chats',
                              subtitle: 'Stay Connected',
                              showProfile: false,
                              primaryColor: Theme.of(context).primaryColor,
                              secondaryColor:
                                  Theme.of(context).colorScheme.secondary,
                            ),
                          ),
                        )
                      : _selectedIndex == 4
                          ? null
                          : AppBar(
                              title: Text(
                                _selectedIndex == 1
                                    ? 'Search'
                                    : _selectedIndex == 2
                                        ? 'Bookings'
                                        : 'Profile',
                              ),
                              backgroundColor: AppConstants.primaryColor,
                            ),
      body: _isLoading && _selectedIndex == 0
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null && _selectedIndex == 0
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red, fontSize: 16),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: _checkLoginAndFetchProfile,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Theme.of(context).primaryColor,
                          padding: const EdgeInsets.symmetric(
                              vertical: 12, horizontal: 24),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          'Retry',
                          style: TextStyle(fontSize: 16, color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                )
              : _selectedIndex >= 0
                  ? _buildPageContent(_selectedIndex)
                  : const Center(child: Text('Error: Invalid tab index')),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        selectedColor: AppConstants.primaryColor,
        unselectedColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }

  Widget _buildDesktopScaffold() {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          _buildDesktopNav(),
          Expanded(
            child: Column(
              children: [
                _buildDesktopTopBar(),
                Expanded(
                  child: _buildPageContent(_selectedIndex),
                ),
              ],
            ),
          ),
          _buildDesktopSidePanel(),
        ],
      ),
    );
  }

  Widget _buildDesktopNav() {
    final items = [
      _NavItem('Home', Icons.home_rounded, 0),
      _NavItem('Search', Icons.search_rounded, 1),
      _NavItem('BnBs', Icons.home_work_rounded, 2),
      _NavItem('Messages', Icons.chat_bubble_rounded, 3),
      _NavItem('Profile', Icons.person_rounded, 4),
    ];

    return Container(
      width: 220,
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.85),
        border: Border(
          right: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        children: [
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.favorite_rounded, color: AppConstants.primaryColor),
              const SizedBox(width: 8),
              Text(
                AppConstants.appName,
                style: const TextStyle(
                  color: AppConstants.softWhite,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          ...items.map((item) => _buildNavItem(item)).toList(),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: OutlinedButton.icon(
              onPressed: () {
                setState(() {
                  _selectedIndex = 4;
                });
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppConstants.softWhite,
                side: BorderSide(color: Colors.white.withOpacity(0.15)),
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              ),
              icon: const Icon(Icons.settings, size: 18),
              label: const Text('Settings'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(_NavItem item) {
    final active = _selectedIndex == item.index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = item.index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: active
              ? AppConstants.primaryColor.withOpacity(0.18)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active
                ? AppConstants.primaryColor.withOpacity(0.35)
                : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Icon(
              item.icon,
              color: active ? AppConstants.primaryColor : AppConstants.mutedGray,
            ),
            const SizedBox(width: 12),
            Text(
              item.label,
              style: TextStyle(
                color: active ? AppConstants.softWhite : AppConstants.mutedGray,
                fontWeight: active ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopTopBar() {
    return Container(
      height: 72,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        color: AppConstants.darkBackground,
        border: Border(
          bottom: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Row(
        children: [
          Text(
            _selectedIndex == 0
                ? 'Discover'
                : _selectedIndex == 1
                    ? 'Search'
                    : _selectedIndex == 2
                        ? 'BnBs'
                        : _selectedIndex == 3
                            ? 'Messages'
                            : 'Profile',
            style: const TextStyle(
              color: AppConstants.softWhite,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              children: [
                const Icon(Icons.circle, color: AppConstants.successColor, size: 8),
                const SizedBox(width: 6),
                Text(
                  'Active',
                  style: TextStyle(
                    color: AppConstants.softWhite.withOpacity(0.9),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSidePanel() {
    return Container(
      width: 280,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppConstants.surfaceColor.withOpacity(0.9),
        border: Border(
          left: BorderSide(color: Colors.white.withOpacity(0.06)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppConstants.primaryColor.withOpacity(0.2),
                child: const Icon(Icons.person, color: AppConstants.softWhite),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _userFullName ?? 'User',
                      style: const TextStyle(
                        color: AppConstants.softWhite,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      'Account overview',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _sideAction(
            title: 'Subscription',
            subtitle: 'Manage plan',
            icon: Icons.workspace_premium_rounded,
            onTap: () => _openSidePanelPage(const SubscriptionScreen()),
          ),
          _sideAction(
            title: 'Wallet',
            subtitle: 'Balance & payouts',
            icon: Icons.account_balance_wallet_rounded,
            onTap: () => _openSidePanelPage(const WalletScreen()),
          ),
          _sideAction(
            title: 'Safety Center',
            subtitle: 'Reports & help',
            icon: Icons.shield_rounded,
            onTap: () => _openSidePanelPage(const SafetyCenterScreen()),
          ),
          const Spacer(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'Tip: Use filters to narrow results faster.',
              style: TextStyle(
                color: AppConstants.softWhite,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sideAction({
    required String title,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppConstants.darkBackground.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppConstants.primaryColor),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      color: AppConstants.softWhite,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: AppConstants.mutedGray,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppConstants.mutedGray),
          ],
        ),
      ),
    );
  }

  Future<void> _openSidePanelPage(Widget page) async {
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const SearchScreen();
      case 2:
        return const BnBsBrowseScreen();
      case 3:
        return const ConversationsScreen();
      case 4:
        return const AccountScreen();
      default:
        return const Center(child: Text('Error: Invalid tab index'));
    }
  }
}
