import 'custom_position.dart';

Future<bool> handlePermissionImpl() async {
  return true;
}

Future<CustomPosition> getCurrentLocationImpl() async {
  return CustomPosition(latitude: 0, longitude: 0, timestamp: DateTime.now());
}
