enum CardType { path, action, goal, start }

enum PathDirection { top, bottom, left, right }

class CardModel {
  final String id;
  final String name;
  final CardType type;
  final String imageUrl;

  CardModel({
    required this.id,
    required this.name,
    required this.type,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'imageUrl': imageUrl,
    };
  }

  factory CardModel.fromMap(Map<String, dynamic> map) {
    final typeStr = map['type'] as String;
    if (typeStr == CardType.path.name) {
      return PathCard.fromMap(map);
    } else if (typeStr == CardType.action.name) {
      return ActionCard.fromMap(map);
    }
    return CardModel(
      id: map['id'] as String,
      name: map['name'] as String,
      type: CardType.values.firstWhere((e) => e.name == typeStr, orElse: () => CardType.path),
      imageUrl: map['imageUrl'] as String,
    );
  }
}

class PathCard extends CardModel {
  final Map<PathDirection, bool> connections;
  final bool hasCenter;

  PathCard({
    required super.id,
    required super.name,
    required super.imageUrl,
    required this.connections,
    this.hasCenter = true,
  }) : super(type: CardType.path);

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['connections'] = connections.map((key, value) => MapEntry(key.name, value));
    map['hasCenter'] = hasCenter;
    return map;
  }

  factory PathCard.fromMap(Map<String, dynamic> map) {
    final connectionsMap = map['connections'] as Map<String, dynamic>;
    final connections = <PathDirection, bool>{};
    for (var entry in connectionsMap.entries) {
      final direction = PathDirection.values.firstWhere(
        (e) => e.name == entry.key,
        orElse: () => PathDirection.top, // Default de seguridad
      );
      connections[direction] = entry.value as bool;
    }

    return PathCard(
      id: map['id'] as String,
      name: map['name'] as String,
      imageUrl: map['imageUrl'] as String,
      connections: connections,
      hasCenter: map['hasCenter'] as bool? ?? true,
    );
  }
}

class ActionCard extends CardModel {
  final String actionType; // 'break_tool', 'fix_tool', 'map', 'rockfall'
  final String targetTool; // e.g. 'pickaxe', 'lantern', 'cart' 
  final List<String> fixTools;

  ActionCard({
    required super.id,
    required super.name,
    required super.imageUrl,
    required this.actionType,
    this.targetTool = 'none',
    this.fixTools = const [],
  }) : super(type: CardType.action);

  @override
  Map<String, dynamic> toMap() {
    final map = super.toMap();
    map['actionType'] = actionType;
    map['targetTool'] = targetTool;
    map['fixTools'] = fixTools;
    return map;
  }

  factory ActionCard.fromMap(Map<String, dynamic> map) {
    return ActionCard(
      id: map['id'] as String,
      name: map['name'] as String,
      imageUrl: map['imageUrl'] as String,
      actionType: map['actionType'] as String,
      targetTool: map['targetTool'] as String? ?? 'none',
      fixTools: (map['fixTools'] as List?)?.cast<String>() ?? [],
    );
  }
}
