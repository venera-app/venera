import 'dart:async';

class Debouncer {
  Timer? _timer;

  void run(void Function() action,
      [Duration delay = const Duration(milliseconds: 300)]) {
    _timer?.cancel();
    _timer = Timer(delay, action);
  }

  void dispose() {
    _timer?.cancel();
  }
}
