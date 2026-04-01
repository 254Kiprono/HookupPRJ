class Provider {
  final int id;
  final String name;
  final double price;
  final bool isActive;
  final String distance;
  final String? profileImage;
  final String? bio;
  final String? locationName;


  Provider({
    required this.id,
    required this.name,
    required this.price,
    required this.isActive,
    required this.distance,
    this.profileImage,
    this.bio,
    this.locationName,
  });


  factory Provider.fromJson(Map<String, dynamic> json) {
    return Provider(
      id: json['id'] as int,
      name: json['name'] as String,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? false,
      distance: json['distance'] as String? ?? 'N/A',
      profileImage: json['profile_image'] as String?,
      bio: json['bio'] as String?,
      locationName: json['region_name'] as String?,
    );

  }
}