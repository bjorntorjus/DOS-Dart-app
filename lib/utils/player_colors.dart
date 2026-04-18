import 'package:flutter/material.dart';

const playerColors = [
  Colors.blue,
  Colors.red,
  Colors.green,
  Colors.orange,
  Colors.purple,
  Colors.teal,
  Colors.pink,
  Colors.amber,
  Colors.indigo,
  Colors.cyan,
];

Color playerColor(int index) => playerColors[index % playerColors.length];
