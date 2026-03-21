import '../models/card_model.dart';
import 'dart:math';

class DeckUtils {
  static List<CardModel> generateStandardDeck() {
    List<CardModel> deck = [];
    int idCounter = 0;
    
    String nextId() => 'card_${DateTime.now().millisecondsSinceEpoch}_${idCounter++}';

    // PATH CARDS (Aproximación para jugabilidad básica)
    // 10 Cruces (Arriba, Abajo, Izquierda, Derecha)
    for (int i = 0; i < 10; i++) {
        deck.add(PathCard(
          id: nextId(),
          name: 'Cruz',
          imageUrl: '',
          connections: {PathDirection.top: true, PathDirection.bottom: true, PathDirection.left: true, PathDirection.right: true},
        ));
    }

    // 10 Rectas Verticales
    for (int i = 0; i < 10; i++) {
        deck.add(PathCard(
          id: nextId(),
          name: 'Recta V.',
          imageUrl: '',
          connections: {PathDirection.top: true, PathDirection.bottom: true},
        ));
    }

    // 10 Rectas Horizontales
    for (int i = 0; i < 10; i++) {
        deck.add(PathCard(
          id: nextId(),
          name: 'Recta H.',
          imageUrl: '',
          connections: {PathDirection.left: true, PathDirection.right: true},
        ));
    }

    // 5 Curvas L
    for (int i = 0; i < 5; i++) {
        deck.add(PathCard(
          id: nextId(),
          name: 'Curva',
          imageUrl: '',
          connections: {PathDirection.top: true, PathDirection.right: true},
        ));
    }

    // 5 en forma de "T"
    for (int i = 0; i < 5; i++) {
        deck.add(PathCard(
          id: nextId(),
          name: 'Forma T',
          imageUrl: '',
          connections: {PathDirection.left: true, PathDirection.right: true, PathDirection.bottom: true},
        ));
    }

    // ACTION CARDS (Aproximación)
    // 5 Romper herramientas
    for (int i = 0; i < 5; i++) {
      deck.add(ActionCard(id: nextId(), name: 'Romper Pico', imageUrl: '', actionType: 'break_tool', targetTool: 'pickaxe'));
    }
    
    // 5 Arreglar herramientas
    for (int i = 0; i < 5; i++) {
      deck.add(ActionCard(id: nextId(), name: 'Arreglar Pico', imageUrl: '', actionType: 'fix_tool', targetTool: 'pickaxe'));
    }

    // 3 Derrumbes
    for (int i = 0; i < 3; i++) {
      deck.add(ActionCard(id: nextId(), name: 'Derrumbe', imageUrl: '', actionType: 'rockfall'));
    }

    // 3 Mapas
    for (int i = 0; i < 3; i++) {
      deck.add(ActionCard(id: nextId(), name: 'Mapa', imageUrl: '', actionType: 'map'));
    }

    // Shuffle
    deck.shuffle(Random());
    return deck;
  }
}
