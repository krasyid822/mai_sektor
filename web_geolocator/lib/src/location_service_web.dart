// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;
import 'custom_position.dart';

Future<bool> handlePermissionImpl() async {
  try {
    final permissions = html.window.navigator.permissions;
    if (permissions != null) {
      final status = await permissions.query({'name': 'geolocation'});
      if (status.state == 'denied') {
        return false;
      }
    }
  } catch (_) {
    // Permissions API is not supported on some browsers
  }
  return true;
}

Future<CustomPosition> getCurrentLocationImpl() async {
  final dynamic geolocation = html.window.navigator.geolocation;
  if (geolocation == null) {
    throw 'Geolocation is not supported or not available (HTTPS/Secure Context required)';
  }
  final geoposition = await geolocation.getCurrentPosition(
    enableHighAccuracy: true,
  );
  final coords = geoposition.coords;
  if (coords != null) {
    return CustomPosition(
      latitude: coords.latitude?.toDouble() ?? 0.0,
      longitude: coords.longitude?.toDouble() ?? 0.0,
      timestamp: DateTime.now(),
    );
  } else {
    throw 'No coordinates found';
  }
}
