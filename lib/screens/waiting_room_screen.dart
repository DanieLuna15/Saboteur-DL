import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/firebase_service.dart';
import '../providers/game_state_provider.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';
import '../utils/debug_logger.dart';

class WaitingRoomScreen extends ConsumerStatefulWidget {
  const WaitingRoomScreen({super.key});

  @override
  ConsumerState<WaitingRoomScreen> createState() => _WaitingRoomScreenState();
}

class _WaitingRoomScreenState extends ConsumerState<WaitingRoomScreen> {
  Timer? _cleanupTimer;
  bool _isDeleting = false;
  bool _isExitingManually = false;
  bool _hasNavigatedToGame = false;

  @override
  void dispose() {
    _cleanupTimer?.cancel();
    super.dispose();
  }

  // BOTÓN DERECHO: ELIMINAR MINA COMPLETA (Solo Host)
  void _handleHostDeleteRoom(BuildContext context, String gameId, FirebaseService service) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('¿ELIMINAR MINA?', style: TextStyle(color: AppColors.brightGold)),
        content: const Text('Se cancelará la partida para todos los jugadores.', style: TextStyle(color: AppColors.cream)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCELAR', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              setState(() => _isExitingManually = true);
              Navigator.pop(dialogContext); // Cerrar diálogo
              
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
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: Text(isHost ? '¿ELIMINAR SALA?' : '¿SALIR DE LA SALA?', style: const TextStyle(color: AppColors.brightGold)),
        content: Text(
          isHost 
            ? 'Si te vas, la sala se cerrará para todos los mineros.' 
            : '¿Estás seguro de que quieres abandonar esta mina?',
          style: const TextStyle(color: AppColors.cream)
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
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
        ref.read(activeGameIdProvider.notifier).state = null;
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

  void _showSettingsDialog(BuildContext context, String gameId, int playerCount, Map<String, dynamic>? currentSettings, FirebaseService service) {
    final int recommendedSaboteurs = playerCount <= 4 ? 1 : (playerCount <= 6 ? 2 : 3);
    const int recommendedRounds = 3;
    const int recommendedDeckSize = 70;

    int numRounds = currentSettings?['numRounds'] ?? recommendedRounds;
    int numSaboteurs = currentSettings?['numSaboteurs'] ?? recommendedSaboteurs;
    int deckSize = currentSettings?['deckSize'] ?? recommendedDeckSize;
    int turnTime = currentSettings?['turnTime'] ?? 60;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: AppColors.darkBackground,
          title: const Text('CONFIGURACIÓN DE PARTIDA', style: TextStyle(color: AppColors.brightGold, fontSize: 18)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSettingSlider(
                  'Rondas', 
                  numRounds.toDouble(), 
                  1, 10, 
                  (val) => setDialogState(() => numRounds = val.toInt()),
                  'Sug: $recommendedRounds'
                ),
                const SizedBox(height: 16),
                _buildSettingSlider(
                  'Saboteadores', 
                  numSaboteurs.toDouble(), 
                  1, (playerCount - 1).clamp(1, 4).toDouble(), 
                  (val) => setDialogState(() => numSaboteurs = val.toInt()),
                  'Sug: $recommendedSaboteurs'
                ),
                const SizedBox(height: 16),
                _buildSettingSlider(
                  'Cartas en Mazo', 
                  deckSize.toDouble(), 
                  30, 100, 
                  (val) => setDialogState(() => deckSize = val.toInt()),
                  'Sug: $recommendedDeckSize'
                ),
                const SizedBox(height: 16),
                _buildSettingSlider(
                  'Tiempo x Turno', 
                  turnTime.toDouble(), 
                  15, 120, 
                  (val) => setDialogState(() => turnTime = val.toInt()),
                  'Sug: 60s'
                ),
                const SizedBox(height: 20),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      setDialogState(() {
                        numRounds = recommendedRounds;
                        numSaboteurs = recommendedSaboteurs;
                        deckSize = recommendedDeckSize;
                        turnTime = 60;
                      });
                    },
                    icon: const Icon(Icons.auto_awesome, size: 16, color: Colors.cyanAccent),
                    label: const Text('ACEPTAR RECOMENDACIÓN', style: TextStyle(color: Colors.cyanAccent, fontSize: 12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
            ElevatedButton(
              onPressed: () async {
                await service.updateGameSettings(gameId, {
                  'numRounds': numRounds,
                  'numSaboteurs': numSaboteurs,
                  'deckSize': deckSize,
                  'turnTime': turnTime,
                });
                if (dialogContext.mounted) Navigator.pop(dialogContext);
              },
              child: const Text('GUARDAR'),
            ),
          ],
        ),
      ),
    );
  }

  void _showChangeNameDialog(BuildContext context, String gameId, String currentUid, Map<dynamic, dynamic> players, FirebaseService service) {
    final TextEditingController controller = TextEditingController(text: players[currentUid]['name']);
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
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
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('CANCELAR')),
          ElevatedButton(
            onPressed: () async {
              final newName = service.getUniqueName(players, controller.text.trim(), currentUid);
              await service.updatePlayerName(gameId, currentUid, newName);
              ref.read(userNicknameProvider.notifier).updateNickname(newName);
              if (dialogContext.mounted) Navigator.pop(dialogContext);
            },
            child: const Text('GUARDAR'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingSlider(String label, double value, double min, double max, Function(double) onChanged, String suggestion) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold)),
            Text(suggestion, style: const TextStyle(color: Colors.grey, fontSize: 10, fontStyle: FontStyle.italic)),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: Slider(
                value: value,
                min: min,
                max: max,
                divisions: (max - min).toInt() == 0 ? 1 : (max - min).toInt(),
                activeColor: AppColors.brightGold,
                inactiveColor: Colors.grey.shade800,
                onChanged: onChanged,
              ),
            ),
            Container(
              width: 30,
              alignment: Alignment.center,
              child: Text(value.toInt().toString(), style: const TextStyle(color: AppColors.brightGold, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  void _setupAutoCleanup(String gameId, DateTime createdAt, int playerCount, FirebaseService service) {
    if (playerCount >= 2) {
      _cleanupTimer?.cancel();
      _cleanupTimer = null;
      return;
    }
    
    if (_cleanupTimer != null || _isDeleting) return;

    final now = DateTime.now();
    final difference = now.difference(createdAt);
    final remainingSeconds = 120 - difference.inSeconds;

    if (remainingSeconds <= 0 && playerCount < 2) {
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
          if (!_isExitingManually && !_hasNavigatedToGame) {
            DebugLogger.log("WaitingRoom: El documento de juego ya no existe. Activando PopUntil.", category: "NAV");
            ref.read(activeGameIdProvider.notifier).state = null; // Limpiar ID guardado
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (context.mounted && ModalRoute.of(context)?.isCurrent == true) {
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
        final settings = data['settings'] as Map<String, dynamic>?;
        final createdAt = (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
        
        final currentUid = firebaseService.currentUid;
        final amIHost = players[currentUid]?['isHost'] ?? false;
        
        int readyCount = players.values.where((p) => p['isReady'] == true || p['isHost'] == true).length;
        bool allReady = readyCount == players.length;

        if (amIHost && status == 'waiting') {
          _setupAutoCleanup(gameId, createdAt, players.length, firebaseService);
        } else {
          _cleanupTimer?.cancel();
          _cleanupTimer = null;
        }

        if (status == 'playing' && !_hasNavigatedToGame) {
          _hasNavigatedToGame = true;
          DebugLogger.log("WaitingRoom: Transición confirmada a GameScreen (status: playing).", category: "NAV");
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => GameScreen()),
              );
            }
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
                if (amIHost)
                  IconButton(
                    icon: const Icon(Icons.settings, color: AppColors.cream),
                    onPressed: () => _showSettingsDialog(context, gameId, players.length, settings, firebaseService),
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
                        const SizedBox(height: 5),
                        Text('$readyCount/${players.length} Jugador(es) listos', 
                          style: TextStyle(
                            color: allReady ? Colors.greenAccent : AppColors.orangeAccent, 
                            fontWeight: FontWeight.bold
                          )
                        ),
                        if (amIHost && players.length < 2)
                          const Padding(
                            padding: EdgeInsets.only(top: 8.0),
                            child: Text(
                              'La sala se cerrará en 2 minutos si no hay 2 jugadores',
                              style: TextStyle(color: Colors.orangeAccent, fontSize: 11, fontStyle: FontStyle.italic),
                            ),
                          ),
                        if (settings != null)
                           Padding(
                             padding: const EdgeInsets.only(top: 12.0),
                             child: Container(
                               padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                               decoration: BoxDecoration(
                                 color: Colors.black26,
                                 borderRadius: BorderRadius.circular(8),
                                 border: Border.all(color: AppColors.brightGold.withOpacity(0.3))
                               ),
                               child: Row(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   _buildMiniSetting(Icons.replay, '${settings['numRounds']} Rds'),
                                   const SizedBox(width: 8),
                                   _buildMiniSetting(Icons.group, '${settings['numSaboteurs']} Sab'),
                                   const SizedBox(width: 8),
                                   _buildMiniSetting(Icons.style, '${settings['deckSize']} Cards'),
                                   const SizedBox(width: 8),
                                   _buildMiniSetting(Icons.timer, '${settings['turnTime'] ?? 60}s'),
                                 ],
                               ),
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
                              : isMe
                                ? ElevatedButton(
                                    onPressed: () => firebaseService.toggleReadyStatus(gameId, currentUid, !(player['isReady'] ?? false)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: (player['isReady'] == true) ? Colors.green : AppColors.blueDark,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
                                      minimumSize: const Size(60, 30),
                                    ),
                                    child: Text((player['isReady'] == true) ? 'LISTO' : 'PREPARARSE', style: const TextStyle(fontSize: 10, color: Colors.white)),
                                  )
                                : Text(
                                    (player['isReady'] == true) ? 'LISTO' : 'ESPERANDO', 
                                    style: TextStyle(color: (player['isReady'] == true) ? Colors.green : Colors.grey, fontSize: 10, fontWeight: FontWeight.bold)
                                  ),
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
                          if (players.length < 2)
                            const Padding(
                              padding: EdgeInsets.only(bottom: 8.0),
                              child: Text(
                                'Se necesitan al menos 2 jugadores para empezar',
                                style: TextStyle(color: Colors.orangeAccent, fontSize: 12),
                              ),
                            ),
                          Container(
                            width: double.infinity,
                            decoration: AppTheme.goldGlowDecoration,
                            child: ElevatedButton(
                              onPressed: (players.length >= 2 && allReady)
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

  Widget _buildMiniSetting(IconData icon, String text) {
    return Row(
      children: [
        Icon(icon, size: 14, color: AppColors.brightGold),
        const SizedBox(width: 4),
        Text(text, style: const TextStyle(color: AppColors.cream, fontSize: 11)),
      ],
    );
  }
}
