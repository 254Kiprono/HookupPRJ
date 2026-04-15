import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/utils/nav.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/utils/responsive.dart';

class BnBsBrowseScreen extends StatefulWidget {
  const BnBsBrowseScreen({super.key});

  @override
  State<BnBsBrowseScreen> createState() => _BnBsBrowseScreenState();
}

class _BnBsBrowseScreenState extends State<BnBsBrowseScreen> with AutomaticKeepAliveClientMixin {
  
  @override
  bool get wantKeepAlive => true;
  List<BnB> _bnbs = [];
  List<BnB> _filteredBnbs = [];
  bool _isLoading = false;
  String? _error;
  
  final TextEditingController _searchController = TextEditingController();
  RangeValues _priceRange = const RangeValues(0, 10000);
  int? _selectedBnBType;
  bool _availableOnly = false;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_applyFilters);
    _loadInitialResults();
  }

  Future<void> _loadInitialResults() async {
    try {
      final lastSearch = await StorageService.getJson('last_bnb_search');
      if (lastSearch != null) {
        _searchController.text = lastSearch['location'] ?? 'Nairobi';
        if (lastSearch['results'] is List) {
          final List<BnB> cached = (lastSearch['results'] as List).map((b) => BnB.fromJson(b)).toList();
          setState(() {
            _bnbs = cached;
            _applyFilters();
          });
        }
      } else {
        _searchController.text = 'Nairobi';
      }
    } catch (_) {}

    _refreshResults();
  }

  Future<void> _refreshResults() async {
    final location = _searchController.text.isEmpty ? 'Nairobi' : _searchController.text;
    try {
      final bnbs = await BnBService.getBnBsByLocation(location);
      if (mounted) {
        setState(() {
          _bnbs = bnbs;
          _applyFilters();
        });
        // Cache success
        await StorageService.saveJson('last_bnb_search', {
          'location': location,
          'results': bnbs.map((b) => b.toJson()).toList(),
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _searchBnBs() async {
    if (_searchController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a location')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final location = _searchController.text;
      final bnbs = await BnBService.getBnBsByLocation(location);
      
      // Cache the result
      await StorageService.saveJson('last_bnb_search', {
        'location': location,
        'results': bnbs.map((b) => b.toJson()).toList(),
      });

      if (mounted) {
        setState(() {
          _bnbs = bnbs;
          _applyFilters();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    setState(() {
      _filteredBnbs = _bnbs.where((bnb) {
        // Price filter
        if (bnb.priceKES < _priceRange.start || bnb.priceKES > _priceRange.end) {
          return false;
        }
        
        // Type filter
        if (_selectedBnBType != null && bnb.bnbType != _selectedBnBType) {
          return false;
        }
        
        // Availability filter
        if (_availableOnly && !bnb.available) {
          return false;
        }
        
        return true;
      }).toList();
    });
  }

  String _getBnBTypeName(int type) {
    switch (type) {
      case 0:
        return 'Studio';
      case 1:
        return '1 Bedroom';
      case 2:
        return '2 Bedrooms';
      case 3:
        return '3 Bedrooms';
      case 4:
        return '4 Bedrooms';
      default:
        return 'Unknown';
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: AppConstants.darkBackground,
      appBar: AppBar(
        title: const Text('Browse BnBs', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Nav.safePop(context),
        ),
      ),
      body: Column(
        children: [
          _buildSearchArea(),
          if (_bnbs.isNotEmpty) _buildFilterArea(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                : _error != null
                    ? _buildErrorWidget()
                    : _filteredBnbs.isEmpty && _bnbs.isEmpty
                        ? _buildEmptyWidget()
                        : _filteredBnbs.isEmpty
                            ? _buildNoResultsWidget()
                            : _buildBnBList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchArea() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppConstants.cardNavy,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.white.withOpacity(0.05)),
              ),
              child: TextField(
                controller: _searchController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'Where are you looking?',
                  hintStyle: TextStyle(color: AppConstants.mutedGray),
                  border: InputBorder.none,
                  icon: Icon(Icons.location_on_rounded, color: AppConstants.primaryColor, size: 20),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _searchBnBs,
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppConstants.primaryColor,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.search_rounded, color: Colors.white, size: 24),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterArea() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        children: [
          _buildFilterChip('Price Range', Icons.tune_rounded, () => _showPriceFilter()),
          const SizedBox(width: 12),
          _buildFilterChip('Type', Icons.home_work_rounded, () => _showTypeFilter()),
          const SizedBox(width: 12),
          _buildAvailabilityToggle(),
          const SizedBox(width: 24),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 16, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildAvailabilityToggle() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _availableOnly = !_availableOnly;
          _applyFilters();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _availableOnly ? AppConstants.primaryColor.withOpacity(0.1) : AppConstants.cardNavy,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _availableOnly ? AppConstants.primaryColor : Colors.white.withOpacity(0.05)),
        ),
        child: Text(
          'Available Only',
          style: TextStyle(
            color: _availableOnly ? AppConstants.primaryColor : Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  void _showPriceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Filter by Price', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                divisions: 20,
                activeColor: AppConstants.primaryColor,
                inactiveColor: Colors.white.withOpacity(0.1),
                labels: RangeLabels('KSh ${_priceRange.start.round()}', 'KSh ${_priceRange.end.round()}'),
                onChanged: (values) {
                  setModalState(() => _priceRange = values);
                },
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    setState(() => _applyFilters());
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filter'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.cardNavy,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Property Type', style: TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 24),
            ...List.generate(5, (index) {
              final isSelected = _selectedBnBType == index;
              return GestureDetector(
                onTap: () {
                  setState(() {
                    _selectedBnBType = index;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected ? AppConstants.primaryColor.withOpacity(0.1) : Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isSelected ? AppConstants.primaryColor : Colors.transparent),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_getBnBTypeName(index), style: TextStyle(color: isSelected ? Colors.white : AppConstants.mutedGray, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
                      if (isSelected) const Icon(Icons.check_circle_rounded, color: AppConstants.primaryColor, size: 20),
                    ],
                  ),
                ),
              );
            }),
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedBnBType = null;
                  _applyFilters();
                });
                Navigator.pop(context);
              },
              child: const Text('Clear Filter', style: TextStyle(color: AppConstants.errorColor)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBnBList() {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: _filteredBnbs.length,
      itemBuilder: (context, index) => _buildBnBCard(_filteredBnbs[index]),
    );
  }

  Widget _buildBnBCard(BnB bnb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      decoration: BoxDecoration(
        color: AppConstants.cardNavy,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // If we had images, they would go here. For now, solid placeholder or icon hero
          Container(
            height: 160,
            width: double.infinity,
            decoration: BoxDecoration(
              color: AppConstants.primaryColor.withOpacity(0.05),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: const Center(child: Icon(Icons.home_work_rounded, color: AppConstants.primaryColor, size: 48)),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(bnb.name, style: const TextStyle(color: Colors.white, fontFamily: 'Sora', fontSize: 18, fontWeight: FontWeight.bold))),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: (bnb.available ? AppConstants.successColor : AppConstants.errorColor).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        bnb.availabilityStatus,
                        style: TextStyle(color: bnb.available ? AppConstants.successColor : AppConstants.errorColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded, color: AppConstants.mutedGray, size: 14),
                    const SizedBox(width: 6),
                    Text(bnb.location, style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
                    const SizedBox(width: 12),
                    const Icon(Icons.king_bed_rounded, color: AppConstants.mutedGray, size: 14),
                    const SizedBox(width: 6),
                    Text(_getBnBTypeName(bnb.bnbType), style: const TextStyle(color: AppConstants.mutedGray, fontSize: 13)),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('KSh ${bnb.priceKES.toStringAsFixed(0)} / mo', style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                    ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0)),
                      child: const Text('Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.house_siding_rounded, size: 64, color: AppConstants.mutedGray.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('Search for properties', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Enter a location to see listings', style: TextStyle(color: AppConstants.mutedGray)),
        ],
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off_rounded, size: 64, color: AppConstants.mutedGray.withOpacity(0.2)),
          const SizedBox(height: 16),
          const Text('No properties found', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          const Text('Try adjusting filters or location', style: TextStyle(color: AppConstants.mutedGray)),
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
          const Text('Something went wrong', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(_error ?? 'Unknown error', style: const TextStyle(color: AppConstants.mutedGray)),
        ],
      ),
    );
  }
}
