import 'package:flutter/material.dart';
import 'package:signature/signature.dart';

/// A reusable signature pad widget with smooth trackpad/touch input.
///
/// Uses [GestureDetector] with [onPanUpdate] for smooth gesture recognition
/// and applies real-time moving average smoothing to eliminate jittery
/// trackpad input. The smoothed points are stored in [SignatureController]
/// for compatibility with existing export/save code.
class SignatureUploadWidget extends StatefulWidget {
  final SignatureController controller;
  final String title;
  final double height;
  final void Function()? onCleared;

  const SignatureUploadWidget({
    super.key,
    required this.controller,
    this.title = 'Tanda Tangan',
    this.height = 120,
    this.onCleared,
  });

  @override
  State<SignatureUploadWidget> createState() => _SignatureUploadWidgetState();
}

class _SignatureUploadWidgetState extends State<SignatureUploadWidget> {
  /// Buffer of raw input points for the current stroke (before smoothing).
  final List<Offset> _rawPoints = [];

  /// Smoothed points for the current stroke.
  final List<Offset> _smoothedPoints = [];

  /// Window size for moving average smoothing.
  static const int _smoothWindow = 5;

  /// Minimum distance between consecutive raw points to filter noise.
  static const double _minPointDistance = 2.0;

  /// Whether user is currently drawing.
  bool _isDrawing = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Container(
              height: widget.height,
              decoration: BoxDecoration(
                color: Colors.white10,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Listener(
                onPointerDown: (event) {
                  _isDrawing = true;
                  _rawPoints.clear();
                  _smoothedPoints.clear();
                  _rawPoints.add(event.localPosition);
                  _smoothedPoints.add(event.localPosition);
                  _addTapPoint(event.localPosition);
                  setState(() {});
                },
                onPointerMove: (event) {
                  if (!_isDrawing) return;
                  final pos = event.localPosition;

                  // Filter out tiny movements (trackpad noise)
                  if (_rawPoints.isNotEmpty) {
                    final last = _rawPoints.last;
                    final dist = (pos - last).distance;
                    if (dist < _minPointDistance) return;
                  }

                  _rawPoints.add(pos);

                  // Apply moving average smoothing
                  final smoothed = _smoothPoint(pos);
                  _smoothedPoints.add(smoothed);

                  // Add smoothed point as a move point
                  widget.controller.addPoint(
                    Point(smoothed, PointType.move, 1.0),
                  );
                  setState(() {});
                },
                onPointerUp: (event) {
                  if (!_isDrawing) return;
                  _isDrawing = false;
                  widget.controller.pushCurrentStateToUndoStack();
                  widget.controller.onDrawEnd?.call();
                  setState(() {});
                },
                onPointerCancel: (event) {
                  _isDrawing = false;
                  setState(() {});
                },
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onVerticalDragStart: (_) {},
                  onVerticalDragUpdate: (_) {},
                  onVerticalDragEnd: (_) {},
                  onHorizontalDragStart: (_) {},
                  onHorizontalDragUpdate: (_) {},
                  onHorizontalDragEnd: (_) {},
                  child: CustomPaint(
                    painter: _SmoothSignaturePainter(
                      widget.controller,
                      _smoothedPoints,
                    ),
                    size: Size.infinite,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                icon: const Icon(
                  Icons.clear,
                  color: Colors.redAccent,
                  size: 16,
                ),
                label: const Text(
                  'Hapus Tanda Tangan',
                  style: TextStyle(color: Colors.redAccent, fontSize: 12),
                ),
                onPressed: () {
                  widget.controller.clear();
                  _rawPoints.clear();
                  _smoothedPoints.clear();
                  widget.onCleared?.call();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Add a tap point (pen down) to the controller.
  void _addTapPoint(Offset pos) {
    widget.controller.addPoint(Point(pos, PointType.tap, 1.0));
  }

  /// Apply moving average smoothing to a new point.
  /// Uses the last [_smoothWindow] raw points to compute the average.
  Offset _smoothPoint(Offset newPoint) {
    if (_rawPoints.length < _smoothWindow) {
      return newPoint;
    }

    final start = _rawPoints.length - _smoothWindow;
    double sumX = 0, sumY = 0;
    for (int i = start; i < _rawPoints.length; i++) {
      sumX += _rawPoints[i].dx;
      sumY += _rawPoints[i].dy;
    }
    return Offset(sumX / _smoothWindow, sumY / _smoothWindow);
  }
}

/// Custom painter that draws both the existing signature points and the
/// current smoothed stroke preview.
class _SmoothSignaturePainter extends CustomPainter {
  final SignatureController controller;
  final List<Offset> currentSmoothedStroke;

  _SmoothSignaturePainter(this.controller, this.currentSmoothedStroke)
    : super(repaint: controller);

  @override
  void paint(Canvas canvas, Size size) {
    final penPaint = Paint()
      ..color = controller.penColor
      ..strokeWidth = controller.penStrokeWidth
      ..strokeCap = controller.strokeCap
      ..strokeJoin = controller.strokeJoin
      ..style = PaintingStyle.stroke;

    // Draw existing strokes from controller
    final points = controller.value;
    if (points.isNotEmpty) {
      final strokes = controller.pointsToStrokes(3);
      for (final stroke in strokes) {
        if (stroke.length > 1) {
          for (int i = 0; i < stroke.length - 1; i++) {
            canvas.drawLine(stroke[i].offset, stroke[i + 1].offset, penPaint);
          }
        } else if (stroke.length == 1) {
          canvas.drawCircle(
            stroke.first.offset,
            controller.penStrokeWidth / 2,
            penPaint,
          );
        }
      }
    }

    // Draw current smoothed stroke preview
    if (currentSmoothedStroke.length > 1) {
      for (int i = 0; i < currentSmoothedStroke.length - 1; i++) {
        canvas.drawLine(
          currentSmoothedStroke[i],
          currentSmoothedStroke[i + 1],
          penPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SmoothSignaturePainter oldDelegate) => true;
}
