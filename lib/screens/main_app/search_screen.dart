// lib/screens/main_app/search_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> with TickerProviderStateMixin {
  final TextEditingController _locationController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  List<dynamic> _providers = [];
  bool _isLoading = false;
  String? _errorMessage;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _isFocused = false;

  @override
  void initState() {
    super.initState();
    
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);
    
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    _searchFocusNode.addListener(() {
      setState(() {
        _isFocused = _searchFocusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _locationController.dispose();
    _searchFocusNode.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _searchProviders(String? region) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      _providers = [];
    });

    try {
      // Get current location
      final position = await _determinePosition();
      
      // Call UserService
      final data = await UserService.searchNearbyUsers(
        latitude: position.latitude,
        longitude: position.longitude,
        radiusKm: 50.0, // Default 50km radius
        county: region?.isNotEmpty == true ? region : null,
      );

      if (mounted) {
        setState(() {
          _providers = data['users'] ?? [];
          _isLoading = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to search: ${error.toString().replaceAll("Exception: ", "")}';
        });
      }
    }
  }

  Future<Position> _determinePosition() async {
    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permissions are denied');
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permissions are permanently denied.');
    } 

    return await Geolocator.getCurrentPosition();
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
            stops: [0.0, 0.5, 1.0],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Text(
                    'Find Providers',
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: AppConstants.softWhite,
                      shadows: [
                        Shadow(
                          blurRadius: 10.0,
                          color: AppConstants.primaryColor.withOpacity(0.5),
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Glassmorphic Search Bar
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: LinearGradient(
                      colors: [
                        AppConstants.deepPurple.withOpacity(0.7),
                        AppConstants.surfaceColor.withOpacity(0.5),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      width: _isFocused ? 2 : 1.5,
                      color: _isFocused
                          ? AppConstants.primaryColor
                          : AppConstants.primaryColor.withOpacity(0.3),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _isFocused
                            ? AppConstants.primaryColor.withOpacity(0.4)
                            : AppConstants.primaryColor.withOpacity(0.2),
                        blurRadius: _isFocused ? 25 : 15,
                        spreadRadius: _isFocused ? 3 : 1,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: TextField(
                    controller: _locationController,
                    focusNode: _searchFocusNode,
                    style: const TextStyle(
                      color: AppConstants.softWhite, // FIX: Visible text color
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter location (e.g., Westlands, Nairobi)',
                      hintStyle: TextStyle(
                        color: AppConstants.mutedGray.withOpacity(0.7),
                        fontSize: 15,
                      ),
                      prefixIcon: Container(
                        padding: const EdgeInsets.all(12),
                        child: Icon(
                          Icons.search,
                          color: _isFocused
                              ? AppConstants.primaryColor
                              : AppConstants.accentColor,
                          size: 24,
                        ),
                      ),
                      suffixIcon: _locationController.text.isNotEmpty
                          ? IconButton(
                              icon: Icon(
                                Icons.clear,
                                color: AppConstants.mutedGray,
                              ),
                              onPressed: () {
                                _locationController.clear();
                                setState(() {
                                  _providers = [];
                                  _errorMessage = null;
                                });
                              },
                            )
                          : null,
                      filled: false,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 18,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() {}); // Update to show/hide clear button
                    },
                    onSubmitted: (value) {
                      if (value.isNotEmpty) {
                        _searchProviders(value);
                      }
                    },
                  ),
                ),
                
                const SizedBox(height: 12),
                
                // Search Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                    ),
                    onPressed: () {
                      if (_locationController.text.isNotEmpty) {
                        _searchProviders(_locationController.text);
                      }
                    },
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            AppConstants.primaryColor,
                            AppConstants.secondaryColor,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: AppConstants.primaryColor.withOpacity(0.4),
                            blurRadius: 15,
                            spreadRadius: 1,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.search,
                              color: AppConstants.softWhite,
                              size: 22,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Search',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppConstants.softWhite,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Results
                Expanded(
                  child: _isLoading
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: AppConstants.primaryColor,
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Searching for providers...',
                                style: TextStyle(
                                  color: AppConstants.softWhite.withOpacity(0.7),
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        )
                      : _errorMessage != null
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    Icons.error_outline,
                                    color: AppConstants.errorColor,
                                    size: 48,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorMessage!,
                                    style: const TextStyle(
                                      color: AppConstants.errorColor,
                                      fontSize: 16,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: () {
                                      if (_locationController.text.isNotEmpty) {
                                        _searchProviders(_locationController.text);
                                      }
                                    },
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppConstants.primaryColor,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                        horizontal: 32,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    child: const Text(
                                      'Retry',
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: AppConstants.softWhite,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )
                          : _providers.isEmpty
                              ? Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.search_off,
                                        color: AppConstants.mutedGray.withOpacity(0.5),
                                        size: 64,
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'Search for providers by location',
                                        style: TextStyle(
                                          color: AppConstants.softWhite.withOpacity(0.6),
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        'Enter a city or neighborhood above',
                                        style: TextStyle(
                                          color: AppConstants.mutedGray.withOpacity(0.5),
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : ListView.builder(
                                  physics: const BouncingScrollPhysics(),
                                  itemCount: _providers.length,
                                  itemBuilder: (context, index) {
                                    final item = _providers[index];

                                    final user = item['user'] ?? {};
                                    final distance = item['distance_km'] ?? 0.0;
                                    final isAvailable = (user['isActive'] ?? user['is_active']) == true;
                                    
                                    return Container(
                                      margin: const EdgeInsets.only(bottom: 16),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(20),
                                        gradient: LinearGradient(
                                          colors: [
                                            AppConstants.deepPurple.withOpacity(0.7),
                                            AppConstants.surfaceColor.withOpacity(0.5),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        border: Border.all(
                                          width: 1.5,
                                          color: AppConstants.primaryColor.withOpacity(0.3),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppConstants.primaryColor.withOpacity(0.15),
                                            blurRadius: 15,
                                            spreadRadius: 1,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.all(16),
                                        leading: Stack(
                                          children: [
                                            Container(
                                              width: 56,
                                              height: 56,
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppConstants.primaryColor.withOpacity(0.3),
                                                    AppConstants.accentColor.withOpacity(0.3),
                                                  ],
                                                ),
                                                image: user['profile_image'] != null && user['profile_image'].toString().isNotEmpty
                                                    ? DecorationImage(
                                                        image: NetworkImage(user['profile_image']),
                                                        fit: BoxFit.cover,
                                                      )
                                                    : null,
                                              ),
                                              child: user['profile_image'] == null || user['profile_image'].toString().isEmpty
                                                  ? const Icon(
                                                      Icons.person,
                                                      color: AppConstants.softWhite,
                                                      size: 28,
                                                    )
                                                  : null,
                                            ),
                                            if (isAvailable)
                                              Positioned(
                                                bottom: 0,
                                                right: 0,
                                                child: ScaleTransition(
                                                  scale: _pulseAnimation,
                                                  child: Container(
                                                    width: 16,
                                                    height: 16,
                                                    decoration: BoxDecoration(
                                                      shape: BoxShape.circle,
                                                      color: AppConstants.successColor,
                                                      border: Border.all(
                                                        color: AppConstants.deepPurple,
                                                        width: 2,
                                                      ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: AppConstants.successColor
                                                              .withOpacity(0.8),
                                                          blurRadius: 8,
                                                          spreadRadius: 1,
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        title: Text(
                                          user['full_name'] ?? 'Unknown User',
                                          style: const TextStyle(
                                            color: AppConstants.softWhite,
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        subtitle: Padding(
                                          padding: const EdgeInsets.only(top: 8.0),
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppConstants.accentColor
                                                      .withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: AppConstants.accentColor
                                                        .withOpacity(0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      Icons.location_on,
                                                      color: AppConstants.accentColor,
                                                      size: 14,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      '${distance.toStringAsFixed(1)} km',
                                                      style: const TextStyle(
                                                        color: AppConstants.accentColor,
                                                        fontSize: 12,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Container(
                                                padding: const EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: isAvailable
                                                      ? AppConstants.successColor
                                                          .withOpacity(0.2)
                                                      : AppConstants.mutedGray
                                                          .withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isAvailable
                                                        ? AppConstants.successColor
                                                            .withOpacity(0.5)
                                                        : AppConstants.mutedGray
                                                            .withOpacity(0.5),
                                                    width: 1,
                                                  ),
                                                ),
                                                child: Text(
                                                  isAvailable ? 'Online' : 'Offline',
                                                  style: TextStyle(
                                                    color: isAvailable
                                                        ? AppConstants.successColor
                                                        : AppConstants.mutedGray,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        trailing: Icon(
                                          Icons.arrow_forward_ios,
                                          color: AppConstants.primaryColor,
                                          size: 18,
                                        ),
                                        onTap: () {
                                          // Navigate to provider details (future implementation)
                                        },
                                      ),
                                    );
                                  },
                                ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
