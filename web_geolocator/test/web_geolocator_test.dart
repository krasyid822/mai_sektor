import 'package:flutter_test/flutter_test.dart';

import 'package:web_geolocator/web_geolocator.dart';

void main() {
  test('location service distance calculation', () {
    final dist = LocationService.getDistance(0, 0, 0, 0);
    expect(dist, 0.0);
  });
}
