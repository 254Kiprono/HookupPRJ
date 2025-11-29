import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/app/routes.dart';
import 'package:hook_app/services/booking_service.dart';
import 'package:hook_app/services/bnb_service.dart';
import 'package:hook_app/services/storage_service.dart';
import 'package:hook_app/services/api_service.dart';
import 'package:hook_app/models/bnb.dart';
import 'package:hook_app/models/bnb_session.dart';

class BookingScreen extends StatefulWidget {
  final int providerId;
  final String providerName;
  final double price;

  const BookingScreen({
    super.key,
    required this.providerId,
    required this.providerName,
    required this.price,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  bool _isLoading = false;
  String? _errorMessage;
  bool _includeBnB = false;
  BnB? _selectedBnB;
  BnBSession? _selectedSession; // Added for session selection
  String? _userFullName;
  String? _userPhone;
  int? _userId;
  List<BnB> _availableBnBs = [];
  bool _isLoadingBnBs = false;
  final _locationController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchUserProfile();
  }

  @override
  void dispose() {
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _fetchUserProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final data = await ApiService.getUserProfile();
      final userId = await StorageService.getUserId();
      
      setState(() {
        _userFullName = data['fullName'] ?? 'User';
        _userPhone = data['phone'] ?? 'N/A';
        _userId = userId != null ? int.tryParse(userId) : null;
        _isLoading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load user profile: $error';
        });
      }
    }
  }

  Future<void> _searchBnBs(String location) async {
    if (location.trim().isEmpty) return;

    setState(() {
      _isLoadingBnBs = true;
    });

    try {
      final bnbs = await BnBService.getBnBsByLocation(location.trim());
      
      setState(() {
        _availableBnBs = bnbs.where((bnb) => bnb.available).toList();
        _isLoadingBnBs = false;
      });
    } catch (error) {
      setState(() {
        _isLoadingBnBs = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error searching BnBs: $error'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  Future<void> _createBooking() async {
    if (_userId == null) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await BookingService.createBooking(
        providerId: widget.providerId.toString(),
        price: widget.price,
        includeBnb: _includeBnB,
        bnbId: _selectedBnB?.bnbId.toString(),
        bnbPrice: _selectedBnB?.priceKES, // Changed from price
        payerName: _userFullName ?? 'User',
        clientPhone: _userPhone ?? '',
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking created! ID: ${response['booking_id']}'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        
        // Navigate to bookings screen
        Navigator.pushReplacementNamed(context, Routes.bookings);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Error creating booking: $e';
        });
      }
    }
  }

  double get _totalPrice {
    double total = widget.price + 100.0; // Base price + service fee
    if (_includeBnB && _selectedBnB != null && _selectedSession != null) {
      total += _selectedSession!.price;
    }
    return total;
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
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _errorMessage != null
                        ? _buildErrorWidget()
                        : _buildBookingContent(),
              ),
            ],
          ),
        ),
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
            icon: const Icon(
              Icons.arrow_back,
              color: AppConstants.softWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Book ${widget.providerName}',
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '\$${widget.price.toStringAsFixed(2)}/hr',
                  style: TextStyle(
                    color: AppConstants.accentColor.withOpacity(0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBookingContent() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildPriceBreakdown(),
          const SizedBox(height: 24),
          _buildBnBToggle(),
          if (_includeBnB) ...[
            const SizedBox(height: 20),
            _buildBnBSearch(),
            if (_availableBnBs.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildBnBList(),
            ],
            if (_selectedBnB != null) ...[
              const SizedBox(height: 20),
              _buildSessionSelector(),
            ],
          ],
          const SizedBox(height: 32),
          _buildConfirmButton(),
        ],
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    return Container(
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
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Price Breakdown',
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildPriceRow('Service', widget.price),
          const SizedBox(height: 8),
          _buildPriceRow('Service Fee', 100.0),
          if (_includeBnB && _selectedBnB != null && _selectedSession != null) ...[
            const SizedBox(height: 8),
            _buildPriceRow(
              'BnB (${_selectedBnB!.name}) - ${_selectedSession!.displayName}',
              _selectedSession!.price,
            ),
          ],
          const Divider(
            color: AppConstants.mutedGray,
            height: 24,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Total',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '\$${_totalPrice.toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppConstants.accentColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriceRow(String label, double amount) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            color: AppConstants.softWhite.withOpacity(0.8),
            fontSize: 16,
          ),
        ),
        Text(
          '\$${amount.toStringAsFixed(2)}',
          style: const TextStyle(
            color: AppConstants.softWhite,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildBnBToggle() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppConstants.deepPurple.withOpacity(0.6),
            AppConstants.surfaceColor.withOpacity(0.4),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _includeBnB 
              ? AppConstants.primaryColor.withOpacity(0.5)
              : AppConstants.mutedGray.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Row(
            children: [
              Icon(Icons.home, color: AppConstants.primaryColor, size: 28),
              SizedBox(width: 12),
              Text(
                'Include BnB',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          Switch(
            value: _includeBnB,
            onChanged: (value) {
              setState(() {
                _includeBnB = value;
                if (!_includeBnB) {
                  _selectedBnB = null;
                  _selectedSession = null; // Clear session when BnB is deselected
                  _availableBnBs = [];
                }
              });
            },
            activeColor: AppConstants.successColor,
            inactiveThumbColor: AppConstants.mutedGray,
          ),
        ],
      ),
    );
  }

  Widget _buildBnBSearch() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Search BnBs',
          style: TextStyle(
            color: AppConstants.softWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppConstants.deepPurple.withOpacity(0.6),
                AppConstants.surfaceColor.withOpacity(0.4),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AppConstants.primaryColor.withOpacity(0.3),
              width: 1,
            ),
          ),
          child: TextField(
            controller: _locationController,
            style: const TextStyle(color: AppConstants.softWhite),
            decoration: InputDecoration(
              hintText: 'Enter location',
              hintStyle: TextStyle(color: AppConstants.softWhite.withOpacity(0.5)),
              prefixIcon: const Icon(Icons.search, color: AppConstants.primaryColor),
              suffixIcon: _isLoadingBnBs
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppConstants.primaryColor,
                        ),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward, color: AppConstants.accentColor),
                      onPressed: () => _searchBnBs(_locationController.text),
                    ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            ),
            onSubmitted: _searchBnBs,
          ),
        ),
      ],
    );
  }

  Widget _buildBnBList() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Available BnBs (${_availableBnBs.length})',
          style: const TextStyle(
            color: AppConstants.softWhite,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _availableBnBs.length,
          itemBuilder: (context, index) {
            return _buildBnBCard(_availableBnBs[index]);
          },
        ),
      ],
    );
  }

  Widget _buildBnBCard(BnB bnb) {
    final isSelected = _selectedBnB?.bnbId == bnb.bnbId;

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
          color: isSelected 
              ? AppConstants.successColor
              : AppConstants.primaryColor.withOpacity(0.3),
          width: isSelected ? 2 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            setState(() {
              _selectedBnB = isSelected ? null : bnb;
              _selectedSession = null; // Clear session when changing BnB
            });
          },
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                if (isSelected)
                  const Icon(
                    Icons.check_circle,
                    color: AppConstants.successColor,
                    size: 28,
                  )
                else
                  Icon(
                    Icons.radio_button_unchecked,
                    color: AppConstants.mutedGray.withOpacity(0.5),
                    size: 28,
                  ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bnb.name,
                        style: const TextStyle(
                          color: AppConstants.softWhite,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
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
                            bnb.location,
                            style: TextStyle(
                              color: AppConstants.softWhite.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                Text(
                  bnb.formattedPrice,
                  style: const TextStyle(
                    color: AppConstants.accentColor,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSessionSelector() {
    if (_selectedBnB == null || _selectedBnB!.sessions.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppConstants.errorColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppConstants.errorColor.withOpacity(0.3)),
        ),
        child: const Row(
          children: [
            Icon(Icons.info_outline, color: AppConstants.errorColor),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'No sessions available for this BnB. Using base price.',
                style: TextStyle(color: AppConstants.errorColor),
              ),
            ),
          ],
        ),
      );
    }

    final validSessions = _selectedBnB!.sessions.where((s) => s.isValid).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Select Booking Duration',
          style: TextStyle(
            color: AppConstants.softWhite,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...validSessions.map((session) {
          final isSelected = _selectedSession?.duration == session.duration;
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
                color: isSelected
                    ? AppConstants.successColor
                    : AppConstants.primaryColor.withOpacity(0.3),
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _selectedSession = isSelected ? null : session;
                  });
                },
                borderRadius: BorderRadius.circular(16),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      if (isSelected)
                        const Icon(
                          Icons.check_circle,
                          color: AppConstants.successColor,
                          size: 28,
                        )
                      else
                        Icon(
                          Icons.radio_button_unchecked,
                          color: AppConstants.mutedGray.withOpacity(0.5),
                          size: 28,
                        ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.displayName,
                              style: const TextStyle(
                                color: AppConstants.softWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.duration} hours',
                              style: TextStyle(
                                color: AppConstants.softWhite.withOpacity(0.7),
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        session.formattedPrice,
                        style: const TextStyle(
                          color: AppConstants.accentColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  Widget _buildConfirmButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [AppConstants.primaryColor, AppConstants.accentColor],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppConstants.primaryColor.withOpacity(0.4),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: _isLoading ? null : _createBooking,
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
                : const Text(
                    'Confirm Booking',
                    style: TextStyle(
                      color: AppConstants.softWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
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
          const Text(
            'Error',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.softWhite,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              _errorMessage ?? 'Unknown error',
              style: TextStyle(
                fontSize: 14,
                color: AppConstants.mutedGray.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _fetchUserProfile,
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
