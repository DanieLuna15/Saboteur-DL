import 'components/grid_component.dart';
import 'components/path_card_component.dart';
import '../models/card_model.dart';
import '../providers/game_state_provider.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SaboteurGame extends FlameGame with RiverpodGameMixin {
  late GridComponent grid;
  String? gameId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> onLoad() async {
    grid = GridComponent();
    add(grid);

    // Obtener el ID de la partida desde el provider
    gameId = ref.read(activeGameIdProvider);

    if (gameId != null) {
      // Escuchar cambios en la partida en tiempo real
      _firestore.collection('games').doc(gameId).snapshots().listen((snapshot) {
        if (snapshot.exists) {
          _updateBoard(snapshot.data() as Map<String, dynamic>);
        }
      });
    } else {
      // Modo local (para pruebas)
      _addStartCard();
      _addGoalCards();
    }

    print('Saboteur Game Loaded. GameId: $gameId');
  }

  void _updateBoard(Map<String, dynamic> data) {
    // 1. Limpiar cartas actuales del grid (excepto el grid mismo)
    children.whereType<PathCardComponent>().forEach((c) => c.removeFromParent());

    // 2. Re-agregar la carta de Inicio y Metas (siempre fijas en este demo)
    _addStartCard();
    _addGoalCards();

    // 3. Agregar cartas jugadas desde el servidor
    final pathCardsData = data['pathCards'] as List<dynamic>? ?? [];
    for (var cardData in pathCardsData) {
      final card = PathCard.fromMap(cardData as Map<String, dynamic>);
      final x = cardData['x'] as int;
      final y = cardData['y'] as int;

      add(PathCardComponent(
        card: card,
        position: Vector2(x * grid.tileSize, y * grid.tileSize),
        size: Vector2(grid.tileSize, grid.tileSize),
      ));
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

    add(PathCardComponent(
      card: startCard,
      position: Vector2(0, 2 * grid.tileSize),
      size: Vector2(grid.tileSize, grid.tileSize),
    ));
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

      add(PathCardComponent(
        card: goalCard,
        isFaceDown: true,
        position: Vector2(8 * grid.tileSize, (i * 2) * grid.tileSize),
        size: Vector2(grid.tileSize, grid.tileSize),
      ));
    }
  }
}
