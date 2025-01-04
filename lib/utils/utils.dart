import 'dart:async';

// 节流
class Throttler {
  Timer? _timer;
  final Duration duration;

  Throttler({required this.duration});

  void run(void Function() callback) {
    if (_timer == null || !_timer!.isActive) {
      callback();
      _timer = Timer(duration, () {
        _timer = null;
      });
    }
  }

  void dispose() {
    _timer?.cancel();
  }
}
