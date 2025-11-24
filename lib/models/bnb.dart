class BnB {
  final String id;
  final String name;
  final double price;
  final String distance;
  final double rating;
  final String imageUrl;

  BnB({
    required this.id,
    required this.name,
    required this.price,
    required this.distance,
    required this.rating,
    required this.imageUrl,
  });

  factory BnB.fromJson(Map<String, dynamic> json) {
    return BnB(
      id: json['id'] as String,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      distance: json['distance'] as String? ?? 'N/A',
      rating: (json['rating'] as num).toDouble(),
      imageUrl:
          json['image_url'] as String? ?? 'https://via.placeholder.com/600x300',
    );
  }
}