import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

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
  Future<void> playCard(String gameId, Map<String, dynamic> cardData, int x, int y) async {
    final cardWithPos = {...cardData, 'x': x, 'y': y};
    await _firestore.collection('games').doc(gameId).update({
      'pathCards': FieldValue.arrayUnion([cardWithPos])
    });
  }

  // Empezar la partida
  Future<void> startGame(String gameId) async {
    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing'
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
