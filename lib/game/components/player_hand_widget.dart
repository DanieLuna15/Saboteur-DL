import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../../theme/app_colors.dart';
import 'path_card_painter.dart';

class PlayerHandWidget extends StatelessWidget {
  final List<dynamic> handData;
  final bool isMyTurn;
  final bool isInteractive;

  const PlayerHandWidget({
    required this.handData,
    required this.isMyTurn,
    this.isInteractive = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(top: BorderSide(color: isMyTurn ? Colors.greenAccent : AppColors.primaryGold, width: 3)),
        boxShadow: [
          BoxShadow(
            color: isMyTurn ? Colors.greenAccent.withOpacity(0.2) : Colors.black,
            blurRadius: 15,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Text(
              isMyTurn ? 'TU MANO (ARRASTRA UNA CARTA)' : 'TU MANO',
              style: TextStyle(
                color: isMyTurn ? Colors.greenAccent : Colors.white70,
                fontSize: 10,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: handData.length,
              itemBuilder: (context, index) {
                // USAR CardModel.fromMap para soportar tanto PathCard como ActionCard
                final card = CardModel.fromMap(Map<String, dynamic>.from(handData[index]));
                
                return Draggable<CardModel>(
                  data: card,
                  maxSimultaneousDrags: isInteractive ? 1 : 0,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: CardItem(card: card, isDragging: true),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: CardItem(card: card),
                  ),
                  child: CardItem(card: card),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CardItem extends StatelessWidget {
  final CardModel card;
  final bool isDragging;

  const CardItem({required this.card, this.isDragging = false, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      child: CustomPaint(
        painter: PathCardPainter(card: card, isHighlight: isDragging),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.bottomCenter,
          padding: const EdgeInsets.only(bottom: 4),
          child: Container(
             padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
             decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4)
             ),
             child: Text(
                card.name.toUpperCase(),
                style: const TextStyle(fontSize: 7, color: Colors.white, fontWeight: FontWeight.bold),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
          ),
        ),
      ),
    );
  }
}
