import 'components/grid_component.dart';
import 'components/path_card_component.dart';
import '../models/card_model.dart';
import 'package:flame/game.dart';

class SaboteurGame extends FlameGame {
  late GridComponent grid;

  @override
  Future<void> onLoad() async {
    grid = GridComponent();
    add(grid);

    // 1. Carta de Inicio (Escalera) en (0, 2) relative to grid
    _addStartCard();

    // 2. Cartas de Meta en (8, 0), (8, 2), (8, 4) relative to grid
    _addGoalCards();

    print('Saboteur Game Loaded with Initial Board');
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
