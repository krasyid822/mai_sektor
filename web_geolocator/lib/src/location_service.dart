import 'dart:math';
import 'custom_position.dart';
import 'location_service_stub.dart'
    if (dart.library.html) 'location_service_web.dart';

class LocationService {
  /// Check and request location permissions. Returns true if granted.
  static Future<bool> handlePermission() => handlePermissionImpl();

  /// Get user's current coordinates.
  static Future<CustomPosition> getCurrentLocation() => getCurrentLocationImpl();

  /// Calculates the distance in meters between two coordinates.
  /// Uses the Haversine formula.
  static double getDistance(double lat1, double lon1, double lat2, double lon2) {
    const p = 0.017453292519943295; // Pi / 180
    final c = cos;
    final a = 0.5 - c((lat2 - lat1) * p)/2 + 
          c(lat1 * p) * c(lat2 * p) * 
          (1 - c((lon2 - lon1) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000; // 2 * R; R = 6371 km -> return meters
  }
}
