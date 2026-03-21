import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
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
        title: const Text('SABOTEUR LOBBY'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.brightGold),
            onPressed: () => authService.signOut(),
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.darkGradient,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(24.0),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: AppColors.primaryGold,
                    child: Text(
                      user?.displayName?[0] ?? "I",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Bienvenido,',
                        style: TextStyle(color: AppColors.cream, fontSize: 14),
                      ),
                      Text(
                        user?.displayName ?? "Invitado",
                        style: const TextStyle(
                          color: AppColors.brightGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Container(
                width: double.infinity,
                decoration: AppTheme.goldGlowDecoration,
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.add_box_rounded, color: Colors.black),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    padding: const EdgeInsets.symmetric(vertical: 16),
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
                  label: const Text(
                    'CREAR NUEVA PARTIDA',
                    style: TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                ),
              ),
            ),
            
            const SizedBox(height: 24),
            const Divider(indent: 24, endIndent: 24),
            
            const Padding(
              padding: EdgeInsets.all(24.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'PARTIDAS DISPONIBLES',
                  style: TextStyle(
                    color: AppColors.brightGold,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ),
            
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: FirebaseFirestore.instance.collection('games').snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  
                  final games = snapshot.data!.docs;
                  if (games.isEmpty) {
                    return const Center(
                      child: Text(
                        'No hay partidas activas.\n¡Sé el primero en crear una!',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.cream),
                      ),
                    );
                  }

                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    itemCount: games.length,
                    itemBuilder: (context, index) {
                      final game = games[index];
                      final players = game['players'] as Map<dynamic, dynamic>;
                      final hostName = players.values.first['name'];
                      
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: AppTheme.premiumCardDecoration,
                        child: ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          title: Text(
                            'Mina de $hostName',
                            style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.cream),
                          ),
                          subtitle: Text(
                            'Estado: ${game['status']} • ${players.length} jugadores',
                            style: const TextStyle(color: AppColors.brownSoft),
                          ),
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
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.blueDark,
                              foregroundColor: AppColors.brightGold,
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                            ),
                            child: const Text('UNIRSE'),
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
      ),
    );
  }
}
