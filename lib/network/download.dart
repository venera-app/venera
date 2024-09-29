import 'package:flutter/widgets.dart' show ChangeNotifier;

abstract class DownloadTask with ChangeNotifier {
  int get current;

  int get total;

  double get progress => current / total;

  bool get isComplete => current == total;

  int get speed;

  void cancel();

  void pause();

  void resume();

  String get title;

  String? get cover;
}