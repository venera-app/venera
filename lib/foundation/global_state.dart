import 'package:flutter/widgets.dart';

abstract class GlobalState {
  static final _state = <Pair<Object?, State>>[];

  static void register(State state, [Object? key]) {
    _state.add(Pair(key, state));
  }

  static T find<T extends State>([Object? key]) {
    for (var pair in _state) {
      if ((key == null || pair.left == key) && pair.right is T) {
        return pair.right as T;
      }
    }
    throw Exception('State not found');
  }

  static T? findOrNull<T extends State>([Object? key]) {
    for (var pair in _state) {
      if ((key == null || pair.left == key) && pair.right is T) {
        return pair.right as T;
      }
    }
    return null;
  }

  static void unregister(State state, [Object? key]) {
    _state.removeWhere(
        (pair) => (key == null || pair.left == key) && pair.right == state);
  }
}

class Pair<K, V> {
  K left;
  V right;

  Pair(this.left, this.right);
}

abstract class AutomaticGlobalState<T extends StatefulWidget>
    extends State<T> {
  @override
  @mustCallSuper
  void initState() {
    super.initState();
    GlobalState.register(this, key);
  }

  @override
  @mustCallSuper
  void dispose() {
    super.dispose();
    GlobalState.unregister(this, key);
  }

  Object? get key;

  void update() {
    setState(() {});
  }

  void refresh() {
    update();
  }
}
