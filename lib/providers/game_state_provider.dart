import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/player_model.dart';
import '../models/card_model.dart';
import '../services/persistence_service.dart';
import '../utils/debug_logger.dart';

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

// Provider para rastrear la partida activa
class ActiveGameIdNotifier extends Notifier<String?> {
  final _persistence = PersistenceService();

  @override
  String? build() {
    // Intentar cargar la partida guardada al iniciar el provider
    _loadStoredGameId();
    return null; 
  }

  Future<void> _loadStoredGameId() async {
    final id = await _persistence.getGameId();
    if (id != null) {
      DebugLogger.log("ActiveGameIdNotifier: Partida recuperada de persistencia local: $id", category: "Persistence");
      state = id;
    }
  }
  
  set state(String? value) {
    super.state = value;
    _persistence.saveGameId(value).then((_) {
      DebugLogger.log("ActiveGameIdNotifier: Estado guardado localmente: $value", category: "Persistence");
    });
  }
}

final activeGameIdProvider = NotifierProvider<ActiveGameIdNotifier, String?>(() {
  return ActiveGameIdNotifier();
});

// Provider para el apodo del usuario actual (para consistencia rápida)
class UserNicknameNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Inicializar desde Firebase si ya hay un usuario (ej: al recargar la app)
    return FirebaseAuth.instance.currentUser?.displayName;
  }
  
  void updateNickname(String? newName) {
    state = newName;
  }
}

final userNicknameProvider = NotifierProvider<UserNicknameNotifier, String?>(() {
  return UserNicknameNotifier();
});

// Provider para el stream de la partida actual
final gameDataProvider = StreamProvider.family<DocumentSnapshot, String>((ref, gameId) {
  return FirebaseFirestore.instance.collection('games').doc(gameId).snapshots();
});
