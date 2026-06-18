// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:js' as js;
import 'dart:math' as math;
import 'dart:convert';
import 'dart:async';
import 'package:camera/camera.dart';

class BiometricHelper {
  // Extract a 64-element feature vector using MediaPipe Face Mesh on Web
  static Future<List<double>> extractFaceVector(XFile file) async {
    final completer = Completer<List<double>>();
    try {
      final bytes = await file.readAsBytes();
      final base64String = base64Encode(bytes);
      final dataUrl = 'data:image/jpeg;base64,$base64String';

      // ignore: undefined_function
      final jsCallback = js.allowInterop((dynamic jsResult) {
        if (completer.isCompleted) return;
        if (jsResult == null || jsResult == '') {
          completer.complete([]);
          return;
        }
        try {
          final List<dynamic> list = json.decode(jsResult as String) as List<dynamic>;
          completer.complete(list.map((e) => (e as num).toDouble()).toList());
        } catch (e) {
          completer.complete([]);
        }
      });

      js.context.callMethod('extractFaceVectorMediaPipeCallback', [dataUrl, jsCallback]);
    } catch (e) {
      // ignore: avoid_print
      print("MediaPipe extraction error: $e");
      if (!completer.isCompleted) completer.complete([]);
    }
    return completer.future;
  }

  // Calculate Euclidean distance (identity similarity) between two 128D face-api.js descriptors.
  // In face-api.js, a Euclidean distance <= 0.6 indicates the same person.
  // We map distance <= 0.53 to similarity >= 65% (matching threshold).
  static double calculateSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;

    double sumSquaredDiff = 0.0;
    for (int i = 0; i < v1.length; i++) {
      final diff = v1[i] - v2[i];
      sumSquaredDiff += diff * diff;
    }
    final distance = math.sqrt(sumSquaredDiff);

    // Map Euclidean distance to similarity.
    // distance of 0.0 -> similarity 1.0 (100%)
    // distance of 0.525 -> similarity 0.65 (65% matching threshold)
    // distance of 1.5 -> similarity 0.0 (0%)
    final similarity = 1.0 - (distance / 1.5);
    return similarity.clamp(0.0, 1.0);
  }

  // Parse string vector "[0.1, 0.2, ...]" to List<double>
  static List<double> parseVectorString(String vectorStr) {
    try {
      final clean = vectorStr.replaceAll('[', '').replaceAll(']', '').trim();
      if (clean.isEmpty) return [];
      return clean
          .split(',')
          .map((e) => double.tryParse(e.trim()) ?? 0.0)
          .toList();
    } catch (_) {
      return [];
    }
  }
}
