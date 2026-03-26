import 'dart:async';
import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/card_model.dart';

class FirebaseService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  String get currentUid => _auth.currentUser?.uid ?? '';

  Stream<DocumentSnapshot> gameStream(String gameId) {
    return _firestore.collection('games').doc(gameId).snapshots();
  }

  Future<void> toggleReadyStatus(String gameId, String playerId, bool isReady) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId.isReady': isReady
    });
  }

  Future<void> joinGame(String gameId, String playerId, String playerName) async {
    await _firestore.collection('games').doc(gameId).set({
      'players': {
        playerId: {
          'name': playerName,
          'role': 'unknown',
          'gold': 0,
          'isHost': false,
          'hand': [],
          'brokenTools': [],
        }
      }
    }, SetOptions(merge: true));
  }

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
          'hand': [],
          'brokenTools': [],
        }
      },
      'board': {},
      'pathCards': [],
      'deck': [],
      'discardPile': [],
      'currentTurn': hostId,
      'turnNumber': 1,
      'createdAt': FieldValue.serverTimestamp(),
      'revealedGoals': [], 
      'goldGoalIndex': 1,
      'roundNumber': 1,
      'lastPlayedUid': '',
      'turnOrder': [],
    });
    return docRef.id;
  }

  Future<void> startGame(String gameId) async {
    final doc = await _firestore.collection('games').doc(gameId).get();
    if (!doc.exists) return;

    final random = Random();
    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final playerIds = players.keys.toList()..shuffle();

    int numSaboteurs = playerIds.length == 2 ? 1 : (playerIds.length / 3).floor().clamp(1, 3);

    for (int i = 0; i < playerIds.length; i++) {
        players[playerIds[i]]['role'] = i < numSaboteurs ? 'saboteur' : 'miner';
        players[playerIds[i]]['brokenTools'] = [];
    }

    final goldIdx = random.nextInt(3);
    final goalShapes = <Map<String, dynamic>>[];
    final stoneShapes = [
      {'top': true, 'left': true, 'bottom': false, 'right': false},
      {'bottom': true, 'left': true, 'top': false, 'right': false},
    ]..shuffle();

    for (int i = 0; i < 3; i++) {
        if (i == goldIdx) {
            goalShapes.add({'top': true, 'bottom': true, 'left': true, 'right': true});
        } else {
            goalShapes.add(stoneShapes.removeLast());
        }
    }

    final deck = _generateDeck();
    for (var pid in playerIds) {
        players[pid]['hand'] = [for (int j = 0; j < 6; j++) if (deck.isNotEmpty) deck.removeLast()];
    }

    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing',
      'players': players,
      'deck': deck,
      'turnOrder': playerIds,
      'currentTurn': playerIds[0],
      'turnNumber': 1,
      'turnStartTime': FieldValue.serverTimestamp(),
      'pathCards': [],
      'discardPile': [],
      'goldGoalIndex': goldIdx,
      'goalShapes': goalShapes,
      'revealedGoals': [],
    });
  }

  Future<void> playCard(String gameId, String? uid, Map<String, dynamic> cardData, int x, int y) async {
    if (uid == null) return;
    final doc = await _firestore.collection('games').doc(gameId).get();
    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final pathCards = List<Map<String, dynamic>>.from(data['pathCards']);
    
    final existingIndex = pathCards.indexWhere((c) => c['x'] == x && c['y'] == y);
    final isAction = cardData['type'] == 'path' ? false : true; // Improved type check
    final actionType = cardData['actionType'];

    if (isAction && actionType == 'rockfall') {
      if (existingIndex == -1) throw Exception("No hay nada que destruir aquí");
      pathCards.removeAt(existingIndex);
      final actorName = players[uid]['name'];
      await _firestore.collection('games').doc(gameId).update({
        'pathCards': pathCards,
        'recentAction': {
          'type': 'rockfall',
          'actorName': actorName,
          'actorId': uid,
          'timestamp': FieldValue.serverTimestamp(),
        }
      });
    } else if (!isAction) {
      if (existingIndex != -1) throw Exception("Casilla ocupada");
      
      // VALIDACIÓN DE CAMINO
      final newCard = PathCard.fromMap(cardData);
      _validatePlacement(newCard, x, y, pathCards, data);

      pathCards.add({...cardData, 'x': x, 'y': y, 'playedBy': uid});
      
      final actorName = players[uid]['name'];
      await _firestore.collection('games').doc(gameId).update({
        'recentAction': {
          'type': 'path_placed',
          'actorName': actorName,
          'actorId': uid,
          'timestamp': FieldValue.serverTimestamp(),
        }
      });
      
      // CHEQUEO DE VICTORIA / REVELAR METAS
      final revealedGoals = List<int>.from(data['revealedGoals'] ?? []);
      final goldIdx = data['goldGoalIndex'] as int;
      bool winnersFound = false;

      // BFS para ver qué se conecta ahora
      final connectedCoords = _getConnectedPath(pathCards);
      
      // Metas están en (8, 1), (8, 3), (8, 5)
      final goals = [(8, 1), (8, 3), (8, 5)];
      for (int i = 0; i < 3; i++) {
        final g = goals[i];
        if (connectedCoords.contains(g)) {
          if (_connectsToGoal(g.$1, g.$2, pathCards)) {
             if (!revealedGoals.contains(i)) {
                revealedGoals.add(i);
                final isGold = (i == goldIdx);
                if (isGold) winnersFound = true;
                
                // Notificar revelación de meta
                await _firestore.collection('games').doc(gameId).update({
                  'recentAction': {
                    'type': 'goal_revealed',
                    'goalIndex': i,
                    'isGold': isGold,
                    'actorName': players[uid]['name'],
                    'timestamp': FieldValue.serverTimestamp(),
                  }
                });
             }
          }
        }
      }

      if (winnersFound) {
        data['pathCards'] = pathCards;
        data['revealedGoals'] = revealedGoals;
        data['players'] = players;
        await _distributeGold(gameId, data, 'miner', uid);
        return;
      }

      await _firestore.collection('games').doc(gameId).update({
        'revealedGoals': revealedGoals,
        'pathCards': pathCards,
      });
    }

    players[uid]['hand'].removeWhere((c) => c['id'] == cardData['id']);
    await _firestore.collection('games').doc(gameId).update({
      'players': players,
    });
  }

  void _validatePlacement(PathCard card, int x, int y, List<Map<String, dynamic>> pathCards, Map<String, dynamic> gameData) {
    // 1. Debe estar conectado a algo (o ser adyacente al inicio)
    bool hasNeighbor = false;
    final neighbors = [
      (x, y - 1, 'top', 'bottom'),
      (x, y + 1, 'bottom', 'top'),
      (x - 1, y, 'left', 'right'),
      (x + 1, y, 'right', 'left'),
    ];

    // Card de inicio está en (0, 3)
    if ((x == 0 && (y == 2 || y == 4)) || (x == 1 && y == 3)) hasNeighbor = true;

    for (var n in neighbors) {
      final nx = n.$1;
      final ny = n.$2;
      final myDir = n.$3;
      final neighborDir = n.$4;

      // Buscar el vecino en las cartas puestas O si es la carta de inicio
      Map<String, dynamic> neighborData = {};
      if (nx == 0 && ny == 3) {
        neighborData = {'connections': {'top': true, 'bottom': true, 'left': true, 'right': true}};
      } else {
        neighborData = pathCards.firstWhere((c) => c['x'] == nx && c['y'] == ny, orElse: () => {});
      }

      if (neighborData.isNotEmpty) {
        hasNeighbor = true;
        final nConns = neighborData['connections'] as Map;
        final myConns = card.connections;
        
        // El "corte" ocurre si uno tiene conexión y el otro no
        bool myHas = myConns[PathDirection.values.firstWhere((e) => e.name == myDir)] == true;
        bool nHas = nConns[neighborDir] == true;
        
        if (myHas != nHas) {
          throw Exception("Las conexiones no coinciden (corte en $myDir)");
        }
        
        // Además, si el vecino es parte del camino conectado al inicio,
        // este nuevo movimiento hereda esa propiedad (reemplaza touchesConnected parcial)
      }
    }

    if (!hasNeighbor) throw Exception("La carta debe estar conectada al camino existente");
    
    // 2. ¿Está connectedToStart? 
    // En Saboteur, la carta debe estar conectada al inicio a través de un camino válido.
    // Para simplificar la validación de colocación, ya verificamos "corte" arriba.
    // Pero falta asegurar que este lugar sea alcanzable desde el inicio.
    final connected = _getConnectedPath(pathCards);
    bool isReachable = false;
    
    // Si somos vecinos del start (0,3) y tenemos conexión hacia él, somos alcanzables.
    if ((x == 0 && (y == 2 || y == 4)) || (x == 1 && y == 3)) {
       final myConns = card.connections;
       if (x == 1 && y == 3 && myConns[PathDirection.left] == true) isReachable = true;
       if (x == 0 && y == 2 && myConns[PathDirection.bottom] == true) isReachable = true;
       if (x == 0 && y == 4 && myConns[PathDirection.top] == true) isReachable = true;
    }
    
    if (!isReachable) {
       for (var n in neighbors) {
         if (connected.contains((n.$1, n.$2))) {
            // Verificar que hay conexión real del vecino hacia nosotros
            final nData = pathCards.firstWhere((c) => c['x'] == n.$1 && c['y'] == n.$2, orElse: () => {});
            if (nData.isNotEmpty) {
               final nConns = nData['connections'] as Map;
               if (nConns[n.$4] == true) {
                 isReachable = true;
                 break;
               }
            }
         }
       }
    }
    
    if (!isReachable) throw Exception("La carta debe estar conectada por un camino al inicio");
  }

  Set<(int, int)> _getConnectedPath(List<Map<String, dynamic>> pathCards) {
    final Set<(int, int)> connected = {};
    final List<(int, int)> queue = [(0, 3)]; // Inicio
    
    final Map<(int, int), Map<String, dynamic>> grid = {};
    for (var c in pathCards) {
      grid[(c['x'] as int, c['y'] as int)] = c;
    }
    // Start card fix:
    grid[(0, 3)] = {'connections': {'top': true, 'bottom': true, 'left': true, 'right': true}};

    while (queue.isNotEmpty) {
      final curr = queue.removeAt(0);
      if (connected.contains(curr)) continue;
      connected.add(curr);

      final currData = grid[curr];
      if (currData == null) continue;
      if (currData['hasCenter'] == false) continue; // Si es un callejón sin salida (Bloqueo)

      final conns = currData['connections'] as Map;
      
      final neighbors = [
        (curr.$1, curr.$2 - 1, 'top', 'bottom'),
        (curr.$1, curr.$2 + 1, 'bottom', 'top'),
        (curr.$1 - 1, curr.$2, 'left', 'right'),
        (curr.$1 + 1, curr.$2, 'right', 'left'),
      ];

      for (var n in neighbors) {
        if (conns[n.$3] == true) {
          final nCoord = (n.$1, n.$2);
          final nData = grid[nCoord];
          if (nData != null && (nData['connections'] as Map)[n.$4] == true) {
            queue.add(nCoord);
          }
          // Special case for goals (meta)
          if (nCoord.$1 == 8 && (nCoord.$2 == 1 || nCoord.$2 == 3 || nCoord.$2 == 5)) {
             connected.add(nCoord);
          }
        }
      }
    }
    return connected;
  }

  bool _connectsToGoal(int gx, int gy, List<Map<String, dynamic>> pathCards) {
    // Un simple chequeo de si algún vecino envía una conexión a la meta
    final neighbors = [
      (gx, gy - 1, 'bottom'),
      (gx, gy + 1, 'top'),
      (gx - 1, gy, 'right'),
      (gx + 1, gy, 'left'),
    ];

    for (var n in neighbors) {
      final nData = pathCards.firstWhere((c) => c['x'] == n.$1 && c['y'] == n.$2, orElse: () => {});
      if (nData.isNotEmpty) {
        if ((nData['connections'] as Map)[n.$3] == true) return true;
      }
      if (n.$1 == 0 && n.$2 == 3) return true; // Start card
    }
    return false;
  }

  Future<void> playActionOnPlayer(String gameId, String? actorUid, String targetUid, Map<String, dynamic> cardData) async {
    if (actorUid == null) return;
    final doc = await _firestore.collection('games').doc(gameId).get();
    final players = Map<String, dynamic>.from(doc.get('players'));
    
    final type = cardData['actionType'];
    final tool = cardData['targetTool'];
    List broken = List.from(players[targetUid]['brokenTools'] ?? []);

    if (type == 'break_tool') {
      if (actorUid == targetUid) {
        throw Exception("No puedes romper tus propias herramientas");
      }
      if (!broken.contains(tool)) {
        broken.add(tool);
      } else {
        throw Exception("Esta herramienta ya está rota");
      }
    } else if (type == 'fix_tool') {
      final List? fixToolsRaw = cardData['fixTools'];
      final List<String> canFix = (fixToolsRaw != null && fixToolsRaw.isNotEmpty) 
          ? fixToolsRaw.cast<String>() 
          : [tool];
          
      final matchingTool = broken.firstWhere((b) => canFix.contains(b), orElse: () => '');
      
      if (matchingTool.isEmpty) {
        throw Exception("Esta carta no puede reparar ninguna de tus herramientas rotas");
      }
      
      broken.remove(matchingTool);
      // For notifications, we use the tool that was actually fixed
      cardData['targetTool'] = matchingTool; 
    }

    players[targetUid]['brokenTools'] = broken;
    players[actorUid]['hand'].removeWhere((c) => c['id'] == cardData['id']);

    final actorName = players[actorUid]['name'];
    final targetName = players[targetUid]['name'];

    await _firestore.collection('games').doc(gameId).update({
      'players': players,
      'recentAction': {
        'type': type,
        'tool': type == 'fix_tool' ? cardData['targetTool'] : tool,
        'actorName': actorName,
        'actorId': actorUid,
        'targetName': targetName,
        'targetId': targetUid,
        'timestamp': FieldValue.serverTimestamp(),
      }
    });
  }

  Future<Map<String, dynamic>> revealGoalSecretly(String gameId, String uid, Map<String, dynamic> cardData, int goalIndex) async {
    final doc = await _firestore.collection('games').doc(gameId).get();
    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final goldIdx = data['goldGoalIndex'] as int? ?? 1;
    final goalShapes = data['goalShapes'] as List<dynamic>?;
    
    players[uid]['hand'].removeWhere((c) => c['id'] == cardData['id']);
    
    await _firestore.collection('games').doc(gameId).update({
      'players': players,
      'recentAction': {
        'type': 'map_used',
        'actorName': players[uid]['name'],
        'actorId': uid,
        'timestamp': FieldValue.serverTimestamp(),
        'goalIndex': goalIndex,
      }
    });

    final isGold = goalIndex == goldIdx;
    Map<String, dynamic> shape = {'top': true, 'bottom': true, 'left': true, 'right': true};
    if (goalShapes != null && goalShapes.length > goalIndex) {
      shape = Map<String, dynamic>.from(goalShapes[goalIndex]);
    }

    return {
      'isGold': isGold,
      'connections': shape,
      'name': isGold ? "¡ORO!" : "Piedra",
    };
  }

  Future<void> discardCard(String gameId, String? uid, Map<String, dynamic> cardData) async {
    if (uid == null) return;
    final doc = await _firestore.collection('games').doc(gameId).get();
    final players = Map<String, dynamic>.from(doc.get('players'));
    
    players[uid]['hand'].removeWhere((c) => c['id'] == cardData['id']);
    await _firestore.collection('games').doc(gameId).update({
      'discardPile': FieldValue.arrayUnion([cardData]),
      'players': players,
    });
  }

  Future<void> endTurnAndDraw(String gameId, String? uid) async {
    if (uid == null) return;
    final doc = await _firestore.collection('games').doc(gameId).get();
    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final deck = List<Map<String, dynamic>>.from(data['deck']);
    final playerIds = players.keys.toList();
    
    if (deck.isNotEmpty && players[uid]['hand'].length < 6) {
        players[uid]['hand'].add(deck.removeLast());
    }

    bool allHandsEmpty = true;
    for (var p in players.values) {
      if ((p['hand'] as List).isNotEmpty) {
        allHandsEmpty = false;
        break;
      }
    }

    if (allHandsEmpty && deck.isEmpty) {
      data['players'] = players;
      data['deck'] = deck;
      await _distributeGold(gameId, data, 'saboteur', uid);
      return;
    }

    final turnOrder = List<String>.from(data['turnOrder'] ?? playerIds);
    int nextIndex = (turnOrder.indexOf(uid) + 1) % turnOrder.length;

    await _firestore.collection('games').doc(gameId).update({
      'players': players,
      'deck': deck,
      'currentTurn': turnOrder[nextIndex],
      'turnNumber': FieldValue.increment(1),
      'turnStartTime': FieldValue.serverTimestamp(),
    });
  }

  Future<void> forceSkipTurn(String gameId, String currentTurnUid) async {
    final doc = await _firestore.collection('games').doc(gameId).get();
    final data = doc.data() as Map<String, dynamic>;
    final players = Map<String, dynamic>.from(data['players']);
    final deck = List<Map<String, dynamic>>.from(data['deck']);
    
    if (deck.isEmpty) {
      final hand = List<Map<String, dynamic>>.from(players[currentTurnUid]['hand'] ?? []);
      if (hand.isNotEmpty) {
        final random = Random();
        final cardToDiscard = hand.removeAt(random.nextInt(hand.length));
        
        await _firestore.collection('games').doc(gameId).update({
          'discardPile': FieldValue.arrayUnion([cardToDiscard]),
        });
        
        players[currentTurnUid]['hand'] = hand;
        await _firestore.collection('games').doc(gameId).update({
          'players': players,
        });
      }
    }
    
    await endTurnAndDraw(gameId, currentTurnUid);
  }

  Future<void> deleteGame(String gameId) async {
    await _firestore.collection('games').doc(gameId).delete();
  }

  Future<void> updatePlayerName(String gameId, String playerId, String newName) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId.name': newName
    });
  }

  Future<void> leaveGame(String gameId, String playerId) async {
    await _firestore.collection('games').doc(gameId).update({
      'players.$playerId': FieldValue.delete()
    });
  }

  String getUniqueName(Map<dynamic, dynamic> players, String targetName, String currentId) {
    List<String> existingNames = [];
    players.forEach((id, data) {
      if (id != currentId) existingNames.add(data['name'].toString());
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

  List<Map<String, dynamic>> _generateDeck() {
    final List<Map<String, dynamic>> deck = [];
    final random = Random();
    final pathTemplates = [
      {'name': 'Recta V', 'conn': {'top': true, 'bottom': true}},
      {'name': 'Recta H', 'conn': {'left': true, 'right': true}},
      {'name': 'Curva SD', 'conn': {'top': true, 'right': true}},
      {'name': 'Curva SI', 'conn': {'top': true, 'left': true}},
      {'name': 'Curva ID', 'conn': {'bottom': true, 'right': true}},
      {'name': 'Curva II', 'conn': {'bottom': true, 'left': true}},
      {'name': 'T-Inter', 'conn': {'left': true, 'right': true, 'bottom': true}},
      {'name': 'T-Inter Inv', 'conn': {'left': true, 'right': true, 'top': true}},
      {'name': 'Cruz', 'conn': {'top': true, 'bottom': true, 'left': true, 'right': true}},
      {'name': 'Bloqueo', 'conn': {'top': true}, 'hasCenter': false},
    ];
    for (int i = 0; i < 40; i++) {
        final t = pathTemplates[random.nextInt(pathTemplates.length)];
        deck.add({'id': 'p_$i', 'name': t['name'], 'type': 'path', 'imageUrl': '', 'connections': t['conn'], 'hasCenter': t['hasCenter'] ?? true});
    }
    for (int i = 0; i < 4; i++) {
        deck.add({'id': 'dyn_$i', 'name': 'Dinamita', 'type': 'action', 'actionType': 'rockfall', 'imageUrl': ''});
        deck.add({'id': 'map_$i', 'name': 'Mapa', 'type': 'action', 'actionType': 'map', 'imageUrl': ''});
    }
    final tools = ['pico', 'linterna', 'carrito'];
    for (var tool in tools) {
        deck.add({'id': 'brk_${tool}_${random.nextInt(100)}', 'name': 'Romper $tool', 'type': 'action', 'actionType': 'break_tool', 'targetTool': tool, 'imageUrl': ''});
        deck.add({'id': 'fix_${tool}_${random.nextInt(100)}', 'name': 'Reparar $tool', 'type': 'action', 'actionType': 'fix_tool', 'fixTools': [tool], 'imageUrl': ''});
    }
    deck.add({'id': 'fix_pico_linterna', 'name': 'Reparar Pico o Linterna', 'type': 'action', 'actionType': 'fix_tool', 'fixTools': ['pico', 'linterna'], 'imageUrl': ''});
    deck.add({'id': 'fix_pico_carrito', 'name': 'Reparar Pico o Carrito', 'type': 'action', 'actionType': 'fix_tool', 'fixTools': ['pico', 'carrito'], 'imageUrl': ''});
    deck.add({'id': 'fix_linterna_carrito', 'name': 'Reparar Linterna o Carrito', 'type': 'action', 'actionType': 'fix_tool', 'fixTools': ['linterna', 'carrito'], 'imageUrl': ''});
    deck.shuffle(random);
    return deck;
  }

  Future<void> _distributeGold(String gameId, Map<String, dynamic> gameData, String winnerRole, String lastPlayerId) async {
    final players = Map<String, dynamic>.from(gameData['players']);
    final int roundNumber = gameData['roundNumber'] ?? 1;
    final int numPlayers = players.length;

    if (winnerRole == 'miner') {
      int numCards = numPlayers == 10 ? 9 : numPlayers;
      List<int> drawnNuggets = [];
      final rand = Random();
      for (int i = 0; i < numCards; i++) {
         int r = rand.nextInt(28);
         if (r < 16) drawnNuggets.add(1);
         else if (r < 24) drawnNuggets.add(2);
         else drawnNuggets.add(3);
      }
      drawnNuggets.sort((a,b) => b.compareTo(a));

      final playerIds = players.keys.toList();
      int startIdx = playerIds.indexOf(lastPlayerId);
      if (startIdx == -1) startIdx = 0;

      List<String> minerIds = [];
      for (int i = 0; i < numPlayers; i++) {
        String pid = playerIds[(startIdx + i) % numPlayers];
        if (players[pid]['role'] == 'miner') {
          minerIds.add(pid);
        }
      }

      if (minerIds.isNotEmpty) {
        int mIdx = 0;
        for (int nugget in drawnNuggets) {
           players[minerIds[mIdx]]['gold'] = (players[minerIds[mIdx]]['gold'] ?? 0) + nugget;
           mIdx = (mIdx + 1) % minerIds.length;
        }
      }
    } else {
      int numSaboteurs = players.values.where((p) => p['role'] == 'saboteur').length;
      int nuggetsPerSaboteur = 0;
      if (numSaboteurs == 1) nuggetsPerSaboteur = 4;
      else if (numSaboteurs >= 2 && numSaboteurs <= 3) nuggetsPerSaboteur = 3;
      else if (numSaboteurs >= 4) nuggetsPerSaboteur = 2;

      for (var pid in players.keys) {
        if (players[pid]['role'] == 'saboteur') {
          players[pid]['gold'] = (players[pid]['gold'] ?? 0) + nuggetsPerSaboteur;
        }
      }
    }

    await _firestore.collection('games').doc(gameId).update({
      'players': players,
      'status': roundNumber >= 3 ? 'finished' : 'round_finished',
      'winnerRole': winnerRole,
      'roundNumber': roundNumber,
      'lastPlayedUid': lastPlayerId,
      'pathCards': gameData['pathCards'] ?? [],
      'revealedGoals': gameData['revealedGoals'] ?? [],
      'deck': gameData['deck'] ?? [],
    });
  }

  Future<void> startNextRound(String gameId) async {
    final doc = await _firestore.collection('games').doc(gameId).get();
    if (!doc.exists) return;

    final data = doc.data() as Map<String, dynamic>;
    int roundNumber = data['roundNumber'] ?? 1;
    if (roundNumber >= 3) return;
    
    final players = Map<String, dynamic>.from(data['players']);
    final random = Random();
    final playerIds = players.keys.toList()..shuffle();

    int numSaboteurs = playerIds.length == 2 ? 1 : (playerIds.length / 3).floor().clamp(1, 4);
    for (int i = 0; i < playerIds.length; i++) {
        players[playerIds[i]]['role'] = i < numSaboteurs ? 'saboteur' : 'miner';
        players[playerIds[i]]['brokenTools'] = [];
    }

    final goldIdx = random.nextInt(3);
    final goalShapes = <Map<String, dynamic>>[];
    final stoneShapes = [
      {'top': true, 'left': true, 'bottom': false, 'right': false},
      {'bottom': true, 'left': true, 'top': false, 'right': false},
    ]..shuffle();

    for (int i = 0; i < 3; i++) {
        if (i == goldIdx) {
            goalShapes.add({'top': true, 'bottom': true, 'left': true, 'right': true});
        } else {
            goalShapes.add(stoneShapes.removeLast());
        }
    }

    final deck = _generateDeck();
    for (var pid in playerIds) {
        players[pid]['hand'] = [for (int j = 0; j < 6; j++) if (deck.isNotEmpty) deck.removeLast()];
    }

    final lastPlayedUid = data['lastPlayedUid'] as String?;
    int nextTurnIdx = 0;
    if (lastPlayedUid != null && playerIds.contains(lastPlayedUid)) {
       nextTurnIdx = (playerIds.indexOf(lastPlayedUid) + 1) % playerIds.length;
    }

    await _firestore.collection('games').doc(gameId).update({
      'status': 'playing',
      'players': players,
      'deck': deck,
      'turnOrder': playerIds,
      'currentTurn': playerIds[nextTurnIdx],
      'turnNumber': 1,
      'turnStartTime': FieldValue.serverTimestamp(),
      'pathCards': [],
      'discardPile': [],
      'goldGoalIndex': goldIdx,
      'goalShapes': goalShapes,
      'revealedGoals': [],
      'roundNumber': roundNumber + 1,
    });
  }
}
