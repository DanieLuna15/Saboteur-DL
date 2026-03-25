import 'package:flutter/material.dart';
import '../../models/card_model.dart';

class PathCardPainter extends CustomPainter {
  final CardModel card;
  final bool isFaceDown;
  final bool isHighlight;
  final bool isOptimistic;
  final bool isRevealed;

  // Caching Paint objects to avoid thousands of allocations per second
  static final _pathPaint = Paint()
    ..color = Colors.orange[400]!
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  static final _backPaint = Paint()..color = const Color(0xFF4E342E);
  static final _frontPaint = Paint()..color = Colors.grey[850]!;
  static final _borderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1;

  PathCardPainter({
    required this.card,
    this.isFaceDown = false,
    this.isHighlight = false,
    this.isOptimistic = false,
    this.isRevealed = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (isOptimistic) {
      canvas.saveLayer(Offset.zero & size, Paint()..color = Colors.white.withOpacity(0.5));
    }

    if (isFaceDown) {
      _drawBack(canvas, size);
    } else {
      _drawFront(canvas, size);
    }

    if (isOptimistic) {
      canvas.restore();
    }
  }

  void _drawBack(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), _backPaint);
    
    _borderPaint.color = Colors.black;
    _borderPaint.strokeWidth = 2;
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), _borderPaint);
  }

  void _drawFront(Canvas canvas, Size size) {
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), _frontPaint);

    bool isGoal = card.id.startsWith('goal');
    
    if (isGoal && !isRevealed) {
       _drawHiddenGoal(canvas, size);
    } else {
      if (card is PathCard) {
        _drawPath(canvas, size, card as PathCard);
      } else if (card is ActionCard) {
        _drawAction(canvas, size, card as ActionCard);
      }
    }

    _borderPaint.color = isHighlight ? Colors.greenAccent : (isRevealed ? Colors.amberAccent : Colors.white38);
    _borderPaint.strokeWidth = isHighlight ? 3 : (isRevealed ? 2 : 1);
    canvas.drawRRect(RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), _borderPaint);
  }

  void _drawPath(Canvas canvas, Size size, PathCard pathCard) {
    _pathPaint.strokeWidth = size.width * 0.18;
    final center = Offset(size.width / 2, size.height / 2);

    if (pathCard.connections[PathDirection.top] == true) {
      canvas.drawLine(center, Offset(size.width / 2, 0), _pathPaint);
    }
    if (pathCard.connections[PathDirection.bottom] == true) {
      canvas.drawLine(center, Offset(size.width / 2, size.height), _pathPaint);
    }
    if (pathCard.connections[PathDirection.left] == true) {
      canvas.drawLine(center, Offset(0, size.height / 2), _pathPaint);
    }
    if (pathCard.connections[PathDirection.right] == true) {
      canvas.drawLine(center, Offset(size.width, size.height / 2), _pathPaint);
    }

    if (pathCard.hasCenter) {
      canvas.drawCircle(center, size.width * 0.12, Paint()..color = Colors.orange[400]!);
    }
  }

  void _drawAction(Canvas canvas, Size size, ActionCard actionCard) {
    IconData icon;
    Color color;

    switch (actionCard.actionType) {
      case 'rockfall': icon = Icons.bolt; color = Colors.redAccent; break;
      case 'map': icon = Icons.map; color = Colors.blueAccent; break;
      case 'break_tool': icon = _getToolIcon(actionCard.targetTool); color = Colors.red; _drawX(canvas, size); break;
      case 'fix_tool': icon = _getToolIcon(actionCard.targetTool); color = Colors.greenAccent; break;
      default: icon = Icons.help_outline; color = Colors.white;
    }

    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size.width * 0.6, fontFamily: icon.fontFamily, package: icon.fontPackage, color: color),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
  }

  void _drawHiddenGoal(Canvas canvas, Size size) {
    // Dibujamos un ícono de meta/interrogación
    final icon = Icons.help_center;
    final textPainter = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(icon.codePoint),
        style: TextStyle(fontSize: size.width * 0.5, fontFamily: icon.fontFamily, package: icon.fontPackage, color: Colors.amberAccent[700]),
      ),
      textDirection: TextDirection.ltr,
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset((size.width - textPainter.width) / 2, (size.height - textPainter.height) / 2));
  }

  IconData _getToolIcon(String tool) => tool == 'pickaxe' ? Icons.construction : (tool == 'lantern' ? Icons.lightbulb : Icons.shopping_cart);

  void _drawX(Canvas canvas, Size size) {
    final xPaint = Paint()..color = Colors.red..strokeWidth = 3..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(size.width * 0.2, size.height * 0.3), Offset(size.width * 0.8, size.height * 0.7), xPaint);
    canvas.drawLine(Offset(size.width * 0.8, size.height * 0.3), Offset(size.width * 0.2, size.height * 0.7), xPaint);
  }

  @override
  bool shouldRepaint(covariant PathCardPainter oldDelegate) {
    return oldDelegate.card != card || 
           oldDelegate.isFaceDown != isFaceDown || 
           oldDelegate.isHighlight != isHighlight ||
           oldDelegate.isOptimistic != isOptimistic ||
           oldDelegate.isRevealed != isRevealed;
  }
}
