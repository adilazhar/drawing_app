import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:skribble_testing/color_picker.dart';
import 'package:skribble_testing/drawing_painter.dart';
import 'package:skribble_testing/drawing_path.dart';
import 'package:skribble_testing/eraser_indicator_painter.dart';

class PaintingCanvas extends StatefulWidget {
  const PaintingCanvas({super.key});

  @override
  PaintingCanvasState createState() => PaintingCanvasState();
}

class PaintingCanvasState extends State<PaintingCanvas> {
  List<DrawingPath> paths = [];
  Color selectedColor = Colors.black;
  double strokeWidth = 2.0;
  double eraserSize = 20.0;
  bool isErasing = false;
  bool showStrokeSlider = false;
  bool showEraserSlider = false;
  final GlobalKey _canvasKey = GlobalKey();
  Offset? currentPosition;

  void _onPanStart(DragStartDetails details) {
    setState(() {
      if (showEraserSlider) showEraserSlider = false;
      if (showStrokeSlider) showStrokeSlider = false;

      currentPosition = details.localPosition;
      if (isErasing) {
        // Start erasing
        _eraseAtPosition(details.localPosition);
      } else {
        // Start drawing
        paths.add(DrawingPath(
          Path()..moveTo(details.localPosition.dx, details.localPosition.dy),
          Paint()
            ..color = selectedColor
            ..strokeWidth = strokeWidth
            ..strokeCap = StrokeCap.round
            ..style = PaintingStyle.stroke
            ..strokeJoin = StrokeJoin.round,
          [details.localPosition],
          false,
        ));
      }
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      currentPosition = details.localPosition;
      if (isErasing) {
        // Continue erasing
        _eraseAtPosition(details.localPosition);
      } else {
        // Continue drawing
        final path = paths.last;
        final newPoint = details.localPosition;

        // Add a control point for smoothing
        if (path.points.length >= 2) {
          final lastPoint = path.points.last;

          final ctrl2 = Offset(
            (lastPoint.dx + newPoint.dx) / 2,
            (lastPoint.dy + newPoint.dy) / 2,
          );

          // Use quadratic Bezier curve for smoother lines
          path.path.quadraticBezierTo(
              lastPoint.dx, lastPoint.dy, ctrl2.dx, ctrl2.dy);
        } else {
          path.path.lineTo(newPoint.dx, newPoint.dy);
        }

        path.points.add(newPoint);
      }
    });
  }

  void _onPanEnd(DragEndDetails details) {
    setState(() {
      currentPosition = null;
      if (!isErasing) {
        // End drawing
        paths.last.points
            .add(paths.last.points.last); // Duplicate last point to mark end
      }
    });
  }

  void _onTapDown(TapDownDetails details) {
    setState(() {
      if (showEraserSlider) showEraserSlider = false;
      if (showStrokeSlider) showStrokeSlider = false;

      currentPosition = details.localPosition;
      if (isErasing) {
        // Erase on tap
        _eraseAtPosition(details.localPosition);
      } else {
        // Draw a point on tap
        final path = Path()
          ..addOval(Rect.fromCircle(
            center: details.localPosition,
            radius: strokeWidth / 2,
          ));
        final paint = Paint()
          ..color = selectedColor
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.fill;
        paths.add(DrawingPath(path, paint, [details.localPosition], false));
      }
    });
  }

  void _eraseAtPosition(Offset position) {
    // Create an eraser circle at the position
    final eraserRect = Rect.fromCircle(
      center: position,
      radius: eraserSize / 2,
    );

    // Mark paths that intersect with eraser as erased
    for (var i = 0; i < paths.length; i++) {
      if (!paths[i].isErased) {
        for (var j = 0; j < paths[i].points.length - 1; j++) {
          if (j + 1 < paths[i].points.length) {
            // Check if the line segment intersects with eraser circle
            final p1 = paths[i].points[j];
            final p2 = paths[i].points[j + 1];

            // Simple check: if either point is inside the circle or
            // the line segment is close to the center of the circle
            if (eraserRect.contains(p1) ||
                eraserRect.contains(p2) ||
                _isPointCloseToLine(position, p1, p2, eraserSize / 2)) {
              // Create new path by splitting the original at the erased portion
              _splitPathAtPosition(i, j, position, eraserSize / 2);
              break;
            }
          }
        }
      }
    }

    // Remove fully erased paths
    paths.removeWhere((path) => path.isErased || path.points.length <= 1);
  }

  bool _isPointCloseToLine(
      Offset point, Offset lineStart, Offset lineEnd, double maxDistance) {
    // Calculate distance from point to line segment
    final a = point.dx - lineStart.dx;
    final b = point.dy - lineStart.dy;
    final c = lineEnd.dx - lineStart.dx;
    final d = lineEnd.dy - lineStart.dy;

    final dot = a * c + b * d;
    final lenSq = c * c + d * d;

    // If line segment is just a point
    if (lenSq == 0) return false;

    // Find projection point parameter
    var param = dot / lenSq;

    // Find closest point on line segment
    Offset closest;
    if (param < 0) {
      closest = lineStart;
    } else if (param > 1) {
      closest = lineEnd;
    } else {
      closest = Offset(lineStart.dx + param * c, lineStart.dy + param * d);
    }

    // Check if distance is less than maxDistance
    final dx = point.dx - closest.dx;
    final dy = point.dy - closest.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    return distance < maxDistance;
  }

  void _splitPathAtPosition(
      int pathIndex, int pointIndex, Offset erasePosition, double eraseRadius) {
    final path = paths[pathIndex];

    // Mark the entire path as erased and replace with new paths
    path.isErased = true;

    // Create two new paths: one before the erasure and one after
    List<Offset> beforePoints = [];
    List<Offset> afterPoints = [];

    // Split points into before and after
    for (var i = 0; i < path.points.length; i++) {
      final dist = (path.points[i] - erasePosition).distance;
      if (i <= pointIndex && dist > eraseRadius) {
        beforePoints.add(path.points[i]);
      } else if (i > pointIndex && dist > eraseRadius) {
        afterPoints.add(path.points[i]);
      }
    }

    // Create new paths if there are enough points
    if (beforePoints.length >= 2) {
      Path beforePath = Path();
      beforePath.moveTo(beforePoints.first.dx, beforePoints.first.dy);

      for (var i = 1; i < beforePoints.length; i++) {
        beforePath.lineTo(beforePoints[i].dx, beforePoints[i].dy);
      }

      paths.add(DrawingPath(
        beforePath,
        Paint()
          ..color = path.paint.color
          ..strokeWidth = path.paint.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
        List.from(beforePoints),
        false,
      ));
    }

    if (afterPoints.length >= 2) {
      Path afterPath = Path();
      afterPath.moveTo(afterPoints.first.dx, afterPoints.first.dy);

      for (var i = 1; i < afterPoints.length; i++) {
        afterPath.lineTo(afterPoints[i].dx, afterPoints[i].dy);
      }

      paths.add(DrawingPath(
        afterPath,
        Paint()
          ..color = path.paint.color
          ..strokeWidth = path.paint.strokeWidth
          ..strokeCap = StrokeCap.round
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round,
        List.from(afterPoints),
        false,
      ));
    }
  }

  void _toggleEraser() {
    setState(() {
      isErasing = !isErasing;
      if (isErasing) {
        showEraserSlider = true;
        showStrokeSlider = false;
      } else {
        showEraserSlider = false;
      }
    });
  }

  void _toggleStrokeSlider() {
    setState(() {
      showStrokeSlider = !showStrokeSlider;
      if (showStrokeSlider) {
        showEraserSlider = false;
        isErasing = false;
      }
    });
  }

  void _selectColor() async {
    final Color? newColor = await showDialog<Color>(
      context: context,
      builder: (BuildContext context) {
        Color tempColor = selectedColor;
        return AlertDialog(
          title: const Text('Select a color'),
          content: SingleChildScrollView(
            child: ColorPicker(
              pickerColor: selectedColor,
              onColorChanged: (Color color) {
                tempColor = color;
                Navigator.of(context).pop(tempColor);
              },
            ),
          ),
        );
      },
    );

    if (newColor != null) {
      setState(() {
        selectedColor = newColor;
        isErasing = false;
        showEraserSlider = false;
      });
    }
  }

  void _undo() {
    setState(() {
      if (paths.isNotEmpty) {
        paths.removeLast();
      }
    });
  }

  Future _saveCanvas() async {
    try {
      // Capture the canvas as an image
      RenderRepaintBoundary boundary = _canvasKey.currentContext!
          .findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData =
          await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData != null) {
        final buffer = byteData.buffer.asUint8List();

        if (Platform.isAndroid || Platform.isIOS) {
          // Save to gallery
          final result = await ImageGallerySaver.saveImage(buffer);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result['isSuccess']
                ? 'Drawing saved to gallery!'
                : 'Failed to save drawing.'),
          ));
        } else if (Platform.isWindows) {
          // Get the default Pictures directory
          final directory = Directory(
              '${Platform.environment['USERPROFILE']}\\Pictures\\Drawing App');

          // Ensure the directory exists
          if (!directory.existsSync()) {
            directory.createSync(recursive: true);
          }

          // Create file path
          final filePath =
              '${directory.path}\\drawing_${DateTime.now().millisecondsSinceEpoch}.png';

          // Write image to file
          File file = File(filePath);
          await file.writeAsBytes(buffer);

          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Drawing saved to: $filePath'),
          ));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Saving not supported on this platform.'),
          ));
        }
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error saving drawing: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Drawing App'),
        actions: [
          IconButton(
            icon: const Icon(Icons.undo),
            onPressed: _undo,
          ),
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveCanvas,
          ),
        ],
      ),
      body: GestureDetector(
        child: Stack(
          children: [
            RepaintBoundary(
              key: _canvasKey,
              child: GestureDetector(
                onPanStart: _onPanStart,
                onPanUpdate: _onPanUpdate,
                onPanEnd: _onPanEnd,
                onTapDown: _onTapDown,
                child: CustomPaint(
                  size: Size.infinite,
                  painter: DrawingPainter(paths),
                  foregroundPainter: isErasing && currentPosition != null
                      ? EraserIndicatorPainter(currentPosition!, eraserSize)
                      : null,
                ),
              ),
            ),
            // Floating bottom toolbar
            Positioned(
              bottom: 20,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  width: 240,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Stroke width icon
                      GestureDetector(
                        onTap: () {
                          _toggleStrokeSlider();
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: showStrokeSlider
                                ? Colors.grey.shade200
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Tooltip(
                            message: 'Width',
                            child: Icon(
                              Icons.edit,
                              color: isErasing ? Colors.grey : Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                      // Color picker icon
                      GestureDetector(
                        onTap: _selectColor,
                        child: Tooltip(
                          message: 'Color picker',
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: selectedColor,
                              border: Border.all(
                                color: Colors.grey.shade300,
                                width: 2,
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Eraser icon
                      GestureDetector(
                        onTap: _toggleEraser,
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: isErasing
                                ? Colors.grey.shade200
                                : Colors.transparent,
                            shape: BoxShape.circle,
                          ),
                          child: Tooltip(
                            message: 'Eraser',
                            child: Icon(
                              Icons.auto_fix_normal,
                              color: isErasing ? Colors.blue : Colors.black,
                              size: 24,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Stroke width slider
            if (showStrokeSlider)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 240,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Stroke Width: ${strokeWidth.toStringAsFixed(1)}'),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: strokeWidth,
                            min: 2.0,
                            max: 30.0,
                            onChanged: (value) {
                              setState(() {
                                strokeWidth = value;
                              });
                            },
                          ),
                        ),
                        Container(
                          width: strokeWidth,
                          height: strokeWidth,
                          decoration: BoxDecoration(
                            color: selectedColor,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            // Eraser size slider
            if (showEraserSlider)
              Positioned(
                bottom: 90,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    width: 240,
                    padding:
                        const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 5,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text('Eraser Size: ${eraserSize.toStringAsFixed(1)}'),
                        SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 4,
                            thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6),
                          ),
                          child: Slider(
                            value: eraserSize,
                            min: 10.0,
                            max: 80.0,
                            onChanged: (value) {
                              setState(() {
                                eraserSize = value;
                              });
                            },
                          ),
                        ),
                        Container(
                          width: eraserSize,
                          height: eraserSize,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.blue,
                              width: 2,
                            ),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
