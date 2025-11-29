import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/booking_service.dart';
import 'package:hook_app/models/booking.dart';

class BnBBookingHistoryScreen extends StatefulWidget {
  const BnBBookingHistoryScreen({super.key});

  @override
  State<BnBBookingHistoryScreen> createState() => _BnBBookingHistoryScreenState();
}

class _BnBBookingHistoryScreenState extends State<BnBBookingHistoryScreen> {
  List<Booking> _bookings = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final bookings = await BookingService.getBookingsByBnbOwner();
      
      setState(() {
        _bookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      print('[BOOKING HISTORY] Error loading bookings: $e');
      
      String errorMessage;
      if (e.toString().contains('authorization token not provided') || 
          e.toString().contains('Unauthenticated')) {
        // This is a specific backend issue where internal service calls fail auth
        // We'll show a friendly message but log the real issue
        errorMessage = 'System error: Unable to verify booking details. Please contact support.';
      } else if (e.toString().contains('ClientException') || e.toString().contains('Failed to fetch')) {
        errorMessage = 'Unable to connect to server. Please check your internet connection.';
      } else {
        errorMessage = 'Failed to load bookings. Please try again later.';
      }

      setState(() {
        _error = errorMessage;
        _isLoading = false;
      });
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
              if (!_isLoading && _error == null) _buildRevenueCard(),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? _buildErrorWidget()
                        : _buildBookingList(),
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
          const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Booking History',
                style: TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'View all BnB bookings',
                style: TextStyle(
                  color: AppConstants.mutedGray,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRevenueCard() {
    final totalRevenue = _bookings.fold<double>(
      0.0,
      (sum, booking) => booking.includeBnb && booking.bnbPrice != null 
          ? sum + booking.bnbPrice! 
          : sum,
    );
    final paidBookings = _bookings.where((b) => b.status == BookingStatus.paid || b.status == BookingStatus.completed).length;

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
          color: AppConstants.accentColor.withOpacity(0.3),
          width: 1.5,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildRevenueItem('Total Bookings', _bookings.length.toString()),
          Container(
            width: 1,
            height: 40,
            color: AppConstants.mutedGray.withOpacity(0.3),
          ),
          _buildRevenueItem('Paid', paidBookings.toString()),
          Container(
            width: 1,
            height: 40,
            color: AppConstants.mutedGray.withOpacity(0.3),
          ),
          _buildRevenueItem('Revenue', '\$${totalRevenue.toStringAsFixed(2)}'),
        ],
      ),
    );
  }

  Widget _buildRevenueItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: AppConstants.accentColor,
            fontSize: 20,
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

  Widget _buildBookingList() {
    if (_bookings.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 80,
              color: AppConstants.mutedGray.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No bookings yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: AppConstants.softWhite.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Bookings will appear here once customers book your BnBs',
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
      onRefresh: _loadBookings,
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _bookings.length,
        itemBuilder: (context, index) {
          return _buildBookingCard(_bookings[index]);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
    Color statusColor;
    switch (booking.status) {
      case BookingStatus.paid:
      case BookingStatus.completed:
        statusColor = AppConstants.successColor;
        break;
      case BookingStatus.cancelled:
        statusColor = AppConstants.errorColor;
        break;
      case BookingStatus.paymentPending:
      case BookingStatus.servicePending:
        statusColor = AppConstants.accentColor;
        break;
      default:
        statusColor = AppConstants.mutedGray;
    }

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
          color: statusColor.withOpacity(0.5),
          width: 1.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Booking #${booking.bookingId}',
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    booking.statusDisplay,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (booking.includeBnb && booking.bnbId != null) ...[
              Row(
                children: [
                  const Icon(Icons.home, size: 16, color: AppConstants.primaryColor),
                  const SizedBox(width: 8),
                  Text(
                    'BnB ID: ${booking.bnbId}',
                    style: TextStyle(
                      color: AppConstants.softWhite.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
            ],
            Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Client: ${booking.clientId}',
                  style: TextStyle(
                    color: AppConstants.softWhite.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16, color: AppConstants.primaryColor),
                const SizedBox(width: 8),
                Text(
                  'Booked: ${_formatDate(booking.createdAt)}',
                  style: TextStyle(
                    color: AppConstants.softWhite.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(color: AppConstants.mutedGray, height: 1),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (booking.includeBnb && booking.bnbPrice != null)
                  Text(
                    'BnB Amount:',
                    style: TextStyle(
                      color: AppConstants.softWhite.withOpacity(0.7),
                      fontSize: 14,
                    ),
                  ),
                if (booking.includeBnb && booking.bnbPrice != null)
                  Text(
                    '\$${booking.bnbPrice!.toStringAsFixed(2)}',
                    style: const TextStyle(
                      color: AppConstants.accentColor,
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

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
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
            'Error loading bookings',
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
            onPressed: _loadBookings,
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
