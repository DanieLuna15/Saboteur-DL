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
}
