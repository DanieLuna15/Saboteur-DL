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
import 'package:flame_audio/flame_audio.dart';

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
  bool _isFirstActionIgnored = false;
  bool _initialTurnHandled = false;
  bool _isRoleHidden = false; // Nuevo: Estado para ocultar/mostrar rol



  @override
  void initState() {
    super.initState();
    _lastActionTimestamp = DateTime.now();
  }


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

    if (data['status'] == 'finished' || data['status'] == 'round_finished') {
       DebugLogger.log("GameScreen: Estado '${data['status']}' detectado.", category: "STATE");
       if (!_gameOverShown) {
         final isGameEnd = data['status'] == 'finished';
         final players = data['players'] as Map;
         final myData = players[service.currentUid];
         final myRole = myData?['role'] as String? ?? 'miner';
         
         final revealedGoals = List<int>.from(data['revealedGoals'] ?? []);
         final goldIdx = data['goldGoalIndex'] as int? ?? 1;
         final minersWon = revealedGoals.contains(goldIdx);
         bool iWonRound = (myRole == 'miner' && minersWon) || (myRole == 'saboteur' && !minersWon);
         
         String soundFile = '';
         if (isGameEnd) {
           // Si la partida termina, SOLO suena el de partida (evitamos choque)
           int myGold = myData?['gold'] ?? 0;
           int maxGold = 0;
           players.forEach((k, v) {
             int g = v['gold'] ?? 0;
             if (g > maxGold) maxGold = g;
           });
           soundFile = (myGold >= maxGold && maxGold > 0) ? 'game_winner_partida.mp3' : 'game_over_partida.mp3';
         } else {
           // Solo ronda
           soundFile = iWonRound ? 'game_winner_ronda.mp3' : 'game_over_ronda.mp3';
         }

         try { FlameAudio.play(soundFile, volume: 0.8); } catch(e){}
       }
       final myData = players[service.currentUid];
       final myRole = myData?['role'] as String? ?? 'miner';
       _showGameOverDialog(data, myRole, service, gameId);
       return;
    }

    if (data['status'] == 'playing' && _gameOverShown) {
      _gameOverShown = false;
      _roleShown = false;
      Navigator.of(context, rootNavigator: true).pop();
    }

    if (turnNumber != _lastTurnNumber || (isMyTurn && _lastTurnId != currentTurn)) {
      _lastTurnNumber = turnNumber;
      _lastTurnId = currentTurn ?? '';
      _currentTurnStartTime = data['turnStartTime'] as Timestamp?;
      _hasPlayedOrDiscardedThisTurn = false;
      
      final handCount = (players[service.currentUid]?['hand'] as List?)?.length ?? 0;
      final deckCount = (data['deck'] as List?)?.length ?? 0;
      final isRealTurnChange = (turnNumber != _lastTurnNumber);

      if (isMyTurn && handCount == 0 && deckCount == 0 && !_isEndingTurn) {
         _isEndingTurn = true;
         Future.delayed(const Duration(milliseconds: 300), () async {
            try { await service.endTurnAndDraw(gameId, service.currentUid); } catch(e) {}
            if (mounted) setState(() => _isEndingTurn = false);   
         });
         return; 
      }
      
      final settings = data['settings'] as Map<String, dynamic>? ?? {};
      final turnTime = (settings['turnTime'] as num?)?.toInt() ?? 60;
      
      final turnPlayerName = (players[currentTurn]?['name'] ?? 'Desconocido').toString().toUpperCase();
      _startTimer(gameId, service.currentUid, service, isMyTurn, turnTime);
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
    
    if (!_isFirstActionIgnored) {
      _isFirstActionIgnored = true;
      _lastActionTimestamp = timestamp;
      return;
    }

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

      String toolName = tool ?? 'herramienta';
      switch(tool) {
        case 'pickaxe':
        case 'pico': 
          toolName = 'pico'; break;
        case 'lantern':
        case 'linterna': 
          toolName = 'lámpara'; break;
        case 'cart':
        case 'carrito': 
          toolName = 'carrito'; break;
      }

      String message = '';
      if (type == 'goal_revealed') {
        try { FlameAudio.play('mapa.mp3', volume: 0.8); } catch(e){}
        final isGold = action['isGold'] == true;
        message = isGold 
          ? '¡${action['actorName']} ENCONTRÓ EL ORO EN UNA META!' 
          : '${action['actorName']} reveló una meta... era solo piedra.';
      } else if (type == 'map_used') {
        try { FlameAudio.play('mapa.mp3', volume: 0.8); } catch(e){}
        message = isFromMe ? 'Usaste un mapa' : '$actorName usó un mapa';
        final goalIndex = action['goalIndex'] as int?;
        if (goalIndex != null) {
          _gameInstance?.triggerMapShine(goalIndex);
        }
      } else if (type == 'path_placed') {
        if (!isFromMe) {
          try { FlameAudio.play('uso_carta_general.mp3', volume: 0.7); } catch(e){}
        }
      } else if (type == 'rockfall') {
        if (!isFromMe) try { FlameAudio.play('dinamita.mp3', volume: 0.8); } catch(e){}
        message = isFromMe ? 'Usaste una dinamita' : '$actorName usó una dinamita';
      } else if (type == 'break_tool') {
        if (!isFromMe) try { FlameAudio.play('romper_herramienta.mp3', volume: 0.8); } catch(e){}
        if (isFromMe && isForMe) {
          message = 'Rompiste tu $toolName';
        } else if (isFromMe) {
          message = 'Rompiste el $toolName de $targetName';
        } else if (isForMe) {
          message = '¡$actorName rompió tu $toolName!';
        } else if (actorId == targetId) {
          message = '$actorName rompió su $toolName';
        } else {
          message = '$actorName rompió el $toolName de $targetName';
        }
      } else if (type == 'fix_tool') {
        if (!isFromMe) try { FlameAudio.play('reparar_herramienta.mp3', volume: 0.8); } catch(e){}
        if (isFromMe && isForMe) {
          message = 'Reparaste tu $toolName';
        } else if (isFromMe) {
          message = 'Reparaste el $toolName de $targetName';
        } else if (isForMe) {
          message = '¡$actorName reparó tu $toolName!';
        } else if (actorId == targetId) {
          message = '$actorName reparó su $toolName';
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
    
    final overlay = Overlay.of(context);
    if (overlay == null) {
      // Fallback a SnackBar si no hay Overlay disponible
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          backgroundColor: isNegative ? Colors.redAccent : Colors.teal.shade700,
          behavior: SnackBarBehavior.floating,
        )
      );
      return;
    }

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100, // Misma posición que las notificaciones de sistema
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -20),
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: () { if (entry.mounted) entry.remove(); },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: (isNegative ? Colors.redAccent : Colors.teal.shade700).withOpacity(0.95),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    Icon(isNegative ? Icons.warning_amber : Icons.info_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.close, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 4), () {
      if (entry.mounted) entry.remove();
    });
  }

  void _startTimer(String gameId, String uid, FirebaseService service, bool isMyTurn, int turnTime) {
    _turnTimer?.cancel();
    setState(() {
      _hasPlayedOrDiscardedThisTurn = false;
      _isEndingTurn = false;
      _secondsLeft = (_currentTurnStartTime != null) 
          ? max(0, turnTime - DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds)
          : turnTime;
    });

    _turnTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) { timer.cancel(); return; }
      setState(() {
        if (_currentTurnStartTime != null) {
          _secondsLeft = max(0, turnTime - DateTime.now().difference(_currentTurnStartTime!.toDate()).inSeconds);
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
    try { FlameAudio.play('siguiente_turno.mp3', volume: 0.8); } catch(e){}
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
    try { FlameAudio.play('descubrir_rol.mp3', volume: 0.8); } catch(e){}
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
  void _showGameOverDialog(Map<String, dynamic> data, String myRole, FirebaseService service, String gameId) {
    if (_gameOverShown) return;
    _gameOverShown = true;
    _turnTimer?.cancel();
    
    final winnerRole = data['winnerRole'] ?? 'miner';
    final isMinerWin = winnerRole == 'miner';
    final didIWin = winnerRole == myRole;
    final isFinished = data['status'] == 'finished';
    final int roundNumber = data['roundNumber'] ?? 1;

    final players = Map<String, dynamic>.from(data['players']);
    final sortedPlayers = players.entries.toList()..sort((a,b) => ((b.value['gold'] ?? 0) as num).compareTo((a.value['gold'] ?? 0) as num));
    final myUid = service.currentUid;
    final isHost = players[myUid]?['isHost'] == true;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(side: BorderSide(color: isMinerWin ? Colors.cyanAccent : Colors.redAccent, width: 3), borderRadius: BorderRadius.circular(20)),
        title: Text(isFinished ? '¡FIN DEL JUEGO!' : '¡FIN DE LA RONDA $roundNumber!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)),
        content: SizedBox(
          width: 300,
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(isFinished ? Icons.celebration : (didIWin ? Icons.emoji_events : Icons.dangerous), size: 80, color: didIWin || isFinished ? Colors.amber : Colors.redAccent),
              const SizedBox(height: 10),
              if (isFinished && sortedPlayers.isNotEmpty)
                Text('¡GANADOR FINAL:\n${sortedPlayers.first.value['name'].toUpperCase()}!', textAlign: TextAlign.center, style: const TextStyle(color: Colors.amber, fontSize: 22, fontWeight: FontWeight.bold))
              else
                Text(didIWin ? '¡GANASTE LA RONDA!' : '¡PERDISTE LA RONDA!', textAlign: TextAlign.center, style: TextStyle(color: didIWin ? Colors.amber : Colors.redAccent, fontSize: 24, fontWeight: FontWeight.bold)),
              const SizedBox(height: 5),
              Text(isMinerWin ? 'RONDA: MINEROS GANAN' : 'RONDA: SABOTEADORES GANAN', textAlign: TextAlign.center, style: TextStyle(color: isMinerWin ? Colors.cyanAccent : Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              const Text('ORO ACUMULADO', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              const Divider(color: Colors.white24),
              ...sortedPlayers.map((p) {
                bool isMe = p.key == myUid;
                String role = p.value['role'] ?? '';
                String roleTag = role == 'miner' ? '(M)' : (role == 'saboteur' ? '(S)' : '');
                
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text('${p.value['name']} $roleTag' + (isMe ? ' (Tú)' : ''), 
                        style: TextStyle(color: isMe ? Colors.amber : Colors.white70, fontWeight: isMe ? FontWeight.bold : FontWeight.normal), 
                        overflow: TextOverflow.ellipsis)),
                      Row(children: [Text('${p.value['gold'] ?? 0}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 16)), const SizedBox(width: 4), const Icon(Icons.stars, color: Colors.amber, size: 16)])
                    ],
                  ),
                );
              }),
            ]),
          ),
        ),
        actions: [
          if (isFinished)
            Center(child: ElevatedButton(onPressed: () async {
              DebugLogger.log("GameScreen: Usuario finalizó el juego.", category: "NAV");
              if (isHost) {
                await service.deleteGame(gameId);
              } else {
                await service.leaveGame(gameId, myUid);
              }
              if (context.mounted) {
                ref.read(activeGameIdProvider.notifier).state = null;
                Navigator.of(context).popUntil((route) => route.isFirst);
              }
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo), child: const Text('VOLVER AL MENÚ', style: TextStyle(color: Colors.white))))
          else if (isHost)
            Center(child: ElevatedButton(onPressed: () async {
              setState(() => _gameOverShown = false);
              Navigator.of(context, rootNavigator: true).pop(); // dismiss dialog immediately for host
              await service.startNextRound(gameId);
            }, style: ElevatedButton.styleFrom(backgroundColor: Colors.green), child: const Text('EMPEZAR SIGUIENTE RONDA', style: TextStyle(color: Colors.white))))
          else 
            const Center(child: Text('Esperando que el Host inicie...', style: TextStyle(color: Colors.white54, fontStyle: FontStyle.italic)))
        ],
      ),
    );
  }

  void _showPlayerDetailDialog(Map<String, dynamic> pdata, String pid, List<String> broken) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: AppColors.brightGold, width: 2),
          borderRadius: BorderRadius.circular(20)
        ),
        title: Text(
          pdata['name'].toString().toUpperCase(), 
          textAlign: TextAlign.center, 
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, color: AppColors.primaryGold, size: 50),
            const SizedBox(height: 10),
            Text(
              'CARTAS EN MANO: ${pdata['hand']?.length ?? 0}',
              style: const TextStyle(color: AppColors.cream, fontSize: 16),
            ),
            const Divider(color: Colors.white24, height: 30),
            const Text(
              'ESTADO DE HERRAMIENTAS:',
              style: TextStyle(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 15),
            if (broken.isEmpty)
              const Text('¡TODO BIEN! ✅', style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold))
            else
              Wrap(
                spacing: 20,
                runSpacing: 20,
                alignment: WrapAlignment.center,
                children: broken.map((t) {
                  String asset = 'assets/images_cards/castigo_pico.png';
                  String label = 'PICO ROTO';
                  if (t == 'linterna' || t == 'lantern') {
                    asset = 'assets/images_cards/castigo_linterna.png';
                    label = 'LÁMPARA ROTA';
                  }
                  if (t == 'carrito' || t == 'cart') {
                    asset = 'assets/images_cards/castigo_carrito.png';
                    label = 'CARRITO ROTO';
                  }
                  return Column(
                    children: [
                      Image.asset(asset, width: 60, height: 60),
                      const SizedBox(height: 4),
                      Text(label, style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  );
                }).toList(),
              ),
          ],
        ),
        actions: [
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(ctx), 
              child: const Text('CERRAR', style: TextStyle(color: AppColors.brightGold, fontWeight: FontWeight.bold))
            ),
          )
        ],
      ),
    );
  }

  void _showFixSelectionDialog(String gameId, String targetPid, String targetName, List<String> options, ActionCard card, FirebaseService service) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.black,
        shape: RoundedRectangleBorder(side: const BorderSide(color: Colors.greenAccent, width: 2), borderRadius: BorderRadius.circular(20)),
        title: Text('REPARAR: $targetName', textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('¿Qué herramienta quieres reparar?', style: TextStyle(color: Colors.white70)),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: options.map((tool) {
                 String label = 'PICO';
                 String asset = 'assets/images_cards/reparar_pico.png';
                 if (tool == 'linterna' || tool == 'lantern') { label = 'LÁMPARA'; asset = 'assets/images_cards/reparar_linterna.png'; }
                 if (tool == 'carrito' || tool == 'cart') { label = 'CARRITO'; asset = 'assets/images_cards/reparar_carrito.png'; }
                 
                 return InkWell(
                   onTap: () async {
                     Navigator.pop(ctx);
                     try {
                       await service.playActionOnPlayer(gameId, service.currentUid, targetPid, card.toMap(), toolToFix: tool);
                       try { FlameAudio.play('reparar_herramienta.mp3', volume: 0.8); } catch(e){}
                       if (mounted) setState(() => _hasPlayedOrDiscardedThisTurn = true);
                     } catch(e) { _showError(e.toString()); }
                   },
                   child: Column(
                     children: [
                       Image.asset(asset, width: 70, height: 70),
                       const SizedBox(height: 8),
                       Text(label, style: const TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.bold, fontSize: 12)),
                     ],
                   ),
                 );
              }).toList(),
            ),
          ],
        ),
        actions: [Center(child: TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CANCELAR', style: TextStyle(color: Colors.grey))))],
      ),
    );
  }

  void _showError(String message) {
    try { FlameAudio.play('error.mp3', volume: 0.8); } catch(e) {}
    
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    
    entry = OverlayEntry(
      builder: (context) => Positioned(
        top: 100,
        left: 20,
        right: 20,
        child: Material(
          color: Colors.transparent,
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 300),
            builder: (context, value, child) => Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, (1 - value) * -20),
                child: child,
              ),
            ),
            child: GestureDetector(
              onTap: () {
                 if (entry.mounted) entry.remove();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(color: Colors.white, width: 2),
                  boxShadow: const [BoxShadow(color: Colors.black45, blurRadius: 10)],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        message,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const Icon(Icons.close, color: Colors.white54, size: 18),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    overlay.insert(entry);
    Future.delayed(const Duration(seconds: 5), () {
      if (entry.mounted) entry.remove();
    });
  }

  int max(int a, int b) => a > b ? a : b;

  bool _audioInitialized = false;

  void _initializeAudio() {
    if (_audioInitialized) return;
    try {
      // Intentamos inicializar el audio context en la primera interacción
      FlameAudio.bgm.initialize();
      _audioInitialized = true;
      DebugLogger.log("Audio Context desbloqueado por interacción del usuario", category: "AUDIO");
      // Reproducir un sonido silencioso o corto si es necesario
    } catch (e) {
      DebugLogger.log("Error inicializando audio: $e", category: "ERROR");
    }
  }

  @override
  Widget build(BuildContext context) {
    final gameId = ref.watch(activeGameIdProvider);
    final firebaseService = FirebaseService();
    if (gameId == null) return const Scaffold(body: Center(child: Text('No GameId')));

    _gameInstance ??= SaboteurGame(gameId: gameId);

    final snapshotAsync = ref.watch(gameDataProvider(gameId));
    if (snapshotAsync.hasValue && !_initialTurnHandled) {
      _initialTurnHandled = true;
      final snapshot = snapshotAsync.value!;
      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleTurnChange(gameId, data, firebaseService);
        });
      }
    }


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
          // Si el juego ha sido eliminado (limpieza), expulsamos a todos al menú
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ref.read(activeGameIdProvider.notifier).state = null;
              Navigator.of(context).popUntil((route) => route.isFirst);
            }
          });
        }
      } else if (next.hasError) {
        DebugLogger.log("GameScreen: Error en el stream: ${next.error}", category: "ERROR");
      }
    });

    return GestureDetector(
      onTapDown: (_) => _initializeAudio(),
      behavior: HitTestBehavior.translucent,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
            Positioned.fill(
              bottom: 250, // Subimos un poco el tablero para dejar espacio a la lista horizontal
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
                                          try { FlameAudio.play('mapa.mp3', volume: 0.8); } catch(e){}
                                          final resultData = await firebaseService.revealGoalSecretly(gameId, firebaseService.currentUid, card.toMap(), goalIdx);
                                          setState(() => _hasPlayedOrDiscardedThisTurn = true);
                                          if (mounted) _showMapRevealDialog(goalIdx, resultData);
                                       } else {
                                          _showError("El mapa solo se puede usar sobre las cartas de meta (en el borde derecho)");
                                       }
                                       return;
                                    }

                                    if (card is PathCard) { 
                                       if (hasBrokenTools) { 
                                         _showError("No puedes construir caminos mientras tus herramientas estén rotas"); 
                                         return; 
                                       } 
                                      // No se puede poner caminos en celdas reservadas (si se desea validar localmente)
                                      try { FlameAudio.play('uso_carta_user.mp3', volume: 0.8); } catch(e){}
                                      _gameInstance?.addOptimisticCard(card, gx, gy);
                                    } else if (card is ActionCard && card.actionType == 'rockfall') {
                                      // VALIDACIÓN LOCAL: No dinamitar el inicio (0,3) ni metas (8,1 / 3 / 5)
                                      bool isProtected = (gx == 0 && gy == 3) || (gx == 8 && (gy == 1 || gy == 3 || gy == 5));
                                      if (isProtected) {
                                         _showError("No puedes usar dinamita en esta celda protegida");
                                         return;
                                      }
                                      try { FlameAudio.play('dinamita.mp3', volume: 0.8); } catch(e){}
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
                                      border: Border.all(color: Colors.white10, width: 1),
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

            // Nueva Lista Horizontal de Jugadores (Debajo del tablero)
            Positioned(
              left: 0, right: 0, bottom: 155, height: 85,
              child: Consumer(builder: (context, ref, _) {
                final gameAsync = ref.watch(gameDataProvider(gameId));
                return gameAsync.when(
                  data: (snapshot) {
                    if (!snapshot.exists) return const SizedBox();
                    final data = snapshot.data() as Map<String, dynamic>;
                    final players = data['players'] as Map;
                    final currentTurn = data['currentTurn'];
                    final isMyTurn = currentTurn == firebaseService.currentUid;
                    
                    return SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: players.entries.map((e) {
                          final pid = e.key;
                          final pdata = e.value;
                          final cardCount = (pdata['hand'] as List? ?? []).length;
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
                                final card = details.data;
                                if (card is ActionCard && card.actionType == 'fix_tool') {
                                   final fixable = card.fixTools.isNotEmpty ? card.fixTools : [card.targetTool];
                                   final common = fixable.where((t) => broken.contains(t)).toList();
                                   
                                   if (common.length > 1) {
                                      _showFixSelectionDialog(gameId, pid, pdata['name'], common, card, firebaseService);
                                      return;
                                   }
                                }

                                await firebaseService.playActionOnPlayer(gameId, firebaseService.currentUid, pid, details.data.toMap());
                                
                                if (card is ActionCard && card.actionType == 'break_tool') {
                                   try { FlameAudio.play('romper_herramienta.mp3', volume: 0.8); } catch(e){}
                                } else {
                                   try { FlameAudio.play('reparar_herramienta.mp3', volume: 0.8); } catch(e){}
                                }
                                setState(() => _hasPlayedOrDiscardedThisTurn = true);
                              } catch (e) { _showError(e.toString()); }
                            },
                            builder: (context, candidate, _) => Container(
                              width: 130,
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: candidate.isNotEmpty ? Colors.orangeAccent.withOpacity(0.5) : Colors.black87,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: pid == currentTurn ? Colors.greenAccent : Colors.white24,
                                  width: pid == currentTurn ? 2 : 1
                                ),
                                boxShadow: pid == currentTurn ? [const BoxShadow(color: Colors.greenAccent, blurRadius: 4)] : null,
                              ),
                              child: InkWell(
                                onTap: () => _showPlayerDetailDialog(pdata, pid, broken),
                                borderRadius: BorderRadius.circular(10),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      pdata['name'] + (pid == firebaseService.currentUid ? ' (Tú)' : ''),
                                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '(${pdata['hand']?.length ?? 0} cartas)',
                                      style: const TextStyle(color: AppColors.cream, fontSize: 9),
                                    ),
                                    if (broken.isNotEmpty)
                                      Padding(
                                        padding: const EdgeInsets.only(top: 4),
                                        child: Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: broken.map((t) {
                                            String asset = 'assets/images_cards/castigo_pico.png';
                                            if (t == 'linterna' || t == 'lantern') asset = 'assets/images_cards/castigo_linterna.png';
                                            if (t == 'carrito' || t == 'cart') asset = 'assets/images_cards/castigo_carrito.png';
                                            return Padding(
                                              padding: const EdgeInsets.symmetric(horizontal: 1),
                                              child: Image.asset(asset, width: 14, height: 14),
                                            );
                                          }).toList(),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
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
                      Positioned(
                        top: 5, left: 10, right: 10,
                        child: Column(
                          children: [
                            // Fila 1: Temporizador de Turno (Siempre al centro)
                            Center(child: _buildTurnTimer(isMyTurn, turnPlayerName)),
                            const SizedBox(height: 5),
                            // Fila 2: Botones de Acción (Alineados a la derecha)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                _buildStandingsButton(data),
                                const SizedBox(width: 8),
                                _buildRoleChip(role),
                              ],
                            ),
                          ],
                        ),
                      ),
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
    ),
   );
  }

  IconData _getIconForTool(String tool) {
    if (tool == 'pico' || tool == 'pickaxe') return Icons.construction;
    if (tool == 'linterna' || tool == 'lantern') return Icons.lightbulb;
    if (tool == 'carrito' || tool == 'cart') return Icons.shopping_cart;
    return Icons.settings;
  }

  Widget _buildStandingsButton(Map<String, dynamic> data) {
    return IconButton(
      icon: const Icon(Icons.leaderboard, color: AppColors.brightGold, size: 28),
      tooltip: 'Puntuaciones',
      onPressed: () {
        final players = Map<String, dynamic>.from(data['players']);
        final sortedPlayers = players.entries.toList()..sort((a,b) => ((b.value['gold'] ?? 0) as num).compareTo((a.value['gold'] ?? 0) as num));
        final int roundNumber = data['roundNumber'] ?? 1;

        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            backgroundColor: AppColors.darkBackground,
            title: Text('CLASIFICACIÓN (Ronda $roundNumber)', style: const TextStyle(color: AppColors.brightGold, fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: 300,
              child: ListView(
                shrinkWrap: true,
                children: sortedPlayers.map((p) => ListTile(
                   leading: const Icon(Icons.person, color: Colors.white70),
                   title: Text(p.value['name'], style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                   trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text('${p.value['gold'] ?? 0}', style: const TextStyle(color: Colors.amber, fontWeight: FontWeight.bold, fontSize: 18)), const SizedBox(width: 4), const Icon(Icons.stars, color: Colors.amber, size: 20)]),
                )).toList()
              ),
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('CERRAR'))]
          )
        );
      }
    );
  }

  Widget _buildRoleChip(String role) {
    final isSabo = role == 'saboteur';
    
    return GestureDetector(
      onTap: () => setState(() => _isRoleHidden = !_isRoleHidden),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.black87, 
            borderRadius: BorderRadius.circular(15), 
            border: Border.all(
              color: _isRoleHidden 
                ? Colors.white54 
                : (isSabo ? Colors.redAccent : Colors.cyanAccent),
              width: 1.5
            ),
            boxShadow: _isRoleHidden ? null : [
              BoxShadow(
                color: (isSabo ? Colors.redAccent : Colors.cyanAccent).withOpacity(0.3),
                blurRadius: 4,
                spreadRadius: 1
              )
            ]
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                _isRoleHidden ? Icons.visibility_off : (isSabo ? Icons.dangerous : Icons.person), 
                size: 14, 
                color: _isRoleHidden ? Colors.white54 : (isSabo ? Colors.redAccent : Colors.cyanAccent)
              ),
              const SizedBox(width: 6),
              Text(
                _isRoleHidden ? 'OCULTO' : (isSabo ? 'SABOTEADOR' : 'MINERO'), 
                style: TextStyle(
                  color: _isRoleHidden ? Colors.white54 : (isSabo ? Colors.redAccent : Colors.cyanAccent), 
                  fontSize: 10, 
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5
                )
              ),
            ],
          ),
        ),
      ),
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
