import 'package:shared_preferences/shared_preferences.dart';

class PersistenceService {
  static const String _gameIdKey = 'active_game_id';

  Future<void> saveGameId(String? id) async {
    final prefs = await SharedPreferences.getInstance();
    if (id == null) {
      await prefs.remove(_gameIdKey);
    } else {
      await prefs.setString(_gameIdKey, id);
    }
  }

  Future<String?> getGameId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_gameIdKey);
  }
}
