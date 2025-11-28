class BnB {
  final int bnbId;
  final int ownerId;
  final String name;
  final String location;
  final double price;
  final bool available;
  final String? callNumber;
  final DateTime createdAt;
  final DateTime updatedAt;

  BnB({
    required this.bnbId,
    required this.ownerId,
    required this.name,
    required this.location,
    required this.price,
    required this.available,
    this.callNumber,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BnB.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse integers that might be null or strings
    int? _parseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is double) return value.toInt();
      return null;
    }

    return BnB(
      bnbId: _parseInt(json['bnb_id']) ?? _parseInt(json['bnbId']) ?? 0,
      ownerId: _parseInt(json['owner_id']) ?? _parseInt(json['ownerId']) ?? 0,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      available: json['available'] as bool? ?? true,
      callNumber: json['call_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'price': price,
      'available': available,
      'call_number': callNumber,
    };
  }

  // Helper for display
  String get formattedPrice => '\$${price.toStringAsFixed(2)}';
  String get availabilityStatus => available ? 'Available' : 'Unavailable';
}