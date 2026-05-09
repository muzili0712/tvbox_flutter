import 'package:flutter/foundation.dart';

class LogService extends ChangeNotifier {
  static final LogService instance = LogService._internal();
  
  final List<LogEntry> _logs = [];
  List<LogEntry> get logs => List.unmodifiable(_logs);
  
  static const int maxLogs = 1000;
  
  LogService._internal() {
    _setupPrintOverride();
  }
  
  void _setupPrintOverride() {
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null && message.isNotEmpty) {
        _addLog(message);
      }
    };
  }
  
  void _addLog(String message) {
    final entry = LogEntry(
      message: message,
      timestamp: DateTime.now(),
      level: _getLogLevel(message),
    );
    
    _logs.add(entry);
    
    if (_logs.length > maxLogs) {
      _logs.removeAt(0);
    }
    
    notifyListeners();
  }
  
  LogLevel _getLogLevel(String message) {
    final upperMessage = message.toUpperCase();
    if (upperMessage.contains('[ERROR]') || upperMessage.contains('❌')) {
      return LogLevel.error;
    } else if (upperMessage.contains('[WARNING]') || upperMessage.contains('⚠️')) {
      return LogLevel.warning;
    } else if (upperMessage.contains('[INFO]') || upperMessage.contains('✅') || upperMessage.contains('🚀') || upperMessage.contains('📡') || upperMessage.contains('📨')) {
      return LogLevel.info;
    }
    return LogLevel.debug;
  }
  
  void clear() {
    _logs.clear();
    notifyListeners();
  }
  
  String getAllLogsAsText() {
    return _logs.map((entry) => entry.formattedString).join('\n');
  }
  
  void addLog(String message, {LogLevel level = LogLevel.info}) {
    _addLog(message);
  }
}

enum LogLevel {
  debug,
  info,
  warning,
  error,
}

class LogEntry {
  final String message;
  final DateTime timestamp;
  final LogLevel level;
  
  LogEntry({
    required this.message,
    required this.timestamp,
    required this.level,
  });
  
  String get formattedString {
    return '[${timestamp.toIso8601String()}] ${message}';
  }
}
