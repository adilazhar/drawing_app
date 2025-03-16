import 'package:flutter/material.dart';

class DrawingPath {
  Path path;
  Paint paint;
  List<Offset> points;
  bool isErased;

  DrawingPath(this.path, this.paint, this.points, this.isErased);
}
