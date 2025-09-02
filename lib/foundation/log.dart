import 'package:flutter/foundation.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/utils/ext.dart';
import 'package:venera/utils/io.dart';

class LogItem {
  final LogLevel level;
  final String title;
  final String content;
  final DateTime time = DateTime.now();

  @override
  toString() => "${level.name} $title $time \n$content\n\n";

  LogItem(this.level, this.title, this.content);
}

enum LogLevel { error, warning, info }

class Log {
  static final List<LogItem> _logs = <LogItem>[];

  static List<LogItem> get logs => _logs;

  static const maxLogLength = 3000;

  static const maxLogNumber = 500;

  static bool ignoreLimitation = false;

  static bool isMuted = false;

  static void printWarning(String text) {
    debugPrint('\x1B[33m$text\x1B[0m');
  }

  static void printError(String text) {
    debugPrint('\x1B[31m$text\x1B[0m');
  }

  static IOSink? _file;

  static void addLog(LogLevel level, String title, String content) {
    if (isMuted) return;
    if (_file == null && App.isInitialized) {
      Directory dir;
      if (App.isAndroid) {
        dir = Directory(App.externalStoragePath!);
      } else {
        dir = Directory(App.dataPath);
      }
      var file = dir.joinFile("logs.txt");
      _file = file.openWrite();
    }

    if (!ignoreLimitation && content.length > maxLogLength) {
      content = "${content.substring(0, maxLogLength)}...";
    }

    switch (level) {
      case LogLevel.error:
        printError(content);
      case LogLevel.warning:
        printWarning(content);
      case LogLevel.info:
        if(kDebugMode) {
          debugPrint(content);
        }
    }

    var newLog = LogItem(level, title, content);

    if (newLog == _logs.lastOrNull) {
      return;
    }

    _logs.add(newLog);
    if(_file != null) {
      _file!.write(newLog.toString());
    }
    if (_logs.length > maxLogNumber) {
      var res = _logs.remove(
          _logs.firstWhereOrNull((element) => element.level == LogLevel.info));
      if (!res) {
        _logs.removeAt(0);
      }
    }
  }

  static info(String title, String content) {
    addLog(LogLevel.info, title, content);
  }

  static warning(String title, String content) {
    addLog(LogLevel.warning, title, content);
  }

  static error(String title, Object content, [Object? stackTrace]) {
    var info = content.toString();
    if(stackTrace != null) {
      info += "\n${stackTrace.toString()}";
    }
    addLog(LogLevel.error, title, info);
  }

  static void clear() => _logs.clear();

  @override
  String toString() {
    var res = "Logs\n\n";
    for (var log in _logs) {
      res += log.toString();
    }
    return res;
  }
}
