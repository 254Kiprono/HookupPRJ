// lib/models/active_user.dart
class ActiveUser {
  final int id;
  final String name;
  final int age;
  final String gender; // 'male' or 'female'
  final double latitude;
  final double longitude;
  final String profileImage;
  final String bio;
  final double distance; // in km
  final bool isOnline;
  final DateTime lastActive;

  ActiveUser({
    required this.id,
    required this.name,
    required this.age,
    required this.gender,
    required this.latitude,
    required this.longitude,
    required this.profileImage,
    required this.bio,
    required this.distance,
    required this.isOnline,
    required this.lastActive,
  });

  factory ActiveUser.fromJson(Map<String, dynamic> json) => ActiveUser(
        id: json['id'] as int,
        name: json['name'] as String,
        age: json['age'] as int,
        gender: json['gender'] as String,
        latitude: (json['latitude'] as num).toDouble(),
        longitude: (json['longitude'] as num).toDouble(),
        profileImage: json['profile_image'] as String,
        bio: json['bio'] as String,
        distance: (json['distance'] as num).toDouble(),
        isOnline: json['is_online'] as bool,
        lastActive: DateTime.parse(json['last_active'] as String),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'age': age,
        'gender': gender,
        'latitude': latitude,
        'longitude': longitude,
        'profile_image': profileImage,
        'bio': bio,
        'distance': distance,
        'is_online': isOnline,
        'last_active': lastActive.toIso8601String(),
      };
}
