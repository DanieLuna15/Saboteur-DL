enum PlayerRole { miner, saboteur, unknown }

class PlayerModel {
  final String id;
  final String name;
  final PlayerRole role;
  final List<String> hand; // IDs of cards in hand
  final int goldNuggets;
  final bool isMyTurn;

  PlayerModel({
    required this.id,
    required this.name,
    this.role = PlayerRole.unknown,
    this.hand = const [],
    this.goldNuggets = 0,
    this.isMyTurn = false,
  });

  PlayerModel copyWith({
    String? id,
    String? name,
    PlayerRole? role,
    List<String>? hand,
    int? goldNuggets,
    bool? isMyTurn,
  }) {
    return PlayerModel(
      id: id ?? this.id,
      name: name ?? this.name,
      role: role ?? this.role,
      hand: hand ?? this.hand,
      goldNuggets: goldNuggets ?? this.goldNuggets,
      isMyTurn: isMyTurn ?? this.isMyTurn,
    );
  }
}
