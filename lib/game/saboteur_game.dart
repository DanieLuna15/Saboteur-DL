import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';
import 'package:flame/particles.dart';
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
  final Map<int, PathCardComponent> _goalComponents = {};


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
        final comp = _renderedCards[k];
        if (comp != null) {
           _triggerDustEffect(comp.position);
           comp.die();
        }
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
      position: Vector2(x * grid.tileWidth + grid.tileWidth / 2, y * grid.tileHeight + grid.tileHeight / 2),
      size: Vector2(grid.tileWidth, grid.tileHeight),
    );
    _renderedCards[key] = comp;
    add(comp);
  }

  void _refreshSpecialCards(List<int> revealedIndices, int goldIdx, List<dynamic>? goalShapes) {
    children.whereType<PathCardComponent>().forEach((c) {
       if (c.card.id == 'start') {
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
      position: Vector2(x * grid.tileWidth + grid.tileWidth / 2, y * grid.tileHeight + grid.tileHeight / 2),
      size: Vector2(grid.tileWidth, grid.tileHeight),
      isOptimistic: true,
    );
    _optimisticComponents[key] = comp;
    add(comp);
  }

  void removeOptimisticCard(int x, int y) {
    final key = "${x}_$y";
    _renderedCards[key]?.die();
    _renderedCards.remove(key);
    _optimisticComponents[key]?.die();
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
      position: Vector2(0 * grid.tileWidth + grid.tileWidth / 2, 3 * grid.tileHeight + grid.tileHeight / 2),
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
        
        if (_goalComponents.containsKey(i)) {
          final existing = _goalComponents[i]!;
          if (isRevealed && !existing.isRevealed) {
            existing.flip(PathCard(id: 'goal_$i', name: isGold ? '¡ORO!' : 'Piedra', imageUrl: '', connections: conns));
          }
        } else {
          final component = PathCardComponent(
            card: PathCard(id: 'goal_$i', name: isRevealed ? (isGold ? '¡ORO!' : 'Piedra') : 'Meta', imageUrl: '', connections: conns),
            position: Vector2(8 * grid.tileWidth + grid.tileWidth / 2, (1 + i * 2) * grid.tileHeight + grid.tileHeight / 2),
            size: Vector2(grid.tileWidth, grid.tileHeight),
            isRevealed: isRevealed,
          );
          _goalComponents[i] = component;
          add(component);
        }
    }
  }

  void _triggerDustEffect(Vector2 position) {
    final random = math.Random();
    
    // 1. Efecto de Destello (Flash central)
    add(
      ParticleSystemComponent(
        particle: CircleParticle(
          radius: 40,
          lifespan: 0.2,
          paint: Paint()..color = Colors.white.withOpacity(0.8),
        ),
      ),
    );

    // 2. Partículas de Fuego (Naranja/Rojo)
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 25,
          lifespan: 0.6,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, 200),
            speed: Vector2(math.cos(i) * 150, math.sin(i) * 150),
            position: position.clone(),
            child: CircleParticle(
              radius: 3 + random.nextDouble() * 5,
              paint: Paint()..color = (i % 2 == 0 ? Colors.orange : Colors.redAccent).withOpacity(0.8),
            ),
          ),
        ),
      ),
    );

    // 3. Partículas de Humo (Gris oscuro)
    add(
      ParticleSystemComponent(
        particle: Particle.generate(
          count: 20,
          lifespan: 1.2,
          generator: (i) => AcceleratedParticle(
            acceleration: Vector2(0, -50),
            speed: Vector2(random.nextDouble() * 100 - 50, -random.nextDouble() * 100),
            position: position.clone(),
            child: CircleParticle(
              radius: 4 + random.nextDouble() * 10,
              paint: Paint()..color = Colors.black54.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
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
