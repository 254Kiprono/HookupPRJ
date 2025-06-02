class BnB {
  final String id;
  final String name;
  final String location;
  final double price;
  final double rating;
  final List<String> amenities;
  final List<String> images;

  BnB({
    required this.id,
    required this.name,
    required this.location,
    required this.price,
    required this.rating,
    required this.amenities,
    required this.images,
  });
}