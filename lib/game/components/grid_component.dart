import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../saboteur_game.dart';

class GridComponent extends PositionComponent with HasGameRef<SaboteurGame> {
  final int rows = 7;
  final int cols = 10;
  final double tileWidth = 80;
  final double tileHeight = 119;

  @override
  Future<void> onLoad() async {
    size = Vector2(cols * tileWidth, rows * tileHeight);
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white10
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(Offset(0, i * tileHeight), Offset(cols * tileWidth, i * tileHeight), paint);
    }

    for (int j = 0; j <= cols; j++) {
      canvas.drawLine(Offset(j * tileWidth, 0), Offset(j * tileWidth, rows * tileHeight), paint);
    }
  }
}
