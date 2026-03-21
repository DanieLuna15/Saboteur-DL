import 'components/grid_component.dart';
import 'components/path_card_component.dart';
import '../models/card_model.dart';
import '../providers/game_state_provider.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaboteurGame extends FlameGame {
  late GridComponent grid;
  final String gameId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final Map<String, PathCardComponent> _boardCards = {};

  SaboteurGame({required this.gameId});

  @override
  Future<void> onLoad() async {
    grid = GridComponent();
    add(grid);

    // Escuchar cambios en la partida en tiempo real
    _firestore.collection('games').doc(gameId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        _updateBoard(snapshot.data() as Map<String, dynamic>);
      }
    });

    print('Saboteur Game Loaded. GameId: $gameId');
  }

  void _updateBoard(Map<String, dynamic> data) {
    if (_boardCards.isEmpty) {
      _addStartCard();
      _addGoalCards();
    }

    final pathCardsData = data['pathCards'] as List<dynamic>? ?? [];
    for (var cardData in pathCardsData) {
      final card = PathCard.fromMap(cardData as Map<String, dynamic>);
      final x = cardData['x'] as int;
      final y = cardData['y'] as int;
      final cardKey = '${x}_$y';

      if (!_boardCards.containsKey(cardKey)) {
        final comp = PathCardComponent(
          card: card,
          position: Vector2(x * grid.tileSize, y * grid.tileSize),
          size: Vector2(grid.tileSize, grid.tileSize),
        );
        _boardCards[cardKey] = comp;
        add(comp);
      }
    }
  }

  void _addStartCard() {
    final startCard = PathCard(
      id: 'start',
      name: 'Inicio',
      imageUrl: '',
      connections: {
        PathDirection.top: true,
        PathDirection.bottom: true,
        PathDirection.left: true,
        PathDirection.right: true,
      },
    );

    final comp = PathCardComponent(
      card: startCard,
      position: Vector2(0, 3 * grid.tileSize),
      size: Vector2(grid.tileSize, grid.tileSize),
    );
    _boardCards['start'] = comp;
    add(comp);
  }

  void _addGoalCards() {
    for (int i = 0; i < 3; i++) {
      final goalCard = PathCard(
        id: 'goal_$i',
        name: 'Meta',
        imageUrl: '',
        connections: {
          PathDirection.top: true,
          PathDirection.bottom: true,
          PathDirection.left: true,
          PathDirection.right: true,
        },
      );

      final comp = PathCardComponent(
        card: goalCard,
        isFaceDown: true,
        position: Vector2(8 * grid.tileSize, ((i * 2) + 1) * grid.tileSize),
        size: Vector2(grid.tileSize, grid.tileSize),
      );
      _boardCards['goal_$i'] = comp;
      add(comp);
    }
  }
}
