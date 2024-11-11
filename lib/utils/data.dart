import 'dart:convert';
import 'dart:isolate';

import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:zip_flutter/zip_flutter.dart';

import 'io.dart';

Future<File> exportAppData() async {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var cacheFilePath = FilePath.join(App.cachePath, '$time.venera');
  var cacheFile = File(cacheFilePath);
  var dataPath = App.dataPath;
  if(await cacheFile.exists()) {
    await cacheFile.delete();
  }
  await Isolate.run(() {
    var zipFile = ZipFile.open(cacheFilePath);
    var historyFile = FilePath.join(dataPath, "history.db");
    var localFavoriteFile = FilePath.join(dataPath, "local_favorite.db");
    var appdata = FilePath.join(dataPath, "appdata.json");
    zipFile.addFile("history.db", historyFile);
    zipFile.addFile("local_favorite.db", localFavoriteFile);
    zipFile.addFile("appdata.json", appdata);
    for(var file in Directory(FilePath.join(dataPath, "comic_source")).listSync()) {
      if(file is File) {
        zipFile.addFile("comic_source/${file.name}", file.path);
      }
    }
    zipFile.close();
  });
  return cacheFile;
}

Future<void> importAppData(File file, [bool checkVersion = false]) async {
  var cacheDirPath = FilePath.join(App.cachePath, 'temp_data');
  var cacheDir = Directory(cacheDirPath);
  await Isolate.run(() {
    ZipFile.openAndExtract(file.path, cacheDirPath);
  });
  var historyFile = cacheDir.joinFile("history.db");
  var localFavoriteFile = cacheDir.joinFile("local_favorite.db");
  var appdataFile = cacheDir.joinFile("appdata.json");
  if(checkVersion && appdataFile.existsSync()) {
    var data = jsonDecode(await appdataFile.readAsString());
    var version = data["settings"]["dataVersion"];
    if(version is int && version <= appdata.settings["dataVersion"]) {
      return;
    }
  }
  if(await historyFile.exists()) {
    HistoryManager().close();
    File(FilePath.join(App.dataPath, "history.db")).deleteIfExistsSync();
    historyFile.renameSync(FilePath.join(App.dataPath, "history.db"));
    HistoryManager().init();
  }
  if(await localFavoriteFile.exists()) {
    LocalFavoritesManager().close();
    File(FilePath.join(App.dataPath, "local_favorite.db")).deleteIfExistsSync();
    localFavoriteFile.renameSync(FilePath.join(App.dataPath, "local_favorite.db"));
    LocalFavoritesManager().init();
  }
  if(await appdataFile.exists()) {
    File(FilePath.join(App.dataPath, "appdata.json")).deleteIfExistsSync();
    appdataFile.renameSync(FilePath.join(App.dataPath, "appdata.json"));
    appdata.init();
  }
  var comicSourceDir = FilePath.join(cacheDirPath, "comic_source");
  if(Directory(comicSourceDir).existsSync()) {
    for(var file in Directory(comicSourceDir).listSync()) {
      if(file is File) {
        var targetFile = FilePath.join(App.dataPath, "comic_source", file.name);
        File(targetFile).deleteIfExistsSync();
        await file.copy(targetFile);
      }
    }
    await ComicSource.reload();
  }
}
