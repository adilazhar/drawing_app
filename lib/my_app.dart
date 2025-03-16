import 'package:flutter/material.dart';
import 'package:skribble_testing/painting_canvas.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: PaintingCanvas(),
    );
  }
}
