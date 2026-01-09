import 'dart:convert';
import 'dart:isolate';

import 'package:sqlite3/sqlite3.dart';
import 'package:venera/foundation/app.dart';
import 'package:venera/foundation/appdata.dart';
import 'package:venera/foundation/comic_source/comic_source.dart';
import 'package:venera/foundation/comic_type.dart';
import 'package:venera/foundation/favorites.dart';
import 'package:venera/foundation/history.dart';
import 'package:venera/foundation/log.dart';
import 'package:venera/network/cookie_jar.dart';
import 'package:venera/utils/ext.dart';
import 'package:zip_flutter/zip_flutter.dart';

import 'io.dart';

Future<File> exportAppData([bool sync = true]) async {
  var time = DateTime.now().millisecondsSinceEpoch ~/ 1000;
  var cacheFilePath = FilePath.join(App.cachePath, '$time.venera');
  var cacheFile = File(cacheFilePath);
  var dataPath = App.dataPath;
  if (await cacheFile.exists()) {
    await cacheFile.delete();
  }
  await Isolate.run(() {
    var zipFile = ZipFile.open(cacheFilePath);
    var historyFile = FilePath.join(dataPath, "history.db");
    var localFavoriteFile = FilePath.join(dataPath, "local_favorite.db");
    var appdata = FilePath.join(dataPath, sync ? "syncdata.json" : "appdata.json");
    var cookies = FilePath.join(dataPath, "cookie.db");
    zipFile.addFile("history.db", historyFile);
    zipFile.addFile("local_favorite.db", localFavoriteFile);
    zipFile.addFile("appdata.json", appdata);
    zipFile.addFile("cookie.db", cookies);
    for (var file
        in Directory(FilePath.join(dataPath, "comic_source")).listSync()) {
      if (file is File) {
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
  if (cacheDir.existsSync()) {
    cacheDir.deleteSync(recursive: true);
  }
  cacheDir.createSync();
  try {
    await Isolate.run(() {
      ZipFile.openAndExtract(file.path, cacheDirPath);
    });
    var historyFile = cacheDir.joinFile("history.db");
    var localFavoriteFile = cacheDir.joinFile("local_favorite.db");
    var appdataFile = cacheDir.joinFile("appdata.json");
    var cookieFile = cacheDir.joinFile("cookie.db");
    if (checkVersion && appdataFile.existsSync()) {
      var data = jsonDecode(await appdataFile.readAsString());
      var version = data["settings"]["dataVersion"];
      if (version is int && version <= appdata.settings["dataVersion"]) {
        return;
      }
    }
    if (await historyFile.exists()) {
      HistoryManager().close();
      File(FilePath.join(App.dataPath, "history.db")).deleteIfExistsSync();
      historyFile.renameSync(FilePath.join(App.dataPath, "history.db"));
      HistoryManager().init();
    }
    if (await localFavoriteFile.exists()) {
      LocalFavoritesManager().close();
      File(FilePath.join(App.dataPath, "local_favorite.db"))
          .deleteIfExistsSync();
      localFavoriteFile
          .renameSync(FilePath.join(App.dataPath, "local_favorite.db"));
      LocalFavoritesManager().init();
    }
    if (await appdataFile.exists()) {
      var content = await appdataFile.readAsString();
      var data = jsonDecode(content);
      appdata.syncData(data);
    }
    if (await cookieFile.exists()) {
      SingleInstanceCookieJar.instance?.dispose();
      File(FilePath.join(App.dataPath, "cookie.db")).deleteIfExistsSync();
      cookieFile.renameSync(FilePath.join(App.dataPath, "cookie.db"));
      SingleInstanceCookieJar.instance =
          SingleInstanceCookieJar(FilePath.join(App.dataPath, "cookie.db"))
            ..init();
    }
    var comicSourceDir = FilePath.join(cacheDirPath, "comic_source");
    if (Directory(comicSourceDir).existsSync()) {
      Directory(FilePath.join(App.dataPath, "comic_source"))
          .deleteIfExistsSync(recursive: true);
      Directory(FilePath.join(App.dataPath, "comic_source")).createSync();
      for (var file in Directory(comicSourceDir).listSync()) {
        if (file is File) {
          var targetFile =
              FilePath.join(App.dataPath, "comic_source", file.name);
          await file.copy(targetFile);
        }
      }
      await ComicSourceManager().reload();
    }
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}

Future<void> _mergeHistory(String localDbPath, String remoteDbPath) async {
  final localDb = sqlite3.open(localDbPath);
  localDb.execute('PRAGMA journal_mode = WAL;');
  localDb.execute('PRAGMA synchronous = NORMAL;');
  final remoteDb = sqlite3.open(remoteDbPath);

  final remoteHistories = remoteDb.select('SELECT * FROM history');

  for (final remoteHistory in remoteHistories) {
    final id = remoteHistory['id'] as String;
    final localHistory = localDb.select('SELECT * FROM history WHERE id = ?', [id]);

    if (localHistory.isEmpty) {
      // History doesn't exist locally, so add it.
      var cols = remoteHistory.keys.join(",");
      var placeholders = remoteHistory.keys.map((e) => "?").join(",");
      localDb.execute(
        'INSERT INTO history ($cols) VALUES ($placeholders)',
        remoteHistory.values.toList(),
      );
    } else {
      // History exists, merge based on timestamp.
      final localTime = localHistory.first['time'] as int;
      final remoteTime = remoteHistory['time'] as int;
      if (remoteTime > localTime) {
        // Remote is newer, update local.
        var updateSql = remoteHistory.keys.where((k) => k != 'id').map((k) => "$k = ?").join(",");
        var values = remoteHistory.keys.where((k) => k != 'id').map((k) => remoteHistory[k]).toList();
        localDb.execute(
          'UPDATE history SET $updateSql WHERE id = ?',
          [...values, id],
        );
      }
    }
  }

  localDb.dispose();
  remoteDb.dispose();
}

Future<void> _mergeFavorites(String localDbPath, String remoteDbPath) async {
  final localDb = sqlite3.open(localDbPath);
  localDb.execute('PRAGMA journal_mode = WAL;');
  localDb.execute('PRAGMA synchronous = NORMAL;');
  final remoteDb = sqlite3.open(remoteDbPath);

  final remoteFolders = remoteDb
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((e) => e['name'] as String)
      .where((name) => name != 'folder_order' && name != 'folder_sync')
      .toList();

  final localFolders = localDb
      .select("SELECT name FROM sqlite_master WHERE type='table'")
      .map((e) => e['name'] as String)
      .where((name) => name != 'folder_order' && name != 'folder_sync')
      .toList();

  for (final folder in remoteFolders) {
    if (!localFolders.contains(folder)) {
      // Create folder if it doesn't exist locally.
      localDb.execute("""
        create table "$folder"(
          id text,
          name TEXT,
          author TEXT,
          type int,
          tags TEXT,
          cover_path TEXT,
          time TEXT,
          display_order int,
          translated_tags TEXT,
          primary key (id, type)
        );
      """);
    }

    // Ensure columns exist
    var columns = localDb.select("PRAGMA table_info(\"$folder\");").map((e) => e['name'] as String).toList();
    var remoteColumns = remoteDb.select("PRAGMA table_info(\"$folder\");").map((e) => e['name'] as String).toList();
    for (var col in remoteColumns) {
      if (!columns.contains(col)) {
        localDb.execute("ALTER TABLE \"$folder\" ADD COLUMN $col ${remoteDb.select("PRAGMA table_info(\"$folder\");").firstWhere((e) => e['name'] == col)['type']};");
      }
    }
    columns = localDb.select("PRAGMA table_info(\"$folder\");").map((e) => e['name'] as String).toList();

    final remoteComics = remoteDb.select('SELECT * FROM "$folder"');
    for (final remoteComic in remoteComics) {
      final id = remoteComic['id'] as String;
      final type = remoteComic['type'] as int;
      final localComic = localDb.select('SELECT * FROM "$folder" WHERE id = ? AND type = ?', [id, type]);

      if (localComic.isEmpty) {
        // Comic doesn't exist, so add it.
        var cols = remoteComic.keys.join(",");
        var placeholders = remoteComic.keys.map((e) => "?").join(",");
        localDb.execute(
          'INSERT INTO "$folder" ($cols) VALUES ($placeholders)',
          remoteComic.values.toList(),
        );
      } else {
        // Comic exists, merge based on timestamp.
        final localTime = DateTime.parse(localComic.first['time'] as String);
        final remoteTime = DateTime.parse(remoteComic['time'] as String);
        if (remoteTime.isAfter(localTime)) {
          // Remote is newer, update local.
          var updateSql = remoteComic.keys.where((k) => k != 'id' && k != 'type').map((k) => "$k = ?").join(",");
          var values = remoteComic.keys.where((k) => k != 'id' && k != 'type').map((k) => remoteComic[k]).toList();
          localDb.execute(
            'UPDATE "$folder" SET $updateSql WHERE id = ? AND type = ?',
            [...values, id, type],
          );
        }
      }
    }
  }

  // Merge folder_order and folder_sync
  for (var table in ['folder_order', 'folder_sync']) {
    var remoteData = remoteDb.select('SELECT * FROM $table');
    var primaryKey = table == 'folder_order' ? 'folder_name' : 'folder_name'; // Both use folder_name as PK
    for (var row in remoteData) {
      var pkValue = row[primaryKey];
      var localRow = localDb.select('SELECT * FROM $table WHERE $primaryKey = ?', [pkValue]);
      if (localRow.isEmpty) {
        var cols = row.keys.join(",");
        var placeholders = row.keys.map((e) => "?").join(",");
        localDb.execute('INSERT INTO $table ($cols) VALUES ($placeholders)', row.values.toList());
      }
    }
  }

  localDb.dispose();
  remoteDb.dispose();
}

Future<void> mergeAppData(File file) async {
  var cacheDirPath = FilePath.join(App.cachePath, 'temp_data');
  var cacheDir = Directory(cacheDirPath);
  if (cacheDir.existsSync()) {
    cacheDir.deleteSync(recursive: true);
  }
  cacheDir.createSync();
  try {
    await Isolate.run(() {
      ZipFile.openAndExtract(file.path, cacheDirPath);
    });

    var remoteHistoryFile = cacheDir.joinFile("history.db");
    var remoteLocalFavoriteFile = cacheDir.joinFile("local_favorite.db");
    var remoteAppdataFile = cacheDir.joinFile("appdata.json");

    // Merge history
    if (await remoteHistoryFile.exists()) {
      HistoryManager().close();
      await _mergeHistory(FilePath.join(App.dataPath, "history.db"), remoteHistoryFile.path);
      HistoryManager().init();
    }

    // Merge favorites
    if (await remoteLocalFavoriteFile.exists()) {
      LocalFavoritesManager().close();
      await _mergeFavorites(FilePath.join(App.dataPath, "local_favorite.db"), remoteLocalFavoriteFile.path);
      LocalFavoritesManager().init();
    }

    // Merge appdata.json
    if (await remoteAppdataFile.exists()) {
      var remoteContent = await remoteAppdataFile.readAsString();
      var remoteData = jsonDecode(remoteContent);
      appdata.syncData(remoteData);
    }
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}

Future<void> importPicaData(File file) async {
  var cacheDirPath = FilePath.join(App.cachePath, 'temp_data');
  var cacheDir = Directory(cacheDirPath);
  if (cacheDir.existsSync()) {
    cacheDir.deleteSync(recursive: true);
  }
  cacheDir.createSync();
  try {
    await Isolate.run(() {
      ZipFile.openAndExtract(file.path, cacheDirPath);
    });
    var localFavoriteFile = cacheDir.joinFile("local_favorite.db");
    if (localFavoriteFile.existsSync()) {
      var db = sqlite3.open(localFavoriteFile.path);
      try {
        var folderNames = db
            .select("SELECT name FROM sqlite_master WHERE type='table';")
            .map((e) => e["name"] as String)
            .toList();
        folderNames
            .removeWhere((e) => e == "folder_order" || e == "folder_sync");
        for (var folderSyncValue in db.select("SELECT * FROM folder_sync;")) {
          var folderName = folderSyncValue["folder_name"];
          String sourceKey = folderSyncValue["key"];
          sourceKey =
              sourceKey.toLowerCase() == "htmanga" ? "wnacg" : sourceKey;
          // 有值就跳过
          if (LocalFavoritesManager().findLinked(folderName).$1 != null) {
            continue;
          }
          try {
            LocalFavoritesManager().linkFolderToNetwork(folderName, sourceKey,
                jsonDecode(folderSyncValue["sync_data"])["folderId"]);
          } catch (e, stack) {
            Log.error(e.toString(), stack);
          }
        }
        for (var folderName in folderNames) {
          if (!LocalFavoritesManager().existsFolder(folderName)) {
            LocalFavoritesManager().createFolder(folderName);
          }
          for (var comic in db.select("SELECT * FROM \"$folderName\";")) {
            LocalFavoritesManager().addComic(
              folderName,
              FavoriteItem(
                id: comic['target'],
                name: comic['name'],
                coverPath: comic['cover_path'],
                author: comic['author'],
                type: ComicType(switch (comic['type']) {
                  0 => 'picacg'.hashCode,
                  1 => 'ehentai'.hashCode,
                  2 => 'jm'.hashCode,
                  3 => 'hitomi'.hashCode,
                  4 => 'wnacg'.hashCode,
                  6 => 'nhentai'.hashCode,
                  _ => comic['type']
                }),
                tags: comic['tags'].split(','),
              ),
            );
          }
        }
      } catch (e) {
        Log.error("Import Data", "Failed to import local favorite: $e");
      } finally {
        db.dispose();
      }
    }
    var historyFile = cacheDir.joinFile("history.db");
    if (historyFile.existsSync()) {
      var db = sqlite3.open(historyFile.path);
      try {
        for (var comic in db.select("SELECT * FROM history;")) {
          HistoryManager().addHistory(
            History.fromMap({
              "type": switch (comic['type']) {
                0 => 'picacg'.hashCode,
                1 => 'ehentai'.hashCode,
                2 => 'jm'.hashCode,
                3 => 'hitomi'.hashCode,
                4 => 'wnacg'.hashCode,
                5 => 'nhentai'.hashCode,
                _ => comic['type']
              },
              "id": comic['target'],
              "max_page": comic["max_page"],
              "ep": comic["ep"],
              "page": comic["page"],
              "time": comic["time"],
              "title": comic["title"],
              "subtitle": comic["subtitle"],
              "cover": comic["cover"],
              "readEpisode": [comic["ep"]],
            }),
          );
        }
        List<ImageFavoritesComic> imageFavoritesComicList =
            ImageFavoriteManager().comics;
        for (var comic in db.select("SELECT * FROM image_favorites;")) {
          String sourceKey = comic["id"].split("-")[0];
          // 换名字了, 绅士漫画
          if (sourceKey.toLowerCase() == "htmanga") {
            sourceKey = "wnacg";
          }
          if (ComicSource.find(sourceKey) == null) {
            continue;
          }
          String id = comic["id"].split("-")[1];
          int page = comic["page"];
          // 章节和page是从1开始的, pica 可能有从 0 开始的, 得转一下
          int ep = comic["ep"] == 0 ? 1 : comic["ep"];
          String title = comic["title"];
          String epName = "";
          ImageFavoritesComic? tempComic = imageFavoritesComicList
              .firstWhereOrNull((e) => e.id == id && e.sourceKey == sourceKey);
          ImageFavorite curImageFavorite =
              ImageFavorite(page, "", null, "", id, ep, sourceKey, epName);
          if (tempComic == null) {
            tempComic = ImageFavoritesComic(id, [], title, sourceKey, [], [],
                DateTime.now(), "", {}, "", 1);
            tempComic.imageFavoritesEp = [
              ImageFavoritesEp("", ep, [curImageFavorite], epName, 1)
            ];
            imageFavoritesComicList.add(tempComic);
          } else {
            ImageFavoritesEp? tempEp =
                tempComic.imageFavoritesEp.firstWhereOrNull((e) => e.ep == ep);
            if (tempEp == null) {
              tempComic.imageFavoritesEp
                  .add(ImageFavoritesEp("", ep, [curImageFavorite], epName, 1));
            } else {
              // 如果已经有这个page了, 就不添加了
              if (tempEp.imageFavorites
                      .firstWhereOrNull((e) => e.page == page) ==
                  null) {
                tempEp.imageFavorites.add(curImageFavorite);
              }
            }
          }
        }
        for (var temp in imageFavoritesComicList) {
          ImageFavoriteManager().addOrUpdateOrDelete(
            temp,
            temp == imageFavoritesComicList.last,
          );
        }
      } catch (e, stack) {
        Log.error("Import Data", "Failed to import history: $e", stack);
      } finally {
        db.dispose();
      }
    }
  } finally {
    cacheDir.deleteIgnoreError(recursive: true);
  }
}
