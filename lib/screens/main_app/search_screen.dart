// lib/screens/main_app/search_screen.dart
import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/user_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:hook_app/utils/responsive.dart';

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
  bool _hasSearched = false;
  String? _lastQuery;
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
      _hasSearched = true;
      _lastQuery = region?.trim().isEmpty == true ? null : region?.trim();
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
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Find Providers', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Column(
        children: [
          _buildSearchOverlay(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                : _errorMessage != null
                    ? _buildErrorWidget()
                    : _providers.isEmpty
                        ? _buildEmptyWidget()
                        : ListView.builder(
                            physics: const BouncingScrollPhysics(),
                            padding: const EdgeInsets.all(20),
                            itemCount: _providers.length,
                            itemBuilder: (context, index) {
                              final item = _providers[index];
                              final user = item['user'] ?? {};
                              final distance = item['distance_km'] ?? 0.0;
                              return _buildProviderCard(user, distance);
                            },
                          ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchOverlay() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppConstants.cardNavy,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: TextField(
              controller: _locationController,
              focusNode: _searchFocusNode,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                hintText: 'Enter location (e.g. Westlands)',
                hintStyle: const TextStyle(color: AppConstants.mutedGray),
                border: InputBorder.none,
                icon: const Icon(Icons.location_on_rounded, color: AppConstants.primaryColor, size: 20),
                suffixIcon: _locationController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, color: AppConstants.mutedGray, size: 20),
                        onPressed: () => setState(() => _locationController.clear()),
                      )
                    : null,
              ),
              onSubmitted: (val) => _searchProviders(val),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _searchProviders(_locationController.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppConstants.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              child: const Text('Search Now', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProviderCard(dynamic user, double distance) {
    final isAvailable = (user['isActive'] ?? user['is_active']) == true;
    final String fullName = user['full_name'] ?? 'Unknown';
    
    return GestureDetector(
      onTap: () {
        // Navigate to details
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppConstants.primaryColor.withOpacity(0.1),
                  child: Text(fullName[0], style: const TextStyle(color: AppConstants.primaryColor, fontWeight: FontWeight.bold, fontSize: 20)),
                ),
                if (isAvailable)
                  Positioned(
                    bottom: 2,
                    right: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: AppConstants.successColor,
                        shape: BoxShape.circle,
                        border: Border.all(color: AppConstants.cardNavy, width: 2),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fullName, style: const TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 17, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.near_me_rounded, color: AppConstants.primaryColor, size: 14),
                      const SizedBox(width: 4),
                      Text('${distance.toStringAsFixed(1)} km away', style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
                      const SizedBox(width: 12),
                      Text(isAvailable ? 'Online' : 'Offline', style: TextStyle(color: isAvailable ? AppConstants.successColor : AppConstants.mutedGray, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.arrow_forward_ios_rounded, color: Colors.white24, size: 16),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_rounded, size: 64, color: AppConstants.mutedGray.withOpacity(0.2)),
          const SizedBox(height: 16),
          Text(_hasSearched ? 'No providers found' : 'Find providers near you', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(_hasSearched ? 'Try a different location' : 'Enter a location to start searching', style: const TextStyle(color: AppConstants.mutedGray)),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline_rounded, size: 64, color: AppConstants.errorColor),
          const SizedBox(height: 16),
          const Text('Search failed', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(_errorMessage!, style: const TextStyle(color: AppConstants.mutedGray), textAlign: TextAlign.center),
          ),
          const SizedBox(height: 24),
          ElevatedButton(onPressed: () => _searchProviders(_locationController.text), child: const Text('Retry')),
        ],
      ),
    );
  }
}
