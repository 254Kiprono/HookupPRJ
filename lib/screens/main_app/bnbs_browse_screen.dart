import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/models/bnb.dart';

class BnBsBrowseScreen extends StatefulWidget {
  const BnBsBrowseScreen({super.key});

  @override
  State<BnBsBrowseScreen> createState() => _BnBsBrowseScreenState();
}

class _BnBsBrowseScreenState extends State<BnBsBrowseScreen> {
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
      final bnbs = await BnBService.getBnBsByLocation(_searchController.text);
      setState(() {
        _bnbs = bnbs;
        _applyFilters();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
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
              // Header
              Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text(
                  'Browse BnBs',
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

              // Search bar
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: AppConstants.softWhite),
                        decoration: InputDecoration(
                          hintText: 'Enter location...',
                          hintStyle: TextStyle(color: AppConstants.mutedGray),
                          prefixIcon: Icon(Icons.search, color: AppConstants.primaryColor),
                          filled: true,
                          fillColor: AppConstants.surfaceColor.withOpacity(0.5),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.search, color: AppConstants.softWhite),
                        onPressed: _searchBnBs,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Filters
              if (_bnbs.isNotEmpty) ...[
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    children: [
                      _buildFilterButton(
                        'Price Range',
                        Icons.attach_money,
                        () => _showPriceFilter(),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterButton(
                        'Type',
                        Icons.home,
                        () => _showTypeFilter(),
                      ),
                      const SizedBox(width: 8),
                      _buildFilterChip(
                        'Available Only',
                        _availableOnly,
                        () {
                          setState(() {
                            _availableOnly = !_availableOnly;
                            _applyFilters();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Content
              Expanded(
                child: _isLoading
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppConstants.primaryColor,
                        ),
                      )
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
        ),
      ),
    );
  }

  Widget _buildFilterButton(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: AppConstants.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppConstants.primaryColor.withOpacity(0.3),
          ),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppConstants.primaryColor),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                color: AppConstants.softWhite,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          gradient: isActive
              ? const LinearGradient(
                  colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                )
              : null,
          color: isActive ? null : AppConstants.surfaceColor.withOpacity(0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive
                ? AppConstants.primaryColor
                : AppConstants.mutedGray.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppConstants.softWhite,
            fontWeight: isActive ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  void _showPriceFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.deepPurple,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Price Range (KES)',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              RangeSlider(
                values: _priceRange,
                min: 0,
                max: 10000,
                divisions: 100,
                activeColor: AppConstants.primaryColor,
                inactiveColor: AppConstants.mutedGray.withOpacity(0.3),
                labels: RangeLabels(
                  _priceRange.start.round().toString(),
                  _priceRange.end.round().toString(),
                ),
                onChanged: (values) {
                  setModalState(() {
                    _priceRange = values;
                  });
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'KES ${_priceRange.start.round()}',
                    style: const TextStyle(color: AppConstants.softWhite),
                  ),
                  Text(
                    'KES ${_priceRange.end.round()}',
                    style: const TextStyle(color: AppConstants.softWhite),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppConstants.primaryColor,
                  minimumSize: const Size(double.infinity, 48),
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

  void _showTypeFilter() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppConstants.deepPurple,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'BnB Type',
              style: TextStyle(
                color: AppConstants.softWhite,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ...List.generate(5, (index) {
              return ListTile(
                title: Text(
                  _getBnBTypeName(index),
                  style: const TextStyle(color: AppConstants.softWhite),
                ),
                leading: Radio<int>(
                  value: index,
                  groupValue: _selectedBnBType,
                  activeColor: AppConstants.primaryColor,
                  onChanged: (value) {
                    setState(() {
                      _selectedBnBType = value;
                      _applyFilters();
                    });
                    Navigator.pop(context);
                  },
                ),
              );
            }),
            ListTile(
              title: const Text(
                'All Types',
                style: TextStyle(color: AppConstants.softWhite),
              ),
              leading: Radio<int?>(
                value: null,
                groupValue: _selectedBnBType,
                activeColor: AppConstants.primaryColor,
                onChanged: (value) {
                  setState(() {
                    _selectedBnBType = null;
                    _applyFilters();
                  });
                  Navigator.pop(context);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBnBList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _filteredBnbs.length,
      itemBuilder: (context, index) {
        final bnb = _filteredBnbs[index];
        return _buildBnBCard(bnb);
      },
    );
  }

  Widget _buildBnBCard(BnB bnb) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.7),
            AppConstants.surfaceColor.withOpacity(0.5),
          ],
        ),
        border: Border.all(
          color: AppConstants.primaryColor.withOpacity(0.3),
        ),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
            const SizedBox(height: 12),
            Row(
              children: [
                Icon(Icons.location_on, size: 16, color: AppConstants.primaryColor),
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
                Icon(Icons.home, size: 16, color: AppConstants.accentColor),
                const SizedBox(width: 4),
                Text(
                  _getBnBTypeName(bnb.bnbType),
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
                Icon(Icons.map, size: 16, color: AppConstants.primaryColor),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    bnb.address,
                    style: TextStyle(
                      color: AppConstants.softWhite.withOpacity(0.7),
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (bnb.callNumber != null && bnb.callNumber!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.phone, size: 16, color: AppConstants.accentColor),
                  const SizedBox(width: 4),
                  Text(
                    bnb.callNumber!,
                    style: TextStyle(
                      color: AppConstants.softWhite.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Divider(color: AppConstants.mutedGray.withOpacity(0.2)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'KES ${bnb.priceKES.toStringAsFixed(0)} / night',
                  style: const TextStyle(
                    color: AppConstants.primaryColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
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
          Icon(
            Icons.search,
            size: 80,
            color: AppConstants.mutedGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'Search for BnBs',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.softWhite.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Enter a location to find available BnBs',
            style: TextStyle(
              fontSize: 14,
              color: AppConstants.mutedGray.withOpacity(0.6),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.filter_list_off,
            size: 80,
            color: AppConstants.mutedGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No results found',
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
        ],
      ),
    );
  }
}
