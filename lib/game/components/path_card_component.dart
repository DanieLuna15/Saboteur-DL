import 'package:flame/components.dart';
import 'package:flame/effects.dart';
import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import 'path_card_painter.dart';

class PathCardComponent extends PositionComponent with HasPaint implements OpacityProvider {
  PathCard card;
  final bool isFaceDown;
  final bool isHighlight;
  final bool isOptimistic;
  bool isRevealed;

  @override
  double get opacity => paint.color.opacity;

  @override
  set opacity(double value) {
    paint.color = paint.color.withOpacity(value);
  }

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
  }) : super(position: position, size: size, anchor: Anchor.center);

  @override
  Future<void> onLoad() async {
    // Animaciones de entrada y pulso removidas por petición del usuario para evitar parpadeos
  }

  void flip(PathCard revealedCard) {
    // Giro instantáneo removiendo la animación por ahora
    isRevealed = true;
    card = revealedCard;
    _cachedPainter = null;
  }

  void die() {
    // Explosión intensa: Escala sónica, vibración fuerte y desvanecimiento
    add(ScaleEffect.by(
      Vector2.all(1.2),
      EffectController(duration: 0.1, reverseDuration: 0.1),
    ));
    add(MoveEffect.by(
      Vector2(8, 4),
      EffectController(duration: 0.03, reverseDuration: 0.03, repeatCount: 10),
    ));
    add(OpacityEffect.fadeOut(
      EffectController(duration: 0.5),
      onComplete: () => removeFromParent(),
    ));
  }

  @override
  void render(Canvas canvas) {
    final currentSize = size.toSize();
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

    // Aplicar la opacidad del componente (manejada por OpacityEffect)
    if (opacity < 1.0) {
      canvas.saveLayer(Offset.zero & currentSize, paint);
      _cachedPainter!.paint(canvas, currentSize);
      canvas.restore();
    } else {
      _cachedPainter!.paint(canvas, currentSize);
    }
  }
}
