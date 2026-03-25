import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../services/auth_service.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'waiting_room_screen.dart';
import 'game_screen.dart';
import '../utils/debug_logger.dart';

class LobbyScreen extends ConsumerStatefulWidget {
  const LobbyScreen({super.key});

  @override
  ConsumerState<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends ConsumerState<LobbyScreen> {
  bool _isNavigating = false;

  void _showEditNameDialog(BuildContext context, WidgetRef ref, User user) {
    final currentNickname = ref.read(userNicknameProvider) ?? user.displayName ?? "";
    final TextEditingController controller = TextEditingController(text: currentNickname);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('CAMBIAR APODO', style: TextStyle(color: AppColors.brightGold)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.primaryGold)),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final newName = controller.text.trim();
              if (newName.isNotEmpty) {
                await user.updateDisplayName(newName);
                await user.reload();
                ref.read(userNicknameProvider.notifier).updateNickname(newName);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final firebaseService = FirebaseService();
    final authService = AuthService();
    final nickname = ref.watch(userNicknameProvider);
    
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, authSnapshot) {
        final user = authSnapshot.data;
        if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
        
        final isAnonymous = user.isAnonymous;
        final currentName = isAnonymous 
          ? (nickname ?? user.displayName ?? "Invitado")
          : (user.displayName ?? "Minero Google");

        return Scaffold(
          appBar: AppBar(
            title: const Text('SABOTEUR LOBBY'),
            actions: [
              IconButton(
                icon: const Icon(Icons.logout, color: AppColors.brightGold),
                onPressed: () async {
                  await authService.signOut();
                  ref.read(userNicknameProvider.notifier).updateNickname(null);
                },
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
                          currentName.isNotEmpty ? currentName[0].toUpperCase() : "M",
                          style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Bienvenido,',
                              style: TextStyle(color: AppColors.cream, fontSize: 13),
                            ),
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isAnonymous ? 'Invitado ($currentName)' : currentName,
                                    style: const TextStyle(
                                      color: AppColors.brightGold,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (isAnonymous)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: AppColors.brightGold),
                                    onPressed: () => _showEditNameDialog(context, ref, user),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Botón Reincorporarse (si hay partida activa)
                if (ref.watch(activeGameIdProvider) != null)
                  StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseFirestore.instance.collection('games').doc(ref.watch(activeGameIdProvider)).snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData || !snapshot.data!.exists) return const SizedBox();
                      final data = snapshot.data!.data() as Map<String, dynamic>;
                      final status = data['status'];
                      final players = data['players'] as Map? ?? {};
                      final isMember = players.containsKey(user.uid);

                      if (status == 'playing' && isMember) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: LinearGradient(colors: [Colors.green.shade800, Colors.green.shade500]),
                              boxShadow: [BoxShadow(color: Colors.green.withOpacity(0.5), blurRadius: 10, spreadRadius: 1)],
                            ),
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.refresh, color: Colors.white),
                              label: const Text('¡PARTIDA EN CURSO! REINCORPORARSE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              onPressed: () {
                                DebugLogger.log("Lobby: Reincorporándose a la partida ${ref.read(activeGameIdProvider)}", category: "NAV");
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => GameScreen())
                                );
                              },
                            ),
                          ),
                        );
                      }
                      return const SizedBox();
                    },
                  ),

                // Botón Crear Partida
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
                      onPressed: _isNavigating ? null : () async {
                        setState(() => _isNavigating = true);
                        try {
                          final gameId = await firebaseService.createGame(
                            user.uid, currentName
                          );
                          
                          if (mounted) {
                            ref.read(activeGameIdProvider.notifier).state = gameId;
                            DebugLogger.log("Lobby: Navegando a WaitingRoom (Crear)", category: "NAV");
                            await Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const WaitingRoomScreen()),
                            );
                            // Al volver de la sala, reseteamos el estado de navegación
                            if (mounted) setState(() => _isNavigating = false);
                          }
                        } catch (e) {
                          if (mounted) {
                            setState(() => _isNavigating = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                          }
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
                    stream: FirebaseFirestore.instance.collection('games')
                      .where('status', isEqualTo: 'waiting')
                      .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final now = DateTime.now();
                      final games = snapshot.data!.docs.where((doc) {
                        final data = doc.data() as Map<String, dynamic>?;
                        final players = data?['players'] as Map<dynamic, dynamic>? ?? {};
                        final createdAt = (data?['createdAt'] as Timestamp?)?.toDate() ?? now;
                        final isOverdue = now.difference(createdAt).inMinutes >= 2;
                        
                        if (players[user.uid]?['isHost'] == true) return false;
                        if (isOverdue && players.length < 2) return false;
                        
                        return true;
                      }).toList();
    
                      if (games.isEmpty) {
                        return const Center(
                          child: Text(
                            'No hay otras partidas en espera.\n¡Crea una nueva!',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AppColors.cream),
                          ),
                        );
                      }
    
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        itemCount: games.length,
                        itemBuilder: (context, index) {
                          final gameDoc = games[index];
                          final gameData = gameDoc.data() as Map<String, dynamic>?;
                          final players = gameData?['players'] as Map<dynamic, dynamic>? ?? {};
                          
                          String hostName = 'Desconocido';
                          for (var p in players.values) {
                            if (p is Map && p['isHost'] == true) {
                              hostName = p['name'] ?? 'Desconocido';
                              break;
                            }
                          }
                          
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
                                '${players.length} jugador(es) en espera',
                                style: const TextStyle(color: AppColors.brownSoft),
                              ),
                              trailing: ElevatedButton(
                                onPressed: _isNavigating ? null : () async {
                                  setState(() => _isNavigating = true);
                                  try {
                                    final uniqueName = firebaseService.getUniqueName(
                                      players, currentName, user.uid
                                    );
    
                                    await firebaseService.joinGame(gameDoc.id, user.uid, uniqueName);
                                    
                                    if (mounted) {
                                      ref.read(activeGameIdProvider.notifier).state = gameDoc.id;
                                      DebugLogger.log("Lobby: Navegando a WaitingRoom (Unirse)", category: "NAV");
                                      await Navigator.push(
                                        context,
                                        MaterialPageRoute(builder: (context) => const WaitingRoomScreen()),
                                      );
                                      if (mounted) setState(() => _isNavigating = false);
                                    }
                                  } catch (e) {
                                    if (mounted) {
                                      setState(() => _isNavigating = false);
                                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                                    }
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
      },
    );
  }
}
