import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flame/game.dart';
import '../game/saboteur_game.dart';
import '../game/components/player_hand_widget.dart';
import '../providers/game_state_provider.dart';
import '../services/firebase_service.dart';
import '../models/card_model.dart';
import '../theme/app_colors.dart';
import '../game/components/path_card_painter.dart';
import '../utils/debug_logger.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  SaboteurGame? _gameInstance;
  bool _roleShown = false;
  Timer? _turnTimer;
  int _secondsLeft = 60;
  String _lastTurnId = '';
  int _lastTurnNumber = 0;
  bool _hasPlayedOrDiscardedThisTurn = false;
  bool _isEndingTurn = false;
  Timestamp? _currentTurnStartTime;
  int? _hoverX;
  int? _hoverY;

  @override
  void dispose() {
    _turnTimer?.cancel();
    super.dispose();
  }

  void _handleTurnChange(String gameId, Map<String, dynamic> data, FirebaseService service) {
    final players = data['players'] as Map<dynamic, dynamic>;
    final currentTurn = data['currentTurn'] as String?;
    final turnNumber = data['turnNumber'] as int? ?? 1;
    final isMyTurn = currentTurn == service.currentUid;

    if (data['status'] == 'finished') {
       DebugLogger.log("GameScreen: Estado 'finished' detectado. Mostrando diálogo final.", category: "STATE");
       _showGameOverDialog(data['winnerRole'] ?? 'miner');
       return;
    }

    if (turnNumber != _lastTurnNumber || (isMyTurn && _lastTurnId != currentTurn)) {
      _lastTurnNumber = turnNumber;
      _lastTurnId = currentTurn ?? '';
      _currentTurnStartTime = data['turnStartTime'] as Timestamp?;
      
      final turnPlayerName = (players[currentTurn]?['name'] ?? 'Desconocido').toString().toUpperCase();
      _startTimer(gameId, service.currentUid, service, isMyTurn);
      _showTurnDialog(isMyTurn ? '¡ES TU TURNO!' : 'TURNO DE:\n$turnPlayerName', isMyTurn);

      final myData = players[service.currentUid];
      if (myData != null) {
        final role = myData['role'] as String? ?? 'unknown';
        if (role != 'unknown' && !_roleShown) _showRoleDialog(role);
      }
    }

    _handleRecentAction(data, service.currentUid);
  }

  DateTime? _lastActionTimestamp;

  void _handleRecentAction(Map<String, dynamic> data, String myUid) {
    final action = data['recentAction'] as Map<String, dynamic>?;
    if (action == null) return;

    final timestamp = (action['timestamp'] as Timestamp?)?.toDate();
    if (timestamp == null) return;

    if (_lastActionTimestamp == null || timestamp.isAfter(_lastActionTimestamp!)) {
      _lastActionTimestamp = timestamp;
      
      final type = action['type'];
      final tool = action['tool'];
      final actorName = action['actorName'];
      final targetName = action['targetName'];
      final actorId = action['actorId'];
      final targetId = action['targetId'];
      final isFromMe = actorId == myUid;
      final isForMe = targetId == myUid;

      String toolName = 'herramienta';
      switch(tool) {
        case 'pickaxe': toolName = 'pico'; break;
        case 'lantern': toolName = 'lámpara'; break;
        case 'cart': toolName = 'carrito'; break;
      }

      String message = '';
      if (type == 'goal_revealed') {
        final isGold = action['isGold'] == true;
        message = isGold 
          ? '¡${action['actorName']} ENCONTRÓ EL ORO EN UNA META!' 
          : '${action['actorName']} reveló una meta... era solo piedra.';
      } else if (type == 'break_tool') {
        if (isFromMe) {
          message = 'Rompiste el $toolName de $targetName';
        } else if (isForMe) {
          message = '¡$actorName rompió tu $toolName!';
        } else {
          message = '$actorName rompió el $toolName de $targetName';
        }
      } else if (type == 'fix_tool') {
        if (isFromMe && isForMe) {
          message = 'Reparaste tu $toolName';
        } else if (isFromMe) {
          message = 'Reparaste el $toolName de $targetName';
        } else if (isForMe) {
          message = '¡$actorName reparó tu $toolName!';
        } else {
          message = '$actorName reparó el $toolName de $targetName';
        }
      }

      if (message.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _showActionAlert(message, type == 'break_tool');
        });
      }
    }
  }

  void _showActionAlert(String message, bool isNegative) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
        backgroundColor: isNegative ? Colors.red[900] : Colors.green[900],
        duration: const Duration(seconds: 4),
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.only(bottom: 250, left: 20, right: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: isNegative ? Colors.redAccent : Colors.greenAccent)),
      )
    );
  }

  void _startTimer(String gameId, String uid, FirebaseService service, bool isMyTurn) {
    _turnTimer?.cancel();
    setState(() {
      _hasPlayedOrDiscardedThisTurn = false;
      _isEndingTurn = false;
      _secondsLeft = (_currentTurnStartTime != null) 
          ? max(0, 60 - DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds)
          : 60;
    });

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_currentTurnStartTime != null) {
          _secondsLeft = max(0, 60 - DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds);
        } else if (_secondsLeft > 0) {
          _secondsLeft--;
        }
        if (_secondsLeft <= 0 && isMyTurn) {
          timer.cancel();
          _handleTimeout(gameId, uid, service);
        }
      });
    });
  }

  void _handleTimeout(String gameId, String uid, FirebaseService service) {
    if (_isEndingTurn) return;
    _isEndingTurn = true;
    if (!_hasPlayedOrDiscardedThisTurn) service.forceSkipTurn(gameId, uid);
    else service.endTurnAndDraw(gameId, uid);
  }

  void _showTurnDialog(String message, bool isMyTurn) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        Future.delayed(const Duration(milliseconds: 1500), () { if (ctx.mounted) Navigator.pop(ctx); });
        return AlertDialog(
          backgroundColor: Colors.black87,
          shape: RoundedRectangleBorder(side: BorderSide(color: isMyTurn ? Colors.greenAccent : AppColors.brightGold, width: 2), borderRadius: BorderRadius.circular(15)),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(isMyTurn ? Icons.play_arrow : Icons.person, color: isMyTurn ? Colors.greenAccent : AppColors.brightGold, size: 50),
            const SizedBox(height: 15),
            Text(message, textAlign: TextAlign.center, style: TextStyle(color: isMyTurn ? Colors.greenAccent : AppColors.cream, fontSize: 22, fontWeight: FontWeight.bold)),
          ]),
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
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.darkBackground,
        title: const Text('TU ROL: SABOTEADOR ONLINE', textAlign: TextAlign.center, style: TextStyle(color: AppColors.brightGold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(role == 'saboteur' ? Icons.dangerous : Icons.construction, size: 80, color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent),
          const SizedBox(height: 20),
          Text(role == 'saboteur' ? 'ERES EL SABOTEADOR' : 'ERES UN MINERO', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: role == 'saboteur' ? Colors.redAccent : Colors.cyanAccent)),
          const SizedBox(height: 10),
          Text(role == 'saboteur' ? '¡Evita que los mineros lleguen al oro!' : '¡Conecta el camino y busca el tesoro!', textAlign: TextAlign.center, style: const TextStyle(color: AppColors.cream)),
        ]),
        actions: [Center(child: ElevatedButton(onPressed: () => Navigator.pop(ctx), child: const Text('¡A JUGAR!')))],
      ),
    );
  }

  void _showMapRevealDialog(int goalIndex, Map<String, dynamic> resultData) {
    final resultText = resultData['name'] ?? '';
    final isGold = resultData['isGold'] == true;
    final connections = Map<PathDirection, bool>.from(
      (resultData['connections'] as Map<String, dynamic>).map((key, value) => MapEntry(_parseDirection(key), value as bool))
    );
    
    final revealedCard = PathCard(
      id: 'revealed_goal',
      name: resultText,
      imageUrl: '',
      connections: connections,
    );

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.indigo.shade900,
        shape: RoundedRectangleBorder(side: BorderSide(color: isGold ? Colors.amber : Colors.white38, width: 2), borderRadius: BorderRadius.circular(15)),
        title: Text('MAPA: META ${goalIndex + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Has mirado esta meta y encontraste:', style: const TextStyle(color: Colors.white70), textAlign: TextAlign.center),
          const SizedBox(height: 20),
          SizedBox(
            width: 100,
            height: 140,
            child: CustomPaint(
              painter: PathCardPainter(card: revealedCard, isRevealed: true),
            ),
          ),
          const SizedBox(height: 20),
          Text(resultText, style: TextStyle(color: isGold ? Colors.amber : Colors.white, fontSize: 32, fontWeight: FontWeight.bold)),
          if (isGold) const Icon(Icons.stars, color: Colors.amber, size: 40),
        ]),
        actions: [Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('ENTENDIDO', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16))))],
      ),
    );
  }

  PathDirection _parseDirection(String dir) {
    switch(dir) {
      case 'top': return PathDirection.top;
      case 'bottom': return PathDirection.bottom;
      case 'left': return PathDirection.left;
      case 'right': return PathDirection.right;
      default: return PathDirection.top;
    }
  }

  bool _gameOverShown = false;
  void _showGameOverDialog(String winnerRole) {
    if (_gameOverShown) return;
    _gameOverShown = true;
    _turnTimer?.cancel();
    
    final isMinerWin = winnerRole == 'miner';
    
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(side: BorderSide(color: isMinerWin ? Colors.cyanAccent : Colors.redAccent, width: 3), borderRadius: BorderRadius.circular(20)),
        title: Text('¡FIN DEL JUEGO!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.bold)),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(isMinerWin ? Icons.emoji_events : Icons.dangerous, size: 100, color: isMinerWin ? Colors.amber : Colors.redAccent),
          const SizedBox(height: 20),
          Text(isMinerWin ? '¡LOS MINEROS HAN GANADO!' : '¡EL SABOTEADOR HA GANADO!', textAlign: TextAlign.center, style: TextStyle(color: isMinerWin ? Colors.cyanAccent : Colors.redAccent, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          const Text('El oro ha sido encontrado o el camino ha sido bloqueado definitivamente.', textAlign: TextAlign.center, style: TextStyle(color: Colors.white70)),
        ]),
        actions: [Center(child: ElevatedButton(onPressed: () {
          DebugLogger.log("GameScreen: Usuario presionó 'VOLVER AL MENÚ' manualmente.", category: "NAV");
          ref.read(activeGameIdProvider.notifier).state = null;
          Navigator.of(context).popUntil((route) => route.isFirst);
        }, style: ElevatedButton.styleFrom(backgroundColor: isMinerWin ? Colors.cyan.shade900 : Colors.red.shade900), child: const Text('VOLVER AL MENÚ', style: TextStyle(color: Colors.white))))],
      ),
    );
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message), backgroundColor: Colors.redAccent));
  }

  int max(int a, int b) => a > b ? a : b;

  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(activeGameIdProvider);
    final firebaseService = FirebaseService();
    if (gameId == null) return const Scaffold(body: Center(child: Text('No GameId')));

    _gameInstance ??= SaboteurGame(gameId: gameId);

    ref.listen(gameDataProvider(gameId), (previous, next) {
      if (next.hasValue) {
        final snapshot = next.value!;
        if (snapshot.exists) {
          final data = snapshot.data() as Map<String, dynamic>;
          DebugLogger.log("GameScreen: Snapshot recibido. Turno#: ${data['turnNumber']}, Status: ${data['status']}", category: "STREAM");
          _handleTurnChange(gameId, data, firebaseService);
          _gameInstance?.updateGameState(data);
        } else {
          DebugLogger.log("GameScreen: ¡AVISO! El documento de juego ya no existe en la DB.", category: "STREAM");
        }
      } else if (next.hasError) {
        DebugLogger.log("GameScreen: Error en el stream: ${next.error}", category: "ERROR");
      }
    });

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            Positioned.fill(
              bottom: 140,
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: 800, height: 770,
                    child: Stack(
                      children: [
                        GameWidget(game: _gameInstance!),
                        Consumer(builder: (context, ref, _) {
                          final gameAsync = ref.watch(gameDataProvider(gameId));
                          return gameAsync.when(
                            data: (snapshot) {
                              if (!snapshot.exists) return const SizedBox();
                              final data = snapshot.data() as Map<String, dynamic>;
                              final players = data['players'] as Map;
                              final isMyTurn = data['currentTurn'] == firebaseService.currentUid;
                              final hasBrokenTools = (players[firebaseService.currentUid]?['brokenTools'] as List? ?? []).isNotEmpty;

                              return DragTarget<CardModel>(
                                onWillAcceptWithDetails: (details) => isMyTurn && !_hasPlayedOrDiscardedThisTurn,
                                onMove: (details) {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final Offset localOffset = box.globalToLocal(details.offset);
                                  
                                  // Normalizamos la posición basándonos en el tamaño real del widget detectado
                                  final double relX = localOffset.dx / box.size.width;
                                  final double relY = localOffset.dy / box.size.height;
                                  final int gx = (relX * 10).floor();
                                  final int gy = (relY * 7).floor();
                                  
                                  if (_hoverX != gx || _hoverY != gy) {
                                    setState(() {
                                      _hoverX = gx;
                                      _hoverY = gy;
                                    });
                                    print("🔦 [Hover] x: ${localOffset.dx.toStringAsFixed(1)}, y: ${localOffset.dy.toStringAsFixed(1)} | gx: $gx, gy: $gy");
                                  }
                                },
                                onLeave: (data) => setState(() { _hoverX = null; _hoverY = null; }),
                                onAcceptWithDetails: (details) async {
                                  final RenderBox box = context.findRenderObject() as RenderBox;
                                  final Offset localOffset = box.globalToLocal(details.offset);
                                  
                                  final double relX = localOffset.dx / box.size.width;
                                  final double relY = localOffset.dy / box.size.height;
                                  int gx = (relX * 10).floor();
                                  int gy = (relY * 7).floor();
                                  
                                  setState(() { _hoverX = null; _hoverY = null; });
                                  if (gx < 0 || gx >= 10 || gy < 0 || gy >= 7) return;

                                  try {
                                    final card = details.data;
                                    if (card is ActionCard && card.actionType == 'map') {
                                       int goalIdx = -1;
                                       if (gx == 8 && (gy == 1)) goalIdx = 0;
                                       else if (gx == 8 && (gy == 3)) goalIdx = 1;
                                       else if (gx == 8 && (gy == 5)) goalIdx = 2;
                                       
                                       if (goalIdx != -1) {
                                          final resultData = await firebaseService.revealGoalSecretly(gameId, firebaseService.currentUid, card.toMap(), goalIdx);
                                          setState(() => _hasPlayedOrDiscardedThisTurn = true);
                                          if (mounted) _showMapRevealDialog(goalIdx, resultData);
                                       }
                                       return;
                                    }

                                    if (card is PathCard) { 
                                       if (hasBrokenTools) { 
                                         _showError("No puedes construir caminos mientras tus herramientas estén rotas"); 
                                         return; 
                                       } 

                                      _gameInstance?.addOptimisticCard(card, gx, gy);
                                    } else if (card is ActionCard && card.actionType == 'rockfall') {
                                      _gameInstance?.removeOptimisticCard(gx, gy);
                                    } else {
                                      return; 
                                    }

                                    await firebaseService.playCard(gameId, firebaseService.currentUid, card.toMap(), gx, gy);
                                    setState(() => _hasPlayedOrDiscardedThisTurn = true);
                                  } catch (e) {
                                    _gameInstance?.refreshBoard();
                                    _showError("Error: $e");
                                  }
                                },
                                builder: (context, candidate, _) {
                                  return Container(
                                    width: 800, height: 770,
                                    decoration: BoxDecoration(
                                      border: Border.all(color: Colors.white10, width: 1), // Borde sutil para verificar alineación
                                      color: Colors.transparent,
                                    ),
                                    child: Stack(
                                      children: [
                                        if (_hoverX != null && _hoverY != null && _hoverX! >= 0 && _hoverX! < 10 && _hoverY! >= 0 && _hoverY! < 7)
                                          Positioned(
                                            left: _hoverX! * 80.0,
                                            top: _hoverY! * 110.0,
                                            width: 80,
                                            height: 110,
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: Colors.greenAccent.withOpacity(0.2),
                                                border: Border.all(color: Colors.greenAccent, width: 2),
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                            loading: () => const SizedBox(),
                            error: (err, _) => Center(child: Text("Error: $err")),
                          );
                        }),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            Positioned(
              left: 10, top: 60, bottom: 250, width: 120,
              child: Consumer(builder: (context, ref, _) {
                final gameAsync = ref.watch(gameDataProvider(gameId));
                return gameAsync.when(
                  data: (snapshot) {
                    if (!snapshot.exists) return const SizedBox();
                    final players = snapshot.get('players') as Map;
                    final currentTurn = snapshot.get('currentTurn');
                    final isMyTurn = currentTurn == firebaseService.currentUid;
                    return ListView(
                      children: players.entries.map((e) {
                        final pid = e.key;
                        final pdata = e.value;
                        final broken = List<String>.from(pdata['brokenTools'] ?? []);
                        return DragTarget<CardModel>(
                          onWillAcceptWithDetails: (details) {
                            if (!isMyTurn || _hasPlayedOrDiscardedThisTurn || details.data is! ActionCard) return false;
                            final action = details.data as ActionCard;
                            if (action.actionType == 'break_tool' && pid == firebaseService.currentUid) return false;
                            return ['break_tool', 'fix_tool'].contains(action.actionType);
                          },
                          onAcceptWithDetails: (details) async {
                            try {
                              await firebaseService.playActionOnPlayer(gameId, firebaseService.currentUid, pid, details.data.toMap());
                              setState(() => _hasPlayedOrDiscardedThisTurn = true);
                            } catch (e) { _showError(e.toString()); }
                          },
                          builder: (context, candidate, _) => Container(
                            margin: const EdgeInsets.only(bottom: 8), padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(color: candidate.isNotEmpty ? Colors.orangeAccent.withOpacity(0.5) : Colors.black54, borderRadius: BorderRadius.circular(10), border: Border.all(color: pid == currentTurn ? Colors.greenAccent : Colors.white24)),
                            child: Column(children: [Text(pdata['name'], style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold), overflow: TextOverflow.ellipsis), if (broken.isNotEmpty) Row(mainAxisAlignment: MainAxisAlignment.center, children: broken.map((t) => Icon(_getIconForTool(t), size: 12, color: Colors.redAccent)).toList())]),
                          ),
                        );
                      }).toList(),
                    );
                  },
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                );
              }),
            ),

            Consumer(builder: (context, ref, _) {
              final gameAsync = ref.watch(gameDataProvider(gameId));
              return gameAsync.when(
                data: (snapshot) {
                  if (!snapshot.exists) return const SizedBox();
                  final data = snapshot.data() as Map<String, dynamic>;
                  final players = data['players'] as Map;
                  final currentTurn = data['currentTurn'] as String?;
                  final isMyTurn = currentTurn == firebaseService.currentUid;
                  final role = players[firebaseService.currentUid]?['role'] ?? 'miner';
                  final turnPlayerName = (players[currentTurn]?['name'] ?? 'Desconocido').toString().toUpperCase();
                  final deckLength = (data['deck'] as List?)?.length ?? 0;
                  final currentPlayer = players[firebaseService.currentUid];

                  return Stack(
                    children: [
                      Positioned(top: 10, right: 10, child: _buildRoleChip(role)),
                      Positioned(top: 10, left: 0, right: 0, child: Center(child: _buildTurnTimer(isMyTurn, turnPlayerName))),
                      Positioned(bottom: 220, right: 15, child: _buildDeckCounter(deckLength)),
                      if (isMyTurn) Positioned(bottom: 150, right: 10, child: _buildTrashZone(gameId, firebaseService)),
                      if (isMyTurn && _hasPlayedOrDiscardedThisTurn) Positioned(bottom: 155, left: 10, child: _buildEndTurnButton(gameId, firebaseService)),
                      Positioned(
                        bottom: 0, left: 0, right: 0,
                        child: PlayerHandWidget(
                          handData: currentPlayer?['hand'] as List? ?? [],
                          isMyTurn: isMyTurn,
                          isInteractive: isMyTurn && !_hasPlayedOrDiscardedThisTurn,
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) => Center(child: Text('Error: $err')),
              );
            }),
          ],
        ),
      ),
    );
  }

  IconData _getIconForTool(String tool) => tool == 'pickaxe' ? Icons.construction : (tool == 'lantern' ? Icons.lightbulb : Icons.shopping_cart);

  Widget _buildRoleChip(String role) {
    final isSabo = role == 'saboteur';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: Colors.black87, borderRadius: BorderRadius.circular(15), border: Border.all(color: isSabo ? Colors.redAccent : Colors.cyanAccent)),
      child: Row(children: [Icon(isSabo ? Icons.dangerous : Icons.person, size: 12, color: isSabo ? Colors.redAccent : Colors.cyanAccent), const SizedBox(width: 4), Text(isSabo ? 'SABOTEADOR' : 'MINERO', style: TextStyle(color: isSabo ? Colors.redAccent : Colors.cyanAccent, fontSize: 10, fontWeight: FontWeight.bold))]),
    );
  }

  Widget _buildTurnTimer(bool isMyTurn, String turnPlayerName) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(color: isMyTurn ? Colors.green.shade900 : Colors.black87, borderRadius: BorderRadius.circular(20), border: Border.all(color: isMyTurn ? Colors.greenAccent : AppColors.brightGold)),
      child: Text(isMyTurn ? '¡TU TURNO! (${_secondsLeft}s)' : 'TURNO DE: $turnPlayerName (${_secondsLeft}s)', style: TextStyle(color: isMyTurn ? Colors.white : AppColors.cream, fontWeight: FontWeight.bold, fontSize: 13)),
    );
  }

  Widget _buildDeckCounter(int count) => Column(children: [const Icon(Icons.layers, color: AppColors.primaryGold, size: 24), Text('$count', style: const TextStyle(color: AppColors.cream, fontWeight: FontWeight.bold, fontSize: 16)), const Text('MAZO', style: TextStyle(color: Colors.white70, fontSize: 8))]);

  Widget _buildTrashZone(String gameId, FirebaseService service) => DragTarget<CardModel>(
    onAcceptWithDetails: (details) async {
      try {
        await service.discardCard(gameId, service.currentUid, details.data.toMap());
        setState(() => _hasPlayedOrDiscardedThisTurn = true);
      } catch (e) { }
    },
    builder: (context, candidate, _) => Container(width: 60, height: 80, decoration: BoxDecoration(color: candidate.isNotEmpty ? Colors.redAccent.withOpacity(0.5) : Colors.black87, border: Border.all(color: Colors.redAccent, width: 2), borderRadius: BorderRadius.circular(10)), child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.delete, color: Colors.white), Text('TIRAR', style: TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.bold))])),
  );

  Widget _buildEndTurnButton(String gameId, FirebaseService service) => ElevatedButton(
    onPressed: _isEndingTurn ? null : () async {
      setState(() => _isEndingTurn = true);
      try {
        await service.endTurnAndDraw(gameId, service.currentUid);
      } catch (e) {
        setState(() => _isEndingTurn = false);
        _showError(e.toString());
      }
    },
    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryGold, foregroundColor: Colors.black, elevation: 8, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
    child: const Text('TERMINAR TURNO', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
  );
}
