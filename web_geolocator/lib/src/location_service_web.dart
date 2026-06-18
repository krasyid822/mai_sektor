// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'dart:convert';
import 'dart:async';
import 'custom_position.dart';

Future<bool> handlePermissionImpl() async {
  try {
    final dynamic state = await js.context.callMethod('checkGeolocationPermission');
    if (state == 'denied') {
      return false;
    }
  } catch (_) {
    // Fallback if permission query fails
  }
  return true;
}

Future<CustomPosition> getCurrentLocationImpl() async {
  final completer = Completer<CustomPosition>();
  try {
    // ignore: undefined_function
    final jsCallback = js.allowInterop((dynamic jsonStr) {
      if (completer.isCompleted) return;
      if (jsonStr == null || jsonStr == '') {
        completer.completeError('No coordinates returned');
        return;
      }
      try {
        final Map<String, dynamic> data = json.decode(jsonStr as String);
        if (data.containsKey('error')) {
          completer.completeError(data['error']);
          return;
        }
        completer.complete(CustomPosition(
          latitude: (data['latitude'] as num).toDouble(),
          longitude: (data['longitude'] as num).toDouble(),
          timestamp: DateTime.now(),
        ));
      } catch (e) {
        completer.completeError('Failed to parse coordinates: $e');
      }
    });

    js.context.callMethod('getGeolocationPositionCallback', [true, 10000, 0, jsCallback]);
  } catch (e) {
    if (!completer.isCompleted) completer.completeError(e.toString());
  }
  return completer.future;
}

class WebGeolocatorWeb {
  static void registerWith(dynamic registrar) {
    // Platform registration entry point for web
  }
}
