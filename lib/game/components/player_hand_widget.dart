import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_state_provider.dart';
import '../../models/card_model.dart';

class PlayerHandWidget extends ConsumerWidget {
  final List<dynamic> handData;
  final bool isMyTurn;
  const PlayerHandWidget({super.key, required this.handData, required this.isMyTurn});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Datos de Firestore para la mano del jugador
    final List<CardModel> hand = handData.map((c) => CardModel.fromMap(Map<String, dynamic>.from(c))).toList();

    return Container(
      height: 120,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        border: const Border(top: BorderSide(color: Colors.amber, width: 2)),
      ),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hand.length,
        itemBuilder: (context, index) {
          final card = hand[index];
          return isMyTurn ? Draggable<CardModel>(
            data: card,
            feedback: Material(
              color: Colors.transparent,
              child: CardItem(card: card, isDragging: true),
            ),
            childWhenDragging: Opacity(
              opacity: 0.3,
              child: CardItem(card: card),
            ),
            child: CardItem(card: card),
          ) : CardItem(card: card);
        },
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
      width: 70,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: isDragging ? Colors.amber.withOpacity(0.5) : Colors.grey[850],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber, width: 1.5),
        boxShadow: isDragging ? [
          const BoxShadow(color: Colors.amber, blurRadius: 10)
        ] : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.grid_4x4, color: Colors.amber, size: 30),
          const SizedBox(height: 4),
          Text(
            card.name,
            style: const TextStyle(fontSize: 10, color: Colors.white, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
