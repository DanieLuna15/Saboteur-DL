import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/game_state_provider.dart';
import '../../models/card_model.dart';

class PlayerHandWidget extends ConsumerWidget {
  const PlayerHandWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Por ahora usamos datos locales para probar la UI
    final List<PathCard> hand = [
      PathCard(
        id: '1',
        name: 'Curva',
        imageUrl: '',
        connections: {PathDirection.bottom: true, PathDirection.right: true},
      ),
      PathCard(
        id: '2',
        name: 'Recta',
        imageUrl: '',
        connections: {PathDirection.left: true, PathDirection.right: true},
      ),
      PathCard(
        id: '3',
        name: 'T',
        imageUrl: '',
        connections: {
          PathDirection.left: true,
          PathDirection.right: true,
          PathDirection.bottom: true
        },
      ),
    ];

    return Container(
      height: 150,
      padding: const EdgeInsets.symmetric(vertical: 10),
      color: Colors.black54,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: hand.length,
        itemBuilder: (context, index) {
          final card = hand[index];
          return CardItem(card: card);
        },
      ),
    );
  }
}

class CardItem extends StatelessWidget {
  final PathCard card;
  const CardItem({required this.card, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 80,
      margin: const EdgeInsets.symmetric(horizontal: 5),
      decoration: BoxDecoration(
        color: Colors.grey[700],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.amber, width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.terrain, color: Colors.orange, size: 40),
          const SizedBox(height: 5),
          Text(
            card.name,
            style: const TextStyle(fontSize: 12, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
