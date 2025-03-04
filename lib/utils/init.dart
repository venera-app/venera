import 'dart:async';

import 'package:flutter/foundation.dart';

/// A mixin class that provides a way to ensure the class is initialized.
abstract mixin class Init {
  bool _isInit = false;

  final _initCompleter = <Completer<void>>[];

  /// Ensure the class is initialized.
  Future<void> ensureInit() async {
    if (_isInit) {
      return;
    }
    var completer = Completer<void>();
    _initCompleter.add(completer);
    return completer.future;
  }

  Future<void> _markInit() async {
    _isInit = true;
    for (var completer in _initCompleter) {
      completer.complete();
    }
    _initCompleter.clear();
  }

  @protected
  Future<void> doInit();

  /// Initialize the class.
  Future<void> init() async {
    if (_isInit) {
      return;
    }
    await doInit();
    await _markInit();
  }
}