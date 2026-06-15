# web_geolocator

A lightweight, dependency-free geolocation plugin for Flutter Web that utilizes native browser Geolocation APIs directly. It includes WASM-safe compilation stub fallbacks for non-web platforms.

## Features

- **WASM-Safe**: Contains no complex bindings, making it fully compatible with WebAssembly compilation targets.
- **Dependency-Free**: Does not rely on heavy external plugins.
- **Native Geolocation**: Accesses HTML5 `navigator.geolocation` directly.
- **Platform-Safe**: Compiles on both web and native platforms via conditional imports (returns a stub `(0.0, 0.0)` location on non-web platforms).

## Getting started

Add `web_geolocator` to your `pubspec.yaml`:

```yaml
dependencies:
  web_geolocator:
    git:
      url: https://github.com/krasyid822/mai_sektor/tree/c32deaf8d98a87cb82ce6ec3d94ce1274ea2e654/web_geolocator
```

## Usage

```dart
import 'package:web_geolocator/web_geolocator.dart';

// Check or query permissions
bool hasPermission = await LocationService.handlePermission();

if (hasPermission) {
  // Retrieve position coordinates
  CustomPosition position = await LocationService.getCurrentLocation();
  print('Latitude: ${position.latitude}, Longitude: ${position.longitude}');

  // Calculate distances
  double distance = LocationService.getDistance(
    position.latitude,
    position.longitude,
    0,
    0,
  );
  print('Distance in meters: $distance');
}
```
