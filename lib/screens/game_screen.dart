import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../game/saboteur_game.dart';
import '../game/components/player_hand_widget.dart';
import '../providers/game_state_provider.dart';
import '../services/firebase_service.dart';
import '../models/card_model.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  // Key requerida por RiverpodAwareGameWidget en la versión 5.5.3
  final GlobalKey<RiverpodAwareGameWidgetState> _gameKey = GlobalKey<RiverpodAwareGameWidgetState>();

  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(activeGameIdProvider);
    final firebaseService = FirebaseService();

    return Scaffold(
      body: Stack(
        children: [
          DragTarget<PathCard>(
            onAcceptWithDetails: (details) async {
              if (gameId == null) return;

              // Calcular las coordenadas de la grilla (X, Y) basándonos en la posición del drop
              // Usamos 100 porque es el tileSize definido en GridComponent
              final x = (details.offset.dx / 100).floor();
              final y = (details.offset.dy / 100).floor();

              print('Soltando carta $gameId en ($x, $y)');
              await firebaseService.playCard(gameId, details.data.toMap(), x, y);
            },
            builder: (context, candidateData, rejectedData) {
              return RiverpodAwareGameWidget(
                key: _gameKey, // Pasamos la clave requerida
                game: SaboteurGame(),
              );
            },
          ),
          
          // Overlay UI (Botón atrás)
          Positioned(
            top: 40,
            left: 20,
            child: CircleAvatar(
              backgroundColor: Colors.black54,
              child: IconButton(
                icon: const Icon(Icons.arrow_back, color: Colors.amber),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),

          // Mano del jugador en la parte inferior
          const Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: PlayerHandWidget(),
          ),
        ],
      ),
    );
  }
}
