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
import 'package:hook_app/utils/nav.dart';
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
  String _selectedCategory = 'Local Services';

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
    var users = _activeUsers.where((user) {
      if (user.distance > _maxDistance) return false;
      if (user.age < _ageRange.start || user.age > _ageRange.end) return false;
      if (_onlineOnly && !user.isOnline) return false;
      return true;
    }).toList();

    if (_selectedCategory == 'Featured') {
      users = users.where((u) => u.isOnline).toList();
      users.sort((a, b) => a.distance.compareTo(b.distance));
    } else if (_selectedCategory == 'Recent') {
      users.sort((a, b) => b.lastActive.compareTo(a.lastActive));
    }

    return users;
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

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHomeHeader(),
          _buildSearchBar(),
          _buildCategoryChips(),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Featured Providers',
                  style: TextStyle(
                    color: Colors.white,
                    fontFamily: 'Sora',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                TextButton(
                  onPressed: () {},
                  child: const Text('View All', style: TextStyle(color: AppConstants.tealLight)),
                ),
              ],
            ),
          ),
          
          SizedBox(
            height: 240,
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              scrollDirection: Axis.horizontal,
              itemCount: filteredUsers.take(10).length,
              itemBuilder: (context, index) {
                return Container(
                  width: 280,
                  margin: const EdgeInsets.only(right: 12),
                  child: _buildUserCard(filteredUsers[index], index),
                );
              },
            ),
          ),
          
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildHomeHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 18),
              ),
              const SizedBox(width: 12),
              const Text(
                'CloseBy',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Sora',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppConstants.cardNavy,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: const Row(
              children: [
                Icon(Icons.near_me, color: AppConstants.primaryColor, size: 14),
                SizedBox(width: 6),
                Text(
                  'Downtown',
                  style: TextStyle(color: Colors.white, fontSize: 13),
                ),
                SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_down, color: AppConstants.mutedGray, size: 16),
              ],
            ),
          ),
          
          const Row(
            children: [
              Icon(Icons.notifications_none, color: AppConstants.mutedGray, size: 24),
              SizedBox(width: 12),
              CircleAvatar(
                radius: 18,
                backgroundImage: NetworkImage('https://via.placeholder.com/150'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: TextField(
        decoration: InputDecoration(
          hintText: 'Find services nearby...',
          prefixIcon: const Icon(Icons.search, color: AppConstants.mutedGray),
          fillColor: AppConstants.cardNavy,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(16),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryChips() {
    final categories = [
      {'label': 'Local Services', 'icon': Icons.build},
      {'label': 'BnB', 'icon': Icons.bed},
      {'label': 'Featured', 'icon': Icons.star},
      {'label': 'Recent', 'icon': Icons.history},
    ];
    
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final label = categories[index]['label'] as String;
          final isSelected = _selectedCategory == label;
          return Container(
            margin: const EdgeInsets.only(right: 10),
            child: ActionChip(
              onPressed: () {
                if (label == 'BnB') {
                  setState(() => _selectedIndex = 1);
                  return;
                }
                setState(() => _selectedCategory = label);
              },
              avatar: Icon(
                categories[index]['icon'] as IconData,
                size: 14,
                color: isSelected ? Colors.white : AppConstants.mutedGray,
              ),
              label: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : AppConstants.mutedGray,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              backgroundColor: isSelected ? AppConstants.primaryColor : AppConstants.cardNavy,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: isSelected ? Colors.transparent : Colors.white.withOpacity(0.05),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildRecommendationCard(String title, IconData icon, String count) {
    return Container(
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: AppConstants.primaryColor, size: 28),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            count,
            style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12),
          ),
        ],
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
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedUserIndex = index;
        });
        _showUserDetails(user);
      },
      child: Container(
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              Positioned.fill(
                child: _buildProfileImage(user.profileImage),
              ),
              Positioned.fill(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Colors.black.withOpacity(0.8)],
                    ),
                  ),
                ),
              ),
              if (user.isOnline)
                Positioned(
                  top: 12,
                  right: 12,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: AppConstants.successColor,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppConstants.successColor.withOpacity(0.5),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              Positioned(
                bottom: 12,
                left: 12,
                right: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${user.name}, ${user.age}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontFamily: 'Sora',
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on, color: AppConstants.primaryColor, size: 12),
                        const SizedBox(width: 4),
                        Text(
                          '${user.distance} mi away',
                          style: const TextStyle(color: AppConstants.mutedGray, fontSize: 11),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Ksh 45/hour',
                      style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProfileImage(String url) {
    if (url.trim().isEmpty || !(url.startsWith('http://') || url.startsWith('https://'))) {
      return Container(
        color: AppConstants.cardNavy,
        child: const Center(
          child: Icon(Icons.person, color: AppConstants.mutedGray, size: 48),
        ),
      );
    }

    return Image.network(
      url,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: AppConstants.cardNavy,
          child: const Center(
            child: Icon(Icons.person, color: AppConstants.mutedGray, size: 48),
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
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.9,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppConstants.darkBackground,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Hero Section (Photo/Video)
                      Stack(
                        children: [
                          Container(
                            height: 400,
                            width: double.infinity,
                            decoration: const BoxDecoration(
                              borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
                            ),
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
                              child: _buildProfileImage(user.profileImage),
                            ),
                          ),
                          Positioned(
                            top: 20,
                            right: 20,
                            child: IconButton(
                              onPressed: () => Nav.safePop(context),
                              icon: const CircleAvatar(
                                backgroundColor: Colors.black45,
                                child: Icon(Icons.close, color: Colors.white),
                              ),
                            ),
                          ),
                          // Play button for video preview
                          Center(
                            child: Container(
                              margin: const EdgeInsets.only(top: 160),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.black38,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.5)),
                              ),
                              child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 40),
                            ),
                          ),
                        ],
                      ),
                      
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${user.name}, ${user.age}',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontFamily: 'Sora',
                                        fontSize: 24,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        const Icon(Icons.location_on, color: AppConstants.primaryColor, size: 16),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${user.distance} mi away • Fast Response',
                                          style: const TextStyle(color: AppConstants.mutedGray, fontSize: 14),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                if (user.isOnline)
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: AppConstants.primaryColor.withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.circle, color: AppConstants.successColor, size: 8),
                                        SizedBox(width: 6),
                                        Text('Online', style: TextStyle(color: Colors.white, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),
                            const Text(
                              'About Me',
                              style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              user.bio,
                              style: const TextStyle(color: AppConstants.mutedGray, fontSize: 15, height: 1.5),
                            ),
                            
                            const SizedBox(height: 32),
                            const Text(
                              'Price Tiers',
                              style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                _buildPriceTier('1 Hour', 'Ksh 45'),
                                const SizedBox(width: 12),
                                _buildPriceTier('2 Hours', 'Ksh 80'),
                                const SizedBox(width: 12),
                                _buildPriceTier('3 Hours', 'Ksh 110'),
                              ],
                            ),
                            
                            const SizedBox(height: 40),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Bottom Action Button
              Container(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                decoration: BoxDecoration(
                  color: AppConstants.cardNavy,
                  border: Border(top: BorderSide(color: Colors.white.withOpacity(0.05))),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppConstants.darkBackground,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                      ),
                      child: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Nav.safePop(context);
                          _requestBooking(user);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppConstants.primaryColor,
                          padding: const EdgeInsets.symmetric(vertical: 18),
                        ),
                        child: const Text(
                          'Request Booking',
                          style: TextStyle(fontFamily: 'Sora', fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceTier(String label, String price) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 12)),
            const SizedBox(height: 8),
            Text(price, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18)),
          ],
        ),
      ),
    );
  }

  void _requestBooking(ActiveUser user) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Booking request sent to ${user.name}. Waiting for acceptance...'),
        backgroundColor: AppConstants.primaryColor,
        behavior: SnackBarBehavior.floating,
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
                onPressed: () => Nav.safePop(context),
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
                onPressed: () => Nav.safePop(context),
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
      backgroundColor: AppConstants.darkBackground,
      body: SafeArea(
        child: _buildPageContent(_selectedIndex),
      ),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
    );
  }

  Widget _buildDesktopScaffold() {
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      body: Row(
        children: [
          // Left Sidebar
          _buildDesktopSidebar(),

          // Main Content — each tab fills the available height/width
          Expanded(
            child: _buildDesktopPageContent(_selectedIndex),
          ),

          // Right Context Panel
          _buildDesktopSidePanel(),
        ],
      ),
    );
  }

  Widget _buildDesktopSidebar() {
    return Container(
      width: 250,
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        border: Border(right: BorderSide(color: Colors.white.withOpacity(0.05))),
      ),
      child: Column(
        children: [
          const SizedBox(height: 48),
          // Logo
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppConstants.primaryColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.location_on, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 12),
              const Text(
                'CloseBy',
                style: TextStyle(
                  color: Colors.white,
                  fontFamily: 'Sora',
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 60),
          _sidebarItem(0, Icons.explore, 'Discovery'),
          _sidebarItem(1, Icons.bed, 'BnB'),
          _sidebarItem(2, Icons.chat_bubble, 'Chats'),
          _sidebarItem(3, Icons.account_balance_wallet, 'Wallet'),
          _sidebarItem(4, Icons.person, 'Profile'),
        ],
      ),
    );
  }

  Widget _sidebarItem(int index, IconData icon, String label) {
    final bool active = _selectedIndex == index;
    return InkWell(
      onTap: () => setState(() => _selectedIndex = index),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: active ? AppConstants.primaryColor.withOpacity(0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(
              active ? icon : (icon == Icons.explore ? Icons.explore_outlined : icon),
              color: active ? AppConstants.primaryColor : AppConstants.mutedGray,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: active ? Colors.white : AppConstants.mutedGray,
                fontFamily: 'Sora',
                fontWeight: active ? FontWeight.bold : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopNav() {
    final items = [
      _NavItem('Home', Icons.home_rounded, 0),
      _NavItem('BnBs', Icons.home_work_rounded, 1),
      _NavItem('Messages', Icons.chat_bubble_rounded, 2),
      _NavItem('Wallet', Icons.account_balance_wallet_rounded, 3),
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

  /// Renders page content for desktop — each screen fills available space
  Widget _buildDesktopPageContent(int index) {
    switch (index) {
      case 0:
        return SingleChildScrollView(
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 1200),
              child: _buildHomeContent(),
            ),
          ),
        );
      case 1:
        return const BnBsBrowseScreen();
      case 2:
        return const ConversationsScreen();
      case 3:
        return const WalletScreen();
      case 4:
        return const AccountScreen();
      default:
        return const Center(child: Text('Error: Invalid tab index', style: TextStyle(color: Colors.white)));
    }
  }

  Widget _buildPageContent(int index) {
    switch (index) {
      case 0:
        return _buildHomeContent();
      case 1:
        return const BnBsBrowseScreen();
      case 2:
        return const ConversationsScreen();
      case 3:
        return const WalletScreen();
      case 4:
        return const AccountScreen();
      default:
        return const Center(child: Text('Error: Invalid tab index'));
    }
  }
}
