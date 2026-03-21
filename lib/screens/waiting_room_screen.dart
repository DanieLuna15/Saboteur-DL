import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  Timer? _cleanupTimer;
  bool _isDeleting = false;
  bool _isExitingManually = false;

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // BOTÓN DERECHO: ELIMINAR MINA COMPLETA (Solo Host)
  void _handleHostDeleteRoom(BuildContext context, String gameId, FirebaseService service) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('¿ELIMINAR MINA?', style: TextStyle(color: AppColors.brightGold)),
        content: const Text('Se cancelará la partida para todos los jugadores.', style: TextStyle(color: AppColors.cream)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isExitingManually = true);
              Navigator.pop(context); // Cerrar diálogo
              
              try {
                await service.deleteGame(gameId);
                
                if (mounted) {
                  Navigator.of(context).pop();
                }
              } catch (e) {
                if (mounted) {
                  setState(() => _isExitingManually = false);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade900),
            child: const Text('ELIMINAR'),
          ),
        ],
      ),
    );
  }

  // BOTÓN IZQUIERDO / ATRÁS: SALIR (Host o Jugador)
  Future<void> _handleBackPress(BuildContext context, bool isHost, String gameId, String uid, FirebaseService service) async {
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: Text(isHost ? '¿ELIMINAR SALA?' : '¿SALIR DE LA SALA?', style: const TextStyle(color: AppColors.brightGold)),
        content: Text(
          isHost 
            ? 'Si te vas, la sala se cerrará para todos los mineros.' 
            : '¿Estás seguro de que quieres abandonar esta mina?',
          style: const TextStyle(color: AppColors.cream)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: isHost ? Colors.red.shade900 : AppColors.blueDark),
            child: const Text('SALIR'),
          ),
        ],
      ),
    );

    if (shouldLeave == true && mounted) {
      setState(() => _isExitingManually = true);
      try {
        if (isHost) {
          await service.deleteGame(gameId);
        } else {
          await service.leaveGame(gameId, uid);
        }
        if (mounted) {
          Navigator.of(context).pop();
        }
      } catch (e) {
        if (mounted) {
          setState(() => _isExitingManually = false);
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
        }
      }
    }
  }

  void _showChangeNameDialog(BuildContext context, String gameId, String currentUid, Map<dynamic, dynamic> players, FirebaseService service) {
    final TextEditingController controller = TextEditingController(text: players[currentUid]['name']);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('CAMBIAR NOMBRE', style: TextStyle(color: AppColors.brightGold)),
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
              final newName = service.getUniqueName(players, controller.text.trim(), currentUid);
              await service.updatePlayerName(gameId, currentUid, newName);
              ref.read(userNicknameProvider.notifier).updateNickname(newName);
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  void _setupAutoCleanup(String gameId, DateTime createdAt, int playerCount, FirebaseService service) {
    if (playerCount >= 3) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      return;
    }
    
    if (_cleanupTimer != null || _isDeleting) return;

    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final remainingSeconds = 120 - difference.inSeconds;

    if (remainingSeconds <= 0 && playerCount < 3) {
      _triggerAutoDelete(gameId, service);
    } else if (remainingSeconds > 0) {
      _cleanupTimer = Timer(Duration(seconds: remainingSeconds), () {
        if (mounted) {
           _triggerAutoDelete(gameId, service);
        }
      });
    }
  }

  Future<void> _triggerAutoDelete(String gameId, FirebaseService service) async {
    if (_isDeleting) return;
    _isDeleting = true;
    await service.deleteGame(gameId);
  }

  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(activeGameIdProvider);
    final firebaseService = FirebaseService();

    if (gameId == null) return const Scaffold(body: Center(child: Text('No hay partida activa')));

    return StreamBuilder<DocumentSnapshot>(
      stream: FirebaseFirestore.instance.collection('games').doc(gameId).snapshots(),
      builder: (context, snapshot) {
        // El documento desaparece
        if (snapshot.hasData && !snapshot.data!.exists) {
          if (!_isExitingManually) {
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted) {
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            });
          }
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        if (!snapshot.hasData) return const Scaffold(body: Center(child: CircularProgressIndicator()));

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Scaffold(body: Center(child: Text('Error al cargar datos')));

        final players = data['players'] as Map<dynamic, dynamic>;
        final status = data['status'] as String;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        final currentUid = firebaseService.currentUid;
        final amIHost = players[currentUid]?['isHost'] ?? false;

        if (amIHost && status == 'waiting') {
          _setupAutoCleanup(gameId, createdAt, players.length, firebaseService);
        } else {
          _cleanupTimer?.cancel();
          _cleanupTimer = null;
        }

        if (status == 'playing') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            Navigator.pushReplacement(
              context,
              MaterialPageRoute(builder: (context) => const GameScreen()),
            );
          });
        }

        return PopScope(
          canPop: _isExitingManually,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleBackPress(context, amIHost, gameId, currentUid, firebaseService);
          },
          child: Scaffold(
            appBar: AppBar(
              title: const Text('SALA DE ESPERA'),
              leading: IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => _handleBackPress(context, amIHost, gameId, currentUid, firebaseService),
              ),
              actions: [
                if (amIHost)
                  IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onPressed: () => _handleHostDeleteRoom(context, gameId, firebaseService),
                  ),
              ],
            ),
            body: Container(
              decoration: const BoxDecoration(gradient: AppColors.darkGradient),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      children: [
                        Text('MINA: $gameId', style: const TextStyle(color: AppColors.brightGold, fontSize: 16)),
                        const SizedBox(height: 10),
                        Text('${players.length} Jugador(es) en la mina', style: const TextStyle(color: AppColors.cream)),
                        if (amIHost && players.length < 3)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'La sala se cerrará en 2 minutos si no hay 3 jugadores',
                              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      itemCount: players.length,
                      itemBuilder: (context, index) {
                        final playerId = players.keys.toList()[index];
                        final player = players[playerId];
                        final isMe = playerId == currentUid;
        
                        return Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: isMe ? AppTheme.goldGlowDecoration : AppTheme.premiumCardDecoration,
                          child: ListTile(
                            leading: Icon(
                              player['isHost'] ? Icons.shield : Icons.person,
                              color: player['isHost'] ? AppColors.brightGold : AppColors.cream,
                            ),
                            title: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    isMe ? '${player['name']} (YO)' : player['name'],
                                    style: TextStyle(
                                      color: isMe ? Colors.black : AppColors.cream, 
                                      fontWeight: FontWeight.bold
                                    ),
                                  ),
                                ),
                                if (isMe)
                                  IconButton(
                                    icon: const Icon(Icons.edit, size: 18, color: Colors.black54),
                                    onPressed: () => _showChangeNameDialog(context, gameId, currentUid, players, firebaseService),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                              ],
                            ),
                            trailing: player['isHost'] 
                              ? Text('ANFITRIÓN', style: TextStyle(color: isMe ? Colors.black : AppColors.brightGold, fontSize: 10))
                              : const Text('LISTO', style: TextStyle(color: Colors.green, fontSize: 10)),
                          ),
                        );
                      },
                    ),
                  ),
                  if (amIHost)
                    Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        children: [
                          if (players.length < 3)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Se necesitan al menos 3 jugadores para empezar',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            decoration: AppTheme.goldGlowDecoration,
                            child: ElevatedButton(
                              onPressed: players.length >= 3
                                ? () => firebaseService.startGame(gameId)
                                : null,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                              ),
                              child: const Text('EMPEZAR PARTIDA', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    const Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text('Esperando a que el anfitrión comience...', 
                        style: TextStyle(color: AppColors.cream, fontStyle: FontStyle.italic)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
