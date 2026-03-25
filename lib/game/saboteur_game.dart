import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'components/path_card_component.dart';
import '../models/card_model.dart';

class SaboteurGame extends FlameGame {
  final String gameId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  StreamSubscription? _boardSub;
  Map<String, dynamic>? _lastData;
  bool isMounted = false;

  final Map<String, PathCardComponent> _renderedCards = {};
  final Map<String, PathCardComponent> _optimisticComponents = {};

  SaboteurGame({required this.gameId});

  @override
  Future<void> onLoad() async {
    isMounted = true;
    add(BackgroundGridComponent());
    _boardSub = _firestore.collection('games').doc(gameId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        _lastData = data;
        _updateBoard(data);
      }
    });
  }

  void updateGameState(Map<String, dynamic> data) {
    if (!isMounted) {
      _lastData = data;
      return;
    }
    _lastData = data;
    _updateBoard(data);
  }

  @override
  void onRemove() {
    isMounted = false;
    _boardSub?.cancel();
    super.onRemove();
  }

  void _updateBoard(Map<String, dynamic> data) {
    if (!isMounted) return;

    final pathCardsData = data['pathCards'] as List? ?? [];
    final goldIdx = data['goldGoalIndex'] as int? ?? -1;
    final revealedGoalsIndices = List<int>.from(data['revealedGoals'] ?? []);
    final goalShapes = data['goalShapes'] as List<dynamic>?;

    final Set<String> serverCardKeys = {};
    for (var cardData in pathCardsData) {
        final map = cardData as Map<String, dynamic>;
        final x = map['x'] as int;
        final y = map['y'] as int;
        final key = "${x}_$y";
        serverCardKeys.add(key);

        if (!_renderedCards.containsKey(key)) {
            _renderRealCard(PathCard.fromMap(map), x, y, key);
        }
    }

    final keysToRemove = _renderedCards.keys.where((k) => !serverCardKeys.contains(k)).toList();
    for (var k in keysToRemove) {
        _renderedCards[k]?.removeFromParent();
        _renderedCards.remove(k);
    }

    _optimisticComponents.removeWhere((key, comp) {
      if (serverCardKeys.contains(key)) {
        comp.removeFromParent();
        return true;
      }
      return false;
    });

    _refreshSpecialCards(revealedGoalsIndices, goldIdx, goalShapes);
  }

  void _renderRealCard(PathCard card, int x, int y, String key) {
    final comp = PathCardComponent(
      card: card,
      position: Vector2(x * grid.tileWidth, y * grid.tileHeight),
      size: Vector2(grid.tileWidth, grid.tileHeight),
    );
    _renderedCards[key] = comp;
    add(comp);
  }

  void _refreshSpecialCards(List<int> revealedIndices, int goldIdx, List<dynamic>? goalShapes) {
    children.whereType<PathCardComponent>().forEach((c) {
       if (c.card.id == 'start' || c.card.id.startsWith('goal')) {
          c.removeFromParent();
       }
    });

    _addStartCard();
    _addGoalCards(revealedIndices, goldIdx, goalShapes);
  }

  void addOptimisticCard(PathCard card, int x, int y) {
    final key = "${x}_$y";
    if (_renderedCards.containsKey(key)) return;

    final comp = PathCardComponent(
      card: card,
      position: Vector2(x * grid.tileWidth, y * grid.tileHeight),
      size: Vector2(grid.tileWidth, grid.tileHeight),
      isOptimistic: true,
    );
    _optimisticComponents[key] = comp;
    add(comp);
  }

  void removeOptimisticCard(int x, int y) {
    final key = "${x}_$y";
    _renderedCards[key]?.removeFromParent();
    _renderedCards.remove(key);
    _optimisticComponents[key]?.removeFromParent();
    _optimisticComponents.remove(key);
  }

  void refreshBoard() {
    for (var c in _optimisticComponents.values) { c.removeFromParent(); }
    _optimisticComponents.clear();
    if (_lastData != null) _updateBoard(_lastData!);
  }

  void _addStartCard() {
    add(PathCardComponent(
      card: PathCard(id: 'start', name: 'Inicio', imageUrl: '', connections: {PathDirection.top: true, PathDirection.bottom: true, PathDirection.left: true, PathDirection.right: true}),
      position: Vector2(0 * grid.tileWidth, 3 * grid.tileHeight),
      size: Vector2(grid.tileWidth, grid.tileHeight),
    ));
  }

  void _addGoalCards(List<int> revealedIndices, int goldIdx, List<dynamic>? goalShapes) {
    for (int i = 0; i < 3; i++) {
        final isRevealed = revealedIndices.contains(i);
        final isGold = i == goldIdx;
        Map<PathDirection, bool> conns = {PathDirection.top: true, PathDirection.bottom: true, PathDirection.left: true, PathDirection.right: true};
        if (goalShapes != null && goalShapes.length > i) {
           final shape = goalShapes[i] as Map<String, dynamic>;
           conns = {PathDirection.top: shape['top'] ?? false, PathDirection.bottom: shape['bottom'] ?? false, PathDirection.left: shape['left'] ?? false, PathDirection.right: shape['right'] ?? false};
        }
        add(PathCardComponent(
          card: PathCard(id: 'goal_$i', name: isRevealed ? (isGold ? '¡ORO!' : 'Piedra') : 'Meta', imageUrl: '', connections: conns),
          position: Vector2(8 * grid.tileWidth, (1 + i * 2) * grid.tileHeight),
          size: Vector2(grid.tileWidth, grid.tileHeight),
          isRevealed: isRevealed,
        ));
    }
  }

  GridInfo get grid => GridInfo();
}

class BackgroundGridComponent extends Component with HasGameRef<SaboteurGame> {
  @override
  void render(Canvas canvas) {
    final paint = Paint()
      ..color = const Color(0xFF333333)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    final grid = GridInfo();
    for (int i = 0; i <= 10; i++) {
      canvas.drawLine(Offset(i * grid.tileWidth, 0), Offset(i * grid.tileWidth, 7 * grid.tileHeight), paint);
    }
    for (int j = 0; j <= 7; j++) {
      canvas.drawLine(Offset(0, j * grid.tileHeight), Offset(10 * grid.tileWidth, j * grid.tileHeight), paint);
    }
  }
}

class GridInfo {
  final double tileWidth = 80;
  final double tileHeight = 110;
}
