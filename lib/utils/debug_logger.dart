import 'package:flutter/foundation.dart';

class DebugLogger {
  static final List<String> _logs = [];
  static int maxLogs = 100;

  static void log(String message, {String? category}) {
    final timestamp = DateTime.now().toIso8601String().substring(11, 19);
    final formattedMessage = "[$timestamp]${category != null ? ' [$category]' : ''} $message";
    
    // Print to console for terminal visibility
    debugPrint("DEBUG: $formattedMessage");
    
    // Store in memory for UI overlay if needed
    _logs.add(formattedMessage);
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
  }

  static List<String> get logs => List.unmodifiable(_logs);
  static void clear() => _logs.clear();
}
