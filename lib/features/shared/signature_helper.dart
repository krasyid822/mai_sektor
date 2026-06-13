import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

class SignatureHelper {
  /// Serializes a signature (image and coordinate points) to a JSON string.
  static String serialize(String base64Image, List<Point> points) {
    final coordList = points.map((p) => [p.offset.dx, p.offset.dy]).toList();
    return jsonEncode({
      'image': base64Image,
      'points': coordList,
    });
  }

  /// Parses a serialized signature string into image and coordinate points.
  static ParsedSignature parse(String? sigStr) {
    if (sigStr == null || sigStr.isEmpty) {
      return ParsedSignature('', []);
    }
    if (sigStr.startsWith('{')) {
      try {
        final decoded = jsonDecode(sigStr) as Map<String, dynamic>;
        final image = decoded['image'] as String? ?? '';
        final pointsRaw = decoded['points'] as List<dynamic>? ?? [];
        final points = pointsRaw.map((p) {
          final xy = p as List<dynamic>;
          return Offset((xy[0] as num).toDouble(), (xy[1] as num).toDouble());
        }).toList();
        return ParsedSignature(image, points);
      } catch (_) {
        // Fallback to legacy
      }
    }
    return ParsedSignature(sigStr, []);
  }

  /// Normalizes a path of coordinate points to origin (0, 0) and scale 100x100,
  /// then resamples it to targetCount points.
  static List<math.Point<double>> normalize(List<Offset> points, {int targetCount = 64}) {
    if (points.isEmpty) return [];

    // Find bounding box
    double minX = points.first.dx;
    double maxX = points.first.dx;
    double minY = points.first.dy;
    double maxY = points.first.dy;
    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dy > maxY) maxY = p.dy;
    }

    double width = maxX - minX;
    double height = maxY - minY;
    if (width == 0) width = 1;
    if (height == 0) height = 1;

    // Translate to origin and scale to 100x100
    final scaled = points.map((p) {
      return math.Point<double>(
        (p.dx - minX) / width * 100.0,
        (p.dy - minY) / height * 100.0,
      );
    }).toList();

    // Resample path
    return resample(scaled, targetCount);
  }

  /// Resamples a path to n equidistant points.
  static List<math.Point<double>> resample(List<math.Point<double>> points, int n) {
    if (points.isEmpty) return [];
    double interval = pathLength(points) / (n - 1);
    if (interval == 0) {
      return List.filled(n, points.first);
    }
    double D = 0.0;
    List<math.Point<double>> newPoints = [points.first];
    int i = 1;
    final tempPoints = List<math.Point<double>>.from(points);
    while (i < tempPoints.length) {
      double d = distance(tempPoints[i - 1], tempPoints[i]);
      if ((D + d) >= interval) {
        double qx = tempPoints[i - 1].x + ((interval - D) / d) * (tempPoints[i].x - tempPoints[i - 1].x);
        double qy = tempPoints[i - 1].y + ((interval - D) / d) * (tempPoints[i].y - tempPoints[i - 1].y);
        final q = math.Point<double>(qx, qy);
        newPoints.add(q);
        tempPoints.insert(i, q);
        D = 0.0;
      } else {
        D += d;
      }
      i++;
    }
    if (newPoints.length < n) {
      newPoints.add(points.last);
    }
    return newPoints.take(n).toList();
  }

  static double pathLength(List<math.Point<double>> points) {
    double d = 0.0;
    for (int i = 1; i < points.length; i++) {
      d += distance(points[i - 1], points[i]);
    }
    return d;
  }

  static double distance(math.Point<double> p1, math.Point<double> p2) {
    return math.sqrt((p1.x - p2.x) * (p1.x - p2.x) + (p1.y - p2.y) * (p1.y - p2.y));
  }

  /// Calculates similarity between two coordinate point paths (0.0 to 100.0).
  static double calculateSimilarity(List<Offset> sig1, List<Offset> sig2) {
    if (sig1.isEmpty || sig2.isEmpty) return 0.0;
    final norm1 = normalize(sig1);
    final norm2 = normalize(sig2);
    if (norm1.length != norm2.length || norm1.isEmpty) return 0.0;

    double sumDist = 0.0;
    for (int i = 0; i < norm1.length; i++) {
      sumDist += distance(norm1[i], norm2[i]);
    }
    double avgDist = sumDist / norm1.length;

    // Convert average distance (0 to 100 scaled space) to percentage similarity
    double similarity = (1.0 - (avgDist / 25.0)) * 100.0;
    if (similarity < 0) similarity = 0.0;
    if (similarity > 100) similarity = 100.0;
    return similarity;
  }
}

class ParsedSignature {
  final String imageBase64;
  final List<Offset> points;

  ParsedSignature(this.imageBase64, this.points);
}
