import 'dart:async';
import 'dart:collection';

class Channel<T> {
  final Queue<T> _queue;

  final int size;

  Channel(this.size) : _queue = Queue<T>();

  Completer? _releaseCompleter;

  Completer? _pushCompleter;

  var currentSize = 0;

  var isClosed = false;

  Future<void> push(T item) async {
    if (currentSize >= size) {
      _releaseCompleter ??= Completer();
      return _releaseCompleter!.future.then((_) {
        if (isClosed) {
          return;
        }
        _queue.addLast(item);
        currentSize++;
      });
    }
    _queue.addLast(item);
    currentSize++;
    _pushCompleter?.complete();
    _pushCompleter = null;
  }

  Future<T?> pop() async {
    while (_queue.isEmpty) {
      if (isClosed) {
        return null;
      }
      _pushCompleter ??= Completer();
      await _pushCompleter!.future;
    }
    var item = _queue.removeFirst();
    currentSize--;
    if (_releaseCompleter != null && currentSize < size) {
      _releaseCompleter!.complete();
      _releaseCompleter = null;
    }
    return item;
  }

  void close() {
    isClosed = true;
    _pushCompleter?.complete();
    _releaseCompleter?.complete();
  }
}