import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../saboteur_game.dart';

class GridComponent extends PositionComponent with HasGameRef<SaboteurGame> {
  final int rows = 5;
  final int cols = 9;
  final double tileSize = 100;

  @override
  Future<void> onLoad() async {
    // Dibujar el fondo o la cuadrícula
  }

  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (int i = 0; i <= rows; i++) {
      canvas.drawLine(Offset(0, i * tileSize), Offset(cols * tileSize, i * tileSize), paint);
    }

    for (int j = 0; j <= cols; j++) {
      canvas.drawLine(Offset(j * tileSize, 0), Offset(j * tileSize, rows * tileSize), paint);
    }
  }
}
