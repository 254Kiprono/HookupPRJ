// lib/services/location_service.dart
import 'package:geolocator/geolocator.dart';
import 'dart:math' show cos, sqrt, asin;

class LocationService {
  /// Get current user location
  static Future<Position?> getCurrentLocation() async {
    try {
      // Add timeout to prevent hanging
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      ).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          print('Location request timed out, using default location');
          return getDefaultLocation();
        },
      );
    } catch (e) {
      print('Error getting location: $e');
      return getDefaultLocation();
    }
  }

  /// Request location permission
  static Future<bool> requestLocationPermission() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }

      return permission == LocationPermission.always ||
          permission == LocationPermission.whileInUse;
    } catch (e) {
      print('Error requesting permission: $e');
      return false;
    }
  }

  /// Calculate distance between two coordinates in kilometers
  static double calculateDistance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const p = 0.017453292519943295; // Math.PI / 180
    final a = 0.5 -
        cos((lat2 - lat1) * p) / 2 +
        cos(lat1 * p) *
            cos(lat2 * p) *
            (1 - cos((lon2 - lon1) * p)) /
            2;

    return 12742 * asin(sqrt(a)); // 2 * R; R = 6371 km
  }

  /// Get default location (Nairobi, Kenya)
  static Position getDefaultLocation() {
    return Position(
      latitude: -1.286389,
      longitude: 36.817223,
      timestamp: DateTime.now(),
      accuracy: 0,
      altitude: 0,
      altitudeAccuracy: 0,
      heading: 0,
      headingAccuracy: 0,
      speed: 0,
      speedAccuracy: 0,
    );
  }
}
