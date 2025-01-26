import 'package:flutter/foundation.dart';
import 'package:flutter_saf/flutter_saf.dart';
import 'package:rhttp/rhttp.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/cookie_jar.dart';
import 'package:venera/utils/app_links.dart';
import 'package:venera/utils/tags_translation.dart';
import 'package:venera/utils/translations.dart';
import 'foundation/appdata.dart';

extension _FutureInit<T> on Future<T> {
  /// Prevent unhandled exception
  ///
  /// A unhandled exception occurred in init() will cause the app to crash.
  Future<void> wait() async {
    try {
      await this;
    } catch (e, s) {
      Log.error("init", "$e\n$s");
    }
  }
}

Future<void> init() async {
  await Rhttp.init();
  await SAFTaskWorker().init().wait();
  await AppTranslation.init().wait();
  await appdata.init().wait();
  await App.init().wait();
  await HistoryManager().init().wait();
  await TagsTranslation.readData().wait();
  await LocalFavoritesManager().init().wait();
  SingleInstanceCookieJar("${App.dataPath}/cookie.db");
  await JsEngine().init().wait();
  await ComicSource.init().wait();
  await LocalManager().init().wait();
  CacheManager().setLimitSize(appdata.settings['cacheSize']);
  if (App.isAndroid) {
    handleLinks();
  }
  FlutterError.onError = (details) {
    Log.error(
        "Unhandled Exception", "${details.exception}\n${details.stack}");
  };
}