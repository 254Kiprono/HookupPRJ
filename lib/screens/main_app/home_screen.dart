import 'package:flutter/material.dart';
import 'package:hook_app/widgets/common/app_bar.dart';
import 'package:hook_app/widgets/bottom_nav_bar.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/screens/main_app/search_screen.dart';
import 'package:hook_app/screens/main_app/bookings_screen.dart';
import 'package:hook_app/screens/sms/conversations_screen.dart';
import 'package:hook_app/screens/main_app/account_screen.dart';
import 'package:hook_app/models/provider.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/api_service.dart';


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String? _userFullName;
  String? _userEmail;
  String? _userPhone;
  String? _userDob;
  String? _userLocation;
  bool _isLoading = true;
  String? _errorMessage;
  int _selectedIndex = 0;
  late final List<Widget> _pages;
  final TextEditingController _regionController =
      TextEditingController(text: 'Roysambu');
  String _searchRegion = 'Roysambu';
  List<Provider> _providers = [];
  List<BnB> _bnbs = [];
  bool _isSearching = false;
  String? _searchError;
  int? _userId;
  bool _includeBnB = false;
  BnB? _selectedBnB;

  @override
  void initState() {
    super.initState();
    _pages = [
      _buildHomeContent(), // 0: Home
      const SearchScreen(), // 1: Search
      const BookingsScreen(), // 2: Bookings
      const ConversationsScreen(), // 3: Messages
      const AccountScreen(), // 4: Profile
    ];
    _checkLoginAndFetchProfile();
  }

  Future<void> _checkLoginAndFetchProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final String? authToken = await StorageService.getAuthToken();

    if (authToken == null || authToken.isEmpty) {
      await StorageService.clearAll();
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
      return;
    }

    try {
      final data = await ApiService.getUserProfile();
      setState(() {
        _userFullName = data['fullName'] ?? 'User';
        _userEmail = data['email'] ?? 'No email';
        _userPhone = data['phone'] ?? 'N/A';
        _userDob = data['dob'] ?? 'N/A';
        _userLocation = data['location'] ?? 'N/A';
        _userId = data['id'] as int?;
        _isLoading = false;
      });
      _fetchNearbyContent(_searchRegion); // Fetch initial content
    } catch (error) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to fetch user profile: $error';
      });
      await StorageService.clearAll();
      if (mounted) {
        Navigator.pushReplacementNamed(context, Routes.login);
      }
    }
  }

  Future<void> _fetchNearbyContent(String region) async {
    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      // Fetch nearby providers
      final providers = await ApiService.searchProviders(region);
      setState(() {
        _providers = providers;
      });

      // Fetch nearby BnBs
      final bnbs = await ApiService.searchBnBs(region);
      setState(() {
        _bnbs = bnbs;
      });
    } catch (e) {
      setState(() {
        _searchError = 'Error fetching content: $e';
      });
    } finally {
      setState(() {
        _isSearching = false;
      });
    }
  }

  void _onItemTapped(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _selectedIndex = index;
      });
    }
  }

  Widget _buildHomeContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 80),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withValues(alpha: 0.2),
                    spreadRadius: 2,
                    blurRadius: 5,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _regionController,
                      decoration: InputDecoration(
                        hintText: 'Search by location (e.g., Roysambu)',
                        prefixIcon:
                            const Icon(Icons.search, color: Colors.grey),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.clear, color: Colors.grey),
                          onPressed: () {
                            _regionController.clear();
                          },
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () {
                      _searchRegion = _regionController.text;
                      _fetchNearbyContent(_searchRegion);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppConstants.primaryColor,
                    ),
                    child: const Text('Search',
                        style: TextStyle(color: Colors.white)),
                  ),
                ],
              ),
            ),
          ),
          if (_isSearching) const Center(child: CircularProgressIndicator()),
          if (_searchError != null)
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                _searchError!,
                style: const TextStyle(color: Colors.red),
                textAlign: TextAlign.center,
              ),
            ),
          SectionHeader(
            title: 'Nearby Providers',
            actionText: 'See all',
            onActionTap: () {},
          ),
          _providers.isEmpty && !_isSearching && _searchError == null
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No providers found in this region.'),
                )
              : GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  padding: const EdgeInsets.all(8),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 0.75,
                  children: _providers.map((provider) {
                    return ProviderCard(
                      name: provider.name,
                      price: '${provider.price} KES/hr',
                      distance: provider.distance,
                      imageUrl: 'https://via.placeholder.com/300x200',
                      onBook: () {
                        Navigator.pushNamed(
                          context,
                          Routes.booking,
                          arguments: {
                            'providerId': provider.id,
                            'providerName': provider.name,
                            'price': provider.price,
                          },
                        );
                      },
                    );
                  }).toList(),
                ),
          SectionHeader(
            title: 'Nearby BnBs',
            actionText: 'See all',
            onActionTap: () {},
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Row(
              children: [
                Checkbox(
                  value: _includeBnB,
                  onChanged: (value) {
                    setState(() {
                      _includeBnB = value ?? false;
                      if (!_includeBnB) _selectedBnB = null;
                    });
                  },
                ),
                const Text('Include BnB in booking'),
              ],
            ),
          ),
          _bnbs.isEmpty && !_isSearching && _searchError == null
              ? const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: Text('No BnBs found in this region.'),
                )
              : Column(
                  children: _bnbs.map((bnb) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      child: BnBCard(
                        bnb: bnb,
                        isSelected: _selectedBnB?.id == bnb.id,
                        onSelect: _includeBnB
                            ? () {
                                setState(() {
                                  _selectedBnB = bnb;
                                });
                              }
                            : null,
                      ),
                    );
                  }).toList(),
                ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _selectedIndex == 0 && !_isLoading && _errorMessage == null
          ? PreferredSize(
              preferredSize: const Size.fromHeight(120.0),
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AppConstants.primaryColor,
                      AppConstants.primaryColor.withValues(alpha: 0.8),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: CustomAppBar(
                  title: 'Hello, ${_userFullName ?? 'User'}',
                  subtitle: 'Find your perfect match',
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
                                  AppConstants.primaryColor.withValues(alpha: 0.8),
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
                      : _selectedIndex == 4 // Skip AppBar for Profile tab
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
              : _selectedIndex >= 0 && _selectedIndex < _pages.length
                  ? _pages[_selectedIndex]
                  : const Center(child: Text('Error: Invalid tab index')),
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: _selectedIndex,
        selectedColor: AppConstants.primaryColor,
        unselectedColor: Colors.grey,
        onTap: _onItemTapped,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String actionText;
  final VoidCallback onActionTap;

  const SectionHeader({
    super.key,
    required this.title,
    required this.actionText,
    required this.onActionTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 20,
              color: Colors.black87,
            ),
          ),
          TextButton(
            onPressed: onActionTap,
            child: Text(
              actionText,
              style: const TextStyle(
                color: AppConstants.primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class ProviderCard extends StatelessWidget {
  final String name;
  final String price;
  final String distance;
  final String imageUrl;
  final VoidCallback onBook;

  const ProviderCard({
    super.key,
    required this.name,
    required this.price,
    required this.distance,
    required this.imageUrl,
    required this.onBook,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Image.network(
              imageUrl,
              height: 120,
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  price,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  distance,
                  style: const TextStyle(
                    color: Colors.grey,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: onBook,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppConstants.primaryColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text(
                    'Book Now',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class BnBCard extends StatelessWidget {
  final BnB bnb;
  final bool isSelected;
  final VoidCallback? onSelect;

  const BnBCard({
    super.key,
    required this.bnb,
    required this.isSelected,
    this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: isSelected
            ? const BorderSide(color: AppConstants.primaryColor, width: 2)
            : BorderSide.none,
      ),
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(12),
        child: Column(
          children: [
            Stack(
              children: [
                ClipRRect(
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(12),
                  ),
                  child: Image.network(
                    bnb.imageUrl,
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                ),
                Container(
                  height: 180,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bnb.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      const Icon(Icons.location_on,
                          size: 16, color: Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        bnb.distance,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: List.generate(5, (index) {
                      return Icon(
                        index < bnb.rating ? Icons.star : Icons.star_border,
                        color: const Color(0xFFFFD54F),
                        size: 16,
                      );
                    }),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${bnb.price} KES',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

const Color amber400 = Color(0xFFFFD54F);
