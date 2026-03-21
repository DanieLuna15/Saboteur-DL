import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import 'game_screen.dart';

class LobbyScreen extends ConsumerWidget {
  const LobbyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firebaseService = FirebaseService();
    final authService = AuthService();
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Lobby - Saboteur Online'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text('Bienvenido, ${user?.displayName ?? "Invitado"}',
                style: const TextStyle(fontSize: 18)),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.amber,
              foregroundColor: Colors.black,
              minimumSize: const Size(200, 50),
            ),
            onPressed: () async {
              final gameId = await firebaseService.createGame(
                user!.uid, user.displayName ?? "Invitado"
              );
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const GameScreen()),
                );
              }
            },
            label: const Text('Crear Nueva Partida', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Text('Partidas Disponibles:', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('games').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final games = snapshot.data!.docs;
                if (games.isEmpty) {
                  return const Center(child: Text('No hay partidas activas. ¡Crea una!'));
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: games.length,
                  itemBuilder: (context, index) {
                    final game = games[index];
                    final players = game['players'] as Map<dynamic, dynamic>;
                    
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        title: Text('Partida de ${players.values.first['name']}'),
                        subtitle: Text('Estado: ${game['status']} • Jugadores: ${players.length}'),
                        trailing: ElevatedButton(
                          onPressed: () async {
                            await firebaseService.joinGame(
                                game.id, user!.uid, user.displayName ?? "Invitado");
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const GameScreen()),
                              );
                            }
                          },
                          child: const Text('Unirse'),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
