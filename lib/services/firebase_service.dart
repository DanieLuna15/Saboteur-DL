import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../game/deck_utils.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser?.uid ?? '';

  // Stream de la partida actual
  Stream<DocumentSnapshot> gameStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots();
  }

  // Unirse a una partida
  Future<void> joinGame(String gameId, String playerId, String playerName) async {
    await _firestore.collection('games').doc(gameId).set({
      'players': {
        playerId: {
          'name': playerName,
          'role': 'unknown',
          'gold': 0,
          'isHost': false,
          'isReady': false,
        }
      }
    }, SetOptions(merge: true));
  }

  // Crear una nueva partida
  Future<String> createGame(String hostId, String hostName) async {
    final docRef = _firestore.collection('games').doc();
    await docRef.set({
      'status': 'waiting',
      'players': {
        hostId: {
          'name': hostName,
          'role': 'unknown',
          'gold': 0,
          'isHost': true,
          'isReady': true,
        }
      },
      'board': {},
      'pathCards': [],
      'currentTurn': hostId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return docRef.id;
  }

  // Jugar una carta en el tablero
  Future<void> playCard(String gameId, String playerId, Map<String, dynamic> cardData, int x, int y) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(gameRef);
      if (!doc.exists) throw Exception('Partida no encontrada');

      final data = doc.data()!;
      if (data['currentTurn'] != playerId) throw Exception('No es tu turno');

      final players = data['players'] as Map<dynamic, dynamic>;
      final hand = List.from(players[playerId]['hand']);
      hand.removeWhere((c) => c['id'] == cardData['id']);

      transaction.update(gameRef, {
        'pathCards': FieldValue.arrayUnion([
          {...cardData, 'x': x, 'y': y}
        ]),
        'players.$playerId.hand': hand,
      });
    });
  }

  Future<void> discardCard(String gameId, String playerId, Map<String, dynamic> cardData) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(gameRef);
      if (!doc.exists) throw Exception('Partida no encontrada');

      final data = doc.data()!;
      if (data['currentTurn'] != playerId) throw Exception('No es tu turno');

      final players = data['players'] as Map<dynamic, dynamic>;
      final hand = List.from(players[playerId]['hand']);
      hand.removeWhere((c) => c['id'] == cardData['id']);

      transaction.update(gameRef, {
        'players.$playerId.hand': hand,
      });
    });
  }

  // Finalizar turno, robar carta y pasar turno
  Future<void> endTurnAndDraw(String gameId, String playerId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(gameRef);
      if (!doc.exists) throw Exception('Partida no encontrada');
      final data = doc.data()!;
      if (data['currentTurn'] != playerId) throw Exception('No es tu turno');
      
      final players = data['players'] as Map<dynamic, dynamic>;
      final deck = List.from(data['deck'] as List<dynamic>? ?? []);
      
      final hand = List.from(players[playerId]['hand']);
      
      if (deck.isNotEmpty) {
        final newCard = deck.removeAt(0);
        hand.add(newCard); // Robar una carta
      }

      final playOrder = List<String>.from(data['playOrder']);
      final currentTurnIndex = playOrder.indexOf(data['currentTurn']);
      final nextTurnIndex = (currentTurnIndex + 1) % playOrder.length;
      final nextTurnId = playOrder[nextTurnIndex];

      transaction.update(gameRef, {
        'deck': deck,
        'players.$playerId.hand': hand,
        'currentTurn': nextTurnId,
        'turnNumber': FieldValue.increment(1),
        'turnStartTime': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> forceSkipTurn(String gameId, String playerId) async {
    final gameRef = _firestore.collection('games').doc(gameId);
    return _firestore.runTransaction((transaction) async {
      final doc = await transaction.get(gameRef);
      if (!doc.exists) throw Exception('Partida no encontrada');
      final data = doc.data()!;
      if (data['currentTurn'] != playerId) return; // Ya no es su turno

      final players = data['players'] as Map<dynamic, dynamic>;
      final deck = List.from(data['deck'] as List<dynamic>? ?? []);
      final hand = List.from(players[playerId]['hand']);
      
      // Pierde carta aleatoria si tiene (la primera de la mano)
      if (hand.isNotEmpty) {
        hand.removeAt(0); 
      }
      
      // Repone la carta si aún hay en la baraja
      if (deck.isNotEmpty) {
        final newCard = deck.removeAt(0);
        hand.add(newCard);
      }

      // Pasar el turno al siguiente jugador de la mesa
      final playOrder = List<String>.from(data['playOrder']);
      final currentTurnIndex = playOrder.indexOf(data['currentTurn']);
      final nextTurnIndex = (currentTurnIndex + 1) % playOrder.length;
      final nextTurnId = playOrder[nextTurnIndex];

      transaction.update(gameRef, {
        'deck': deck,
        'players.$playerId.hand': hand,
        'currentTurn': nextTurnId,
        'turnNumber': FieldValue.increment(1),
        'turnStartTime': FieldValue.serverTimestamp(),
      });
    });
  }

  // Toggle ready status
  Future<void> toggleReadyStatus(String gameId, String playerId, bool isReady) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId.isReady': isReady
    });
  }

  // Empezar la partida con asignación de roles
  Future<void> startGame(String gameId) async {
    final doc = await _firestore.collection('games').doc(gameId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final playerIds = players.keys.toList()..shuffle();
    final numPlayers = playerIds.length;

    // Determinar número de saboteadores
    int numSaboteurs = 1;
    if (numPlayers >= 5 && numPlayers <= 6) numSaboteurs = 2;
    if (numPlayers >= 7) numSaboteurs = 3;
    // Si solo hay 2 para pruebas, 1 de cada uno
    if (numPlayers == 2) numSaboteurs = 1;

    // Generar mazo y definir tamaño de mano
    final initialDeck = DeckUtils.generateStandardDeck();
    int handSize = 6;
    if (numPlayers >= 6) handSize = 5;
    if (numPlayers >= 8) handSize = 4;

    for (int i = 0; i < numPlayers; i++) {
        final role = i < numSaboteurs ? 'saboteur' : 'miner';
        
        final playerHand = <Map<String, dynamic>>[];
        for (int j = 0; j < handSize; j++) {
            if (initialDeck.isNotEmpty) {
                playerHand.add(initialDeck.removeLast().toMap());
            }
        }
        
        players[playerIds[i]]['role'] = role;
        players[playerIds[i]]['hand'] = playerHand;
    }

    final serializedDeck = initialDeck.map((c) => c.toMap()).toList();

    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing',
      'players': players,
      'deck': serializedDeck,
      'playOrder': playerIds,
      'currentTurn': playerIds.first,
      'turnNumber': 1,
      'turnStartTime': FieldValue.serverTimestamp(),
    });
  }

  // Eliminar la partida
  Future<void> deleteGame(String gameId) async {
    await _firestore.collection('games').doc(gameId).delete();
  }

  // Actualizar nombre de un jugador
  Future<void> updatePlayerName(String gameId, String playerId, String newName) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId.name': newName
    });
  }

  // Salir de una partida
  Future<void> leaveGame(String gameId, String playerId) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId': FieldValue.delete()
    });
  }

  // Generar un nombre único si ya existe uno igual en la sala
  String getUniqueName(Map<dynamic, dynamic> players, String targetName, String currentId) {
    List<String> existingNames = [];
    players.forEach((id, data) {
      if (id != currentId) { // No compararse con uno mismo si estamos editando
        existingNames.add(data['name'].toString());
      }
    });

    if (!existingNames.contains(targetName)) return targetName;

    int counter = 2;
    String newName = '$targetName ($counter)';
    while (existingNames.contains(newName)) {
      counter++;
      newName = '$targetName ($counter)';
    }
    return newName;
  }
}
