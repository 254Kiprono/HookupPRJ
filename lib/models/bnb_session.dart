class BnBSession {
  // Core fields matching backend proto
  final int duration; // Duration in hours: 1, 2, 6, 12, 24
  final double price;
  final String currency;

  BnBSession({
    required this.duration,
    required this.price,
    this.currency = 'KES',
  });

  // Factory constructor for creating from backend response
  factory BnBSession.fromJson(Map<String, dynamic> json) {
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    double? _parseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      return null;
    }

    return BnBSession(
      duration: _parseInt(json['duration']) ?? 0,
      price: _parseDouble(json['price']) ?? 0.0,
      currency: json['currency'] as String? ?? 'KES',
    );
  }

  // Convert to JSON for API requests
  Map<String, dynamic> toJson() {
    return {
      'duration': duration,
      'price': price,
      'currency': currency,
    };
  }

  // Helper methods for display
  String get formattedPrice => '$currency ${price.toStringAsFixed(0)}';
  
  String get displayName {
    switch (duration) {
      case 1:
        return '1 Hour';
      case 2:
        return '2 Hours';
      case 6:
        return '6 Hours';
      case 12:
        return 'Half Day (12 hrs)';
      case 24:
        return 'Full Day (24 hrs)';
      default:
        return '$duration Hours';
    }
  }

  String get shortDisplayName {
    switch (duration) {
      case 1:
        return '1h';
      case 2:
        return '2h';
      case 6:
        return '6h';
      case 12:
        return '12h';
      case 24:
        return '24h';
      default:
        return '${duration}h';
    }
  }

  // Check if this is a valid session duration
  bool get isValid => [1, 2, 6, 12, 24].contains(duration);
}
