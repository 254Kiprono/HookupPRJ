class Provider {
  final String id;
  final String name;
  final String serviceType;
  final double price;
  final double rating;
  final String distance;
  final String imageUrl;
  final List<String> services;

  Provider({
    required this.id,
    required this.name,
    required this.serviceType,
    required this.price,
    required this.rating,
    required this.distance,
    required this.imageUrl,
    required this.services,
  });
}