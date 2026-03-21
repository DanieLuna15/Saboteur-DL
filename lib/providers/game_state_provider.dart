import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/player_model.dart';
import '../models/card_model.dart';

class GameState {
  final List<PlayerModel> players;
  final String? currentPlayerId;
  final Map<String, CardModel?> board;
  final bool isGameStarted;

  GameState({
    this.players = const [],
    this.currentPlayerId,
    this.board = const {},
    this.isGameStarted = false,
  });

  GameState copyWith({
    List<PlayerModel>? players,
    String? currentPlayerId,
    Map<String, CardModel?>? board,
    bool? isGameStarted,
  }) {
    return GameState(
      players: players ?? this.players,
      currentPlayerId: currentPlayerId ?? this.currentPlayerId,
      board: board ?? this.board,
      isGameStarted: isGameStarted ?? this.isGameStarted,
    );
  }
}

class GameStateNotifier extends Notifier<GameState> {
  @override
  GameState build() {
    return GameState();
  }

  void addPlayer(PlayerModel player) {
    state = state.copyWith(players: [...state.players, player]);
  }

  void startGame() {
    state = state.copyWith(isGameStarted: true);
  }

  void playCard(String playerId, String cardId, int x, int y) {
    // Lógica para poner una carta en el tablero
  }
}

final gameStateProvider = NotifierProvider<GameStateNotifier, GameState>(() {
  return GameStateNotifier();
});
