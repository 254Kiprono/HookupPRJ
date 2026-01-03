import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/booking_service.dart';
import 'package:hook_app/models/booking.dart';
import 'package:intl/intl.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  List<Booking> _bookings = [];
  List<Booking> _filteredBookings = [];
  bool _isLoading = true;
  String? _error;
  BookingStatus? _filterStatus;

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
      final bookings = await BookingService.listBookings();
      setState(() {
        _bookings = bookings;
        _filteredBookings = bookings;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  void _filterByStatus(BookingStatus? status) {
    setState(() {
      _filterStatus = status;
      if (status == null) {
        _filteredBookings = _bookings;
      } else {
        _filteredBookings = _bookings.where((b) => b.status == status).toList();
      }
    });
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.completed:
        return AppConstants.successColor;
      case BookingStatus.paid:
        return AppConstants.accentColor;
      case BookingStatus.pending:
      case BookingStatus.servicePending:
        return AppConstants.mutedGray;
      case BookingStatus.paymentPending:
        return Colors.orange;
      case BookingStatus.cancelled:
        return AppConstants.errorColor;
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
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'My Orders',
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
                    IconButton(
                      icon: const Icon(Icons.refresh, color: AppConstants.softWhite),
                      onPressed: _loadBookings,
                    ),
                  ],
                ),
              ),

              // Filter chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _buildFilterChip('All', null),
                    const SizedBox(width: 8),
                    _buildFilterChip('Pending', BookingStatus.pending),
                    const SizedBox(width: 8),
                    _buildFilterChip('Paid', BookingStatus.paid),
                    const SizedBox(width: 8),
                    _buildFilterChip('Completed', BookingStatus.completed),
                    const SizedBox(width: 8),
                    _buildFilterChip('Cancelled', BookingStatus.cancelled),
                  ],
                ),
              ),

              const SizedBox(height: 20),

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
                        : _filteredBookings.isEmpty
                            ? _buildEmptyWidget()
                            : _buildBookingsList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, BookingStatus? status) {
    final isSelected = _filterStatus == status;
    return GestureDetector(
      onTap: () => _filterByStatus(status),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
                  colors: [AppConstants.primaryColor, AppConstants.secondaryColor],
                )
              : null,
          color: isSelected ? null : AppConstants.surfaceColor.withOpacity(0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppConstants.primaryColor
                : AppConstants.mutedGray.withOpacity(0.3),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: AppConstants.softWhite,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  Widget _buildBookingsList() {
    return RefreshIndicator(
      onRefresh: _loadBookings,
      color: AppConstants.primaryColor,
      child: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _filteredBookings.length,
        itemBuilder: (context, index) {
          final booking = _filteredBookings[index];
          return _buildBookingCard(booking);
        },
      ),
    );
  }

  Widget _buildBookingCard(Booking booking) {
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
            color: AppConstants.primaryColor.withOpacity(0.2),
            blurRadius: 15,
            spreadRadius: 1,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Order #${booking.bookingId}',
                  style: const TextStyle(
                    color: AppConstants.softWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: _getStatusColor(booking.status).withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _getStatusColor(booking.status),
                    ),
                  ),
                  child: Text(
                    booking.statusDisplay,
                    style: TextStyle(
                      color: _getStatusColor(booking.status),
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            Divider(color: AppConstants.mutedGray.withOpacity(0.2)),
            const SizedBox(height: 12),

            // Details
            _buildInfoRow(Icons.person_outline, 'Provider ID', booking.providerId),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.attach_money,
              'Service Price',
              'KES ${booking.price.toStringAsFixed(2)}',
            ),
            const SizedBox(height: 8),
            _buildInfoRow(
              Icons.receipt_outlined,
              'Service Fee',
              'KES ${booking.serviceFee.toStringAsFixed(2)}',
            ),

            // BnB info if included
            if (booking.includeBnb && booking.bnbId != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppConstants.accentColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppConstants.accentColor.withOpacity(0.3),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.home,
                          size: 16,
                          color: AppConstants.accentColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'BnB Included',
                          style: TextStyle(
                            color: AppConstants.accentColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _buildInfoRow(
                      Icons.tag,
                      'BnB ID',
                      booking.bnbId!,
                      compact: true,
                    ),
                    const SizedBox(height: 4),
                    _buildInfoRow(
                      Icons.attach_money,
                      'BnB Price',
                      'KES ${booking.bnbPrice?.toStringAsFixed(2) ?? '0.00'}',
                      compact: true,
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 12),
            Divider(color: AppConstants.mutedGray.withOpacity(0.2)),
            const SizedBox(height: 12),

            // Total and date
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total Amount',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'KES ${booking.totalAmount.toStringAsFixed(2)}',
                      style: const TextStyle(
                        color: AppConstants.primaryColor,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'Created',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('MMM dd, yyyy').format(booking.createdAt),
                      style: TextStyle(
                        color: AppConstants.softWhite.withOpacity(0.7),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, {bool compact = false}) {
    return Row(
      children: [
        Icon(
          icon,
          size: compact ? 14 : 16,
          color: AppConstants.primaryColor,
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: TextStyle(
            color: AppConstants.mutedGray,
            fontSize: compact ? 12 : 14,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: compact ? 12 : 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyWidget() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            size: 80,
            color: AppConstants.mutedGray.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No orders yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: AppConstants.softWhite.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your bookings will appear here',
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
            'Error loading orders',
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
