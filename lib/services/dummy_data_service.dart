// lib/services/dummy_data_service.dart
import 'dart:math';
import 'package:hook_app/models/active_user.dart';

class DummyDataService {
  static final Random _random = Random();

  // Kenyan female names
  static const List<String> _femaleNames = [
    'Amina Hassan',
    'Grace Wanjiku',
    'Faith Akinyi',
    'Mercy Njeri',
    'Esther Wambui',
    'Naomi Chebet',
    'Sarah Muthoni',
    'Joy Achieng',
    'Beatrice Wanjiru',
    'Lucy Nyambura',
    'Rose Adhiambo',
    'Mary Kamau',
    'Jane Kiplagat',
    'Ann Wairimu',
    'Catherine Atieno',
  ];

  // Kenyan male names
  static const List<String> _maleNames = [
    'David Kimani',
    'Brian Ochieng',
    'James Mwangi',
    'Peter Kipchoge',
    'John Kamau',
    'Michael Otieno',
    'Daniel Kariuki',
    'Samuel Koech',
    'Joseph Njoroge',
    'Emmanuel Wekesa',
    'Patrick Mutua',
    'Francis Omondi',
    'George Kiprotich',
    'Anthony Maina',
    'Kevin Odongo',
  ];

  // Bio templates
  static const List<String> _bios = [
    'Coffee lover ☕ | Travel enthusiast 🌍 | Fitness junkie 💪',
    'Foodie 🍕 | Netflix addict 📺 | Dog mom 🐕',
    'Adventure seeker 🏔️ | Beach lover 🏖️ | Yoga enthusiast 🧘',
    'Book worm 📚 | Wine connoisseur 🍷 | Art lover 🎨',
    'Entrepreneur 💼 | Gym rat 🏋️ | Adventure seeker 🏔️',
    'Tech geek 💻 | Music lover 🎵 | Foodie 🍔',
    'Photographer 📷 | Hiker 🥾 | Coffee addict ☕',
    'Chef 👨‍🍳 | Gamer 🎮 | Movie buff 🎬',
    'Dancer 💃 | Fashion enthusiast 👗 | Brunch lover 🥞',
    'Runner 🏃 | Vegan 🥗 | Meditation practitioner 🧘',
    'Cyclist 🚴 | Nature lover 🌿 | Photography hobbyist 📸',
    'Swimmer 🏊 | Sushi lover 🍣 | Jazz enthusiast 🎷',
    'Basketball player 🏀 | Sneakerhead 👟 | Hip-hop fan 🎤',
    'Soccer fan ⚽ | BBQ master 🍖 | Craft beer lover 🍺',
    'Traveler ✈️ | Blogger ✍️ | Sunset chaser 🌅',
  ];

  /// Generate active users based on user gender and location
  static List<ActiveUser> generateActiveUsers({
    required String userGender,
    required double centerLat,
    required double centerLon,
    int count = 20,
  }) {
    final List<ActiveUser> users = [];
    final oppositeGender = userGender.toLowerCase() == 'male' ? 'female' : 'male';
    final namesList = oppositeGender == 'female' ? _femaleNames : _maleNames;

    for (int i = 0; i < count && i < namesList.length; i++) {
      // Generate random location within ~10km radius
      final double latOffset = (_random.nextDouble() - 0.5) * 0.18; // ~10km
      final double lonOffset = (_random.nextDouble() - 0.5) * 0.18;

      final double lat = centerLat + latOffset;
      final double lon = centerLon + lonOffset;

      // Calculate distance from center
      final double distance = _calculateDistance(centerLat, centerLon, lat, lon);

      // Random online status (70% online)
      final bool isOnline = _random.nextDouble() < 0.7;

      // Random last active time (within last 24 hours)
      final DateTime lastActive = DateTime.now().subtract(
        Duration(
          hours: _random.nextInt(24),
          minutes: _random.nextInt(60),
        ),
      );

      users.add(ActiveUser(
        id: i + 1,
        name: namesList[i],
        age: 21 + _random.nextInt(15), // Age 21-35
        gender: oppositeGender,
        latitude: lat,
        longitude: lon,
        profileImage: 'https://i.pravatar.cc/300?img=${i + 1}',
        bio: _bios[i % _bios.length],
        distance: double.parse(distance.toStringAsFixed(1)),
        isOnline: isOnline,
        lastActive: lastActive,
      ));
    }

    // Sort by distance
    users.sort((a, b) => a.distance.compareTo(b.distance));

    return users;
  }

  static double _calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295;
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;
    return 12742 * asin(sqrt(a));
  }
}
