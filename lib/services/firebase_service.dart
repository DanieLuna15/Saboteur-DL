import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

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
    final doc = await _firestore.collection('games').add({
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
      'pathCards': [], // Cartas jugadas en el tablero
      'currentTurn': hostId,
      'createdAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }
}
