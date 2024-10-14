import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/cache_manager.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/js_engine.dart';
import 'package:venera/foundation/local.dart';
import 'package:venera/network/cookie_jar.dart';
import 'package:venera/utils/translations.dart';

import 'foundation/appdata.dart';

Future<void> init() async {
  await AppTranslation.init();
  await appdata.init();
  await App.init();
  await HistoryManager().init();
  await LocalFavoritesManager().init();
  SingleInstanceCookieJar("${App.dataPath}/cookie.db");
  await JsEngine().init();
  await ComicSource.init();
  await LocalManager().init();
  CacheManager();
}