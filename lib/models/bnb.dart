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
    return BnB(
      bnbId: json['bnb_id'] as int,
      ownerId: json['owner_id'] as int,
      name: json['name'] as String,
      location: json['location'] as String,
      price: (json['price'] as num).toDouble(),
      available: json['available'] as bool? ?? true,
      callNumber: json['call_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
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