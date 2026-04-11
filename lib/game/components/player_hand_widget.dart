import 'package:flutter/material.dart';
import '../../models/card_model.dart';
import '../../theme/app_colors.dart';
import 'path_card_painter.dart';

class PlayerHandWidget extends StatefulWidget {
  final List<dynamic> handData;
  final bool isMyTurn;
  final bool isInteractive;

  const PlayerHandWidget({
    required this.handData,
    required this.isMyTurn,
    this.isInteractive = false,
    super.key,
  });

  @override
  State<PlayerHandWidget> createState() => _PlayerHandWidgetState();
}

class _PlayerHandWidgetState extends State<PlayerHandWidget> {
  late ScrollController _scrollController;
  final Set<int> _rotatedIndices = {}; // Track which cards are rotated

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
  }

  @override
  void didUpdateWidget(PlayerHandWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reset rotations if hand changes (new round or turn)
    if (widget.handData.length != oldWidget.handData.length) {
       _rotatedIndices.clear();
    }
  }

  void _toggleRotation(int index) {
    if (!widget.isInteractive) return;
    
    // Solo permitir rotar si es una carta de camino
    final baseCard = CardModel.fromMap(Map<String, dynamic>.from(widget.handData[index]));
    if (baseCard.type != CardType.path) return;

    setState(() {
      if (_rotatedIndices.contains(index)) {
        _rotatedIndices.remove(index);
      } else {
        _rotatedIndices.add(index);
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 140,
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.9),
        border: Border(top: BorderSide(color: widget.isMyTurn ? Colors.greenAccent : AppColors.primaryGold, width: 3)),
        boxShadow: [
          BoxShadow(
            color: widget.isMyTurn ? Colors.greenAccent.withOpacity(0.2) : Colors.black,
            blurRadius: 15,
            spreadRadius: 5,
          )
        ],
      ),
      child: Column(
        children: [
          // Área del título que permite hacer scroll arrastrando
          GestureDetector(
            onHorizontalDragUpdate: (details) {
              if (_scrollController.hasClients) {
                _scrollController.jumpTo(
                  (_scrollController.offset - details.delta.dx).clamp(
                    0,
                    _scrollController.position.maxScrollExtent,
                  ),
                );
              }
            },
            child: Container(
              width: double.infinity,
              color: Colors.transparent, // Recibe toques
              padding: const EdgeInsets.only(bottom: 8.0, top: 4.0),
              child: Center(
                child: Text(
                  widget.isMyTurn ? 'TU MANO (>> ARRASTRA PARA VER MÁS >>)' : 'TU MANO',
                  style: TextStyle(
                    color: widget.isMyTurn ? Colors.greenAccent : Colors.white70,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: widget.handData.length,
              itemBuilder: (context, index) {
                final baseCard = CardModel.fromMap(Map<String, dynamic>.from(widget.handData[index]));
                // Solo permitimos rotación si es de tipo path
                final bool isRotated = _rotatedIndices.contains(index) && baseCard.type == CardType.path;
                final card = baseCard.copyWith(isRotated: isRotated);

                return Draggable<CardModel>(
                  data: card,
                  maxSimultaneousDrags: widget.isInteractive ? 1 : 0,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: Material(
                    color: Colors.transparent,
                    child: SizedBox(
                      width: 78,
                      height: 110,
                      child: CardItem(card: card, isDragging: true, isHighlight: true),
                    ),
                  ),
                  childWhenDragging: Opacity(
                    opacity: 0.3,
                    child: CardItem(card: card),
                  ),
                  child: GestureDetector(
                    onTap: () => _toggleRotation(index),
                    behavior: HitTestBehavior.opaque,
                    child: CardItem(card: card, isHighlight: widget.isMyTurn),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class CardItem extends StatelessWidget {
  final CardModel card;
  final bool isDragging;
  final bool isHighlight;

  const CardItem({
    required this.card, 
    this.isDragging = false, 
    this.isHighlight = false, 
    super.key
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 78,
      height: 125,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedRotation(
            turns: card.isRotated ? 0.5 : 0, // 0.5 turns = 180 degrees
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutBack,
            child: Stack(
              children: [
                Positioned.fill(
                  child: CustomPaint(
                    painter: PathCardPainter(
                      card: card, 
                      isHighlight: isHighlight || isDragging,
                      isFaceDown: false,
                    ),
                  ),
                ),
                if (card.imageUrl.isNotEmpty)
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.asset(
                        card.imageUrl, 
                        fit: BoxFit.fill,
                        errorBuilder: (context, error, stackTrace) => const SizedBox(),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (isDragging)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.greenAccent.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          if (card.isRotated && !isDragging)
             Positioned(
               top: 4,
               right: 4,
               child: Container(
                 padding: const EdgeInsets.all(2),
                 decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                 child: const Icon(Icons.sync, size: 10, color: Colors.cyanAccent),
               ),
             ),
        ],
      ),
    );
  }
}
