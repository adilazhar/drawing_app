import 'package:flutter/material.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';

class ColorPicker extends StatelessWidget {
  final Color pickerColor;
  final ValueChanged<Color> onColorChanged;

  const ColorPicker(
      {super.key, required this.pickerColor, required this.onColorChanged});

  @override
  Widget build(BuildContext context) {
    return BlockPicker(
      pickerColor: pickerColor,
      onColorChanged: onColorChanged,
    );
  }
}
