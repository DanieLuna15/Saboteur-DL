import 'package:flame/components.dart';
import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'path_card_painter.dart';

class PathCardComponent extends PositionComponent {
  final PathCard card;
  final bool isFaceDown;
  final bool isHighlight;
  final bool isOptimistic;
  final bool isRevealed;

  PathCardPainter? _cachedPainter;
  Size? _lastSize;

  PathCardComponent({
    required this.card,
    this.isFaceDown = false,
    this.isHighlight = false,
    this.isOptimistic = false,
    this.isRevealed = false,
    required Vector2 position,
    required Vector2 size,
  }) : super(position: position, size: size);

  @override
  void render(Canvas canvas) {
    final currentSize = size.toSize();
    
    // Solo creamos el pintor si no existe o si algo cambió
    if (_cachedPainter == null || _lastSize != currentSize) {
      _cachedPainter = PathCardPainter(
        card: card,
        isFaceDown: isFaceDown,
        isHighlight: isHighlight,
        isOptimistic: isOptimistic,
        isRevealed: isRevealed,
      );
      _lastSize = currentSize;
    }

    _cachedPainter!.paint(canvas, currentSize);
  }
}
