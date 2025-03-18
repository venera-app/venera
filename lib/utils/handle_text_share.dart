import 'package:flutter/services.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/pages/aggregated_search_page.dart';

bool _isHandling = false;

/// Handle text share event.
/// App will navigate to [AggregatedSearchPage] with the shared text as keyword.
void handleTextShare() async {
  if (_isHandling) return;
  _isHandling = true;

  var channel = EventChannel('venera/text_share');
  await for (var event in channel.receiveBroadcastStream()) {
    if (App.mainNavigatorKey == null) {
      await Future.delayed(const Duration(milliseconds: 200));
    }
    if (event is String) {
      App.rootContext.to(() => AggregatedSearchPage(keyword: event));
    }
  }
}
