// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:math' as math;
import 'package:camera/camera.dart';

class BiometricHelper {
  // Extract a 64-element feature vector from XFile image on web using canvas
  static Future<List<double>> extractFaceVector(XFile file) async {
    final bytes = await file.readAsBytes();
    final blob = html.Blob([bytes]);
    final url = html.Url.createObjectUrlFromBlob(blob);

    final image = html.ImageElement();
    image.src = url;
    await image.onLoad.first;

    final canvas = html.CanvasElement(width: 32, height: 32);
    final ctx = canvas.context2D;
    ctx.drawImageScaled(image, 0, 0, 32, 32);

    final imgData = ctx.getImageData(0, 0, 32, 32);
    final data = imgData.data; // List of RGBA values

    // Compute simple feature descriptors
    // We divide the 32x32 image into 4x4 blocks (16 blocks)
    // For each block, we calculate the average R, G, B and Luminance (4 values per block -> 64 values total)
    List<double> vector = [];
    const int blockSize = 8; // 32 / 4

    for (int by = 0; by < 4; by++) {
      for (int bx = 0; bx < 4; bx++) {
        double sumR = 0;
        double sumG = 0;
        double sumB = 0;
        double sumL = 0;

        for (int y = 0; y < blockSize; y++) {
          for (int x = 0; x < blockSize; x++) {
            final pixelX = bx * blockSize + x;
            final pixelY = by * blockSize + y;
            final index = (pixelY * 32 + pixelX) * 4;

            final r = data[index];
            final g = data[index + 1];
            final b = data[index + 2];
            final l = 0.299 * r + 0.587 * g + 0.114 * b; // Luminance

            sumR += r;
            sumG += g;
            sumB += b;
            sumL += l;
          }
        }

        final count = blockSize * blockSize;
        vector.add(sumR / (count * 255.0));
        vector.add(sumG / (count * 255.0));
        vector.add(sumB / (count * 255.0));
        vector.add(sumL / (count * 255.0));
      }
    }

    html.Url.revokeObjectUrl(url);
    return vector;
  }

  // Calculate cosine similarity between two vectors
  static double calculateSimilarity(List<double> v1, List<double> v2) {
    if (v1.length != v2.length || v1.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double normA = 0.0;
    double normB = 0.0;

    for (int i = 0; i < v1.length; i++) {
      dotProduct += v1[i] * v2[i];
      normA += v1[i] * v1[i];
      normB += v2[i] * v2[i];
    }

    if (normA == 0.0 || normB == 0.0) return 0.0;
    return dotProduct / (math.sqrt(normA) * math.sqrt(normB));
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
