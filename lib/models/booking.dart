class Booking {
  final String bookingId;
  final String clientId;
  final String providerId;
  final double price;
  final double serviceFee;
  final double totalAmount;
  final bool includeBnb;
  final String? bnbId;
  final double? bnbPrice;
  final BookingStatus status;
  final String? paymentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? completedAt;

  Booking({
    required this.bookingId,
    required this.clientId,
    required this.providerId,
    required this.price,
    required this.serviceFee,
    required this.totalAmount,
    required this.includeBnb,
    this.bnbId,
    this.bnbPrice,
    required this.status,
    this.paymentId,
    required this.createdAt,
    required this.updatedAt,
    this.completedAt,
  });

  factory Booking.fromJson(Map<String, dynamic> json) {
    String _parseString(dynamic value) {
      if (value == null) return '';
      return value.toString();
    }

    double _parseDouble(dynamic value) {
      if (value == null) return 0.0;
      if (value is int) return value.toDouble();
      if (value is double) return value;
      if (value is String) return double.tryParse(value) ?? 0.0;
      return 0.0;
    }

    return Booking(
      bookingId: _parseString(json['booking_id']),
      clientId: _parseString(json['client_id']),
      providerId: _parseString(json['provider_id']),
      price: _parseDouble(json['price']),
      serviceFee: _parseDouble(json['service_fee']),
      totalAmount: _parseDouble(json['total_amount']),
      includeBnb: json['include_bnb'] as bool? ?? false,
      bnbId: json['bnb_id']?.toString(),
      bnbPrice: json['bnb_price'] != null ? _parseDouble(json['bnb_price']) : null,
      status: _statusFromString(json['status'] as String? ?? 'PENDING'),
      paymentId: json['payment_id']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      completedAt: json['completed_at'] != null
          ? DateTime.tryParse(json['completed_at'] as String)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'booking_id': bookingId,
      'client_id': clientId,
      'provider_id': providerId,
      'price': price,
      'service_fee': serviceFee,
      'total_amount': totalAmount,
      'include_bnb': includeBnb,
      'bnb_id': bnbId,
      'bnb_price': bnbPrice,
      'status': status.toString().split('.').last,
      'payment_id': paymentId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'completed_at': completedAt?.toIso8601String(),
    };
  }

  static BookingStatus _statusFromString(String status) {
    switch (status.toUpperCase()) {
      case 'PENDING':
        return BookingStatus.pending;
      case 'PAID':
        return BookingStatus.paid;
      case 'COMPLETED':
        return BookingStatus.completed;
      case 'CANCELLED':
        return BookingStatus.cancelled;
      case 'PAYMENT_PENDING':
        return BookingStatus.paymentPending;
      case 'SERVICE_PENDING':
        return BookingStatus.servicePending;
      default:
        return BookingStatus.pending;
    }
  }

  String get statusDisplay {
    switch (status) {
      case BookingStatus.pending:
        return 'Pending';
      case BookingStatus.paid:
        return 'Paid';
      case BookingStatus.completed:
        return 'Completed';
      case BookingStatus.cancelled:
        return 'Cancelled';
      case BookingStatus.paymentPending:
        return 'Payment Pending';
      case BookingStatus.servicePending:
        return 'Service Pending';
    }
  }

  String get formattedTotal => '\$${totalAmount.toStringAsFixed(2)}';
}

enum BookingStatus {
  pending,
  paid,
  completed,
  cancelled,
  paymentPending,
  servicePending,
}
