import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import 'package:flame_riverpod/flame_riverpod.dart';
import '../game/saboteur_game.dart';
import '../game/components/player_hand_widget.dart';
import '../providers/game_state_provider.dart';
import '../services/firebase_service.dart';
import '../models/card_model.dart';
import '../theme/app_colors.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  bool _roleShown = false;
  Timer? _turnTimer;
  int _secondsLeft = 60;
  String _lastTurnId = '';
  int _lastTurnNumber = 0;
  bool _hasPlayedOrDiscardedThisTurn = false;
  bool _isEndingTurn = false;
  Timestamp? _currentTurnStartTime;
  late final SaboteurGame _game;

  @override
  void initState() {
    super.initState();
    final gameId = ref.read(activeGameIdProvider);
    _game = SaboteurGame(gameId: gameId!);
  }

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
  }

  void _startTimer(String gameId, String uid, FirebaseService service, bool isMyTurn) {
    _turnTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _hasPlayedOrDiscardedThisTurn = false;
      _isEndingTurn = false;
      if (_currentTurnStartTime != null) {
        final elapsed = DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds;
        _secondsLeft = 60 - elapsed;
        if (_secondsLeft < 0) _secondsLeft = 0;
      } else {
        _secondsLeft = 60;
      }
    });

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_currentTurnStartTime != null) {
          final elapsed = DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds;
          _secondsLeft = 60 - elapsed;
          if (_secondsLeft < 0) _secondsLeft = 0;
        } else {
          if (_secondsLeft > 0) _secondsLeft--;
        }

        if (_secondsLeft <= 0) {
          timer.cancel();
          if (isMyTurn) {
            _isEndingTurn = true;
            if (!_hasPlayedOrDiscardedThisTurn) {
              _hasPlayedOrDiscardedThisTurn = true;
              service.forceSkipTurn(gameId, uid);
            } else {
              service.endTurnAndDraw(gameId, uid);
            }
          } else {
            // El jugador actual AFK no terminó, cualquier observador puede forzar su fin de turno seguro
            service.forceSkipTurn(gameId, _lastTurnId);
          }
        }
      });
    });
  }

  void _showTurnDialog(String message, bool isMyTurn) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (dialogContext.mounted) {
            Navigator.of(dialogContext).pop();
          }
        });
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
              side: BorderSide(color: isMyTurn ? Colors.greenAccent : AppColors.brightGold, width: 2),
              borderRadius: BorderRadius.circular(15)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(isMyTurn ? Icons.play_arrow : Icons.person, color: isMyTurn ? Colors.greenAccent : AppColors.brightGold, size: 50),
              const SizedBox(height: 15),
              Text(
                message,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: isMyTurn ? Colors.greenAccent : AppColors.cream,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showRoleDialog(String role) {
    if (_roleShown) return;
    _roleShown = true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('TU ROL HA SIDO ASIGNADO', textAlign: TextAlign.center, style: TextStyle(color: AppColors.brightGold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              role == 'saboteur' ? Icons.dangerous : Icons.construction,
              size: 80,
              color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent,
            ),
            const SizedBox(height: 20),
            Text(
              role == 'saboteur' ? 'ERES EL SABOTEADOR' : 'ERES UN MINERO',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              role == 'saboteur' 
                ? '¡Evita que los mineros lleguen al oro sin que te descubran!' 
                : '¡Conecta el camino y encuentra el tesoro escondido!',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.cream),
            ),
          ],
        ),
        actions: [
          Center(
            child: ElevatedButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('¡ENTENDIDO!'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(activeGameIdProvider);
    final firebaseService = FirebaseService();

    if (gameId == null) {
      return const Scaffold(body: Center(child: Text('Error: No se encontró ID de partida')));
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: firebaseService.gameStream(gameId),
      builder: (context, snapshot) {
        if (snapshot.hasError) return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
        if (!snapshot.hasData || !snapshot.data!.exists) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final data = snapshot.data!.data() as Map<String, dynamic>?;
        if (data == null) return const Scaffold(body: Center(child: Text('Datos corruptos')));

        final players = data['players'] as Map<dynamic, dynamic>? ?? {};
        final currentPlayer = players[firebaseService.currentUid];
        
        if (currentPlayer == null) return const Scaffold(body: Center(child: Text('No estás en esta partida')));

        final role = currentPlayer['role'] as String? ?? 'unknown';

        // Mostrar diálogo de rol al inicio si ya fue asignado
        if (role != 'unknown' && !_roleShown) {
          WidgetsBinding.instance.addPostFrameCallback((_) => _showRoleDialog(role));
        }

        final currentTurn = data['currentTurn'] as String?;
        final turnNumber = data['turnNumber'] as int? ?? 1;
        _currentTurnStartTime = data['turnStartTime'] as Timestamp?;

        final isMyTurn = currentTurn == firebaseService.currentUid;
        final turnPlayerName = (players[currentTurn]?['name'] ?? 'Desconocido').toString().toUpperCase();
        final deck = data['deck'] as List<dynamic>? ?? [];

        if (turnNumber != _lastTurnNumber || (_lastTurnId.isEmpty && currentTurn != null)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _lastTurnNumber = turnNumber;
            _lastTurnId = currentTurn!;
            _startTimer(gameId, firebaseService.currentUid!, firebaseService, isMyTurn);
            _showTurnDialog(isMyTurn ? '¡ES TU TURNO!' : 'TURNO DE:\n$turnPlayerName', isMyTurn);
          });
        }

        return PopScope(
          canPop: false,
          child: Scaffold(
            backgroundColor: Colors.black,
            body: SafeArea(
              child: Stack(
                children: [
                  // Tablero Centrado y Escalado
                  Positioned(
                    top: 0,
                    left: 0,
                    right: 0,
                    bottom: 120, // Espacio para la mano abajo
                    child: Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: 1000,
                          height: 700,
                          child: Stack(
                            children: [
                              GameWidget(
                                game: _game,
                              ),
                              // Grid Visual y de Hover para arrastrar (10 cols x 7 rows)
                              for (int gridX = 0; gridX < 10; gridX++)
                                for (int gridY = 0; gridY < 7; gridY++)
                                  Positioned(
                                    left: gridX * 100.0,
                                    top: gridY * 100.0,
                                    child: DragTarget<CardModel>(
                                      onWillAcceptWithDetails: (details) => isMyTurn && !_hasPlayedOrDiscardedThisTurn && details.data.type == CardType.path,
                                      onAcceptWithDetails: (details) async {
                                        setState(() => _hasPlayedOrDiscardedThisTurn = true);
                                        await firebaseService.playCard(gameId, firebaseService.currentUid, details.data.toMap(), gridX, gridY);
                                      },
                                      builder: (context, candidateData, rejectedData) {
                                        final isHovered = candidateData.isNotEmpty;
                                        return Container(
                                          width: 100, height: 100,
                                          decoration: BoxDecoration(
                                            color: isHovered ? Colors.greenAccent.withOpacity(0.4) : Colors.transparent,
                                            border: Border.all(
                                              color: isHovered ? Colors.greenAccent : Colors.white10,
                                              width: isHovered ? 2 : 1,
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              
              // El botón atrás se eliminó intencionalmente para evitar escapar al menú principal

                  // UI FLOTANTE SOBRE EL TABLERO (No se escala)
                  Positioned(
                    top: 10,
                    right: 10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            role == 'saboteur' ? Icons.dangerous : Icons.person,
                            size: 14,
                            color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            role == 'saboteur' ? 'SABOTEADOR' : 'MINERO',
                            style: TextStyle(
                              color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Positioned(
                    top: 10,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isMyTurn ? Colors.green.shade900 : Colors.black87,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isMyTurn ? Colors.greenAccent : AppColors.brightGold),
                        ),
                        child: Text(
                          isMyTurn ? '¡ES TU TURNO! (${_secondsLeft}s)' : 'Turno de: $turnPlayerName (${_secondsLeft}s)',
                          style: TextStyle(
                            color: isMyTurn ? Colors.white : AppColors.cream,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  // Contador de mazo
                  Positioned(
                    bottom: 220,
                    right: 15,
                    child: Column(
                      children: [
                        const Icon(Icons.layers, color: AppColors.primaryGold, size: 30),
                        Text(
                          '${deck.length}',
                          style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                        const Text('CARTAS', style: TextStyle(color: Colors.white70, fontSize: 8)),
                      ],
                    ),
                  ),

                  // Zona de descartar cartas
                  if (isMyTurn)
                    Positioned(
                      bottom: 130,
                      right: 10,
                      child: DragTarget<CardModel>(
                        onWillAcceptWithDetails: (details) => isMyTurn && !_hasPlayedOrDiscardedThisTurn,
                        onAcceptWithDetails: (details) async {
                          setState(() => _hasPlayedOrDiscardedThisTurn = true);
                          await firebaseService.discardCard(gameId, firebaseService.currentUid, details.data.toMap());
                        },
                        builder: (context, candidateData, rejectedData) {
                          return Container(
                            width: 60, height: 70,
                            decoration: BoxDecoration(
                              color: candidateData.isNotEmpty ? Colors.redAccent.withOpacity(0.5) : Colors.black87,
                              border: Border.all(color: Colors.redAccent, width: 2),
                              borderRadius: BorderRadius.circular(10)
                            ),
                            child: const Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.delete, color: Colors.white, size: 24),
                                SizedBox(height: 2),
                                Text('TIRAR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold), textAlign: TextAlign.center,)
                              ]
                            )
                          );
                        },
                      )
                    ),

                  // Botón Terminar Turno
                  if (isMyTurn && _hasPlayedOrDiscardedThisTurn)
                    Positioned(
                      bottom: 140,
                      left: 10,
                      child: ElevatedButton(
                        onPressed: _isEndingTurn ? null : () async {
                          setState(() => _isEndingTurn = true);
                          try {
                            await firebaseService.endTurnAndDraw(gameId, firebaseService.currentUid);
                          } catch (e) {
                            setState(() => _isEndingTurn = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                              content: Text('Error al procesar el turno: $e'),
                              backgroundColor: Colors.red,
                            ));
                          }
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primaryGold,
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          elevation: 10,
                        ),
                        child: const Row(
                          children: [
                            Text('TERMINAR TURNO', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(width: 5),
                            Icon(Icons.check_circle, size: 18),
                          ],
                        ),
                      )
                    ),

                  // Mano del jugador nativa en la parte inferior
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: PlayerHandWidget(
                      handData: currentPlayer['hand'] as List<dynamic>? ?? [],
                      isMyTurn: isMyTurn && !_hasPlayedOrDiscardedThisTurn,
                    ),
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
