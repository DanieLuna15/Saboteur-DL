import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class PathCardComponent extends PositionComponent {
  final PathCard card;
  final bool isFaceDown;

  PathCardComponent({
    required this.card,
    this.isFaceDown = false,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    if (isFaceDown) {
      _renderBack(canvas);
    } else {
      _renderFront(canvas);
    }
  }

  void _renderBack(Canvas canvas) {
    final paint = Paint()..color = Colors.brown[700]!;
    canvas.drawRect(size.toRect(), paint);
    
    final borderPaint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(size.toRect(), borderPaint);
  }

  void _renderFront(Canvas canvas) {
    // Fondo de la carta
    final paint = Paint()..color = Colors.grey[800]!;
    canvas.drawRect(size.toRect(), paint);

    // Dibujar los caminos (simplificado con líneas por ahora)
    final pathPaint = Paint()
      ..color = Colors.orange[300]!
      ..strokeWidth = 15
      ..style = PaintingStyle.stroke;

    final center = size / 2;

    if (card.connections[PathDirection.top] == true) {
      canvas.drawLine(center.toOffset(), Offset(center.x, 0), pathPaint);
    }
    if (card.connections[PathDirection.bottom] == true) {
      canvas.drawLine(center.toOffset(), Offset(center.x, size.y), pathPaint);
    }
    if (card.connections[PathDirection.left] == true) {
      canvas.drawLine(center.toOffset(), Offset(0, center.y), pathPaint);
    }
    if (card.connections[PathDirection.right] == true) {
      canvas.drawLine(center.toOffset(), Offset(size.x, center.y), pathPaint);
    }

    if (card.hasCenter) {
      canvas.drawCircle(center.toOffset(), 10, Paint()..color = Colors.orange[300]!);
    }

    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(size.toRect(), borderPaint);
  }
}
