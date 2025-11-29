import 'bnb_session.dart';

class BnB {
  final int bnbId;
  final int ownerId;
  final String name;
  final String location;
  final String address;
  final double priceKES; // Renamed from price
  final bool available;
  final String? callNumber;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<BnBSession> sessions; // New field

  BnB({
    required this.bnbId,
    required this.ownerId,
    required this.name,
    required this.location,
    required this.address,
    required this.priceKES,
    required this.available,
    this.callNumber,
    required this.createdAt,
    required this.updatedAt,
    this.sessions = const [],
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

    // Parse sessions array
    List<BnBSession> parseSessions(dynamic sessionsJson) {
      if (sessionsJson == null) return [];
      if (sessionsJson is! List) return [];
      return sessionsJson
          .map((s) => BnBSession.fromJson(s as Map<String, dynamic>))
          .toList();
    }

    return BnB(
      bnbId: _parseInt(json['bnb_id']) ?? _parseInt(json['bnbId']) ?? 0,
      ownerId: _parseInt(json['owner_id']) ?? _parseInt(json['ownerId']) ?? 0,
      name: json['name'] as String? ?? '',
      location: json['location'] as String? ?? '',
      address: json['address'] as String? ?? '',
      priceKES: (json['price_kes'] as num?)?.toDouble() ?? 0.0, // Changed from 'price'
      available: json['available'] as bool? ?? true,
      callNumber: json['call_number'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      sessions: parseSessions(json['sessions']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'address': address,
      'price_kes': priceKES, // Changed from 'price'
      'available': available,
      'call_number': callNumber,
    };
  }

  // Helper for display
  String get formattedPrice => 'KES ${priceKES.toStringAsFixed(0)}';
  String get availabilityStatus => available ? 'Available' : 'Unavailable';
  
  // Get cheapest session price or base price
  double get cheapestPrice {
    if (sessions.isEmpty) return priceKES;
    final validSessions = sessions.where((s) => s.isValid).toList();
    if (validSessions.isEmpty) return priceKES;
    return validSessions.map((s) => s.price).reduce((a, b) => a < b ? a : b);
  }
}