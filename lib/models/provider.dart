class Provider {
  final int id;
  final String name;
  final double price;
  final bool isActive;
  final String distance;

  Provider({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    required this.distance,
  });

  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? false,
      distance: json['distance'] as String? ?? 'N/A',
    );
  }
}