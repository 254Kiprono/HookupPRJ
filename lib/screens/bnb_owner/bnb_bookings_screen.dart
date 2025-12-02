import 'package:flutter/material.dart';
import 'package:hook_app/utils/constants.dart';
import 'package:hook_app/services/booking_service.dart';
import 'package:hook_app/models/booking.dart';
import 'package:hook_app/services/wallet_service.dart';

class BnBBookingsScreen extends StatefulWidget {
  const BnBBookingsScreen({super.key});

  @override
  State<BnBBookingsScreen> createState() => _BnBBookingsScreenState();
}

class _BnBBookingsScreenState extends State<BnBBookingsScreen> {
  bool _isLoading = true;
  List<Booking> _bookings = [];
  String _selectedFilter = 'all'; // 'all', 'pending', 'payment_pending', 'paid', 'completed', 'cancelled'

  @override
  void initState() {
    super.initState();
    _loadBookings();
  }

  Future<void> _loadBookings() async {
    setState(() => _isLoading = true);

    try {
      final bookings = await BookingService.getBookingsByBnbOwner();
      
      if (mounted) {
        setState(() {
          _bookings = bookings;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading bookings: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        
        // Parse error message to provide more helpful feedback
        String errorMessage = 'Failed to load bookings';
        String errorDetails = e.toString();
        
        if (errorDetails.contains('invalid UTF-8')) {
          errorMessage = 'Unable to load bookings due to data encoding issue. Please check your BnB details for special characters.';
        } else if (errorDetails.contains('500')) {
          errorMessage = 'Server error occurred. Please try again later or contact support.';
        } else if (errorDetails.contains('401') || errorDetails.contains('Unauthorized')) {
          errorMessage = 'Authentication failed. Please log in again.';
        } else if (errorDetails.contains('403') || errorDetails.contains('Permission')) {
          errorMessage = 'You do not have permission to view these bookings.';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  errorMessage,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  'Error: ${errorDetails.length > 100 ? errorDetails.substring(0, 100) + "..." : errorDetails}',
                  style: const TextStyle(fontSize: 12),
                ),
              ],
            ),
            backgroundColor: AppConstants.errorColor,
            duration: const Duration(seconds: 5),
            action: SnackBarAction(
              label: 'Retry',
              textColor: AppConstants.softWhite,
              onPressed: () => _loadBookings(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _handlePayment(Booking booking) async {
    // When a booking is paid, create an earning entry
    if (booking.includeBnb && booking.bnbPrice != null && booking.bnbPrice! > 0) {
      try {
        await WalletService.createEarning(
          bookingId: booking.bookingId,
          bnbId: booking.bnbId ?? '',
          bnbName: 'BnB ${booking.bnbId}', // You might want to fetch actual BnB name
          clientName: booking.clientId, // You might want to fetch actual client name
          amount: booking.bnbPrice!,
          reference: 'BOOKING-${booking.bookingId}',
        );

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Earning recorded successfully'),
              backgroundColor: AppConstants.successColor,
            ),
          );
        }
      } catch (e) {
        print('Error creating earning: $e');
      }
    }
  }

  Future<void> _updateBookingStatus(Booking booking, BookingStatus newStatus) async {
    try {
      await BookingService.updateBookingStatus(
        bookingId: booking.bookingId,
        status: newStatus,
      );

      // If status is paid or completed, create earning entry
      if (newStatus == BookingStatus.paid || newStatus == BookingStatus.completed) {
        await _handlePayment(booking);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Booking status updated to ${newStatus.toString().split('.').last}'),
            backgroundColor: AppConstants.successColor,
          ),
        );
        _loadBookings();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error updating booking: $e'),
            backgroundColor: AppConstants.errorColor,
          ),
        );
      }
    }
  }

  List<Booking> get _filteredBookings {
    if (_selectedFilter == 'all') return _bookings;
    
    BookingStatus? status;
    switch (_selectedFilter) {
      case 'pending':
        status = BookingStatus.pending;
        break;
      case 'payment_pending':
        status = BookingStatus.paymentPending;
        break;
      case 'paid':
        status = BookingStatus.paid;
        break;
      case 'completed':
        status = BookingStatus.completed;
        break;
      case 'cancelled':
        status = BookingStatus.cancelled;
        break;
    }
    
    if (status != null) {
      return _bookings.where((b) => b.status == status).toList();
    }
    return _bookings;
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
                    ? const Center(child: CircularProgressIndicator(color: AppConstants.primaryColor))
                    : Column(
                        children: [
                          _buildFilterTabs(),
                          Expanded(
                            child: _buildBookingsList(),
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
          const Text(
            'My Bookings',
            style: TextStyle(
              color: AppConstants.softWhite,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const Spacer(),
          IconButton(
            onPressed: _loadBookings,
            icon: const Icon(
              Icons.refresh,
              color: AppConstants.softWhite,
              size: 24,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTabs() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            _buildFilterChip('all', 'All'),
            const SizedBox(width: 8),
            _buildFilterChip('payment_pending', 'Payment Pending'),
            const SizedBox(width: 8),
            _buildFilterChip('paid', 'Paid'),
            const SizedBox(width: 8),
            _buildFilterChip('completed', 'Completed'),
            const SizedBox(width: 8),
            _buildFilterChip('cancelled', 'Cancelled'),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return FilterChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (selected) {
        if (selected) {
          setState(() => _selectedFilter = value);
        }
      },
      selectedColor: AppConstants.primaryColor.withOpacity(0.3),
      checkmarkColor: AppConstants.primaryColor,
      labelStyle: TextStyle(
        color: isSelected ? AppConstants.primaryColor : AppConstants.mutedGray,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
      ),
      side: BorderSide(
        color: isSelected
            ? AppConstants.primaryColor
            : AppConstants.mutedGray.withOpacity(0.3),
      ),
    );
  }

  Widget _buildBookingsList() {
    final filtered = _filteredBookings;
    
    if (filtered.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            children: [
              Icon(
                Icons.calendar_today,
                size: 64,
                color: AppConstants.mutedGray.withOpacity(0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'No bookings found',
                style: TextStyle(
                  color: AppConstants.mutedGray,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Sort by creation date (newest first)
    filtered.sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final booking = filtered[index];
        return _buildBookingCard(booking);
      },
    );
  }

  Widget _buildBookingCard(Booking booking) {
    final statusColor = _getStatusColor(booking.status);
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Booking #${booking.bookingId.substring(0, 8)}',
                      style: const TextStyle(
                        color: AppConstants.softWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Client ID: ${booking.clientId}',
                      style: TextStyle(
                        color: AppConstants.mutedGray,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: statusColor),
                ),
                child: Text(
                  booking.statusDisplay,
                  style: TextStyle(
                    color: statusColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (booking.includeBnb && booking.bnbId != null) ...[
            _buildDetailRow(Icons.home, 'BnB ID', booking.bnbId!),
            const SizedBox(height: 8),
          ],
          _buildDetailRow(
            Icons.attach_money,
            'Service Price',
            'KES ${booking.price.toStringAsFixed(2)}',
          ),
          if (booking.includeBnb && booking.bnbPrice != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.bed,
              'BnB Price',
              'KES ${booking.bnbPrice!.toStringAsFixed(2)}',
            ),
          ],
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.account_balance_wallet,
            'Total Amount',
            'KES ${booking.totalAmount.toStringAsFixed(2)}',
          ),
          const SizedBox(height: 8),
          _buildDetailRow(
            Icons.access_time,
            'Created',
            _formatDateTime(booking.createdAt),
          ),
          if (booking.completedAt != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.check_circle,
              'Completed',
              _formatDateTime(booking.completedAt!),
            ),
          ],
          if (booking.paymentId != null) ...[
            const SizedBox(height: 8),
            _buildDetailRow(
              Icons.payment,
              'Payment ID',
              booking.paymentId!,
            ),
          ],
          const SizedBox(height: 16),
          // Show action buttons based on booking status
          if (booking.status == BookingStatus.paymentPending) ...[
            // Payment pending - can mark as paid or cancel
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Mark as Paid',
                    AppConstants.successColor,
                    () => _updateBookingStatus(booking, BookingStatus.paid),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Cancel',
                    AppConstants.errorColor,
                    () => _updateBookingStatus(booking, BookingStatus.cancelled),
                  ),
                ),
              ],
            ),
          ] else if (booking.status == BookingStatus.paid) ...[
            // Paid - can mark as completed or cancel
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Mark as Completed',
                    AppConstants.successColor,
                    () => _updateBookingStatus(booking, BookingStatus.completed),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Cancel',
                    AppConstants.errorColor,
                    () => _updateBookingStatus(booking, BookingStatus.cancelled),
                  ),
                ),
              ],
            ),
          ] else if (booking.status == BookingStatus.pending) ...[
            // Pending - can mark as paid or cancel
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    'Mark as Paid',
                    AppConstants.successColor,
                    () => _updateBookingStatus(booking, BookingStatus.paid),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildActionButton(
                    'Cancel',
                    AppConstants.errorColor,
                    () => _updateBookingStatus(booking, BookingStatus.cancelled),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: AppConstants.primaryColor, size: 18),
        const SizedBox(width: 12),
        Expanded(
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: AppConstants.mutedGray.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  color: AppConstants.softWhite,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: color.withOpacity(0.2),
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: color),
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Color _getStatusColor(BookingStatus status) {
    switch (status) {
      case BookingStatus.pending:
        return AppConstants.accentColor;
      case BookingStatus.paymentPending:
        return AppConstants.accentColor; // Orange/yellow for payment pending
      case BookingStatus.paid:
        return AppConstants.primaryColor; // Pink for paid
      case BookingStatus.completed:
        return AppConstants.successColor; // Green for completed
      case BookingStatus.cancelled:
        return AppConstants.errorColor; // Red for cancelled
      case BookingStatus.servicePending:
        return AppConstants.accentColor; // Blue for service pending
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    
    if (diff.inDays == 0) {
      return 'Today ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else if (diff.inDays == 1) {
      return 'Yesterday ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    } else {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
    }
  }
}

