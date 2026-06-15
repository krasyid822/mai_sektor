// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

class LocationService {
  /// Check and request location permissions. Returns true if granted.
  static Future<bool> handlePermission() async {
    if (kIsWeb) {
      try {
        final permissions = html.window.navigator.permissions;
        if (permissions != null) {
          final status = await permissions.query({'name': 'geolocation'});
          if (status.state == 'denied') {
            return false;
          }
        }
      } catch (_) {
        // If Permissions API is not supported on some browsers
      }
      return true;
    }

    bool serviceEnabled;
    LocationPermission permission;

    serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return false;
    }

    permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return false;
      }
    }
    
    if (permission == LocationPermission.deniedForever) {
      return false;
    }

    return true;
  }

  /// Get user's current coordinates.
  static Future<Position> getCurrentLocation() async {
    if (kIsWeb) {
      final geoposition = await html.window.navigator.geolocation.getCurrentPosition(
        enableHighAccuracy: true,
      );
      final coords = geoposition.coords;
      if (coords != null) {
        return Position(
          latitude: coords.latitude?.toDouble() ?? 0.0,
          longitude: coords.longitude?.toDouble() ?? 0.0,
          timestamp: DateTime.now(),
          accuracy: coords.accuracy?.toDouble() ?? 0.0,
          altitude: coords.altitude?.toDouble() ?? 0.0,
          altitudeAccuracy: 0.0,
          heading: coords.heading?.toDouble() ?? 0.0,
          headingAccuracy: 0.0,
          speed: coords.speed?.toDouble() ?? 0.0,
          speedAccuracy: 0.0,
        );
      } else {
        throw 'No coordinates found';
      }
    }

    return await Geolocator.getCurrentPosition(
      desiredAccuracy: LocationAccuracy.high,
    );
  }

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
